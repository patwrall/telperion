import json
import os
from dataclasses import dataclass, field, fields
from pathlib import Path


def _runtime_dir() -> Path:
    return Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp"))


@dataclass
class Config:
    # STT
    stt_model: str = "small.en"
    stt_device: str = "cuda"
    stt_compute_type: str = "auto"
    preload_stt: bool = True

    # Wake word (wyoming-openwakeword companion service)
    wake_enabled: bool = True
    wake_uri: str = "tcp://127.0.0.1:10400"
    wake_names: list[str] = field(default_factory=lambda: ["hey_jarvis"])

    # TTS (piper voice model path; empty disables spoken acknowledgments)
    tts_voice: str = ""

    # ElevenLabs TTS (primary when key + voice id are set; piper is fallback)
    eleven_voice_id: str = ""
    eleven_model_id: str = "eleven_flash_v2_5"
    eleven_api_key_file: str = ""
    eleven_stability: float = 0.4
    eleven_similarity: float = 0.75
    eleven_style: float = 0.4
    eleven_speaker_boost: bool = True

    # Audio capture
    sample_rate: int = 16000
    max_utterance_s: float = 15.0
    silence_ms: int = 450
    rms_threshold: float = 0.015

    # After a voice command, keep listening this long for a chained command
    # without requiring the wake word again. 0 disables.
    followup_s: float = 5.0

    # llama.cpp server for conversational intent (empty disables; regex
    # fast-path always runs first)
    llama_url: str = ""

    @property
    def control_socket(self) -> Path:
        return _runtime_dir() / "huan.sock"

    @classmethod
    def load(cls, path: str | None) -> "Config":
        if path is None:
            return cls()
        raw = json.loads(Path(path).read_text())
        known = {f.name for f in fields(cls)}
        unknown = set(raw) - known
        if unknown:
            raise ValueError(f"unknown config keys: {sorted(unknown)}")
        return cls(**raw)
