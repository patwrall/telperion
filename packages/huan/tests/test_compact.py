import datetime
import time

from huan.collectors import NotifyParser
from huan.compact import digest_day


class TestDigest:
    def test_empty_day_is_empty(self, store):
        assert digest_day(store, datetime.date.today()) == ""

    def test_digest_contents(self, store, monkeypatch):
        today = datetime.date.today()
        base = time.mktime(today.timetuple()) + 3600
        monkeypatch.setattr(time, "time", lambda: base)
        store.add_event(
            "shell", cmd="nix build .#huan", cwd="~/telperion", exit=1, duration_s=355.0
        )
        store.add_event(
            "shell", cmd="git status", cwd="~/telperion", exit=0, duration_s=0.5
        )
        store.add_exchange("user", "hello")
        note = digest_day(store, today)
        assert "2 notable shell commands (1 failed)" in note
        assert "~/telperion" in note
        assert "nix build" in note and "exit 1" in note
        assert "1 voice exchanges" in note

    def test_notes_roundtrip_and_order(self, store):
        store.set_daily_note("2026-08-09", "day one")
        store.set_daily_note("2026-08-10", "day two")
        assert store.daily_notes() == [
            ("2026-08-09", "day one"),
            ("2026-08-10", "day two"),
        ]
        store.set_daily_note("2026-08-10", "day two revised")
        assert store.daily_notes(1) == [("2026-08-10", "day two revised")]

    def test_prune_removes_old_rows(self, store):
        old = time.time() - 40 * 86400
        store._db.execute("INSERT INTO events VALUES (?, 'shell', '{}')", (old,))
        store._db.execute("INSERT INTO exchanges VALUES (?, 'user', 'ancient')", (old,))
        store._db.commit()
        store.add_event("shell", cmd="fresh")
        store.add_exchange("user", "fresh")
        store.prune()
        assert len(store.recent_events()) == 1
        assert store.recent_exchanges() == ["user: fresh"]


class TestNotifyParser:
    DBUS_BLOCK = [
        "method call time=1 sender=:1.2 -> destination=:1.3 serial=4 path=/org/freedesktop/Notifications; interface=org.freedesktop.Notifications; member=Notify",
        '   string "Discord"',
        "   uint32 0",
        '   string "discord-icon"',
        '   string "vance"',
        '   string "you seeing this kernel perf regression?"',
        "   array [",
    ]

    def test_parses_notification(self):
        seen = []
        parser = NotifyParser(lambda a, s, b: seen.append((a, s, b)))
        for line in self.DBUS_BLOCK:
            parser.feed(line)
        assert seen == [("Discord", "vance", "you seeing this kernel perf regression?")]

    def test_ignores_noise_outside_calls(self):
        seen = []
        parser = NotifyParser(lambda a, s, b: seen.append(1))
        parser.feed('   string "stray"')
        parser.feed("signal time=2 member=NotificationClosed")
        assert seen == []

    def test_world_state_notification_flow(self, store):
        from huan.collectors import WorldState

        w = WorldState(store)
        w.notification("Discord", "vance", "hey")
        assert "notification" in w.describe()
        assert "Discord" in w.describe()

    def test_chronic_notifications_ignored(self, store):
        from huan.collectors import WorldState

        w = WorldState(store)
        w.notification("Claude Code", "Claude Code — Awaiting your input", "")
        assert not w.notifications
