import re
from dataclasses import dataclass

# v1 router is deliberately rule-based: with only two commands, regex is
# both faster (<1ms vs ~100ms) and more predictable than an LLM. The LLM
# backend comes back when the command surface outgrows patterns.

_WORD_NUMBERS = {
    "one": 1,
    "two": 2,
    "three": 3,
    "four": 4,
    "five": 5,
    "six": 6,
    "seven": 7,
    "eight": 8,
    "nine": 9,
    "ten": 10,
}

# ASR homophones ("workspace to" for "workspace two"): rescue them only in
# short, clean transcripts so a degraded 12s capture full of "to"s can't
# accidentally dispatch an action.
_HOMOPHONE_NUMBERS = {"to": 2, "too": 2, "for": 4}
_HOMOPHONE_MAX_WORDS = 5


@dataclass
class Intent:
    action: str  # workspace | close-window | sleep | wake | delegate | details | cancel
    arg: int | None = None
    ack: str = ""
    task: str | None = None  # for delegate: the cleaned-up task text


_WORKSPACE_RE = re.compile(
    r"\b(?:(?:switch|go)(?: to)?|workspace)\s+(?:workspace\s+)?(\d+|[a-z]+)\b"
)
_CLOSE_RE = re.compile(r"\b(?:close|kill)\b.*\b(?:window|this|it)\b|\bclose window\b")
_SLEEP_RE = re.compile(r"\b(?:go to sleep|sleep now|sleep)\b")
_WAKE_RE = re.compile(r"\b(?:wake up|wake)\b")


def _parse_number(token: str, allow_homophones: bool) -> int | None:
    if token.isdigit():
        return int(token)
    number = _WORD_NUMBERS.get(token)
    if number is None and allow_homophones:
        number = _HOMOPHONE_NUMBERS.get(token)
    return number


def classify(text: str) -> Intent | None:
    t = text.lower().strip().rstrip(".!?")
    if not t:
        return None

    m = _WORKSPACE_RE.search(t)
    if m:
        n = _parse_number(m.group(1), len(t.split()) <= _HOMOPHONE_MAX_WORDS)
        if n is not None and 1 <= n <= 10:
            return Intent("workspace", n, f"workspace {n}")

    if _CLOSE_RE.search(t):
        return Intent("close-window", ack="closed")

    if _SLEEP_RE.search(t):
        return Intent("sleep", ack="sleeping")

    if _WAKE_RE.search(t):
        return Intent("wake", ack="awake")

    return None
