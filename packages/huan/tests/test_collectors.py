from huan.collectors import WorldState, _ago, _short
from hypothesis import given
from hypothesis import strategies as st


def make_state(store):
    return WorldState(store)


class TestShellLifecycle:
    def test_start_then_end(self, store):
        w = make_state(store)
        w.shell_event({"phase": "start", "id": "1", "cmd": "make", "cwd": "/x"})
        assert len(w.running_cmds) == 1
        w.shell_event(
            {"phase": "end", "id": "1", "cmd": "make", "exit": 0, "duration": 3}
        )
        assert not w.running_cmds
        assert w.finished_cmds[-1]["exit"] == 0

    def test_end_without_start(self, store):
        w = make_state(store)
        w.shell_event(
            {"phase": "end", "id": "ghost", "cmd": "ls", "exit": 0, "duration": 0.1}
        )
        assert w.finished_cmds[-1]["cmd"] == "ls"

    def test_running_cap(self, store):
        w = make_state(store)
        for i in range(40):
            w.shell_event({"phase": "start", "id": str(i), "cmd": "x", "cwd": "/"})
        assert len(w.running_cmds) <= 20

    def test_finished_cap(self, store):
        w = make_state(store)
        for i in range(30):
            w.shell_event(
                {"phase": "end", "id": str(i), "cmd": "x", "exit": 0, "duration": 0.1}
            )
        assert len(w.finished_cmds) == 10

    def test_only_interesting_events_persist(self, store):
        w = make_state(store)
        w.shell_event(
            {"phase": "end", "id": "a", "cmd": "ls", "exit": 0, "duration": 0.1}
        )
        w.shell_event(
            {"phase": "end", "id": "b", "cmd": "build", "exit": 0, "duration": 60}
        )
        w.shell_event(
            {"phase": "end", "id": "c", "cmd": "bad", "exit": 1, "duration": 0.1}
        )
        persisted = {e["cmd"] for e in store.recent_events("shell")}
        assert persisted == {"build", "bad"}

    def test_command_end_hook_fires(self, store):
        w = make_state(store)
        seen = []
        w.on_command_end = seen.append
        w.shell_event({"phase": "end", "id": "1", "cmd": "x", "exit": 2, "duration": 9})
        assert seen and seen[0]["exit"] == 2


class TestDescribe:
    def test_empty(self, store):
        assert "no desktop state" in make_state(store).describe()

    def test_includes_workspace_window_and_commands(self, store):
        w = make_state(store)
        w.workspace = 3
        w.window_class, w.window_title = "kitty", "vim daemon.py"
        w.shell_event(
            {"phase": "start", "id": "1", "cmd": "nix build .#huan", "cwd": "/home/x/t"}
        )
        text = w.describe()
        assert "workspace 3" in text
        assert "kitty" in text and "vim daemon.py" in text
        assert "nix build .#huan" in text and "running" in text

    def test_failed_command_shows_exit(self, store):
        w = make_state(store)
        w.shell_event(
            {"phase": "end", "id": "1", "cmd": "make", "exit": 2, "duration": 30}
        )
        assert "exit 2" in w.describe()


class TestHelpers:
    def test_short_replaces_home(self, monkeypatch):
        monkeypatch.setenv("HOME", "/home/pat")
        assert _short("/home/pat/telperion") == "~/telperion"

    def test_short_empty(self):
        assert _short("") == "?"

    def test_ago_ranges(self):
        assert _ago(30).endswith("s")
        assert _ago(600).endswith("m")
        assert _ago(7200).endswith("h")


class NullStore:
    def add_event(self, kind, **data):
        pass


@given(
    st.dictionaries(
        st.sampled_from(["phase", "id", "cmd", "cwd", "exit", "duration"]),
        st.one_of(st.text(max_size=20), st.integers(-2, 300), st.none()),
        max_size=6,
    )
)
def test_shell_event_never_crashes(data):
    w = WorldState(NullStore())
    try:
        w.shell_event(data)
    except (TypeError, ValueError):
        # tolerated only for junk duration values; state must stay usable
        pass
    w.describe()
