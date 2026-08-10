import json

import pytest
from huan.config import Config
from hypothesis import given
from hypothesis import strategies as st


class TestLoad:
    def test_none_path_gives_defaults(self):
        config = Config.load(None)
        assert config.stt_model == "small.en"
        assert config.silence_ms == 450

    def test_load_overrides(self, tmp_path):
        p = tmp_path / "c.json"
        p.write_text(json.dumps({"stt_device": "cpu", "followup_s": 0}))
        config = Config.load(str(p))
        assert config.stt_device == "cpu"
        assert config.followup_s == 0
        assert config.stt_model == "small.en"  # untouched default

    def test_unknown_key_rejected(self, tmp_path):
        # a typo in the nix module must fail loudly, not silently no-op
        p = tmp_path / "c.json"
        p.write_text(json.dumps({"sttt_model": "x"}))
        with pytest.raises(ValueError, match="sttt_model"):
            Config.load(str(p))

    def test_module_shape_loads(self, tmp_path):
        """The exact key set the nix module generates must stay loadable."""
        p = tmp_path / "c.json"
        p.write_text(
            json.dumps(
                {
                    "stt_model": "/nix/store/x",
                    "stt_device": "cuda",
                    "wake_enabled": True,
                    "wake_uri": "tcp://127.0.0.1:10400",
                    "wake_names": ["hey_huan"],
                    "silence_ms": 450,
                    "followup_s": 5,
                    "llama_url": "http://127.0.0.1:10401",
                    "agent_cmd": "claude",
                    "brain_model": "haiku",
                    "announce_min_s": 60,
                    "agent_model": "sonnet",
                    "agent_timeout_s": 300,
                    "agent_cwd": "~",
                    "agent_mcp_config": "/nix/store/mcp.json",
                    "agent_allowed_tools": ["Read"],
                    "agent_permission_mode": "acceptEdits",
                    "tts_voice": "/nix/store/v.onnx",
                    "eleven_voice_id": "abc",
                    "eleven_model_id": "eleven_flash_v2_5",
                    "eleven_api_key_file": "~/.config/huan/elevenlabs-key",
                    "eleven_stability": 0.4,
                    "eleven_similarity": 0.75,
                    "eleven_style": 0.4,
                    "eleven_speaker_boost": True,
                }
            )
        )
        config = Config.load(str(p))
        assert config.agent_cmd == "claude"
        assert config.brain_model == "haiku"


@given(
    st.dictionaries(
        st.text(min_size=1, max_size=15),
        st.one_of(st.text(max_size=10), st.integers(), st.booleans()),
        max_size=5,
    )
)
def test_arbitrary_json_never_partially_applies(tmp_path_factory, data):
    """Unknown keys raise; known keys load. Never a silent half-load."""
    p = tmp_path_factory.mktemp("c") / "c.json"
    p.write_text(json.dumps(data))
    import dataclasses

    known = {f.name for f in dataclasses.fields(Config)}
    if set(data) <= known:
        try:
            Config.load(str(p))
        except TypeError:
            pass  # wrong type for a known field is acceptable to reject
    else:
        with pytest.raises(ValueError):
            Config.load(str(p))
