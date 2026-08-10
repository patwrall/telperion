import pytest
from huan import daemon as daemon_mod
from huan.config import Config
from huan.daemon import Daemon, Stopwatch


@pytest.fixture
def make_daemon(tmp_path, monkeypatch):
    def build(**config_overrides):
        monkeypatch.setenv("XDG_DATA_HOME", str(tmp_path))
        d = Daemon(Config(**config_overrides))

        class FakeStt:
            loaded = True

            def unload(self):
                self.loaded = False

            def load(self):
                self.loaded = True

        d.stt = FakeStt()
        d.spoken_responses = []
        d.chats = []
        monkeypatch.setattr(
            d,
            "_say_response",
            lambda said, happened, fallback: d.spoken_responses.append(happened),
        )
        monkeypatch.setattr(d, "_say_chat", lambda said: d.chats.append(said))
        return d

    return build


@pytest.fixture
def dispatched(monkeypatch):
    calls = []

    async def fake_run_intent(action, arg):
        calls.append((action, arg))

    monkeypatch.setattr(daemon_mod.hypr, "run_intent", fake_run_intent)
    return calls


class TestActRouting:
    async def test_regex_workspace_dispatches(self, make_daemon, dispatched):
        d = make_daemon()
        result = await d._act("switch to workspace 3", Stopwatch())
        assert dispatched == [("workspace", 3)]
        assert result == "workspace(3)"
        assert d.spoken_responses  # a confirmation line was generated

    async def test_close_window(self, make_daemon, dispatched):
        d = make_daemon()
        result = await d._act("close this window", Stopwatch())
        assert dispatched == [("close-window", None)]
        assert result == "close-window"

    async def test_unknown_goes_to_chat(self, make_daemon, dispatched):
        d = make_daemon()
        result = await d._act("what a lovely day", Stopwatch())
        assert result == "unknown"
        assert d.chats == ["what a lovely day"]
        assert not dispatched

    async def test_unknown_in_followup_stays_quiet(self, make_daemon):
        # regression: musing during the follow-up window must not trigger replies
        d = make_daemon()
        result = await d._act("so are we what do we have", Stopwatch(), quiet=True)
        assert result == "unknown"
        assert d.chats == [] and d.spoken_responses == []

    async def test_sleep_unloads_stt(self, make_daemon):
        d = make_daemon()
        said = []

        async def fake_say(text):
            said.append(text)

        d.speaker.say = fake_say
        result = await d._act("go to sleep", Stopwatch())
        assert result == "sleep"
        assert d.sleeping and not d.stt.loaded
        assert said  # canned ack, since the responder LLM is going down

    async def test_remember_writes_memory_file(self, make_daemon, monkeypatch):
        d = make_daemon()
        from huan import llm
        from huan.intent import Intent

        async def classify_remember(http, url, text, timeout_s=3.0):
            return Intent("remember", task="likes tea")

        monkeypatch.setattr(llm, "classify", classify_remember)
        d.config.llama_url = "http://x"
        result = await d._act("remember that I like tea", Stopwatch())
        assert result == "remember"
        assert "likes tea" in d._memory_path.read_text()
        assert "likes tea" in d._memory_facts()

    async def test_cancel_without_agent(self, make_daemon):
        d = make_daemon()
        result = await d._act("never mind, stop", Stopwatch())
        # no agent configured: routed by regex? no -- 'cancel' comes from the
        # LLM router; without llama_url this lands in chat as unknown
        assert result == "unknown"


class TestDelegateGating:
    async def test_delegate_without_agent_degrades(self, make_daemon):
        d = make_daemon()
        result = d._delegate("do the thing", "do the thing", Stopwatch())
        assert result == "unknown"
        assert d.spoken_responses and "no reasoning tier" in d.spoken_responses[0]

    async def test_busy_agent_reports_literally(self, make_daemon):
        d = make_daemon(agent_cmd="claude")

        class Running:
            returncode = None

        d.agent._proc = Running()
        result = d._delegate("another task", "another task", Stopwatch())
        assert result == "agent-busy"
        assert "still running" in d.spoken_responses[0]

    async def test_status_question_never_delegates(self, make_daemon, monkeypatch):
        d = make_daemon(agent_cmd="claude")
        from huan import llm
        from huan.intent import Intent

        async def classify_delegate(http, url, text, timeout_s=3.0):
            return Intent("delegate", task="check the build")

        monkeypatch.setattr(llm, "classify", classify_delegate)
        d.config.llama_url = "http://x"
        result = await d._act("how is my build doing", Stopwatch())
        assert result == "status"
        assert d.chats == ["how is my build doing"]


class TestMemoryHelpers:
    def test_facts_joined_and_capped(self, make_daemon):
        d = make_daemon()
        for i in range(100):
            d._memory_append(f"fact number {i}")
        facts = d._memory_facts(cap=200)
        assert len(facts) <= 200
        assert "fact number 99" in facts

    def test_no_file_is_empty(self, make_daemon):
        assert make_daemon()._memory_facts() == ""


class TestAnnouncements:
    def test_short_commands_silent(self, make_daemon):
        d = make_daemon()
        d._on_command_end({"cmd": "ls", "exit": 0, "duration_s": 1.0})
        assert d.spoken_responses == []

    def test_long_command_announced(self, make_daemon):
        d = make_daemon()
        d._on_command_end({"cmd": "nix build", "exit": 0, "duration_s": 90.0})
        assert d.spoken_responses and "succeeded" in d.spoken_responses[0]

    def test_failure_wording(self, make_daemon):
        d = make_daemon()
        d._on_command_end({"cmd": "make", "exit": 2, "duration_s": 90.0})
        assert "failed with exit 2" in d.spoken_responses[0]

    def test_disabled_by_zero_threshold(self, make_daemon):
        d = make_daemon(announce_min_s=0)
        d._on_command_end({"cmd": "x", "exit": 0, "duration_s": 900.0})
        assert d.spoken_responses == []

    def test_silent_while_sleeping(self, make_daemon):
        d = make_daemon()
        d.sleeping = True
        d._on_command_end({"cmd": "x", "exit": 0, "duration_s": 900.0})
        assert d.spoken_responses == []


class TestHistory:
    def test_remember_persists_and_reloads(self, make_daemon, tmp_path, monkeypatch):
        d = make_daemon()
        d._remember("user", "hello there")
        d._remember("huan", "hi yourself")
        monkeypatch.setenv("XDG_DATA_HOME", str(tmp_path))
        d2 = Daemon(Config())
        assert list(d2.history)[-2:] == ["user: hello there", "huan: hi yourself"]
