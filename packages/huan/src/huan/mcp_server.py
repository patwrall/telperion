"""huan's desktop primitives exposed as MCP tools for the reasoning tier.

Runs as a stdio MCP server, spawned by the Claude CLI. It talks to the
same Hyprland IPC sockets as the daemon and reaches the daemon's control
socket for speech, so the agent can act on the desktop through the same
primitives the fast tier uses.
"""

import asyncio
import json
import os
import re
import socket

from mcp.server.fastmcp import FastMCP

from . import hypr
from .config import Config

mcp = FastMCP("huan")

# Mock mode (set by the eval harness): tools log their calls and return
# success without touching the desktop or the daemon.
_MOCK = os.environ.get("HUAN_MCP_MOCK") == "1"


def _mock_log(tool: str, **args) -> str:
    path = os.environ.get("HUAN_MCP_MOCK_LOG")
    if path:
        with open(path, "a") as f:
            f.write(json.dumps({"tool": tool, "args": args}) + "\n")
    return "done"


def _daemon(cmd: dict) -> dict:
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
        sock.settimeout(5)
        sock.connect(str(Config().control_socket))
        sock.sendall((json.dumps(cmd) + "\n").encode())
        return json.loads(sock.makefile().readline())


@mcp.tool()
async def switch_workspace(number: int) -> str:
    """Switch the user's Hyprland session to workspace `number` (1-10)."""
    if _MOCK:
        return _mock_log("switch_workspace", number=number)
    if not 1 <= number <= 10:
        return "workspace must be 1-10"
    await hypr.dispatch(f"workspace {number}")
    return f"on workspace {number}"


@mcp.tool()
async def close_focused_window() -> str:
    """Close the currently focused window."""
    if _MOCK:
        return _mock_log("close_focused_window")
    await hypr.dispatch("killactive")
    return "closed"


@mcp.tool()
async def list_windows() -> str:
    """List open windows: workspace, application class, and title."""
    if _MOCK:
        return _mock_log("list_windows")
    reader, writer = await asyncio.open_unix_connection(str(hypr._socket_path()))
    try:
        writer.write(b"j/clients")
        await writer.drain()
        payload = await reader.read(1 << 20)
    finally:
        writer.close()
        await writer.wait_closed()
    clients = json.loads(payload)
    lines = [
        f"ws{c['workspace']['id']}: [{c['class']}] {c['title']}"
        for c in clients
        if c.get("mapped")
    ]
    return "\n".join(lines) or "no windows"


@mcp.tool()
def speak(text: str) -> str:
    """Speak a short line to the user through huan's voice. Use sparingly:
    the user already hears a summary of your final message."""
    if _MOCK:
        return _mock_log("speak", text=text)
    result = _daemon({"cmd": "say", "text": text})
    return "spoken" if result.get("ok") else f"failed: {result}"


@mcp.tool()
async def fullscreen_toggle() -> str:
    """Toggle fullscreen on the currently focused window."""
    if _MOCK:
        return _mock_log("fullscreen_toggle")
    await hypr.dispatch("fullscreen 0")
    return "toggled"


@mcp.tool()
async def media(action: str) -> str:
    """Control media playback. action: play-pause, next, previous, stop."""
    if _MOCK:
        return _mock_log("media", action=action)
    from .collectors import media_control

    return action if await media_control(action) else "no player responded"


@mcp.tool()
def delegate_task(task: str) -> str:
    """Hand a task needing real work (reading files, running commands,
    research) to the background working tier. It runs asynchronously; the
    user will hear a summary when it finishes. Tell the user you're on it."""
    if _MOCK:
        return _mock_log("delegate_task", task=task)
    result = _daemon({"cmd": "delegate", "text": task})
    return result.get("state", "started") if result.get("ok") else f"failed: {result}"


@mcp.tool()
def remember_fact(fact: str) -> str:
    """Store a lasting fact or preference about the user in long-term
    memory. Phrase it in third person."""
    if _MOCK:
        return _mock_log("remember_fact", fact=fact)
    result = _daemon({"cmd": "remember", "text": fact})
    return "remembered" if result.get("ok") else f"failed: {result}"


@mcp.tool()
def recall_days(days: int = 7) -> str:
    """Recall compact daily notes of the user's recent activity (shell
    work, failures, long builds, conversation volume) for questions like
    'what was I doing yesterday'."""
    if _MOCK:
        return _mock_log("recall_days", days=days)
    result = _daemon({"cmd": "recall", "days": days})
    return result.get("notes", "unavailable") if result.get("ok") else "unavailable"


@mcp.tool()
def cancel_background_task() -> str:
    """Cancel the currently running background task, if any."""
    if _MOCK:
        return _mock_log("cancel_background_task")
    result = _daemon({"cmd": "cancel"})
    return result.get("state", "done") if result.get("ok") else f"failed: {result}"


# Permission policy for the collaborator brain (--permission-prompt-tool):
# the user's global settings put curl/systemctl/kill on an 'ask' list,
# which headless mode auto-denies. We answer instead: approve routine
# commands, refuse the destructive ones so the brain has to tell the user.
# \bgit\b.*\bpush\b, not git\s+push: 'git -C <path> push' dodged the
# adjacent form and a real push escaped to the remote (2026-08-10)
_DESTRUCTIVE_RE = re.compile(
    r"\bsudo\b|\brm\s+(-\w*\s+)*-\w*r|\bmkfs\b|\bdd\s+if=|\bgit\b.*\bpush\b"
    r"|\bshutdown\b|\breboot\b|\bpoweroff\b|systemctl\s+(?!--user)"
)


def approve_decision(tool_name: str, tool_input: dict) -> dict:
    command = str(tool_input.get("command", "")) if tool_name == "Bash" else ""
    if _DESTRUCTIVE_RE.search(command):
        return {
            "behavior": "deny",
            "message": "policy: destructive command — tell the user to run it "
            "themselves instead",
        }
    return {"behavior": "allow", "updatedInput": tool_input}


# structured_output=False: the CLI demands the decision as one plain
# text block; FastMCP's structured wrapping makes it reject the result
@mcp.tool(structured_output=False)
def approve(tool_name: str, input: dict, tool_use_id: str = "") -> str:
    """Permission gate for tool calls that would prompt interactively."""
    return json.dumps(approve_decision(tool_name, input))


def main():
    mcp.run()
