import asyncio
import logging

import numpy as np
import sounddevice as sd

log = logging.getLogger("huan.audio")

# 32ms = 512 samples at 16kHz, the native window of Silero VAD
CHUNK_MS = 32
VAD_CONTEXT_SAMPLES = 64


class Microphone:
    """A single capture stream fanned out to any number of subscribers.

    The wake-word listener subscribes for the daemon's lifetime; each
    utterance capture opens a fresh short-lived subscription, so the two
    never steal chunks from each other.
    """

    def __init__(self, sample_rate: int):
        self.sample_rate = sample_rate
        self._chunk_frames = sample_rate * CHUNK_MS // 1000
        self._subscribers: set[asyncio.Queue[bytes]] = set()
        self._stream: sd.RawInputStream | None = None
        self._loop = asyncio.get_event_loop()

    def _callback(self, indata, _frames, _time, status):
        if status:
            log.warning("capture status: %s", status)
        self._loop.call_soon_threadsafe(self._fanout, bytes(indata))

    def _fanout(self, data: bytes):
        for queue in self._subscribers:
            try:
                queue.put_nowait(data)
            except asyncio.QueueFull:
                pass  # slow consumer drops audio rather than stalling capture

    def start(self):
        if self._stream is not None:
            return
        self._stream = sd.RawInputStream(
            samplerate=self.sample_rate,
            channels=1,
            dtype="int16",
            blocksize=self._chunk_frames,
            callback=self._callback,
        )
        self._stream.start()
        log.info("microphone open (%d Hz, %dms chunks)", self.sample_rate, CHUNK_MS)

    def stop(self):
        if self._stream is not None:
            self._stream.stop()
            self._stream.close()
            self._stream = None

    async def chunks(self):
        """Yield raw int16 chunks from a fresh subscription until cancelled."""
        self.start()
        queue: asyncio.Queue[bytes] = asyncio.Queue(maxsize=256)
        self._subscribers.add(queue)
        try:
            while True:
                yield await queue.get()
        finally:
            self._subscribers.discard(queue)


def rms(chunk: bytes) -> float:
    samples = np.frombuffer(chunk, dtype=np.int16).astype(np.float32) / 32768.0
    if len(samples) == 0:
        return 0.0
    return float(np.sqrt(np.mean(samples**2)))


class SileroDetector:
    """Streaming Silero VAD, driving faster-whisper's bundled ONNX model
    one 512-sample window at a time with persistent recurrent state.

    An energy threshold can't tell ambient noise from speech, which made
    endpointing fail in a noisy room (silence never detected, 12s
    captures). Silero classifies actual speech; noise reads as silence.
    """

    def __init__(self, threshold: float = 0.5):
        from faster_whisper.vad import get_vad_model

        self._session = get_vad_model().session
        self.threshold = threshold
        self.reset()

    def reset(self):
        self._h = np.zeros((1, 1, 128), dtype=np.float32)
        self._c = np.zeros((1, 1, 128), dtype=np.float32)
        self._context = np.zeros(VAD_CONTEXT_SAMPLES, dtype=np.float32)

    def is_speech(self, chunk: bytes) -> bool:
        samples = np.frombuffer(chunk, dtype=np.int16).astype(np.float32) / 32768.0
        window = np.concatenate([self._context, samples])[None, :]
        prob, self._h, self._c = self._session.run(
            None, {"input": window, "h": self._h, "c": self._c}
        )
        self._context = samples[-VAD_CONTEXT_SAMPLES:]
        return float(prob.reshape(-1)[0]) >= self.threshold


class AdaptiveRmsDetector:
    """Fallback endpointer: energy threshold that tracks the ambient noise
    floor instead of being fixed, so background noise can't hold the
    silence countdown open forever."""

    def __init__(self, base_threshold: float):
        self.base = base_threshold
        self.reset()

    def reset(self):
        self._floor: float | None = None

    def is_speech(self, chunk: bytes) -> bool:
        level = rms(chunk)
        if self._floor is None:
            self._floor = level
        speech = level >= max(self.base, self._floor * 3.0)
        if not speech:
            self._floor = 0.95 * self._floor + 0.05 * level
        return speech


def make_speech_detector(base_threshold: float):
    try:
        detector = SileroDetector()
        log.info("endpointing with Silero VAD")
        return detector
    except Exception as exc:
        log.warning("Silero VAD unavailable (%s); falling back to adaptive RMS", exc)
        return AdaptiveRmsDetector(base_threshold)


async def capture_utterance(
    mic: Microphone,
    detector,
    *,
    silence_ms: int,
    max_s: float,
    stop_event: asyncio.Event | None = None,
    suppress=None,
    onset_timeout_ms: int | None = None,
) -> np.ndarray:
    """Record until trailing silence (or stop_event for push-to-talk).

    Returns float32 mono audio normalized to [-1, 1] for faster-whisper.
    Silence detection only starts after speech has been heard once, so a
    slow start doesn't produce an empty capture.

    Chunks arriving while suppress() is true (our own TTS playing) are
    dropped entirely so the transcript never contains huan's own voice.
    With onset_timeout_ms set, returns empty audio if no speech starts
    within that window.
    """
    detector.reset()
    buf: list[bytes] = []
    heard_speech = False
    silent_ms = 0
    total_ms = 0

    async for chunk in mic.chunks():
        total_ms += CHUNK_MS
        if suppress is not None and suppress():
            continue
        buf.append(chunk)
        if stop_event is not None:
            if stop_event.is_set():
                break
        else:
            if detector.is_speech(chunk):
                heard_speech = True
                silent_ms = 0
            else:
                silent_ms += CHUNK_MS
            if heard_speech and silent_ms >= silence_ms:
                break
            if (
                not heard_speech
                and onset_timeout_ms is not None
                and total_ms >= onset_timeout_ms
            ):
                return np.zeros(0, dtype=np.float32)
        if total_ms >= max_s * 1000:
            log.warning("utterance capture hit %.0fs cap", max_s)
            break

    samples = np.frombuffer(b"".join(buf), dtype=np.int16)
    return samples.astype(np.float32) / 32768.0
