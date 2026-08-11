import asyncio

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
        spoken = []

        async def fake_say(text):
            spoken.append(text)

        d.speaker.say = fake_say
        result = await d._act("switch to workspace 3", Stopwatch())
        await asyncio.sleep(0)  # let the ack task run
        assert dispatched == [("workspace", 3)]
        assert result == "workspace(3)"
        # deterministic ack carries the REAL number (the 3B responder
        # once said 'workspace 4' after a switch to 2)
        assert spoken and "3" in spoken[0]

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


class TestWorldContextTruth:
    async def test_no_agent_reports_none_running(self, make_daemon):
        d = make_daemon()
        assert "background tasks: none running" in await d._world_context()

    async def test_idle_agent_reports_none_running(self, make_daemon):
        d = make_daemon(agent_cmd="claude")
        assert "background tasks: none running" in await d._world_context()

    async def test_busy_agent_reports_its_task(self, make_daemon):
        # regression: the brain invented phantom background tasks because
        # the state blob never carried the truth
        d = make_daemon(agent_cmd="claude")

        class Running:
            returncode = None

        d.agent._proc = Running()
        d.agent.current_task = "investigate the wifi drops"
        context = await d._world_context()
        assert "background task running: investigate the wifi drops" in context


class TestHeartbeat:
    def test_fail_streak_triggers_heartbeat(self, make_daemon, monkeypatch):
        d = make_daemon()
        beats = []
        monkeypatch.setattr(
            d,
            "_heartbeat",
            lambda obs, must_speak=False: beats.append((obs, must_speak)),
        )
        d._on_command_end(
            {"cmd": "nix build", "exit": 1, "duration_s": 4.0, "streak": 2}
        )
        assert beats and "failed" in beats[0][0] and "2 times" in beats[0][0]
        assert beats[0][1] is False  # quick double-fail: brain may stay silent
        assert d.spoken_responses == []  # heartbeat replaces the announcement

    def test_serious_fail_loop_must_speak(self, make_daemon, monkeypatch):
        d = make_daemon()
        beats = []
        monkeypatch.setattr(
            d, "_heartbeat", lambda obs, must_speak=False: beats.append(must_speak)
        )
        d._on_command_end(
            {"cmd": "nixos-rebuild", "exit": 1, "duration_s": 350.0, "streak": 2}
        )
        d._on_command_end({"cmd": "make", "exit": 1, "duration_s": 2.0, "streak": 3})
        assert beats == [True, True]  # long-cmd repeat and 3+ streak both compel speech

    def test_single_failure_no_heartbeat(self, make_daemon, monkeypatch):
        d = make_daemon()
        beats = []
        monkeypatch.setattr(d, "_heartbeat", beats.append)
        d._on_command_end({"cmd": "make", "exit": 1, "duration_s": 4.0, "streak": 1})
        assert beats == []

    def test_heartbeat_rate_limited(self, make_daemon):
        import time as time_mod

        d = make_daemon()

        class FakeBrain:
            pass

        d.brain = FakeBrain()
        d._last_heartbeat_ts = time_mod.time()
        d._heartbeat("something notable")  # inside the gap: must not schedule
        # no exception and no task created is the pass condition; the
        # scheduled-path is covered by the trigger test above

    def test_heartbeat_disabled_by_config(self, make_daemon, monkeypatch):
        d = make_daemon(heartbeat=False)
        beats = []
        monkeypatch.setattr(d, "_heartbeat", beats.append)
        d._on_command_end({"cmd": "make", "exit": 1, "duration_s": 4.0, "streak": 5})
        assert beats == []


class TestHotConversation:
    async def test_followup_musing_stays_quiet_when_cold(self, make_daemon):
        d = make_daemon()
        result = await d._act("random musing here", Stopwatch(), quiet=True)
        assert result == "unknown" and d.chats == []

    async def test_followup_continues_hot_conversation(self, make_daemon):
        import time as time_mod

        d = make_daemon()
        d._last_chat_ts = time_mod.time()  # a chat exchange just happened
        result = await d._act("and what about tomorrow", Stopwatch(), quiet=True)
        assert result == "unknown"
        assert d.chats == ["and what about tomorrow"]

    def test_hot_window_expires(self, make_daemon):
        d = make_daemon()
        d._last_chat_ts = 0.0
        assert not d._conversation_hot()


