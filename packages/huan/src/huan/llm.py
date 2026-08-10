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
            # the v7 router diet: pure desk reflexes only. delegate/
            # details/remember used to be classes here; every class the
            # 3B can output is a class it can misroute into ('dispose of
            # <project>' -> close-window), and the collaborator brain
            # handles all of that better as the fallthrough anyway.
            "enum": [
                "workspace",
                "close-window",
                "sleep",
                "wake",
                "cancel",
                "none",
            ],
        },
        "workspace": {"type": ["integer", "null"]},
    },
    "required": ["action", "workspace"],
    "additionalProperties": False,
}

SYSTEM_PROMPT = """\
You route voice commands for a Linux desktop assistant named huan.
Map the user's transcript to exactly one action:
- "workspace": switch to workspace N (1-10). Set "workspace" to N.
- "close-window": close the currently focused window.
- "sleep": the user tells the assistant to sleep / stand down.
- "wake": the user tells the assistant to wake up.
- "cancel": ONLY stopping the current background task ("never mind,
  stop", "drop the task", "forget it"). NOT "undo" — undoing or
  reversing a desktop action is "none" (handled conversationally).
- "none": EVERYTHING else. Questions, requests for work or research,
  memory requests, follow-ups, greetings, chit-chat, opinions, status
  questions, garbage transcripts. The voice layer holds a real
  conversation with full tools and live desktop state; when in any
  doubt, answer "none".
Transcripts come from speech recognition and may contain small errors;
infer the obvious meaning ("workspace to" means workspace 2).
Respond with JSON only.

Examples:
"switch to workspace three" -> {"action":"workspace","workspace":3}
"get rid of this window" -> {"action":"close-window","workspace":null}
"never mind, stop" -> {"action":"cancel","workspace":null}
"why is my build failing" -> {"action":"none","workspace":null}
"tell me more" -> {"action":"none","workspace":null}
"remember that I use neovim" -> {"action":"none","workspace":null}
"what time is it" -> {"action":"none","workspace":null}
"dispose of that old project folder" -> {"action":"none","workspace":null}
"okay undo that" -> {"action":"none","workspace":null}
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
    if action == "cancel":
        return Intent(action)
    if action in _ACKS:
        return Intent(action, ack=_ACKS[action])
    return None


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
