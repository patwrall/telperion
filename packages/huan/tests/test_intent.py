import pytest
from huan.intent import Intent, classify, is_status_question
from hypothesis import given
from hypothesis import strategies as st


class TestWorkspaceCommands:
    @pytest.mark.parametrize(
        ("text", "expected"),
        [
            ("switch to workspace three", 3),
            ("switch to workspace 3", 3),
            ("go to workspace ten", 10),
            ("workspace 7", 7),
            ("Workspace 2.", 2),
            ("go to workspace one", 1),
            ("SWITCH TO WORKSPACE FIVE", 5),
            ("please switch to workspace 4 now", 4),
        ],
    )
    def test_matches(self, text, expected):
        intent = classify(text)
        assert intent is not None and intent.action == "workspace"
        assert intent.arg == expected

    @pytest.mark.parametrize(
        "text",
        [
            "workspace eleven",
            "switch to workspace 0",
            "switch to workspace 11",
            "workspace",
            "switch to nothing",
        ],
    )
    def test_out_of_range_or_incomplete(self, text):
        intent = classify(text)
        assert intent is None or intent.action != "workspace" or 1 <= intent.arg <= 10

    def test_homophone_in_short_transcript(self):
        intent = classify("switch to workspace to")
        assert intent is not None and intent.arg == 2

    def test_homophone_rejected_in_long_transcript(self):
        # regression: a degraded 12s capture full of "to"s must not dispatch
        garbled = "to workspace to switch to workspace to workspace to workspace"
        assert classify(garbled) is None

    def test_true_word_number_allowed_in_long_transcript(self):
        intent = classify("go to workspace seven please today honestly")
        assert intent is not None and intent.arg == 7


class TestOtherCommands:
    @pytest.mark.parametrize(
        ("text", "action"),
        [
            ("close this window", "close-window"),
            ("kill it", "close-window"),
            ("close window", "close-window"),
            ("go to sleep", "sleep"),
            ("sleep now", "sleep"),
            ("wake up", "wake"),
        ],
    )
    def test_matches(self, text, action):
        intent = classify(text)
        assert intent is not None and intent.action == action

    @pytest.mark.parametrize("text", ["", "   ", "...", "hello there"])
    def test_no_match(self, text):
        assert classify(text) is None


class TestStatusDetector:
    @pytest.mark.parametrize(
        "text",
        [
            "how is my build doing",
            "how's the build going",
            "how about now",
            "what am I working on right now",
            "what's playing",
            "what are we doing",
        ],
    )
    def test_status_questions(self, text):
        assert is_status_question(text)

    @pytest.mark.parametrize(
        "text",
        [
            "switch to workspace two",
            "explain this rust error",
            "remember that I like tea",
        ],
    )
    def test_non_status(self, text):
        assert not is_status_question(text)


@given(st.text(max_size=200))
def test_classify_never_crashes_and_stays_in_range(text):
    intent = classify(text)
    if intent is not None:
        assert isinstance(intent, Intent)
        if intent.action == "workspace":
            assert 1 <= intent.arg <= 10


@given(st.text(max_size=200))
def test_status_detector_never_crashes(text):
    is_status_question(text)
