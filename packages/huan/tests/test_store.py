import itertools
import tempfile
from pathlib import Path

from huan.store import Store
from hypothesis import given
from hypothesis import strategies as st


class TestExchanges:
    def test_roundtrip_and_order(self, store):
        store.add_exchange("user", "first")
        store.add_exchange("huan", "second")
        store.add_exchange("user", "third")
        assert store.recent_exchanges(2) == ["huan: second", "user: third"]

    def test_limit_larger_than_content(self, store):
        store.add_exchange("user", "only")
        assert store.recent_exchanges(50) == ["user: only"]

    def test_empty(self, store):
        assert store.recent_exchanges() == []

    def test_survives_reopen(self, tmp_path):
        # regression: restart amnesia was the core v4.1 complaint
        path = tmp_path / "p.db"
        Store(path).add_exchange("user", "before restart")
        assert Store(path).recent_exchanges() == ["user: before restart"]


class TestKV:
    def test_set_get(self, store):
        store.set("k", "v")
        assert store.get("k") == "v"

    def test_overwrite(self, store):
        store.set("k", "v1")
        store.set("k", "v2")
        assert store.get("k") == "v2"

    def test_default(self, store):
        assert store.get("missing") is None
        assert store.get("missing", "d") == "d"

    def test_delete_via_none(self, store):
        store.set("k", "v")
        store.set("k", None)
        assert store.get("k") is None


class TestEvents:
    def test_kind_filter_and_order(self, store):
        store.add_event("shell", cmd="a")
        store.add_event("focus", title="b")
        store.add_event("shell", cmd="c")
        shells = store.recent_events("shell")
        assert [e["cmd"] for e in shells] == ["a", "c"]
        assert all(e["kind"] == "shell" for e in shells)

    def test_limit(self, store):
        for i in range(10):
            store.add_event("shell", i=i)
        events = store.recent_events("shell", limit=3)
        assert [e["i"] for e in events] == [7, 8, 9]

    def test_all_kinds(self, store):
        store.add_event("a", x=1)
        store.add_event("b", x=2)
        assert len(store.recent_events()) == 2


_shared_store = Store(Path(tempfile.mkdtemp()) / "hypothesis.db")
_unique = itertools.count()


@given(
    role=st.text(min_size=1, max_size=20),
    text=st.text(min_size=1, max_size=500),
)
def test_exchange_roundtrip_arbitrary_unicode(role, text):
    _shared_store.add_exchange(role, text)
    assert _shared_store.recent_exchanges(1) == [f"{role}: {text}"]


@given(
    st.dictionaries(
        st.text(min_size=1, max_size=10).filter(lambda k: k not in ("ts", "kind")),
        st.one_of(
            st.text(max_size=50), st.integers(), st.floats(allow_nan=False), st.none()
        ),
        max_size=5,
    )
)
def test_event_roundtrip_arbitrary_payload(payload):
    kind = f"k{next(_unique)}"
    _shared_store.add_event(kind, **payload)
    (event,) = _shared_store.recent_events(kind)
    for key, value in payload.items():
        assert event[key] == value
