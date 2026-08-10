import json
import logging
import os
import sqlite3
import time
from pathlib import Path

log = logging.getLogger("huan.store")

# Persistence: conversation, learned state, and ambient events survive
# daemon restarts and reboots. Writes are tiny and WAL-mode, so sync
# sqlite on the event loop is fine.

DDL = """
CREATE TABLE IF NOT EXISTS exchanges (
    ts REAL NOT NULL,
    role TEXT NOT NULL,
    text TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS kv (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS events (
    ts REAL NOT NULL,
    kind TEXT NOT NULL,
    data TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS events_kind_ts ON events (kind, ts);
CREATE TABLE IF NOT EXISTS daily_notes (
    day TEXT PRIMARY KEY,
    note TEXT NOT NULL
);
"""


class Store:
    def __init__(self, path: str | os.PathLike | None = None):
        if path is None:
            base = Path(os.environ.get("XDG_DATA_HOME", "~/.local/share")).expanduser()
            path = base / "huan" / "huan.db"
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self._db = sqlite3.connect(path)
        self._db.execute("PRAGMA journal_mode=WAL")
        self._db.executescript(DDL)
        log.info("store open at %s", path)

    # -- conversation --------------------------------------------------------

    def add_exchange(self, role: str, text: str):
        self._db.execute(
            "INSERT INTO exchanges VALUES (?, ?, ?)", (time.time(), role, text)
        )
        self._db.commit()

    def recent_exchanges(self, n: int = 8) -> list[str]:
        rows = self._db.execute(
            "SELECT role, text FROM exchanges ORDER BY ts DESC LIMIT ?", (n,)
        ).fetchall()
        return [f"{role}: {text}" for role, text in reversed(rows)]

    # -- key/value (agent session, learned settings) -------------------------

    def get(self, key: str, default: str | None = None) -> str | None:
        row = self._db.execute("SELECT value FROM kv WHERE key = ?", (key,)).fetchone()
        return row[0] if row else default

    def set(self, key: str, value: str | None):
        if value is None:
            self._db.execute("DELETE FROM kv WHERE key = ?", (key,))
        else:
            self._db.execute(
                "INSERT INTO kv VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value",
                (key, value),
            )
        self._db.commit()

    # -- daily notes (episodic memory) ---------------------------------------

    def set_daily_note(self, day: str, note: str):
        self._db.execute(
            "INSERT INTO daily_notes VALUES (?, ?) ON CONFLICT(day) DO UPDATE SET note = excluded.note",
            (day, note),
        )
        self._db.commit()

    def daily_notes(self, n: int = 7) -> list[tuple[str, str]]:
        rows = self._db.execute(
            "SELECT day, note FROM daily_notes ORDER BY day DESC LIMIT ?", (n,)
        ).fetchall()
        return list(reversed(rows))

    def prune(self, event_days: int = 14, exchange_days: int = 30):
        cutoff_events = time.time() - event_days * 86400
        cutoff_exchanges = time.time() - exchange_days * 86400
        self._db.execute("DELETE FROM events WHERE ts < ?", (cutoff_events,))
        self._db.execute("DELETE FROM exchanges WHERE ts < ?", (cutoff_exchanges,))
        self._db.commit()

    def events_between(self, start: float, end: float) -> list[dict]:
        rows = self._db.execute(
            "SELECT ts, kind, data FROM events WHERE ts >= ? AND ts < ? ORDER BY ts",
            (start, end),
        ).fetchall()
        return [{"ts": ts, "kind": k, **json.loads(data)} for ts, k, data in rows]

    def exchange_count_between(self, start: float, end: float) -> int:
        return self._db.execute(
            "SELECT COUNT(*) FROM exchanges WHERE ts >= ? AND ts < ?", (start, end)
        ).fetchone()[0]

    # -- ambient events (collectors) -----------------------------------------

    def add_event(self, kind: str, **data):
        self._db.execute(
            "INSERT INTO events VALUES (?, ?, ?)",
            (time.time(), kind, json.dumps(data)),
        )
        self._db.commit()

    def recent_events(self, kind: str | None = None, limit: int = 30) -> list[dict]:
        if kind is None:
            rows = self._db.execute(
                "SELECT ts, kind, data FROM events ORDER BY ts DESC LIMIT ?", (limit,)
            ).fetchall()
        else:
            rows = self._db.execute(
                "SELECT ts, kind, data FROM events WHERE kind = ? ORDER BY ts DESC LIMIT ?",
                (kind, limit),
            ).fetchall()
        return [
            {"ts": ts, "kind": k, **json.loads(data)} for ts, k, data in reversed(rows)
        ]
