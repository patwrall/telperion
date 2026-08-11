import pytest
from huan.intent import Intent, classify
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


class TestMediaCommands:
    @pytest.mark.parametrize(
        ("text", "verb"),
        [
            ("pause the music", "play-pause"),
            ("pause", "play-pause"),
            ("pause it", "play-pause"),
            ("play the music", "play-pause"),
            ("resume", "play-pause"),
            ("next song", "next"),
            ("skip this", "next"),
            ("skip the track", "next"),
            ("previous song", "previous"),
            ("go back a track", "previous"),
        ],
    )
    def test_matches(self, text, verb):
        intent = classify(text)
        assert intent is not None and intent.action == "media"
        assert intent.task == verb

    @pytest.mark.parametrize(
        "text",
        [
            "play it again sam that old movie line you know",
            "I want to play some games later tonight maybe",
            "the next thing we should build is barge in support",
        ],
    )
    def test_long_transcripts_never_hijacked(self, text):
        intent = classify(text)
        assert intent is None or intent.action != "media"


class TestUnfinishedDetector:
    from huan.intent import looks_unfinished as _lu

    @pytest.mark.parametrize(
        "text",
        [
            "What version of",
            "Um...",
            "so like, and",
            "switch to the",
            "or",
            "what's my,",
            "hold on-",
        ],
    )
    def test_unfinished(self, text):
        from huan.intent import looks_unfinished

        assert looks_unfinished(text)

    @pytest.mark.parametrize(
        "text",
        [
            "What version of CUDA do I have?",
            "switch to workspace 2",
            "pause the music",
            "how is my build doing",
            "",
        ],
    )
    def test_finished(self, text):
        from huan.intent import looks_unfinished

        assert not looks_unfinished(text)


@given(st.text(max_size=200))
def test_classify_never_crashes_and_stays_in_range(text):
    intent = classify(text)
    if intent is not None:
        assert isinstance(intent, Intent)
        if intent.action == "workspace":
            assert 1 <= intent.arg <= 10


class TestBackchannel:
    @pytest.mark.parametrize(
        "text",
        [
            "Okay.",
            "okay",
            "Mmm.",
            "mm-hm",
            "uh huh",
            "Yeah.",
            "yeah okay",
            "Fair enough, fair enough",
            "got it",
            "Cool cool.",
            "Right.",
            "makes sense",
        ],
    )
    def test_pure_acknowledgments(self, text):
        from huan.intent import is_backchannel

        assert is_backchannel(text)

    @pytest.mark.parametrize(
        "text",
        [
            "okay so how does the scheduler work",
            "yeah but why did it fail",
            "no, the other one",
            "right click the file",
            "cool it down a bit",
            "what's the weather",
            "",
        ],
    )
    def test_real_content_is_not_backchannel(self, text):
        from huan.intent import is_backchannel

        assert not is_backchannel(text)
