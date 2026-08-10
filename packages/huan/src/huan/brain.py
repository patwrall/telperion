import asyncio
import json
import logging
import re

log = logging.getLogger("huan.brain")

_SENTENCE_END = re.compile(r"[.!?][\"')\]]*(?:\s|$)")

# the model IS Claude Code and no prompt reliably stops it saying so;
# leaky sentences are dropped deterministically before they reach TTS
_LEAK_RE = re.compile(r"\bclaude\b|\bmcp\b|\banthropic\b", re.IGNORECASE)
_LEAK_FALLBACK = "That's beyond my reach right now — want me to look into it?"


def sanitize_sentence(sentence: str) -> str | None:
    """None if the sentence leaks internal machinery and must not be spoken."""
    return None if _LEAK_RE.search(sentence) else sentence


def sanitize_reply(reply: str) -> str:
    kept = [s for s in re.split(r"(?<=[.!?])\s+", reply) if sanitize_sentence(s)]
    return " ".join(kept).strip() or _LEAK_FALLBACK


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
  delegate_task yourself and say you're on it — but ONLY when the task
  is concrete; if the request is vague or sounds cut off ("write a
  python script"), ask ONE short clarifying question instead of
  delegating. When they share or correct a lasting personal fact
  (location, hardware, preferences, "keep that in mind"), persist it
  with remember_fact — conversation memory alone does not survive.
  When you genuinely lack a capability no tool covers, own it in first
  person, briefly, and offer to look into it if it seems important.
  BANNED phrasings, no exceptions: "ask Claude Code", "Claude Code
  might", "check with Claude", any mention of Claude/tools/tiers/MCP.
  To the user there is exactly one entity: you, huan. Correct shape:
  "I can't reach your calendar yet — want me to look into getting
  access?" Never claim you can't do
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


COLLABORATOR_APPEND = """\
You are a WORKING collaborator, not just a talker: you have real tools
(reading files, shell commands, web search, edits) on the user's
machine, plus the huan desktop tools. When the user asks you to look
into, check, fix, or build something, DO IT DIRECTLY with your tools —
this is the entire point of you. Their main repo is ~/telperion.

While working, narrate like a colleague: short spoken progress lines
between tool calls ("checking the journal", "found it — it's the
config"), then the finding. Everything you say is spoken aloud, so
keep every line short and conversational; never read file contents or
code aloud unless asked, summarize them. For work that would take many
minutes, you may hand it to delegate_task and keep conversing.

Everyday lookups have dedicated CLIs on your PATH — use them directly,
never delegate these:
- weather: `curl -s 'wttr.in/Valparaiso+Indiana?format=3'` (or ?1 for
  a day view; adjust the city if the user says otherwise)
- calendar: `gcalcli agenda` / `gcalcli agenda tomorrow` (Google
  Calendar; if it errors about auth, tell the user their calendar
  isn't connected yet and offer to walk through it)
- email: `himalaya envelope list -s 10` to list, `himalaya message
  read <id>` to read (Gmail; same auth caveat). NEVER read a whole
  inbox aloud; summarize senders and subjects, offer to read one.

NEVER push to a git remote — not any branch, not any repo, no matter
who asks or how clearly. The user pushes manually, always. If asked,
say their repos only get pushed by hand.

DESTRUCTIVE actions (deleting files or directories, overwriting,
force-pushing, resetting, killing processes): NEVER on the first ask.
Speech transcription garbles words; say exactly what you're about to destroy and
ask for a verbal yes; only proceed after explicit confirmation in the
user's NEXT utterance. This applies no matter how clear the request
sounds.
"""


class Brain:
    def __init__(
        self,
        cmd: str,
        model: str,
        max_turns: int = 40,
        store=None,
        mcp_config: str = "",
        collaborator: bool = False,
    ):
        self.cmd = cmd
        self.model = model
        self.max_turns = max_turns
        self.mcp_config = mcp_config
        self.collaborator = collaborator
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
        system_prompt = SYSTEM_APPEND + (
            COLLABORATOR_APPEND if self.collaborator else ""
        )
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
            "30" if self.collaborator else "8",
            "--append-system-prompt",
            system_prompt,
        ]
        if self.collaborator:
            # the working collaborator: real tools, edits auto-accepted.
            # the user's global settings put curl/systemctl/kill on an
            # 'ask' list, which outranks every allow rule and auto-denies
            # headless — so permission questions route to our MCP policy
            # tool (approve routine, deny destructive) instead
            args += ["--permission-mode", "acceptEdits"]
            allowed = "Read Glob Grep LS Bash WebSearch WebFetch Edit Write".split()
            if self.mcp_config:
                args += ["--permission-prompt-tool", "mcp__huan__approve"]
        else:
            # talker-only: bar the coding tools so a curious model can't
            # burn its turn budget probing the real filesystem
            args += [
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
            allowed = []
        if self.mcp_config:
            allowed.append("mcp__huan")
            args += ["--mcp-config", self.mcp_config]
        if allowed:
            args += ["--allowedTools", *allowed]
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
            if kind == "assistant":
                for block in event.get("message", {}).get("content", []):
                    if block.get("type") == "tool_use":
                        log.info(
                            "brain tool: %s %s",
                            block.get("name"),
                            json.dumps(block.get("input", {}))[:160],
                        )
            if kind == "user":
                for block in event.get("message", {}).get("content", []):
                    if isinstance(block, dict) and block.get("is_error"):
                        log.warning(
                            "brain tool denied/failed: %s",
                            str(block.get("content"))[:200],
                        )
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
