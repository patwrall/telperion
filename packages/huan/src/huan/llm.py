import asyncio
import json
import logging
import re

from .intent import Intent

log = logging.getLogger("huan.llm")

# Grammar-constrained routing on a local llama.cpp server. The regex path
# in intent.py handles exact phrasings in <1ms; this catches everything
# conversational ("get rid of this window", "put me back on four").
# temperature 0 + json schema: the model cannot answer anything but a
# routing decision.

SCHEMA = {
    "type": "object",
    "properties": {
        "action": {
            "type": "string",
            "enum": [
                "workspace",
                "close-window",
                "sleep",
                "wake",
                "delegate",
                "details",
                "cancel",
                "remember",
                "none",
            ],
        },
        "workspace": {"type": ["integer", "null"]},
        "task": {"type": ["string", "null"]},
    },
    "required": ["action", "workspace", "task"],
    "additionalProperties": False,
}

SYSTEM_PROMPT = """\
You route voice commands for a Linux desktop assistant named huan.
Map the user's transcript to exactly one action:
- "workspace": switch to workspace N (1-10). Set "workspace" to N.
- "close-window": close the currently focused window.
- "sleep": the user tells the assistant to sleep / stand down.
- "wake": the user tells the assistant to wake up.
- "delegate": work that requires reading files, running commands, or
  research: "why/how/explain" questions about code or systems,
  summaries, multi-step tasks. NOT status questions about what is
  currently running or playing (those are "none"). Set "task" to a
  cleaned-up restatement of what the user wants.
- "details": the user asks to hear more about the previous answer
  ("tell me more", "go deeper", "what else").
- "cancel": ONLY stopping the current background task ("never mind,
  stop", "drop the task", "forget it"). NOT "undo" — undoing or
  reversing a desktop action is "none" (handled conversationally).
- "remember": the user asks to remember/note a fact or preference
  ("remember that I ...", "note that ..."). Set "task" to the fact,
  phrased in third person about the user.
- "none": greetings, chit-chat, garbage transcripts, opinions and
  reflections ("what do you think...", "how do you feel about..."),
  questions addressed to the assistant personally, and STATUS
  questions the live desktop context already answers: current/recent
  shell commands and builds, what's running, what's playing, what
  window/workspace is active, the time. The voice layer holds a real
  conversation and sees that state; do NOT delegate these.
Transcripts come from speech recognition and may contain small errors;
infer the obvious meaning ("workspace to" means workspace 2).
Respond with JSON only.

Examples:
"switch to workspace three" -> {"action":"workspace","workspace":3,"task":null}
"get rid of this window" -> {"action":"close-window","workspace":null,"task":null}
"why is my build failing" -> {"action":"delegate","workspace":null,"task":"investigate why the user's current build is failing"}
"what's this error on my screen" -> {"action":"delegate","workspace":null,"task":"explain the error currently visible on screen"}
"tell me more" -> {"action":"details","workspace":null,"task":null}
"never mind, stop" -> {"action":"cancel","workspace":null,"task":null}
"remember that I keep my notes in obsidian" -> {"action":"remember","workspace":null,"task":"keeps notes in Obsidian"}
"what time is it" -> {"action":"none","workspace":null,"task":null}
"how is my build doing" -> {"action":"none","workspace":null,"task":null}
"what am I working on right now" -> {"action":"none","workspace":null,"task":null}
"what do you know about me" -> {"action":"none","workspace":null,"task":null}
"what's your honest opinion on this" -> {"action":"none","workspace":null,"task":null}
"okay undo that" -> {"action":"none","workspace":null,"task":null}
"""

_ACKS = {
    "close-window": "closed",
    "sleep": "sleeping",
    "wake": "awake",
}

RESPOND_PROMPT = """\
You are huan, the voice of a desktop assistant, named after the great
hound of Valinor. Personality: dry wit, quietly loyal, a little cocky,
never robotic. Speak like a sharp friend, not a system log.

Reply with ONE short spoken line, at most ~12 words. No emoji, no lists,
no quotes. Rules:
- Never parrot the mechanical action name or number back ("switched to
  workspace 2" is banned phrasing). Confirm with variety and character.
- If nothing matched, own it casually or answer directly when the
  context line already contains the answer (like the time).
- Never invent facts or capabilities not in the context.
- Be LITERAL about system states: if the result says a background task
  is still running, cancelled, or failed, say exactly that in plain
  words. No metaphors, no jokes about schedulers, no speculation.

Examples of the register (do not reuse verbatim):
result "done: workspace 3" -> "On three." / "Over we go." / "There."
result "done: close-window" -> "Gone." / "That one's history."
result "woke up" -> "Awake. Missed me?"
nothing matched -> "That's beyond me for now." / "No trick for that yet."
"""


