import asyncio
import logging
import os
from pathlib import Path

log = logging.getLogger("huan.hypr")


def _socket_path() -> Path:
    runtime = os.environ.get("XDG_RUNTIME_DIR")
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not runtime or not sig:
        raise RuntimeError(
            "HYPRLAND_INSTANCE_SIGNATURE not set; not in a Hyprland session?"
        )
    return Path(runtime) / "hypr" / sig / ".socket.sock"


async def dispatch(command: str) -> None:
    """Send one dispatcher over Hyprland's IPC socket (no hyprctl fork)."""
    reader, writer = await asyncio.open_unix_connection(str(_socket_path()))
    try:
        writer.write(f"dispatch {command}".encode())
        await writer.drain()
        reply = (await reader.read(1024)).decode(errors="replace")
        if reply.strip() != "ok":
            raise RuntimeError(f"hyprland rejected {command!r}: {reply.strip()}")
    finally:
        writer.close()
        await writer.wait_closed()


async def run_intent(action: str, arg: int | None) -> None:
    if action == "workspace":
        await dispatch(f"workspace {arg}")
    elif action == "close-window":
        await dispatch("killactive")
    else:
        raise ValueError(f"no hyprland dispatch for action {action!r}")
