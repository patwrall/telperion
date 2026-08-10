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
                mcp_config=config.agent_mcp_config,
                collaborator=config.brain_collaborator,
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
        self._last_chat_ts = 0.0
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

        tasks = [
            asyncio.create_task(collectors.watch_hyprland(self.world)),
            asyncio.create_task(collectors.watch_notifications(self.world)),
        ]
        if self.brain is not None:
            # pay the process cold-start at boot, not on the first question
            tasks.append(asyncio.create_task(self.brain.start()))
        tasks.append(asyncio.create_task(self.speaker.prime_fillers()))
        if self.config.wake_enabled:
            # the wake stream stays live during huan's own speech so the
            # wake word barges in; capture stays echo-gated separately
            tasks.append(
                asyncio.create_task(
                    wake.listen(
                        self.mic,
                        self.config.wake_uri,
                        self.config.wake_names,
                        self._on_wake_word,
                    )
                )
            )

        async with server:
            await asyncio.gather(server.serve_forever(), *tasks)

    # -- activation paths ----------------------------------------------------

    async def _on_wake_word(self, name: str):
        # barge-in: the wake word mid-speech cuts huan off and listens
        self.speaker.interrupt()
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
        self.speaker.interrupt()  # push-to-talk doubles as the barge-in button
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
                    # mid-thought pause: keep listening and splice instead
                    # of answering fragments ("what version of" ... "cuda").
                    # never delay a transcript that already resolves to a
                    # command ("switch to workspace to" is complete)
                    for _ in range(3):
                        if intent.classify(text) is not None:
                            break
                        if not intent.looks_unfinished(text):
                            break
                        log.info(
                            "%s: unfinished (%r), listening on", source, text[-30:]
                        )
                        more = await audio.capture_utterance(
                            self.mic,
                            self.detector,
                            silence_ms=self.config.silence_ms,
                            max_s=self.config.max_utterance_s,
                            suppress=lambda: self.speaker.speaking,
                            onset_timeout_ms=2000,
                        )
                        if len(more) == 0:
                            break
                        continuation = await asyncio.to_thread(
                            self.stt.transcribe, more
                        )
                        if not continuation:
                            break
                        text = f"{text} {continuation}"
                    watch.lap("splice")
                result = await self._act(text, watch, quiet=source == "followup")
                log.info("%s %s text=%r -> %s", source, watch.summary(), text, result)
                # chat turns ("unknown"/"status") schedule their own hot
                # window after the reply finishes speaking
                followup = (
                    self.config.followup_s > 0
                    and source.startswith(("wake:", "followup"))
                    and result not in ("unknown", "status", "sleep")
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
            # in the follow-up window, unmatched speech is usually musing —
            # unless a chat exchange just happened, in which case the
            # conversation is hot and continuing it is the human behavior
            if not quiet or self._conversation_hot():
                self._say_chat(text)
            return "unknown"

        if parsed.action == "sleep":
            # canned ack: the responder LLM is about to be stopped
            await self.speaker.say(parsed.ack)
            self._sleep()
        elif parsed.action == "wake":
            await self._wake_models()
            self._say_response(text, "woke up; models reloaded", fallback=parsed.ack)
        elif parsed.action == "media":
            ok = await collectors.media_control(parsed.task or "play-pause")
            self._say_response(
                text,
                f"media {parsed.task}: {'done' if ok else 'no player responded'}",
                fallback="Done." if ok else "No player's listening.",
            )
        elif parsed.action == "delegate":
            if intent.is_status_question(text):
                # answerable from live state; don't burn an agent run on it
                self._say_chat(text)
                return "status"
            # the brain decides: a concrete task gets delegate_task, a vague
            # one gets a clarifying question first ('write a python script'
            # burned an agent run just to ask what script)
            self._say_chat(text)
            return "delegate-via-brain"
        elif parsed.action == "details":
            # agent reports live in the brain's conversation since the relay
            # change; it expands them with full context
            self._say_chat(text)
            return "details-via-brain"
        elif parsed.action == "remember":
            # the brain persists via remember_fact and phrases it in context
            self._say_chat(text)
            return "remember-via-brain"
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
        # the brain relays results: better summaries than the 3B, and the
        # report enters its conversation so follow-ups work natively
        if self.brain is not None:
            try:
                line = await self.brain.ask(
                    f"[background task finished — '{task[:80]}'. Report:]\n"
                    f"{report[:4000]}\n"
                    "Relay the key finding to the user now in one or two "
                    "spoken sentences, opening with a few words naming the topic.",
                    await self._world_context(),
                )
                line = brain_mod.sanitize_reply(line)
                self._remember("huan", f"(after working on '{task[:60]}') {line}")
                log.info("agent summary: %r", line)
                self._last_chat_ts = time.time()
                await self.speaker.say(line)
                return
            except Exception as exc:
                log.warning("brain relay failed (%s); speaking report head", exc)
        # truthful fallback: the report's own opening sentences. The 3B
        # summarizer hallucinated technical numbers here ('16 SMs per die')
        # and is banned from relaying findings.
        sentences = report.replace("\n", " ").split(". ")
        line = ". ".join(sentences[:2])[:280].strip()
        self._remember("huan", f"(after working on '{task[:60]}') {line}")
        log.info("agent summary (report head): %r", line)
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

    def _conversation_hot(self) -> bool:
        return (time.time() - getattr(self, "_last_chat_ts", 0.0)) < 30

    def _say_chat(self, said: str):
        """Conversational turn: the brain (real model, own memory) when
        available, 3B responder as fallback. Off the critical path."""
        self._remember("user", said)

        async def _chat():
            if self.brain is not None:
                loop = asyncio.get_running_loop()
                filler = loop.call_later(1.3, self.speaker.play_filler)

                spoke = False

                def speak_sentence(sentence: str):
                    nonlocal spoke
                    filler.cancel()
                    clean = brain_mod.sanitize_sentence(sentence)
                    if clean is None:
                        log.info("leak dropped: %r", sentence[:80])
                        return
                    spoke = True
                    asyncio.create_task(self.speaker.say(clean))

                try:
                    reply = await self.brain.ask(
                        said,
                        await self._world_context(),
                        on_sentence=speak_sentence,
                        # a working collaborator turn can run real commands;
                        # its narration covers the wait
                        timeout_s=300 if self.brain.collaborator else 25,
                    )
                    reply = brain_mod.sanitize_reply(reply)
                    if not spoke:
                        # every sentence leaked; speak the sanitized fallback
                        await self.speaker.say(reply)
                    self._remember("huan", reply)
                    log.info("brain: %r", reply)
                    self._last_chat_ts = time.time()
                    # hot window: keep listening so the user can continue
                    # the conversation without the wake word
                    if self.config.followup_s > 0 and not self._pipeline_lock.locked():
                        asyncio.create_task(
                            self._run_pipeline(
                                source="followup",
                                onset_timeout_ms=int(self.config.followup_s * 1000),
                            )
                        )
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
        # background-task truth: without this the brain invents phantom
        # tasks from stale conversation memory (seen live)
        if self.agent is not None and self.agent.busy:
            parts.append(
                f"background task running: {self.agent.current_task[:60] or 'unnamed'}"
            )
        else:
            parts.append("background tasks: none running")
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
        if self.sleeping:
            return
        # a fail loop is worth a thoughtful interruption: the brain decides
        # whether to speak (and may offer to investigate on its own)
        if entry.get("streak", 0) >= 2 and self.config.heartbeat:
            # 3+ failures, or repeated failures of a long command, are
            # always worth a line; the brain only chooses the phrasing
            must_speak = entry["streak"] >= 3 or entry["duration_s"] >= 60
            self._heartbeat(
                f"the user's command `{entry['cmd'][:80]}` has now failed "
                f"{entry['streak']} times in a row (latest exit "
                f"{entry.get('exit')}, {entry['duration_s']:.0f}s)",
                must_speak=must_speak,
            )
            return
        threshold = self.config.announce_min_s
        if threshold <= 0 or entry["duration_s"] < threshold:
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

    def _heartbeat(self, observation: str, must_speak: bool = False):
        """A silent brain turn on a notable event: it may speak one line
        (and act via its tools) or answer SILENT and nothing happens."""
        now = time.time()
        last = getattr(self, "_last_heartbeat_ts", 0)
        if self.brain is None or now - last < self.config.heartbeat_min_gap_s:
            return
        self._last_heartbeat_ts = now

        async def _beat():
            if must_speak:
                instruction = (
                    "This IS worth one short helpful spoken line — say it "
                    "(you may also start an investigation with your tools)."
                )
            else:
                instruction = (
                    "If this is worth interrupting the user, say ONE short "
                    "helpful line (you may also start an investigation with "
                    "your tools); if not, reply with exactly: SILENT"
                )
            prompt = (
                "[background observation — the user did NOT speak] "
                f"{observation}. {instruction}"
            )
            try:
                reply = await self.brain.ask(prompt, await self._world_context())
            except Exception as exc:
                log.warning("heartbeat failed: %s", exc)
                return
            if reply.strip().upper().startswith("SILENT"):
                log.info("heartbeat: brain chose silence (%s)", observation[:60])
                return
            log.info("heartbeat: %r", reply)
            self._remember("huan", f"(unprompted) {reply}")
            self._last_chat_ts = time.time()
            await self.speaker.say(reply)

        asyncio.create_task(_beat())

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
        try:
            writer.write((json.dumps(response) + "\n").encode())
            await writer.drain()
        except (ConnectionResetError, BrokenPipeError):
            pass  # fire-and-forget clients (the shell hook) never read replies
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
        # brain-initiated verbs (via the MCP server): the brain speaks for
        # itself, so these skip the daemon's own handoff/confirmation lines
        if cmd == "delegate":
            if self.agent is None:
                return {"ok": False, "state": "no reasoning tier configured"}
            if self.agent.busy:
                return {"ok": True, "state": "already busy with the previous task"}
            task = request.get("text", "")
            asyncio.create_task(self._run_agent(task, task))
            return {"ok": True, "state": "started"}
        if cmd == "remember":
            self._memory_append(request.get("text", ""))
            return {"ok": True}
        if cmd == "cancel":
            cancelled = self.agent is not None and self.agent.cancel()
            return {
                "ok": True,
                "state": "cancelled" if cancelled else "nothing running",
            }
        if cmd == "recall":
            notes = self.store.daily_notes(int(request.get("days", 7)))
            return {
                "ok": True,
                "notes": "\n".join(f"{day}: {note}" for day, note in notes)
                or "no daily notes yet",
            }
        return {"ok": False, "error": f"unknown command {cmd!r}"}


def run(config_path: str | None):
    import os

    logging.basicConfig(
        level=logging.INFO, format="%(asctime)s %(name)s %(levelname)s %(message)s"
    )
    config = Config.load(config_path)
    if config.extra_path:
        # capability CLIs (gcalcli, himalaya, ...) for the collaborator
        os.environ["PATH"] = (
            ":".join(config.extra_path) + ":" + os.environ.get("PATH", "")
        )
    config.control_socket.unlink(missing_ok=True)
    asyncio.run(Daemon(config).run())
