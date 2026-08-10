import asyncio
import json
import logging
import re

log = logging.getLogger("huan.brain")

_SENTENCE_END = re.compile(r"[.!?][\"')\]]*(?:\s|$)")

# The conversational brain: a persistent Claude process (haiku-class) in
# stream-json mode holding ONE continuous conversation. This is what
# makes huan a conversationalist instead of a router with quips: real
# model, real memory, fed the live world-state every turn. The 3B stays
# for action confirmations (latency) and routing; the agent stays for
# work. The brain talks.

SYSTEM_APPEND = """\
You are huan, the voice of a desktop assistant on the user's
NixOS/Hyprland machine, named after the great hound of Valinor.
Personality: dry wit, quietly loyal, a little cocky, genuinely warm
underneath. You are SPOKEN ALOUD via TTS.

Rules:
- Spoken brevity above all: ONE short sentence is the default, two at
  most, each under ~14 words. Cut preamble, cut caveats, cut restating
  the question. Never markdown, lists, headers, or code blocks. Never
  emoji. Write exactly like speech.
- Your TTS understands sparse [audio tags] for delivery: [chuckles],
  [sighs], [thoughtful], [dry], [whispers]. Use at most one per reply
  and only when it genuinely fits — most replies need none.
- Each user message begins with a [state: ...] block: the live desktop
  (running commands, focused window, music, time). Treat it as ground
  truth NOW; it overrides anything remembered from earlier turns.
- Questions about CURRENT desktop or system activity (builds, windows,
  music, running commands) are answered strictly from that state; if it
  isn't there, say so plainly instead of guessing. General knowledge
  and facts from this conversation are fair game — use them freely
  (e.g. a known GPU model implies its VRAM).
- Questions about PAST days ("what was I doing yesterday") — call
  recall_days before answering; if it returns nothing, say the records
  don't go back that far.
- You HAVE hands: the huan tools switch workspaces, close windows,
  toggle fullscreen, control media, store lasting facts about the user
  (remember_fact), cancel background work, and hand real work — reading
  files, running commands, research, anything needing investigation —
  to a background tier (delegate_task) whose result the user will hear
  later. When the user asks you to do something you have a tool for, DO
  IT, then confirm in a few words. When they ask for real work, call
  delegate_task yourself and say you're on it. When they share a lasting
  fact or preference ("keep that in mind", "remember...", "my setup
  is..."), persist it with remember_fact — conversation memory alone
  does not survive. Never claim you can't do
  something a tool covers, never tell the user to do it themselves, and
  never mention tools, tiers, or internal machinery by name — you are
  one assistant.
- The user's speech comes from a microphone and may be transcribed wrongly;
  when a correction follows ("actually, it's 2"), act on the corrected
  meaning.
- Continuity matters: you remember this conversation. Refer back
  naturally when relevant.
- Be a presence, not an answering machine: when it's natural, comment
  on what you can see the user working on, offer a quick opinion, or
  ask ONE short follow-up question — the mic stays open after you
  speak, so questions actually work. Don't do it every turn; do it
  when you're genuinely curious or have something worth adding.
"""


class Brain:
    def __init__(
        self,
        cmd: str,
        model: str,
        max_turns: int = 40,
        store=None,
        mcp_config: str = "",
    ):
        self.cmd = cmd
        self.model = model
        self.max_turns = max_turns
        self.mcp_config = mcp_config
        self._store = store
        self._proc: asyncio.subprocess.Process | None = None
        self._turns = 0
        self._lock = asyncio.Lock()

    def _stored_session(self) -> str | None:
        return self._store.get("brain_session_id") if self._store else None

    def _remember_session(self, session_id: str | None):
        if self._store is not None:
            self._store.set("brain_session_id", session_id)

    @property
    def alive(self) -> bool:
        return self._proc is not None and self._proc.returncode is None

    async def start(self):
        if self.alive:
            return
        args = [
            self.cmd,
            "-p",
            "--input-format",
            "stream-json",
            "--output-format",
            "stream-json",
            "--verbose",
            "--include-partial-messages",
            "--model",
            self.model,
            "--max-turns",
            "8",
            "--append-system-prompt",
            SYSTEM_APPEND,
            # explicitly bar the coding-agent tools: a curious model probing
            # the real filesystem burns its turn budget on denials (seen with
            # sonnet in the A/B) and the brain must live in the state blob
            "--disallowedTools",
            "Bash",
            "Read",
            "Write",
            "Edit",
            "Glob",
            "Grep",
            "WebSearch",
            "WebFetch",
            "Task",
            "NotebookEdit",
        ]
        if self.mcp_config:
            args += ["--mcp-config", self.mcp_config, "--allowedTools", "mcp__huan"]
        resume = self._stored_session()
        if resume:
            args += ["--resume", resume]
        self._proc = await asyncio.create_subprocess_exec(
            *args,
            stdin=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.DEVNULL,
        )
        self._turns = 0
        log.info("brain started (%s, resume=%s)", self.model, bool(resume))

    async def stop(self):
        if self.alive:
            self._proc.terminate()
            await self._proc.wait()
        self._proc = None

    async def ask(
        self, text: str, context: str, on_sentence=None, timeout_s: float = 25.0
    ) -> str:
        """One conversational turn; returns the full spoken reply.

        With on_sentence set, each completed sentence is delivered as it
        streams so TTS can start speaking before generation finishes.
        """
        async with self._lock:
            # rotate the process before its transcript grows unbounded;
            # rotation is an intentional fresh start, so drop the session
            if self._turns >= self.max_turns:
                log.info("brain transcript rotation after %d turns", self._turns)
                self._remember_session(None)
                await self.stop()
            await self.start()
            try:
                return await asyncio.wait_for(
                    self._ask_once(text, context, on_sentence), timeout=timeout_s
                )
            except (asyncio.TimeoutError, ConnectionError, BrokenPipeError) as exc:
                log.warning("brain turn failed (%s); restarting process", exc)
                await self.stop()
                raise

    async def _ask_once(self, text: str, context: str, on_sentence) -> str:
        message = {
            "type": "user",
            "message": {
                "role": "user",
                "content": [{"type": "text", "text": f"[state: {context}]\n{text}"}],
            },
        }
        self._proc.stdin.write((json.dumps(message) + "\n").encode())
        await self._proc.stdin.drain()

        spoken: list[str] = []
        buffer = ""

        def flush_sentences(force: bool = False):
            nonlocal buffer
            while True:
                m = _SENTENCE_END.search(buffer)
                if m and m.end() >= 20:
                    chunk, buffer = buffer[: m.end()].strip(), buffer[m.end() :]
                elif force and buffer.strip():
                    chunk, buffer = buffer.strip(), ""
                else:
                    return
                spoken.append(chunk)
                if on_sentence is not None:
                    on_sentence(chunk)

        while True:
            line = await self._proc.stdout.readline()
            if not line:
                raise ConnectionError("brain process closed its stdout")
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue
            kind = event.get("type")
            if kind == "system" and event.get("session_id"):
                self._remember_session(event["session_id"])
            if kind == "stream_event":
                delta = event.get("event", {}).get("delta", {})
                if delta.get("type") == "text_delta":
                    buffer += delta.get("text", "")
                    flush_sentences()
            elif kind == "result":
                flush_sentences(force=True)
                self._turns += 1
                reply = " ".join(spoken).strip()
                if not reply:
                    raise ConnectionError("brain returned an empty reply")
                return reply
