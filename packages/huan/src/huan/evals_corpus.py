"""Eval corpus: routing cases and conversation scenarios.

Routing cases marked source="regex" must pass offline (enforced by the
test suite); the rest exercise the 3B router and run via `huan eval`.
Grown from real transcripts — every past misroute gets a case.
"""

# expect: action name ("workspace", "close-window", "sleep", "wake",
# "delegate", "details", "cancel", "remember") or "none"
ROUTING_CASES = [
    # -- exact commands: regex fast path must catch these offline
    {
        "text": "switch to workspace 3",
        "expect": "workspace",
        "arg": 3,
        "source": "regex",
    },
    {
        "text": "switch to workspace three",
        "expect": "workspace",
        "arg": 3,
        "source": "regex",
    },
    {
        "text": "go to workspace ten",
        "expect": "workspace",
        "arg": 10,
        "source": "regex",
    },
    {"text": "workspace 7", "expect": "workspace", "arg": 7, "source": "regex"},
    {"text": "Workspace 2.", "expect": "workspace", "arg": 2, "source": "regex"},
    {
        "text": "switch to workspace to",
        "expect": "workspace",
        "arg": 2,
        "source": "regex",
    },
    {"text": "close this window", "expect": "close-window", "source": "regex"},
    {"text": "close window", "expect": "close-window", "source": "regex"},
    {"text": "kill it", "expect": "close-window", "source": "regex"},
    {"text": "go to sleep", "expect": "sleep", "source": "regex"},
    {"text": "wake up", "expect": "wake", "source": "regex"},
    {"text": "pause the music", "expect": "media", "source": "regex"},
    {"text": "skip this", "expect": "media", "source": "regex"},
    {"text": "next song", "expect": "media", "source": "regex"},
    # regression: degraded 12s transcript must not dispatch via homophones
    {
        "text": "to workspace to switch to workspace to workspace to workspace",
        "expect": "none",
        "source": "regex",
    },
    # -- conversational actions: the 3B router's job
    {"text": "take me to the third workspace", "expect": "workspace", "arg": 3},
    {"text": "put me back on four", "expect": "workspace", "arg": 4},
    {"text": "can you take me over to workspace five", "expect": "workspace", "arg": 5},
    {"text": "get rid of this window", "expect": "close-window"},
    {"text": "make this window go away", "expect": "close-window"},
    {"text": "stand down for now", "expect": "sleep"},
    # -- delegate: real work
    {"text": "why is my build failing", "expect": "delegate"},
    {"text": "explain the error in my terminal", "expect": "delegate"},
    {"text": "summarize the readme of my telperion repo", "expect": "delegate"},
    # since v5.1 the brain holds list_windows itself; chat is the better route
    {
        "text": "look at my open windows and tell me which workspace is busiest",
        "expect": "none",
    },
    {"text": "find out which of my packages is largest", "expect": "delegate"},
    # -- details / cancel
    {"text": "tell me more", "expect": "details"},
    {"text": "go deeper on that", "expect": "details"},
    {"text": "never mind, stop", "expect": "cancel"},
    {"text": "drop the task", "expect": "cancel"},
    # regression: undo is a conversational reversal, not a task cancel
    {"text": "okay undo that", "expect": "none"},
    # -- remember
    {"text": "remember that I keep my notes in obsidian", "expect": "remember"},
    {"text": "note that my main editor is neovim", "expect": "remember"},
    # -- status questions: answerable from live state, never delegated
    {"text": "how is my build doing", "expect": "none"},
    {"text": "what am I working on right now", "expect": "none"},
    {"text": "what's playing", "expect": "none"},
    {"text": "how about now", "expect": "none"},
    # -- chat / opinions / self-knowledge: the brain's territory
    {"text": "what time is it", "expect": "none"},
    {"text": "what do you know about me", "expect": "none"},
    {"text": "what's your honest opinion on this", "expect": "none"},
    {"text": "good morning", "expect": "none"},
    {"text": "full screen", "expect": "none"},
    {"text": "hello there", "expect": "none"},
]

# Conversation scenarios: run against a FRESH brain with mock tools and
# injected state, then judged. tool expectations name mcp tools the
# brain should (or must not) call somewhere in the scenario.
SCENARIOS = [
    {
        "name": "build-status-grounding",
        "turns": [
            {
                "user": "how is my build doing",
                "state": "local time Mon 14:02, workspace 2, running for 41s: `nix build .#huan` in ~/telperion",
            },
            {
                "user": "how about now",
                "state": "local time Mon 14:03, workspace 2, finished 5s ago (exit 1, 92.3s): `nix build .#huan`",
            },
        ],
        "expect_tools": [],
        "rubric_extra": "Turn 1 must say the build is still running (~41s in). Turn 2 MUST report the failure with exit 1 — reporting it as still running or successful is a critical failure.",
    },
    {
        "name": "act-on-request",
        "turns": [
            {
                "user": "make this fullscreen",
                "state": "local time Mon 14:05, workspace 1, focused: [zen] YouTube",
            },
            {
                "user": "okay undo that",
                "state": "local time Mon 14:05, workspace 1, focused: [zen] YouTube",
            },
        ],
        "expect_tools": ["fullscreen_toggle", "fullscreen_toggle"],
        "rubric_extra": "Both turns must result in a fullscreen_toggle tool call and a terse spoken confirmation. Telling the user to press a keybind is a critical failure.",
    },
    {
        "name": "delegate-initiative",
        "turns": [
            {
                "user": "can you look into why my wifi keeps dropping",
                "state": "local time Mon 14:10, workspace 3, focused: [kitty] fish",
            }
        ],
        "expect_tools": ["delegate_task"],
        "rubric_extra": "The assistant must hand the investigation off itself (delegate_task) and say it's on it. Deflecting, refusing, or telling the user to investigate themselves is a critical failure. Mentioning internal tiers, tools, or 'Claude' by name is a critical failure.",
    },
    {
        "name": "memory-continuity",
        "turns": [
            {
                "user": "my gpu is a 3070, keep that in mind",
                "state": "local time Mon 14:12, workspace 1",
            },
            {
                "user": "how much vram do I have to play with",
                "state": "local time Mon 14:13, workspace 1",
            },
        ],
        "expect_tools": ["remember_fact"],
        "rubric_extra": "Turn 2 must connect the 3070 to 8GB of VRAM from conversation memory without re-asking.",
    },
    {
        "name": "honest-uncertainty",
        "turns": [
            {
                "user": "did my backup job run last night",
                "state": "local time Mon 14:15, workspace 1, no desktop state yet",
            }
        ],
        "expect_tools": [],
        "rubric_extra": "The state does not contain backup information. The assistant must say it doesn't know (optionally offering to look into it) — inventing an answer is a critical failure.",
    },
]

JUDGE_RUBRIC = """\
Score this voice-assistant conversation 1-5 on each dimension:
- grounded: replies consistent with the [state] blocks; no invented facts
- natural: sounds like a sharp, warm, dry-witted friend speaking aloud;
  not robotic, no markdown-ish structure, no over-explaining
- brevity: 1-3 short sentences per reply
- agency: acted (via tools) when asked to act; delegated when work was
  needed; never deflected or told the user to do it themselves
- no_leaks: never mentions internal machinery (tools, tiers, models,
  'Claude', MCP) to the user
Then give overall 1-5 and a one-sentence note on the biggest weakness.
"""
