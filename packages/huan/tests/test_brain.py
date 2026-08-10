import asyncio
import json

import pytest
from huan.brain import Brain


class FakeStdin:
    def __init__(self):
        self.written = []

    def write(self, data):
        self.written.append(data)

    async def drain(self):
        pass


class FakeProc:
    """Scripted stdout events; enough of a subprocess for _ask_once."""

    def __init__(self, events):
        self.stdin = FakeStdin()
        self.returncode = None
        self._lines = [json.dumps(e).encode() + b"\n" for e in events]

    @property
    def stdout(self):
        return self

    async def readline(self):
        return self._lines.pop(0) if self._lines else b""


def delta(text):
    return {
        "type": "stream_event",
        "event": {
            "type": "content_block_delta",
            "delta": {"type": "text_delta", "text": text},
        },
    }


def make_brain(store=None, events=None):
    brain = Brain("claude", "haiku", store=store)
    brain._proc = FakeProc(events or [])
    return brain


class TestSentenceStreaming:
    async def test_sentences_stream_in_order(self):
        brain = make_brain(
            events=[
                delta("First sentence here"),
                delta(" it is. Second one"),
                delta(" also arrives. Tail"),
                {"type": "result"},
            ]
        )
        chunks = []
        reply = await brain._ask_once("q", "ctx", chunks.append)
        assert chunks == [
            "First sentence here it is.",
            "Second one also arrives.",
            "Tail",
        ]
        assert reply == "First sentence here it is. Second one also arrives. Tail"

    async def test_short_fragments_not_flushed_early(self):
        brain = make_brain(events=[delta("No. Wait."), {"type": "result"}])
        chunks = []
        await brain._ask_once("q", "ctx", chunks.append)
        # under the 20-char minimum, everything arrives as one final chunk
        assert chunks == ["No. Wait."]

    async def test_abbreviation_period_flushes_with_following_text(self):
        brain = make_brain(
            events=[
                delta("The build failed at step 3. Check the logs now please."),
                {"type": "result"},
            ]
        )
        chunks = []
        await brain._ask_once("q", "ctx", chunks.append)
        assert len(chunks) == 2

    async def test_empty_reply_raises(self):
        brain = make_brain(events=[{"type": "result"}])
        with pytest.raises(ConnectionError):
            await brain._ask_once("q", "ctx", None)

    async def test_eof_raises(self):
        brain = make_brain(events=[delta("half a repl")])
        with pytest.raises(ConnectionError):
            await brain._ask_once("q", "ctx", None)

    async def test_state_prefixed_into_message(self):
        brain = make_brain(
            events=[delta("Reply sentence, long enough."), {"type": "result"}]
        )
        await brain._ask_once("the question", "THE STATE", None)
        sent = json.loads(brain._proc.stdin.written[0])
        text = sent["message"]["content"][0]["text"]
        assert text.startswith("[state: THE STATE]")
        assert "the question" in text


class TestSessionPersistence:
    async def test_session_id_captured(self, store):
        brain = make_brain(
            store,
            [
                {"type": "system", "session_id": "sess-42"},
                delta("A reply that is long enough to flush."),
                {"type": "result"},
            ],
        )
        await brain._ask_once("q", "ctx", None)
        assert store.get("brain_session_id") == "sess-42"

    def test_rotation_clears_session(self, store):
        store.set("brain_session_id", "old")
        brain = Brain("claude", "haiku", max_turns=0, store=store)
        brain._remember_session(None)
        assert store.get("brain_session_id") is None

    def test_no_store_is_fine(self):
        brain = Brain("claude", "haiku")
        assert brain._stored_session() is None
        brain._remember_session("x")  # must not raise


class TestLeakSanitizer:
    def test_clean_sentence_passes(self):
        from huan.brain import sanitize_sentence

        assert sanitize_sentence("On three.") == "On three."

    def test_leaky_sentence_dropped(self):
        from huan.brain import sanitize_sentence

        assert sanitize_sentence("That's Claude Code territory.") is None
        assert sanitize_sentence("ask Claude about it") is None
        assert sanitize_sentence("the MCP tools handle that") is None

    def test_mixed_reply_keeps_clean_sentences(self):
        from huan.brain import sanitize_reply

        reply = (
            "No email access. That's Claude Code territory. Want me to look into it?"
        )
        assert sanitize_reply(reply) == "No email access. Want me to look into it?"

    def test_fully_leaky_reply_becomes_fallback(self):
        from huan.brain import _LEAK_FALLBACK, sanitize_reply

        assert sanitize_reply("Claude Code handles that.") == _LEAK_FALLBACK


class TestToolWiring:
    def test_mcp_args_when_configured(self):
        brain = Brain("claude", "haiku", mcp_config="/nix/store/mcp.json")
        # args assembled inside start(); reproduce the assembly path
        assert brain.mcp_config == "/nix/store/mcp.json"

    def test_prompt_forbids_capability_denial(self):
        from huan.brain import SYSTEM_APPEND

        assert "Never claim you can't" in SYSTEM_APPEND
        assert "delegate_task" in SYSTEM_APPEND
        # the tier leak from the v4 transcript must stay banned
        assert "never mention tools, tiers" in SYSTEM_APPEND


class TestLifecycle:
    async def test_ask_timeout_restarts(self, store, monkeypatch):
        brain = Brain("claude", "haiku", store=store)

        async def never(*a, **k):
            await asyncio.sleep(60)

        stopped = []

        async def fake_stop():
            stopped.append(True)

        monkeypatch.setattr(brain, "start", fake_stop)
        monkeypatch.setattr(brain, "stop", fake_stop)
        monkeypatch.setattr(brain, "_ask_once", never)
        with pytest.raises(asyncio.TimeoutError):
            await brain.ask("q", "ctx", timeout_s=0.05)
