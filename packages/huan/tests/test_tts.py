import time

from huan.config import Config
from huan.tts import SPEAKING_TAIL_S, Speaker


def make_speaker(tmp_path, **overrides):
    config = Config(**overrides)
    speaker = Speaker(config)
    return speaker


class TestSpeakingState:
    def test_silent_by_default(self, tmp_path):
        assert not make_speaker(tmp_path).speaking

    def test_buffered_audio_means_speaking(self, tmp_path):
        speaker = make_speaker(tmp_path)
        speaker._enqueue(b"\x00" * 1024)
        assert speaker.speaking

    def test_tail_after_drain(self, tmp_path):
        speaker = make_speaker(tmp_path)
        speaker._last_active = time.monotonic()
        assert speaker.speaking  # inside the tail margin
        speaker._last_active = time.monotonic() - SPEAKING_TAIL_S - 0.1
        assert not speaker.speaking


class TestKeyHandling:
    def test_missing_key_file_degrades(self, tmp_path):
        speaker = make_speaker(
            tmp_path,
            eleven_voice_id="v",
            eleven_api_key_file=str(tmp_path / "nope"),
        )
        assert not speaker.eleven_enabled

    def test_key_read_and_stripped(self, tmp_path):
        keyfile = tmp_path / "key"
        keyfile.write_text("sk_test\n")
        speaker = make_speaker(
            tmp_path, eleven_voice_id="v", eleven_api_key_file=str(keyfile)
        )
        assert speaker.eleven_enabled and speaker._api_key == "sk_test"

    def test_no_voice_id_disables_eleven(self, tmp_path):
        keyfile = tmp_path / "key"
        keyfile.write_text("sk_test")
        speaker = make_speaker(tmp_path, eleven_api_key_file=str(keyfile))
        assert not speaker.eleven_enabled


class TestFillers:
    def test_play_filler_without_clips_is_noop(self, tmp_path, monkeypatch):
        monkeypatch.setenv("XDG_DATA_HOME", str(tmp_path))
        speaker = make_speaker(tmp_path)
        speaker.play_filler()  # must not raise, must not open a stream
        assert speaker._stream is None

    def test_play_filler_skips_while_speaking(self, tmp_path, monkeypatch):
        monkeypatch.setenv("XDG_DATA_HOME", str(tmp_path))
        clips = tmp_path / "huan" / "fillers"
        clips.mkdir(parents=True)
        (clips / "filler_0.pcm").write_bytes(b"\x01" * 512)
        speaker = make_speaker(tmp_path)
        speaker._enqueue(b"\x00" * 1024)  # already talking
        before = bytes(speaker._buffer)
        speaker.play_filler()
        assert bytes(speaker._buffer) == before


class TestVoiceSettings:
    def test_settings_assembled_from_config(self, tmp_path):
        speaker = make_speaker(tmp_path, eleven_stability=0.2, eleven_style=0.9)
        assert speaker.eleven_voice_settings["stability"] == 0.2
        assert speaker.eleven_voice_settings["style"] == 0.9
        assert speaker.eleven_voice_settings["use_speaker_boost"] is True
