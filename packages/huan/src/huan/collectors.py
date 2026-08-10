import asyncio
import logging
import os
import time
from pathlib import Path

log = logging.getLogger("huan.collectors")

# Ambient awareness: a live world-state dict fed by push sources, so
# "what am I doing / how's my build" is answerable locally in
# milliseconds instead of delegating a cold investigation.

RECONNECT_DELAY_S = 5


class WorldState:
    """Live desktop state assembled from collectors + shell hook events."""

    def __init__(self, store):
        self.store = store
        self.on_command_end = None  # daemon hook for proactive announcements
        self.workspace: int | None = None
        self.window_class = ""
        self.window_title = ""
        # command id -> {cmd, cwd, start}
        self.running_cmds: dict[str, dict] = {}
        self.finished_cmds: list[dict] = []  # most recent last, capped

    # -- shell hook events (via control socket) ------------------------------

    def shell_event(self, data: dict):
        kind = data.get("phase")
        if kind == "start":
            self.running_cmds[data.get("id", "?")] = {
                "cmd": data.get("cmd", ""),
                "cwd": data.get("cwd", ""),
                "start": time.time(),
            }
            # cap runaway growth from lost end-events
            while len(self.running_cmds) > 20:
                self.running_cmds.pop(next(iter(self.running_cmds)))
        elif kind == "end":
            started = self.running_cmds.pop(data.get("id", "?"), None)
            entry = {
                "cmd": data.get("cmd", (started or {}).get("cmd", "")),
                "cwd": (started or {}).get("cwd", data.get("cwd", "")),
                "exit": data.get("exit"),
                "duration_s": round(float(data.get("duration", 0)), 1),
                "ts": time.time(),
            }
            self.finished_cmds.append(entry)
            del self.finished_cmds[:-10]
            # persist only the interesting ones: long-running or failed
            if entry["duration_s"] >= 5 or entry.get("exit") not in (0, None):
                self.store.add_event("shell", **entry)
            if self.on_command_end is not None:
                self.on_command_end(entry)

    # -- context assembly ----------------------------------------------------

    def describe(self) -> str:
        parts = []
        if self.workspace is not None:
            parts.append(f"workspace {self.workspace}")
        if self.window_title:
            parts.append(f"focused: [{self.window_class}] {self.window_title[:60]}")
        now = time.time()
        for c in list(self.running_cmds.values())[-3:]:
            parts.append(
                f"running for {now - c['start']:.0f}s: `{c['cmd'][:60]}` in {_short(c['cwd'])}"
            )
        for c in self.finished_cmds[-3:]:
            status = "ok" if c.get("exit") == 0 else f"exit {c.get('exit')}"
            parts.append(
                f"finished {_ago(now - c['ts'])} ago ({status}, {c['duration_s']}s): `{c['cmd'][:60]}`"
            )
        return "; ".join(parts) or "no desktop state yet"


def _short(path: str) -> str:
    home = os.path.expanduser("~")
    return path.replace(home, "~") if path else "?"


def _ago(seconds: float) -> str:
    if seconds < 90:
        return f"{seconds:.0f}s"
    if seconds < 5400:
        return f"{seconds / 60:.0f}m"
    return f"{seconds / 3600:.1f}h"


async def watch_hyprland(state: WorldState):
    """Subscribe to Hyprland's push event socket; no polling."""
    runtime = os.environ.get("XDG_RUNTIME_DIR", "")
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
    path = Path(runtime) / "hypr" / sig / ".socket2.sock"
    while True:
        try:
            reader, _writer = await asyncio.open_unix_connection(str(path))
            log.info("hyprland event stream connected")
            while True:
                line = await reader.readline()
                if not line:
                    raise ConnectionError("hyprland event socket closed")
                event, _, data = line.decode(errors="replace").strip().partition(">>")
                if event == "workspace":
                    try:
                        state.workspace = int(data)
                    except ValueError:
                        pass
                elif event == "activewindow":
                    cls, _, title = data.partition(",")
                    state.window_class, state.window_title = cls, title
        except asyncio.CancelledError:
            raise
        except Exception as exc:
            log.warning(
                "hyprland events lost (%s); retrying in %ss", exc, RECONNECT_DELAY_S
            )
            await asyncio.sleep(RECONNECT_DELAY_S)


async def now_playing() -> str:
    """On-demand MPRIS query via playerctl; empty string when silent."""
    try:
        proc = await asyncio.create_subprocess_exec(
            "playerctl",
            "metadata",
            "--format",
            "{{artist}} - {{title}} ({{status}})",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.DEVNULL,
        )
        stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=0.5)
        return stdout.decode().strip()
    except Exception:
        return ""
