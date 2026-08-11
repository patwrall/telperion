import asyncio
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


class TestSpeechSerialization:
    async def test_utterances_synthesize_strictly_in_order(self, tmp_path, monkeypatch):
        # regression: v3's HTTP path let concurrent say() calls interleave
        # their audio chunks — two voices cutting each other off
        speaker = make_speaker(tmp_path)
        speaker.eleven_voice_id = "v"
        speaker._api_key = "k"
        order = []

        async def fake_synth(text):
            order.append(f"start:{text}")
            await asyncio.sleep(0.01)
            order.append(f"end:{text}")

        monkeypatch.setattr(speaker, "_say_with_fallback", fake_synth)
        monkeypatch.setattr(speaker, "_ensure_output_stream", lambda: None)
        await speaker.say("one")
        await speaker.say("two")
        await speaker.say("three")
        await asyncio.sleep(0.1)
        assert order == [
            "start:one",
            "end:one",
            "start:two",
            "end:two",
            "start:three",
            "end:three",
        ]

    async def test_interrupt_drops_queued_utterances(self, tmp_path, monkeypatch):
        speaker = make_speaker(tmp_path)
        speaker.eleven_voice_id = "v"
        speaker._api_key = "k"
        spoken = []

        async def slow_synth(text):
            spoken.append(text)
            await asyncio.sleep(1)

        monkeypatch.setattr(speaker, "_say_with_fallback", slow_synth)
        monkeypatch.setattr(speaker, "_ensure_output_stream", lambda: None)
        await speaker.say("one")
        await speaker.say("two")
        await asyncio.sleep(0.02)  # worker starts 'one'
        speaker.interrupt()
        await asyncio.sleep(0.05)
        assert spoken == ["one"]  # 'two' never synthesized


class TestInterrupt:
    def test_interrupt_clears_buffer_and_state(self, tmp_path):
        speaker = make_speaker(tmp_path)
        speaker._enqueue(b"\x00" * 4096)
        assert speaker.speaking
        speaker.interrupt()
        assert not speaker.speaking
        assert len(speaker._buffer) == 0

    def test_interrupt_when_silent_is_noop(self, tmp_path):
        make_speaker(tmp_path).interrupt()  # must not raise


class TestTagStripping:
    def test_tags_removed_for_piper(self):
        from huan.tts import _strip_tags

        assert _strip_tags("[chuckles] On three.") == "On three."
        assert _strip_tags("Done. [sighs] Finally.") == "Done. Finally."
        assert _strip_tags("no tags here") == "no tags here"

    def test_brackets_in_real_content_survive(self):
        from huan.tts import _strip_tags

        # a spoken array index should not be eaten (no lowercase-word shape)
        assert _strip_tags("check index [42] there") == "check index [42] there"


class TestVoiceSettings:
    def test_settings_assembled_from_config(self, tmp_path):
        speaker = make_speaker(tmp_path, eleven_stability=0.2, eleven_style=0.9)
        assert speaker.eleven_voice_settings["stability"] == 0.2
        assert speaker.eleven_voice_settings["style"] == 0.9
        assert speaker.eleven_voice_settings["use_speaker_boost"] is True


class TestFillerVariety:
    def test_no_immediate_repeat(self, tmp_path, monkeypatch):
        monkeypatch.setenv("XDG_DATA_HOME", str(tmp_path))
        speaker = make_speaker(tmp_path)
        clips = tmp_path / "huan" / "fillers"
        clips.mkdir(parents=True)
        for name in ("filler_aaa.pcm", "filler_bbb.pcm", "filler_ccc.pcm"):
            (clips / name).write_bytes(b"\x01" * 512)
        speaker._ensure_output_stream = lambda: None
        played = []
        speaker._enqueue = lambda pcm: played.append(speaker._last_filler)
        for _ in range(20):
            speaker.play_filler()
        assert all(a != b for a, b in zip(played, played[1:]))

    def test_single_clip_still_plays(self, tmp_path, monkeypatch):
        monkeypatch.setenv("XDG_DATA_HOME", str(tmp_path))
        speaker = make_speaker(tmp_path)
        clips = tmp_path / "huan" / "fillers"
        clips.mkdir(parents=True)
        (clips / "filler_only.pcm").write_bytes(b"\x01" * 512)
        speaker._ensure_output_stream = lambda: None
        count = []
        speaker._enqueue = lambda pcm: count.append(1)
        speaker.play_filler()
        speaker.play_filler()
        assert len(count) == 2


class TestWarm:
    async def test_warm_rate_limited(self, tmp_path):
        speaker = make_speaker(tmp_path, eleven_voice_id="v")
        speaker._api_key = "k"
        calls = []

        class FakeHttp:
            async def get(self, *a, **kw):
                calls.append(1)

        speaker._http = FakeHttp()
        await speaker.warm()
        await speaker.warm()  # within 30s window: skipped
        assert len(calls) == 1

    async def test_warm_noop_without_eleven(self, tmp_path):
        speaker = make_speaker(tmp_path)
        await speaker.warm()  # must not raise or create a client
        assert speaker._http is None

    async def test_warm_swallows_network_errors(self, tmp_path):
        speaker = make_speaker(tmp_path, eleven_voice_id="v")
        speaker._api_key = "k"

        class FailingHttp:
            async def get(self, *a, **kw):
                raise OSError("no network")

        speaker._http = FailingHttp()
        await speaker.warm()  # must not raise
