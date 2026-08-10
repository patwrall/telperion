import asyncio

import numpy as np
from huan.audio import CHUNK_MS, AdaptiveRmsDetector, capture_utterance, rms

SILENCE = (np.zeros(512, dtype=np.int16)).tobytes()
SPEECH = (np.full(512, 8000, dtype=np.int16)).tobytes()


class ScriptedMic:
    def __init__(self, chunks):
        self._chunks = list(chunks)

    async def chunks(self):
        for chunk in self._chunks:
            yield chunk
        while True:  # endless trailing silence, like a real mic
            yield SILENCE


class MarkerDetector:
    """Speech iff the chunk is the SPEECH marker."""

    def reset(self):
        pass

    def is_speech(self, chunk):
        return chunk == SPEECH


def n_silence(ms):
    return [SILENCE] * (ms // CHUNK_MS)


class TestEndpointing:
    async def test_ends_after_trailing_silence(self):
        mic = ScriptedMic([SPEECH] * 10)
        audio = await capture_utterance(mic, MarkerDetector(), silence_ms=160, max_s=5)
        assert len(audio) > 0

    async def test_leading_silence_does_not_end_capture(self):
        mic = ScriptedMic(n_silence(1000) + [SPEECH] * 5)
        audio = await capture_utterance(mic, MarkerDetector(), silence_ms=160, max_s=10)
        assert len(audio) >= 5 * 512

    async def test_mid_pause_shorter_than_window_survives(self):
        mic = ScriptedMic([SPEECH] * 5 + n_silence(96) + [SPEECH] * 5)
        audio = await capture_utterance(mic, MarkerDetector(), silence_ms=320, max_s=10)
        assert len(audio) >= 10 * 512

    async def test_onset_timeout_returns_empty(self):
        # regression: wake word + silence used to hold a 15s open capture
        mic = ScriptedMic([])
        audio = await capture_utterance(
            mic, MarkerDetector(), silence_ms=160, max_s=10, onset_timeout_ms=200
        )
        assert len(audio) == 0

    async def test_max_cap(self):
        mic = ScriptedMic([SPEECH] * 10_000)
        audio = await capture_utterance(
            mic, MarkerDetector(), silence_ms=10_000, max_s=0.5
        )
        assert len(audio) <= int(0.6 * 16_000) * 2

    async def test_suppress_drops_chunks_entirely(self):
        # regression: huan used to transcribe its own TTS
        mic = ScriptedMic([SPEECH] * 5)
        audio = await capture_utterance(
            mic,
            MarkerDetector(),
            silence_ms=64,
            max_s=0.5,
            suppress=lambda: True,
        )
        assert len(audio) == 0

    async def test_ptt_stop_event(self):
        stop = asyncio.Event()
        mic = ScriptedMic([SPEECH, SPEECH])

        async def stopper():
            await asyncio.sleep(0.01)
            stop.set()

        task = asyncio.create_task(stopper())
        audio = await capture_utterance(
            mic, MarkerDetector(), silence_ms=10_000, max_s=30, stop_event=stop
        )
        await task
        assert len(audio) >= 512


class TestRms:
    def test_silence_is_zero(self):
        assert rms(SILENCE) == 0.0

    def test_signal_is_positive(self):
        assert rms(SPEECH) > 0.2

    def test_empty_chunk(self):
        assert rms(b"") == 0.0


class TestAdaptiveRms:
    def test_speech_over_quiet_floor(self):
        d = AdaptiveRmsDetector(0.015)
        for _ in range(5):
            assert not d.is_speech(SILENCE)
        assert d.is_speech(SPEECH)

    def test_constant_noise_becomes_floor(self):
        # regression: fixed threshold let ambient noise hold captures open
        noise = (np.full(512, 900, dtype=np.int16)).tobytes()
        d = AdaptiveRmsDetector(0.015)
        d.is_speech(noise)
        for _ in range(60):
            d.is_speech(noise)
        assert not d.is_speech(noise)
