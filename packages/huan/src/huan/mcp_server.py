"""huan's desktop primitives exposed as MCP tools for the reasoning tier.

Runs as a stdio MCP server, spawned by the Claude CLI. It talks to the
same Hyprland IPC sockets as the daemon and reaches the daemon's control
socket for speech, so the agent can act on the desktop through the same
primitives the fast tier uses.
"""

import asyncio
import json
import socket

from mcp.server.fastmcp import FastMCP

from . import hypr
from .config import Config

mcp = FastMCP("huan")


def _daemon(cmd: dict) -> dict:
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
        sock.settimeout(5)
        sock.connect(str(Config().control_socket))
        sock.sendall((json.dumps(cmd) + "\n").encode())
        return json.loads(sock.makefile().readline())


@mcp.tool()
async def switch_workspace(number: int) -> str:
    """Switch the user's Hyprland session to workspace `number` (1-10)."""
    if not 1 <= number <= 10:
        return "workspace must be 1-10"
    await hypr.dispatch(f"workspace {number}")
    return f"on workspace {number}"


@mcp.tool()
async def close_focused_window() -> str:
    """Close the currently focused window."""
    await hypr.dispatch("killactive")
    return "closed"


@mcp.tool()
async def list_windows() -> str:
    """List open windows: workspace, application class, and title."""
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
    result = _daemon({"cmd": "say", "text": text})
    return "spoken" if result.get("ok") else f"failed: {result}"


def main():
    mcp.run()
