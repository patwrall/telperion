import asyncio
import collections
import datetime
import json
import logging
import time

from . import agent as agent_mod
from . import audio
from . import brain as brain_mod
from . import collectors, hypr, intent, llm, store, tts, wake
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
        self.store = store.Store()
        self.world = collectors.WorldState(self.store)
        self.world.on_command_end = self._on_command_end
        self.agent = agent_mod.Agent(config, self.store) if config.agent_cmd else None
        self.brain = (
            brain_mod.Brain(
                config.agent_cmd,
                config.brain_model,
                config.brain_max_turns,
                store=self.store,
            )
            if config.agent_cmd and config.brain_model
            else None
        )
        # rolling conversation memory, reloaded from disk so a restart is
        # not amnesia; makes the fast tier reference what was just said
        self.history: collections.deque[str] = collections.deque(
            self.store.recent_exchanges(8), maxlen=8
        )
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

        tasks = [asyncio.create_task(collectors.watch_hyprland(self.world))]
        if self.brain is not None:
            # pay the process cold-start at boot, not on the first question
            tasks.append(asyncio.create_task(self.brain.start()))
        tasks.append(asyncio.create_task(self.speaker.prime_fillers()))
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
                self._say_chat(text)
            return "unknown"

        if parsed.action == "sleep":
            # canned ack: the responder LLM is about to be stopped
            await self.speaker.say(parsed.ack)
            self._sleep()
        elif parsed.action == "wake":
            await self._wake_models()
            self._say_response(text, "woke up; models reloaded", fallback=parsed.ack)
        elif parsed.action == "delegate":
            if intent.is_status_question(text):
                # answerable from live state; don't burn an agent run on it
                self._say_chat(text)
                return "status"
            return self._delegate(text, parsed.task or text, watch)
        elif parsed.action == "details":
            return await self._details(text)
        elif parsed.action == "remember":
            fact = (parsed.task or text).strip()
            self._memory_append(fact)
            self._say_response(
                text,
                f"noted to long-term memory: {fact}. Confirm briefly",
                fallback="Noted.",
            )
            return "remember"
        elif parsed.action == "cancel":
            if self.agent is not None and self.agent.cancel():
                self._say_response(
                    text, "background task cancelled", fallback="Dropped it."
                )
            else:
                self._say_response(
                    text,
                    "there was nothing running to cancel",
                    fallback="Nothing running.",
                )
            return "cancel"
        else:
            await hypr.run_intent(parsed.action, parsed.arg)
            arg = f" {parsed.arg}" if parsed.arg is not None else ""
            self._say_response(text, f"done: {parsed.action}{arg}", fallback=parsed.ack)
        watch.lap("act")

        arg = f"({parsed.arg})" if parsed.arg is not None else ""
        return f"{parsed.action}{arg}"

    # -- reasoning tier ------------------------------------------------------

    def _delegate(self, said: str, task: str, watch) -> str:
        if self.agent is None:
            self._say_response(
                said,
                "no reasoning tier is configured",
                fallback="I can't think that hard yet.",
            )
            return "unknown"
        if self.agent.busy:
            self._say_response(
                said,
                "SYSTEM STATE: a background task for the user's earlier question "
                "is still running. Say ONLY a short plain line that you're still "
                "on it and the answer is coming",
                fallback="Still on it.",
            )
            return "agent-busy"
        self._say_response(
            said,
            f"you just started working on: {task}. Say a short natural on-it "
            "line naming the topic in a few words. Do NOT attempt to answer yet",
            fallback="On it.",
        )
        asyncio.create_task(self._run_agent(said, task))
        watch.lap("act")
        return f"delegate({task[:60]})"

    async def _run_agent(self, said: str, task: str):
        agent_task = asyncio.create_task(
            self.agent.run(task, await self._context_line())
        )

        async def status_line():
            await asyncio.sleep(30)
            if not agent_task.done():
                self._say_response(
                    said, "still working on it, going deep", fallback="Still digging."
                )

        status = asyncio.create_task(status_line())
        try:
            report = await agent_task
        except agent_mod.AgentError as exc:
            if str(exc) == "cancelled":
                return  # the cancel handler already spoke
            log.warning("agent task failed: %s", exc)
            self._say_response(
                said,
                f"the task failed: {str(exc)[:200]}",
                fallback="That one fell apart on me.",
            )
            return
        except Exception:
            log.exception("agent task crashed")
            self._say_response(
                said,
                "the reasoning tier crashed",
                fallback="Something broke back there.",
            )
            return
        finally:
            status.cancel()

        self.agent.last_task = task
        self.store.set("agent_last_task", task)
        try:
            line = await llm.summarize(
                self._ensure_http(), self.config.llama_url, task, report
            )
        except Exception as exc:
            log.warning("summarizer failed (%s); speaking first sentence", exc)
            line = report.split(". ")[0][:200]
        self._remember("huan", f"(after working on '{task[:60]}') {line}")
        log.info("agent summary: %r", line)
        await self.speaker.say(line)

    async def _details(self, said: str) -> str:
        if self.agent is None or not self.agent.last_result:
            self._say_response(
                said,
                "there is no previous answer to expand on",
                fallback="Nothing to expand yet.",
            )
            return "details-empty"
        try:
            line = await llm.expand(
                self._ensure_http(),
                self.config.llama_url,
                self.agent.last_task,
                self.agent.last_result,
            )
        except Exception as exc:
            log.warning("expand failed: %s", exc)
            line = self.agent.last_result[:400]
        self._remember("huan", f"(details) {line[:120]}")
        log.info("details: %r", line)
        await self.speaker.say(line)
        return "details"

    def _remember(self, role: str, text: str):
        self.history.append(f"{role}: {text}")
        self.store.add_exchange(role, text)

    def _say_chat(self, said: str):
        """Conversational turn: the brain (real model, own memory) when
        available, 3B responder as fallback. Off the critical path."""
        self._remember("user", said)

        async def _chat():
            if self.brain is not None:
                loop = asyncio.get_running_loop()
                filler = loop.call_later(1.3, self.speaker.play_filler)

                def speak_sentence(sentence: str):
                    filler.cancel()
                    asyncio.create_task(self.speaker.say(sentence))

                try:
                    reply = await self.brain.ask(
                        said, await self._world_context(), on_sentence=speak_sentence
                    )
                    self._remember("huan", reply)
                    log.info("brain: %r", reply)
                    return
                except Exception as exc:
                    log.warning("brain failed (%s); 3B fallback", exc)
                finally:
                    filler.cancel()
            self._ensure_http()
            try:
                line = await llm.respond(
                    self._llm_http,
                    self.config.llama_url,
                    said,
                    "no command action taken; answer from the context state if "
                    "it contains the answer, otherwise say you don't have that",
                    await self._context_line(),
                )
            except Exception:
                line = "I didn't catch that."
            self._remember("huan", line)
            log.info("respond: %r", line)
            await self.speaker.say(line)

        asyncio.create_task(_chat())

    async def _world_context(self) -> str:
        """Context for the brain: live state only — it keeps its own
        conversation memory, so feeding history back would double it."""
        parts = [
            f"local time {datetime.datetime.now():%a %H:%M}",
            self.world.describe(),
        ]
        playing = await collectors.now_playing()
        if playing:
            parts.append(f"playing: {playing}")
        facts = self._memory_facts()
        if facts:
            parts.append(f"known facts about the user: {facts}")
        return ", ".join(parts)

    # -- long-term memory (user-editable markdown file) ----------------------

    @property
    def _memory_path(self):
        return self.store.path.parent / "memory.md"

    def _memory_append(self, fact: str):
        with open(self._memory_path, "a") as f:
            f.write(f"- {fact} ({datetime.date.today()})\n")
        log.info("memory: %r", fact)

    def _memory_facts(self, cap: int = 800) -> str:
        try:
            text = self._memory_path.read_text().strip()
        except OSError:
            return ""
        facts = [
            line.lstrip("- ").strip() for line in text.splitlines() if line.strip()
        ]
        return "; ".join(facts)[-cap:]

    # -- proactive announcements ---------------------------------------------

    def _on_command_end(self, entry: dict):
        threshold = self.config.announce_min_s
        if threshold <= 0 or entry["duration_s"] < threshold or self.sleeping:
            return
        status = (
            "succeeded"
            if entry.get("exit") == 0
            else f"failed with exit {entry.get('exit')}"
        )
        self._say_response(
            "(no user utterance: proactive announcement)",
            f"SYSTEM STATE: the user's command `{entry['cmd'][:60]}` just "
            f"{status} after {entry['duration_s']:.0f}s. Briefly announce this "
            "unprompted, like a colleague calling it across the room",
            fallback=f"Your command {status}.",
        )

    def _ensure_http(self):
        import httpx

        if self._llm_http is None:
            self._llm_http = httpx.AsyncClient()
        return self._llm_http

    async def _context_line(self) -> str:
        parts = [await self._world_context()]
        if self.history:
            recent = "; ".join(list(self.history)[-4:])
            parts.append(f"recent conversation: {recent}")
        return ", ".join(parts)

    def _say_response(self, said: str, happened: str, fallback: str):
        """Speak an LLM-generated line off the critical path; the action has
        already been dispatched by the time this is even scheduled."""
        self._remember("user", said)
        if not self.config.llama_url:
            asyncio.create_task(self.speaker.say(fallback))
            return

        async def _generate():
            self._ensure_http()
            try:
                line = await llm.respond(
                    self._llm_http,
                    self.config.llama_url,
                    said,
                    happened,
                    await self._context_line(),
                )
            except Exception as exc:
                log.warning("responder failed (%s); using fallback line", exc)
                line = fallback
            self._remember("huan", line)
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
        if cmd == "event":
            self.world.shell_event(request.get("data", {}))
            return {"ok": True}
        if cmd == "context":
            return {"ok": True, "context": await self._context_line()}
        return {"ok": False, "error": f"unknown command {cmd!r}"}


def run(config_path: str | None):
    logging.basicConfig(
        level=logging.INFO, format="%(asctime)s %(name)s %(levelname)s %(message)s"
    )
    config = Config.load(config_path)
    config.control_socket.unlink(missing_ok=True)
    asyncio.run(Daemon(config).run())