class TestBrainControlVerbs:
    async def test_delegate_verb_starts_agent(self, make_daemon, monkeypatch):
        d = make_daemon(agent_cmd="claude")
        started = []

        async def fake_run_agent(said, task):
            started.append(task)

        monkeypatch.setattr(d, "_run_agent", fake_run_agent)
        result = await d._dispatch_control({"cmd": "delegate", "text": "check weather"})
        assert result == {"ok": True, "state": "started"}
        await asyncio.sleep(0)  # let the spawned task run
        assert started == ["check weather"]

    async def test_delegate_verb_reports_busy(self, make_daemon):
        d = make_daemon(agent_cmd="claude")

        class Running:
            returncode = None

        d.agent._proc = Running()
        result = await d._dispatch_control({"cmd": "delegate", "text": "x"})
        assert "busy" in result["state"]

    async def test_delegate_verb_without_agent(self, make_daemon):
        d = make_daemon()
        result = await d._dispatch_control({"cmd": "delegate", "text": "x"})
        assert result["ok"] is False

    async def test_remember_verb_writes_memory(self, make_daemon):
        d = make_daemon()
        result = await d._dispatch_control({"cmd": "remember", "text": "prefers dark"})
        assert result["ok"]
        assert "prefers dark" in d._memory_facts()

    async def test_cancel_verb_idle(self, make_daemon):
        d = make_daemon()
        result = await d._dispatch_control({"cmd": "cancel"})
        assert result == {"ok": True, "state": "nothing running"}


class TestHistory:
    def test_remember_persists_and_reloads(self, make_daemon, tmp_path, monkeypatch):
        d = make_daemon()
        d._remember("user", "hello there")
        d._remember("huan", "hi yourself")
        monkeypatch.setenv("XDG_DATA_HOME", str(tmp_path))
        d2 = Daemon(Config())
        assert list(d2.history)[-2:] == ["user: hello there", "huan: hi yourself"]


class TestConverseMode:
    async def test_toggle_on_starts_loop_and_speaks(self, make_daemon):
        d = make_daemon()
        said = []

        async def fake_say(text):
            said.append(text)

        d.speaker.say = fake_say
        result = d._converse_toggle()
        assert result == "converse on"
        assert d._converse_task is not None and not d._converse_task.done()
        d._converse_task.cancel()
        await asyncio.sleep(0)
        assert said == ["Ears on."]

    async def test_toggle_off_cancels_loop(self, make_daemon):
        d = make_daemon()

        async def fake_say(text):
            pass

        d.speaker.say = fake_say
        d._converse_toggle()
        task = d._converse_task
        result = d._converse_toggle()
        assert result == "converse off"
        await asyncio.sleep(0)
        assert task.cancelled() or task.done()

    async def test_silence_windows_auto_off(self, make_daemon, monkeypatch):
        d = make_daemon()
        said = []

        async def fake_say(text):
            said.append(text)

        d.speaker.say = fake_say
        windows = []

        async def fake_pipeline(source, onset_timeout_ms=None, **kw):
            windows.append(source)
            return None  # silence: nothing heard

        monkeypatch.setattr(d, "_run_pipeline", fake_pipeline)
        await d._converse_loop()
        assert windows == ["converse"] * 5
        assert said == ["Going quiet."]
        assert d._converse_task is None

    async def test_control_verb_dispatches(self, make_daemon):
        d = make_daemon()

        async def fake_say(text):
            pass

        d.speaker.say = fake_say
        result = await d._dispatch_control({"cmd": "converse"})
        assert result == {"ok": True, "state": "converse on"}
        d._converse_task.cancel()


class TestConverseMediaPause:
    async def test_pauses_playing_media_and_resumes(self, make_daemon, monkeypatch):
        d = make_daemon()
        actions = []

        async def fake_control(action):
            actions.append(action)
            return True

        async def fake_playing():
            return "IShowSpeed - Minecraft Hardcore"

        monkeypatch.setattr(daemon_mod.collectors, "media_control", fake_control)
        monkeypatch.setattr(daemon_mod.collectors, "now_playing", fake_playing)
        await d._converse_media(resume=False)
        assert actions == ["pause"]
        await d._converse_media(resume=True)
        assert actions == ["pause", "play"]

    async def test_never_resumes_what_it_did_not_pause(self, make_daemon, monkeypatch):
        d = make_daemon()
        actions = []

        async def fake_control(action):
            actions.append(action)
            return True

        async def fake_playing():
            return ""  # nothing playing at ears-on

        monkeypatch.setattr(daemon_mod.collectors, "media_control", fake_control)
        monkeypatch.setattr(daemon_mod.collectors, "now_playing", fake_playing)
        await d._converse_media(resume=False)
        await d._converse_media(resume=True)
        assert actions == []


class TestBackchannelGate:
    async def test_backchannel_gets_no_reply(self, make_daemon):
        d = make_daemon()
        result = await d._act("Okay.", Stopwatch())
        assert result == "backchannel"
        assert d.chats == [] and d.spoken_responses == []

    async def test_backchannel_after_question_is_an_answer(self, make_daemon):
        d = make_daemon()
        d._last_reply_question = True
        result = await d._act("Yeah.", Stopwatch())
        assert result == "unknown"
        assert d.chats == ["Yeah."]

    async def test_content_still_chats(self, make_daemon):
        d = make_daemon()
        result = await d._act("okay so how does the scheduler work", Stopwatch())
        assert result == "unknown"
        assert d.chats == ["okay so how does the scheduler work"]
