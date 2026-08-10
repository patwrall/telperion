import asyncio
import json
import logging
import os

log = logging.getLogger("huan.agent")

# The reasoning tier: the Claude Code CLI driven headless. One task at a
# time; sessions are resumed across tasks so follow-ups keep context. The
# user never hears this tier directly — its final report is summarized
# into speech by the local 3B (user's explicit design: "not just a fancy
# TTS"; details stay available on request).

SYSTEM_APPEND = """\
You are the reasoning tier of huan, a voice-controlled desktop assistant
running on the user's NixOS/Hyprland machine. The user speaks to a fast
local model; tasks needing real thought are delegated to you.

The user will only HEAR a 1-2 sentence spoken summary of your final
message, produced by a small local model. Anything not in your final
message is lost to the user, so end with a compact, self-contained
report: lead with the answer, plain prose, no markdown, no headers, no
code blocks unless the code itself is the answer. A few sentences is
ideal.

You may have huan MCP tools available (switching workspaces, listing
windows, speaking). Use them only when the task genuinely calls for
desktop interaction; speak() sparingly — the summary already reaches
the user.
"""


class AgentError(Exception):
    pass


class Agent:
    def __init__(self, config):
        self.cmd = config.agent_cmd
        self.model = config.agent_model
        self.timeout_s = config.agent_timeout_s
        self.cwd = os.path.expanduser(config.agent_cwd)
        self.mcp_config = config.agent_mcp_config
        self.allowed_tools = config.agent_allowed_tools
        self.permission_mode = config.agent_permission_mode
        self.session_id: str | None = None
        self.last_task = ""
        self.last_result = ""
        self._proc: asyncio.subprocess.Process | None = None

    @property
    def busy(self) -> bool:
        return self._proc is not None and self._proc.returncode is None

    def cancel(self) -> bool:
        if not self.busy:
            return False
        self._proc.terminate()
        log.info("agent task cancelled")
        return True

    def _args(self, resume: bool) -> list[str]:
        args = [self.cmd, "-p", "--output-format", "json"]
        if resume and self.session_id:
            args += ["--resume", self.session_id]
        if self.model:
            args += ["--model", self.model]
        if self.permission_mode:
            args += ["--permission-mode", self.permission_mode]
        if self.allowed_tools:
            args += ["--allowedTools", *self.allowed_tools]
        if self.mcp_config:
            args += ["--mcp-config", self.mcp_config]
        args += ["--append-system-prompt", SYSTEM_APPEND]
        return args

    async def run(self, task: str, context: str) -> str:
        """Run one task to completion; returns the agent's final report."""
        if self.busy:
            raise AgentError("agent is busy")
        prompt = f"[desktop context: {context}]\n{task}"
        try:
            return await self._run_once(prompt, resume=True)
        except AgentError as exc:
            # a stale/expired session must not kill the task
            if self.session_id and "session" in str(exc).lower():
                log.warning("resume failed (%s); starting a fresh session", exc)
                self.session_id = None
                return await self._run_once(prompt, resume=False)
            raise

    async def _run_once(self, prompt: str, resume: bool) -> str:
        args = self._args(resume)
        log.info(
            "agent starting (resume=%s, model=%s)",
            resume and bool(self.session_id),
            self.model or "default",
        )
        self._proc = await asyncio.create_subprocess_exec(
            *args,
            stdin=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            cwd=self.cwd,
        )
        try:
            stdout, stderr = await asyncio.wait_for(
                self._proc.communicate(prompt.encode()), timeout=self.timeout_s
            )
        except asyncio.TimeoutError:
            self._proc.kill()
            await self._proc.wait()
            raise AgentError(f"timed out after {self.timeout_s}s")
        finally:
            proc, self._proc = self._proc, None

        if proc.returncode < 0:
            # killed by signal: cancellation, already acknowledged elsewhere
            raise AgentError("cancelled")
        if proc.returncode != 0:
            err = stderr.decode(errors="replace").strip()[-500:]
            raise AgentError(err or f"exit code {proc.returncode}")

        try:
            payload = json.loads(stdout.decode())
        except json.JSONDecodeError as exc:
            raise AgentError(f"unparsable agent output: {exc}")

        # newer CLI versions emit an array of events; the result is the
        # (last) object with type == "result"
        if isinstance(payload, list):
            results = [
                p for p in payload if isinstance(p, dict) and p.get("type") == "result"
            ]
            if not results:
                raise AgentError("no result object in agent output")
            payload = results[-1]

        self.session_id = payload.get("session_id") or self.session_id
        result = (payload.get("result") or "").strip()
        if payload.get("is_error") or not result:
            raise AgentError(result or "agent returned an error with no message")

        self.last_result = result
        log.info(
            "agent finished: %d chars, cost $%.4f",
            len(result),
            payload.get("total_cost_usd") or 0.0,
        )
        return result
