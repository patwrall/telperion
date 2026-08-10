"""Nightly episodic compaction: yesterday's raw events become one
deterministic digest line per day, old raw data is pruned, and the brain
can recall the digests on demand (recall_days MCP tool)."""

import collections
import datetime
import logging
import time

from .store import Store

log = logging.getLogger("huan.compact")


def digest_day(store: Store, day: datetime.date) -> str:
    start = time.mktime(day.timetuple())
    end = start + 86400
    events = store.events_between(start, end)
    shell = [e for e in events if e["kind"] == "shell"]
    exchanges = store.exchange_count_between(start, end)

    if not shell and not exchanges:
        return ""

    failed = [e for e in shell if e.get("exit") not in (0, None)]
    dirs = collections.Counter(
        e.get("cwd", "?") for e in shell if e.get("cwd")
    ).most_common(2)
    long_runs = sorted(
        (e for e in shell if e.get("duration_s", 0) >= 60),
        key=lambda e: -e["duration_s"],
    )[:3]

    parts = [f"{len(shell)} notable shell commands ({len(failed)} failed)"]
    if dirs:
        parts.append("mostly in " + ", ".join(f"{d} ({n})" for d, n in dirs))
    for e in long_runs:
        status = "ok" if e.get("exit") == 0 else f"exit {e.get('exit')}"
        parts.append(
            f"long run: `{e.get('cmd', '?')[:50]}` {e['duration_s']:.0f}s {status}"
        )
    if exchanges:
        parts.append(f"{exchanges} voice exchanges")
    return "; ".join(parts)


def run(config_path: str | None) -> int:
    logging.basicConfig(level=logging.INFO, format="%(message)s")
    store = Store()
    yesterday = datetime.date.today() - datetime.timedelta(days=1)
    note = digest_day(store, yesterday)
    if note:
        store.set_daily_note(yesterday.isoformat(), note)
        log.info("daily note %s: %s", yesterday, note)
    else:
        log.info("no activity to compact for %s", yesterday)
    store.prune()
    log.info("pruned events >14d and exchanges >30d")
    return 0
