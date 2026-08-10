import asyncio
import json
import logging
import time

from . import audio, hypr, intent, llm, tts, wake
from .config import Config

log = logging.getLogger("huan")


class Stopwatch:
    """Per-request stage timings. The whole point of v1 is proving the
    latency budget, so every pipeline run logs one line of real numbers."""

    def __init__(self):
        self._t0 = time.perf_counter()
        self._last = self._t0
        self.laps: dict[str, float] = {}

    def lap(self, name: str):
        now = time.perf_counter()
        self.laps[name] = (now - self._last) * 1000
        self._last = now

    def total_ms(self) -> float:
        return (time.perf_counter() - self._t0) * 1000

    def summary(self) -> str:
        stages = " ".join(f"{k}={v:.0f}" for k, v in self.laps.items())
        return f"{self.total_ms():.0f}ms [{stages}]"


class Daemon:
    def __init__(self, config: Config):
        self.config = config
        self.stt = None  # created in run() so imports stay off the fast path
        self.mic = None
        self.speaker = tts.Speaker(config)
        self._llm_http = None
        self.sleeping = False
        self._pipeline_lock = asyncio.Lock()
        self._ptt_stop: asyncio.Event | None = None

    async def run(self):
        from .stt import SpeechToText

        self.mic = audio.Microphone(self.config.sample_rate)
        self.detector = audio.make_speech_detector(self.config.rms_threshold)
        self.stt = SpeechToText(
            self.config.stt_model,
            self.config.stt_device,
            self.config.stt_compute_type,
        )
        if self.config.preload_stt:
            await asyncio.to_thread(self.stt.load)

        server = await asyncio.start_unix_server(
            self._handle_control, path=str(self.config.control_socket)
        )
        log.info("control socket at %s", self.config.control_socket)

        tasks = []
        if self.config.wake_enabled:
            tasks.append(
                asyncio.create_task(
                    wake.listen(
                        self.mic,
                        self.config.wake_uri,
                        self.config.wake_names,
                        self._on_wake_word,
                        suppress=lambda: self.speaker.speaking,
                    )
                )
            )

        async with server:
            await asyncio.gather(server.serve_forever(), *tasks)

    # -- activation paths ----------------------------------------------------

    async def _on_wake_word(self, name: str):
        if self._pipeline_lock.locked():
            log.info("wake word %r ignored: pipeline busy", name)
            return
        log.info("wake word %r detected", name)
        # a wake word followed by silence gives up after the onset window
        # instead of holding an open capture until the length cap
        asyncio.create_task(
            self._run_pipeline(
                source=f"wake:{name}",
                onset_timeout_ms=int(self.config.followup_s * 1000) or None,
            )
        )

    def _ptt_start(self) -> str:
        if self._ptt_stop is not None:
            return "already recording"
        if self._pipeline_lock.locked():
            return "busy"
        self._ptt_stop = asyncio.Event()
        asyncio.create_task(self._run_pipeline(source="ptt", stop_event=self._ptt_stop))
        return "recording"

    def _ptt_stop_cmd(self) -> str:
        if self._ptt_stop is None:
            return "not recording"
        self._ptt_stop.set()
        return "stopped"

    # -- pipeline ------------------------------------------------------------

    async def _run_pipeline(
        self,
        source: str,
        stop_event: asyncio.Event | None = None,
        text: str | None = None,
        onset_timeout_ms: int | None = None,
    ):
        followup = False
        async with self._pipeline_lock:
            watch = Stopwatch()
            try:
                if text is None:
                    await self.speaker.wait_quiet()
                    captured = await audio.capture_utterance(
                        self.mic,
                        self.detector,
                        silence_ms=self.config.silence_ms,
                        max_s=self.config.max_utterance_s,
                        stop_event=stop_event,
                        suppress=lambda: self.speaker.speaking,
                        onset_timeout_ms=onset_timeout_ms,
                    )
                    watch.lap("capture")
                    if len(captured) == 0:
                        log.info("%s: no speech in window", source)
                        return
                    if self.sleeping and not self.stt.loaded:
                        log.info("waking: reloading STT (cold start)")
                    text = await asyncio.to_thread(self.stt.transcribe, captured)
                    self.sleeping = False
                    watch.lap("stt")
                    if not text:
                        log.info("%s %s: empty transcript", source, watch.summary())
                        return
                result = await self._act(text, watch, quiet=source == "followup")
                log.info("%s %s text=%r -> %s", source, watch.summary(), text, result)
                followup = (
                    self.config.followup_s > 0
                    and source.startswith(("wake:", "followup"))
                    and result not in ("unknown", "sleep")
                )
            except Exception:
                log.exception("%s pipeline failed after %s", source, watch.summary())
            finally:
                if stop_event is not None:
                    self._ptt_stop = None
        if followup:
            asyncio.create_task(
                self._run_pipeline(
                    source="followup",
                    onset_timeout_ms=int(self.config.followup_s * 1000),
                )
            )

    async def _act(self, text: str, watch: Stopwatch, quiet: bool = False) -> str:
        parsed = intent.classify(text)
        watch.lap("intent")
        if parsed is None and self.config.llama_url:
            import httpx

            if self._llm_http is None:
                self._llm_http = httpx.AsyncClient()
            try:
                parsed = await llm.classify(self._llm_http, self.config.llama_url, text)
            except Exception as exc:
                log.warning("llm intent failed: %s", exc)
            watch.lap("intent_llm")
        if parsed is None:
            # in the follow-up window, unmatched speech is probably not
            # aimed at us; complaining about it would be obnoxious
            if not quiet:
                self._say_response(
                    text,
                    "nothing matched; no action taken",
                    fallback="I didn't catch that",
                )
            return "unknown"

        if parsed.action == "sleep":
            # canned ack: the responder LLM is about to be stopped
            await self.speaker.say(parsed.ack)
            self._sleep()
        elif parsed.action == "wake":
            await self._wake_models()
            self._say_response(text, "woke up; models reloaded", fallback=parsed.ack)
        else:
            await hypr.run_intent(parsed.action, parsed.arg)
            arg = f" {parsed.arg}" if parsed.arg is not None else ""
            self._say_response(text, f"done: {parsed.action}{arg}", fallback=parsed.ack)
        watch.lap("act")

        arg = f"({parsed.arg})" if parsed.arg is not None else ""
        return f"{parsed.action}{arg}"

    def _say_response(self, said: str, happened: str, fallback: str):
        """Speak an LLM-generated line off the critical path; the action has
        already been dispatched by the time this is even scheduled."""
        if not self.config.llama_url:
            asyncio.create_task(self.speaker.say(fallback))
            return

        async def _generate():
            import httpx

            if self._llm_http is None:
                self._llm_http = httpx.AsyncClient()
            try:
                import datetime

                title = await hypr.active_window_title()
                context = f"local time {datetime.datetime.now():%H:%M}, focused window: {title or 'none'}"
                line = await llm.respond(
                    self._llm_http, self.config.llama_url, said, happened, context
                )
            except Exception as exc:
                log.warning("responder failed (%s); using fallback line", exc)
                line = fallback
            log.info("respond: %r", line)
            await self.speaker.say(line)

        asyncio.create_task(_generate())

    def _sleep(self):
        self.stt.unload()
        self.sleeping = True
        if self.config.llama_url:
            asyncio.create_task(self._llama_service("stop"))
        log.info("sleeping: GPU models unloaded (wake word stays on CPU)")

    async def _wake_models(self):
        if self.config.llama_url:
            await self._llama_service("start")
        await asyncio.to_thread(self.stt.load)
        self.sleeping = False

    async def _llama_service(self, verb: str):
        proc = await asyncio.create_subprocess_exec(
            "systemctl", "--user", verb, "huan-llama.service"
        )
        await proc.wait()
        if proc.returncode != 0:
            log.warning("systemctl --user %s huan-llama failed", verb)

    # -- control socket ------------------------------------------------------

    async def _handle_control(self, reader, writer):
        try:
            line = await reader.readline()
            if not line:
                return
            request = json.loads(line)
            response = await self._dispatch_control(request)
        except Exception as exc:
            response = {"ok": False, "error": str(exc)}
        writer.write((json.dumps(response) + "\n").encode())
        await writer.drain()
        writer.close()

    async def _dispatch_control(self, request: dict) -> dict:
        cmd = request.get("cmd")
        if cmd == "status":
            return {
                "ok": True,
                "sleeping": self.sleeping,
                "stt_loaded": self.stt.loaded,
                "recording": self._ptt_stop is not None,
            }
        if cmd == "ptt-start":
            return {"ok": True, "state": self._ptt_start()}
        if cmd == "ptt-stop":
            return {"ok": True, "state": self._ptt_stop_cmd()}
        if cmd == "sleep":
            self._sleep()
            return {"ok": True}
        if cmd == "wake":
            await self._wake_models()
            return {"ok": True}
        if cmd == "toggle":
            if self.sleeping:
                await self._wake_models()
            else:
                self._sleep()
            return {"ok": True, "sleeping": self.sleeping}
        if cmd == "text":
            await self._run_pipeline(source="text", text=request.get("text", ""))
            return {"ok": True}
        if cmd == "say":
            await self.speaker.say(request.get("text", ""))
            return {"ok": True}
        return {"ok": False, "error": f"unknown command {cmd!r}"}


def run(config_path: str | None):
    logging.basicConfig(
        level=logging.INFO, format="%(asctime)s %(name)s %(levelname)s %(message)s"
    )
    config = Config.load(config_path)
    config.control_socket.unlink(missing_ok=True)
    asyncio.run(Daemon(config).run())
