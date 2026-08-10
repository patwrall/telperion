import json

import pytest
from huan.agent import Agent, AgentError
from huan.config import Config


def make_agent(store, **overrides):
    config = Config(
        agent_cmd="claude",
        agent_model="sonnet",
        agent_mcp_config="/tmp/mcp.json",
        agent_allowed_tools=["Read", "Bash", "mcp__huan"],
        **overrides,
    )
    return Agent(config, store)


class FakeProc:
    def __init__(self, stdout=b"", stderr=b"", returncode=0):
        self._out, self._err, self.returncode = stdout, stderr, returncode

    async def communicate(self, _input):
        return self._out, self._err

    async def wait(self):
        pass

    def kill(self):
        pass


def result_payload(**overrides):
    payload = {
        "type": "result",
        "result": "the answer",
        "session_id": "s-1",
        "total_cost_usd": 0.01,
        "is_error": False,
    }
    payload.update(overrides)
    return payload


async def run_with(agent, proc, monkeypatch):
    import huan.agent as agent_mod

    async def fake_exec(*args, **kwargs):
        fake_exec.args = args
        return proc

    monkeypatch.setattr(agent_mod.asyncio, "create_subprocess_exec", fake_exec)
    result = await agent.run("task", "ctx")
    return result, fake_exec.args


class TestOutputParsing:
    async def test_object_form(self, store, monkeypatch):
        proc = FakeProc(json.dumps(result_payload()).encode())
        result, _ = await run_with(make_agent(store), proc, monkeypatch)
        assert result == "the answer"

    async def test_array_form(self, store, monkeypatch):
        # regression: newer CLI versions emit an event array, not an object
        events = [{"type": "system"}, {"type": "assistant"}, result_payload()]
        proc = FakeProc(json.dumps(events).encode())
        result, _ = await run_with(make_agent(store), proc, monkeypatch)
        assert result == "the answer"

    async def test_array_takes_last_result(self, store, monkeypatch):
        events = [result_payload(result="early"), result_payload(result="final")]
        proc = FakeProc(json.dumps(events).encode())
        result, _ = await run_with(make_agent(store), proc, monkeypatch)
        assert result == "final"

    async def test_array_without_result_errors(self, store, monkeypatch):
        proc = FakeProc(json.dumps([{"type": "system"}]).encode())
        with pytest.raises(AgentError, match="no result"):
            await run_with(make_agent(store), proc, monkeypatch)

    async def test_is_error_raises(self, store, monkeypatch):
        proc = FakeProc(json.dumps(result_payload(is_error=True)).encode())
        with pytest.raises(AgentError):
            await run_with(make_agent(store), proc, monkeypatch)

    async def test_garbage_output_raises(self, store, monkeypatch):
        proc = FakeProc(b"not json at all")
        with pytest.raises(AgentError, match="unparsable"):
            await run_with(make_agent(store), proc, monkeypatch)

    async def test_signal_death_is_cancelled(self, store, monkeypatch):
        # regression: SIGTERM cancel must not speak a failure line
        proc = FakeProc(returncode=-15)
        with pytest.raises(AgentError, match="cancelled"):
            await run_with(make_agent(store), proc, monkeypatch)

    async def test_nonzero_exit_surfaces_stderr(self, store, monkeypatch):
        proc = FakeProc(stderr=b"auth expired", returncode=1)
        with pytest.raises(AgentError, match="auth expired"):
            await run_with(make_agent(store), proc, monkeypatch)


class TestCurrentTask:
    async def test_current_task_set_and_cleared(self, store, monkeypatch):
        proc = FakeProc(json.dumps(result_payload()).encode())
        agent = make_agent(store)
        assert agent.current_task == ""
        await run_with(agent, proc, monkeypatch)
        assert agent.current_task == ""  # cleared after completion

    async def test_current_task_cleared_on_failure(self, store, monkeypatch):
        proc = FakeProc(b"garbage")
        agent = make_agent(store)
        with pytest.raises(AgentError):
            await run_with(agent, proc, monkeypatch)
        assert agent.current_task == ""


class TestSessionPersistence:
    async def test_session_saved_and_reloaded(self, store, monkeypatch):
        proc = FakeProc(json.dumps(result_payload(session_id="persisted")).encode())
        agent, _ = make_agent(store), None
        await run_with(agent, proc, monkeypatch)
        assert store.get("agent_session_id") == "persisted"
        assert make_agent(store).session_id == "persisted"

    async def test_resume_flag_present_when_session_known(self, store, monkeypatch):
        store.set("agent_session_id", "known")
        proc = FakeProc(json.dumps(result_payload()).encode())
        _, args = await run_with(make_agent(store), proc, monkeypatch)
        assert "--resume" in args and "known" in args

    async def test_no_resume_on_fresh_agent(self, store, monkeypatch):
        proc = FakeProc(json.dumps(result_payload()).encode())
        _, args = await run_with(make_agent(store), proc, monkeypatch)
        assert "--resume" not in args


class TestArgs:
    def test_flag_assembly(self, store):
        agent = make_agent(store)
        args = agent._args(resume=False)
        assert args[:3] == ["claude", "-p", "--output-format"]
        assert "--model" in args and "sonnet" in args
        assert "--mcp-config" in args and "/tmp/mcp.json" in args
        assert "--allowedTools" in args and "mcp__huan" in args
        assert "--permission-mode" in args

    async def test_busy_agent_refuses_second_run(self, store):
        agent = make_agent(store)

        class Running:
            returncode = None

        agent._proc = Running()
        assert agent.busy
        with pytest.raises(AgentError, match="busy"):
            await agent.run("t", "c")

    def test_cancel_when_idle_returns_false(self, store):
        assert make_agent(store).cancel() is False