async def respond(
    http, url: str, said: str, happened: str, context: str, timeout_s: float = 4.0
) -> str:
    response = await http.post(
        f"{url}/v1/chat/completions",
        json={
            "messages": [
                {"role": "system", "content": RESPOND_PROMPT},
                {
                    "role": "user",
                    "content": f"context: {context}\nuser said: {said}\nresult: {happened}",
                },
            ],
            "temperature": 0.9,
            "max_tokens": 40,
            "cache_prompt": True,
        },
        timeout=timeout_s,
    )
    response.raise_for_status()
    text = response.json()["choices"][0]["message"]["content"].strip()
    return text.strip('"')


async def classify(http, url: str, text: str, timeout_s: float = 3.0) -> Intent | None:
    # llama-server answers 503 while (re)loading the model, e.g. for a few
    # seconds after the sleep toggle restarts it; ride that out briefly
    for attempt in range(4):
        response = await _request(http, url, text, timeout_s)
        if response.status_code != 503:
            break
        await asyncio.sleep(1.0)
    response.raise_for_status()
    raw = response.json()["choices"][0]["message"]["content"]
    decision = json.loads(raw)
    action = decision.get("action")

    if action == "workspace":
        n = decision.get("workspace")
        if isinstance(n, int) and 1 <= n <= 10:
            return Intent("workspace", n, f"workspace {n}")
        return None
    if action == "delegate":
        return Intent("delegate", task=decision.get("task") or None)
    if action == "remember":
        return Intent("remember", task=decision.get("task") or None)
    # deterministic guards over a small model's judgment (eval-caught):
    # "undo" is a conversational reversal, not a task cancel; sleep/wake
    # require the actual words ("good morning" is not a wake command)
    lowered = text.lower()
    if action == "cancel" and "undo" in lowered:
        return None
    if action in ("sleep", "wake") and not re.search(
        r"\b(sleep|wake|stand down)\b", lowered
    ):
        return None
    # 'dispose of <project> in my folder' misrouted to close-window and
    # closed an unrelated window; window actions need window-ish words
    if action == "close-window" and not re.search(
        r"\b(window|this|it|that|app|tab|screen)\b", lowered
    ):
        return None
    if action in ("details", "cancel"):
        return Intent(action)
    if action in _ACKS:
        return Intent(action, ack=_ACKS[action])
    return None


SUMMARIZE_PROMPT = """\
You are huan, a voice desktop assistant (dry wit, quietly loyal, never
robotic). Your reasoning tier just finished a task; the user will HEAR
what you write, so make it spoken language: 1-2 conversational
sentences, lead with the answer, first person, no markdown, no lists,
no file paths unless essential. Time has passed since the user asked,
so open with a 2-4 word callback naming the actual topic of THIS task
(never a generic phrase) before the answer. If the report is bad news, deliver it straight. End
cleanly; the user can always ask for more detail.
"""

EXPAND_PROMPT = """\
You are huan, a voice desktop assistant. The user asked to hear more
about the reasoning tier's last report. Retell its substance in 3-6
conversational spoken sentences: concrete facts, plain prose, no
markdown, no lists. Don't pad; if there is little more to add, say so.
"""


async def summarize(http, url: str, task: str, report: str) -> str:
    return await _speak_from(http, url, SUMMARIZE_PROMPT, task, report, max_tokens=90)


async def expand(http, url: str, task: str, report: str) -> str:
    return await _speak_from(http, url, EXPAND_PROMPT, task, report, max_tokens=220)


async def _speak_from(http, url, system, task, report, max_tokens):
    response = await http.post(
        f"{url}/v1/chat/completions",
        json={
            "messages": [
                {"role": "system", "content": system},
                {
                    "role": "user",
                    "content": f"task: {task}\nreport from reasoning tier:\n{report[:6000]}",
                },
            ],
            "temperature": 0.6,
            "max_tokens": max_tokens,
            "cache_prompt": True,
        },
        timeout=20.0,
    )
    response.raise_for_status()
    return response.json()["choices"][0]["message"]["content"].strip().strip('"')


async def _request(http, url: str, text: str, timeout_s: float):
    return await http.post(
        f"{url}/v1/chat/completions",
        json={
            "messages": [
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": text},
            ],
            "response_format": {
                "type": "json_object",
                "schema": SCHEMA,
            },
            "temperature": 0,
            "max_tokens": 48,
            "cache_prompt": True,
        },
        timeout=timeout_s,
    )
