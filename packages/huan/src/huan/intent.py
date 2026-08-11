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


# media verbs map straight to playerctl; short transcripts only so
# conversational mentions of "play" don't hijack the fast path
_MEDIA_RES = [
    (
        re.compile(r"\b(?:pause|stop)\b.*\b(?:music|song|media|it)\b|\bpause\b"),
        "play-pause",
    ),
    (
        re.compile(r"\b(?:resume|unpause)\b|\bplay\b.*\b(?:music|song|it)\b"),
        "play-pause",
    ),
    (re.compile(r"\b(?:next|skip)\b.*\b(?:song|track)\b|\bskip (?:it|this)\b"), "next"),
    (
        re.compile(
            r"\b(?:previous|last)\b.*\b(?:song|track)\b|\bgo back a (?:song|track)\b"
        ),
        "previous",
    ),
]
_MEDIA_MAX_WORDS = 5

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


# a transcript that trails off mid-thought ("what version of", "um...")
# is a pause, not a finished turn: the pipeline keeps listening and
# splices the continuation instead of answering fragments
_TRAILING_UNFINISHED = {
    "um",
    "uh",
    "er",
    "hmm",
    "like",
    "so",
    "and",
    "or",
    "but",
    "of",
    "the",
    "a",
    "an",
    "to",
    "for",
    "with",
    "in",
    "on",
    "my",
    "is",
    "are",
    "was",
    "what",
    "which",
    "that",
}


def looks_unfinished(text: str) -> bool:
    stripped = text.strip()
    if not stripped:
        return False
    if stripped.endswith(("...", "…", "-", ",")):
        return True
    last = stripped.split()[-1].strip(".,!?…").lower()
    return last in _TRAILING_UNFINISHED


# pure acknowledgments ("okay", "mm-hm") are backchannels: a human
# conversation partner lets them pass instead of replying to each one
_BACKCHANNEL_WORD = (
    r"(?:m+|mm+[\s-]?hm+|uh[\s-]?huh|okay|ok|k|yeah|yep|yes|no|nah|right|"
    r"cool|sure|gotcha|got it|nice|alright|all right|fair|fair enough|"
    r"makes sense|i see|true|word|bet)"
)
_BACKCHANNEL_RE = re.compile(rf"(?:{_BACKCHANNEL_WORD}[\s,.!]*){{1,3}}", re.IGNORECASE)


def is_backchannel(text: str) -> bool:
    return bool(_BACKCHANNEL_RE.fullmatch(text.strip().strip(".!,? ")))


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

    if len(t.split()) <= _MEDIA_MAX_WORDS:
        for pattern, action in _MEDIA_RES:
            if pattern.search(t):
                return Intent("media", ack=action, task=action)

    if _SLEEP_RE.search(t):
        return Intent("sleep", ack="sleeping")

    if _WAKE_RE.search(t):
        return Intent("wake", ack="awake")

    return None
