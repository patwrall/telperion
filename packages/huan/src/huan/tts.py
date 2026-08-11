import asyncio
import base64
import json
import logging
import os
import threading
import time
from pathlib import Path

import sounddevice as sd

log = logging.getLogger("huan.tts")

# pw-play exits once a bursty raw stream goes idle (verified: rc=1 after the
# first utterance, piper then dies of SIGPIPE), so the daemon plays audio
# itself: synthesis backend -> daemon-side buffer -> sounddevice output.
# Bonus: the buffer tells us exactly when audio is audible, which the mic
# uses to avoid transcribing our own voice.

SPEAKING_TAIL_S = 0.35  # sink latency margin after the buffer drains
ELEVEN_RATE = 22050  # pcm_22050 output; matches the default piper voices

_TAG_RE = None


def _strip_tags(text: str) -> str:
    """Remove [audio tags] meant for eleven v3; piper would read them aloud."""
    global _TAG_RE
    if _TAG_RE is None:
        import re

        _TAG_RE = re.compile(r"\[[a-z][a-z ']{0,25}\]\s*", re.IGNORECASE)
    return _TAG_RE.sub("", text).strip()


class Speaker:
    """TTS with two synthesis sources feeding one playback path.

    ElevenLabs (streaming PCM over HTTP) is primary when configured;
    a persistent local piper process is the fallback for network/quota/
    key failures, so acks never go silent offline.
    """

    def __init__(self, config):
        self.voice = config.tts_voice
        self.eleven_voice_id = config.eleven_voice_id
        self.eleven_model_id = config.eleven_model_id
        self.eleven_voice_settings = {
            "stability": config.eleven_stability,
            "similarity_boost": config.eleven_similarity,
            "style": config.eleven_style,
            "use_speaker_boost": config.eleven_speaker_boost,
        }
        self._api_key = self._read_key(config.eleven_api_key_file)
        self._http = None
        self._ws = None
        self._ws_recv_task: asyncio.Task | None = None
        self._ws_flush_t0: float | None = None
        self._piper: asyncio.subprocess.Process | None = None
        self._reader_task: asyncio.Task | None = None
        self._stream: sd.RawOutputStream | None = None
        self._stream_rate: int | None = None
        self._buffer = bytearray()
        self._buffer_lock = threading.Lock()  # callback runs on PortAudio thread
        self._last_active = 0.0
        self._say_queue: asyncio.Queue[str] = asyncio.Queue()
        self._say_worker: asyncio.Task | None = None
        self._current_utterance = None
        if self.eleven_enabled:
            log.info("elevenlabs TTS enabled (voice %s)", self.eleven_voice_id)

    @staticmethod
    def _read_key(path: str) -> str:
        if not path:
            return ""
        try:
            return Path(os.path.expanduser(path)).read_text().strip()
        except OSError as exc:
            log.warning("cannot read elevenlabs key (%s); using piper only", exc)
            return ""

    @property
    def eleven_enabled(self) -> bool:
        return bool(self._api_key and self.eleven_voice_id)

    @property
    def speaking(self) -> bool:
        with self._buffer_lock:
            if self._buffer:
                return True
        return (time.monotonic() - self._last_active) < SPEAKING_TAIL_S

    async def wait_quiet(self, timeout_s: float = 10.0):
        deadline = time.monotonic() + timeout_s
        while self.speaking and time.monotonic() < deadline:
            await asyncio.sleep(0.05)

    def interrupt(self):
        """Barge-in: stop talking immediately. Drops queued utterances,
        buffered audio, and the in-flight synthesis stream."""
        while not self._say_queue.empty():
            self._say_queue.get_nowait()
        if self._say_worker is not None and not self._say_worker.done():
            self._say_worker.cancel()
            self._say_worker = None
        with self._buffer_lock:
            had_audio = bool(self._buffer)
            self._buffer.clear()
        self._last_active = 0.0
        self._prev_synth_text = ""  # a cut-off take is no prosody anchor
        if self._ws is not None:
            ws, self._ws = self._ws, None
            asyncio.ensure_future(ws.close())
        if had_audio:
            log.info("speech interrupted")

    # -- playback ------------------------------------------------------------

    def _piper_sample_rate(self) -> int:
        try:
            config = json.loads(Path(self.voice + ".json").read_text())
            return int(config["audio"]["sample_rate"])
        except (OSError, KeyError, ValueError) as exc:
            log.warning("could not read voice config, assuming 22050 Hz: %s", exc)
            return 22050

    def _playback_callback(self, outdata, _frames, _time, status):
        if status:
            log.warning("playback status: %s", status)
        needed = len(outdata)
        with self._buffer_lock:
            take = bytes(self._buffer[:needed])
            del self._buffer[:needed]
        if take:
            self._last_active = time.monotonic()
        outdata[: len(take)] = take
        outdata[len(take) :] = b"\x00" * (needed - len(take))

    def _ensure_output_stream(self):
        rate = ELEVEN_RATE if self.eleven_enabled else self._piper_sample_rate()
        if self._stream is not None:
            return
        if self.eleven_enabled and self._piper_sample_rate() != rate:
            log.warning(
                "piper voice rate %d != %d; fallback audio will play off-pitch",
                self._piper_sample_rate(),
                rate,
            )
        self._stream_rate = rate
        self._stream = sd.RawOutputStream(
            samplerate=rate,
            channels=1,
            dtype="int16",
            callback=self._playback_callback,
        )
        self._stream.start()

    def _enqueue(self, chunk: bytes):
        with self._buffer_lock:
            self._buffer.extend(chunk)

    # -- elevenlabs websocket backend ----------------------------------------
    # A persistent stream-input connection skips the per-utterance TLS/HTTP
    # handshake. ElevenLabs closes idle connections (inactivity_timeout caps
    # at 180s), so sparse acks pay one reconnect; bursts and follow-up
    # chains ride the warm socket. No keepalive spam: a keepalive character
    # every minute would quietly eat ~7% of the monthly credit budget.

    async def _ws_connect(self):
        import websockets

        url = (
            f"wss://api.elevenlabs.io/v1/text-to-speech/{self.eleven_voice_id}"
            f"/stream-input?model_id={self.eleven_model_id}"
            f"&output_format=pcm_{ELEVEN_RATE}&inactivity_timeout=180"
        )
        t0 = time.monotonic()
        self._ws = await websockets.connect(
            url, additional_headers={"xi-api-key": self._api_key}, open_timeout=5
        )
        await self._ws.send(
            json.dumps({"text": " ", "voice_settings": self.eleven_voice_settings})
        )
        self._ws_recv_task = asyncio.create_task(self._ws_receive(self._ws))
        log.info("elevenlabs ws connected in %.0fms", (time.monotonic() - t0) * 1000)

    async def _ws_receive(self, ws):
        try:
            async for message in ws:
                data = json.loads(message)
                audio = data.get("audio")
                if audio:
                    if self._ws_flush_t0 is not None:
                        log.info(
                            "elevenlabs ws first audio in %.0fms",
                            (time.monotonic() - self._ws_flush_t0) * 1000,
                        )
                        self._ws_flush_t0 = None
                    self._enqueue(base64.b64decode(audio))
        except Exception as exc:
            log.debug("elevenlabs ws closed: %s", exc)
        finally:
            if self._ws is ws:
                self._ws = None

    async def _say_eleven_ws(self, text: str):
        if self._ws is None:
            await self._ws_connect()
        self._ws_flush_t0 = time.monotonic()
        await self._ws.send(
            json.dumps({"text": text.replace("\n", " ") + " ", "flush": True})
        )

    # -- elevenlabs http backend (fallback for ws failures) ------------------

    async def warm(self):
        """Re-establish the TLS connection to ElevenLabs while the brain is
        still thinking, so first audio doesn't pay the handshake. Called at
        turn start; rate-limited; failures are irrelevant."""
        if not self.eleven_enabled:
            return
        now = time.monotonic()
        if now - getattr(self, "_last_warm", 0.0) < 30.0:
            return
        self._last_warm = now
        import httpx

        if self._http is None:
            self._http = httpx.AsyncClient(timeout=10.0)
        try:
            await self._http.get(
                "https://api.elevenlabs.io/v1/models",
                headers={"xi-api-key": self._api_key},
                timeout=3.0,
            )
        except Exception:
            pass

    async def _say_eleven(self, text: str):
        import httpx

        if self._http is None:
            self._http = httpx.AsyncClient(timeout=10.0)
        url = (
            f"https://api.elevenlabs.io/v1/text-to-speech/{self.eleven_voice_id}/stream"
        )
        t0 = time.monotonic()
        first = True
        # previous_text: each sentence of a reply is its own request, and
        # v3 renders each as an independent take — audibly different mid
        # reply. Passing the prior sentence keeps the prosody continuous.
        body = {
            "text": text,
            "model_id": self.eleven_model_id,
            "voice_settings": self.eleven_voice_settings,
        }
        if getattr(self, "_prev_synth_text", ""):
            body["previous_text"] = self._prev_synth_text[-300:]
        async with self._http.stream(
            "POST",
            url,
            params={"output_format": f"pcm_{ELEVEN_RATE}"},
            headers={"xi-api-key": self._api_key},
            json=body,
        ) as response:
            response.raise_for_status()
            async for chunk in response.aiter_bytes():
                if first:
                    log.info(
                        "elevenlabs first audio in %.0fms",
                        (time.monotonic() - t0) * 1000,
                    )
                    first = False
                self._enqueue(chunk)
        self._prev_synth_text = text

    # -- piper fallback ------------------------------------------------------

    async def _piper_read_audio(self):
        while True:
            chunk = await self._piper.stdout.read(4096)
            if not chunk:
                log.warning("piper stdout closed")
                break
            self._enqueue(chunk)

    async def _say_piper(self, text: str):
        if not self.voice:
            return
        if self._piper is None or self._piper.returncode is not None:
            if self._reader_task is not None:
                self._reader_task.cancel()
            self._piper = await asyncio.create_subprocess_exec(
                "piper",
                "--model",
                self.voice,
                "--output-raw",
                stdin=asyncio.subprocess.PIPE,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.DEVNULL,
            )
            self._reader_task = asyncio.create_task(self._piper_read_audio())
            log.info("piper started (voice %s)", self.voice)
        self._piper.stdin.write(text.replace("\n", " ").encode() + b"\n")
        await self._piper.stdin.drain()

    # -- public --------------------------------------------------------------

    async def say(self, text: str):
        """Queue an utterance. One worker synthesizes strictly in order, so
        concurrent speakers (acks, brain replies, agent summaries) can never
        interleave their audio — the jank when two things talked at once."""
        if not text or not (self.eleven_enabled or self.voice):
            return
        self._ensure_output_stream()
        if self._say_worker is None or self._say_worker.done():
            self._say_worker = asyncio.create_task(self._speech_worker())
        self._say_queue.put_nowait(text)

    async def _speech_worker(self):
        while True:
            text = await self._say_queue.get()
            self._current_utterance = asyncio.current_task()
            try:
                if self.eleven_enabled:
                    await self._say_with_fallback(text)
                else:
                    await self._say_piper(_strip_tags(text))
            except asyncio.CancelledError:
                raise
            except Exception as exc:
                log.warning("utterance failed (%s): %r", exc, text[:60])

    # -- thinking fillers ----------------------------------------------------
    # short pre-synthesized clips played instantly while the brain thinks;
    # silence is what makes a 3s reply feel slow

    # short, dry, low-energy — variety without theater; sparse [tags]
    # give eleven_v3 natural delivery. Clips are cached by content hash,
    # so editing this list regenerates only what changed. NEUTRAL
    # thinking sounds only: work-flavored fillers ("Checking.", "Let me
    # look.") played before casual banter and read as robotic ack spam —
    # a filler must fit both "fix my build" and "what's your genre".
    FILLER_PHRASES = [
        "Hmm.",
        "Mm.",
        "[thoughtful] Hmm, hold on.",
        "Mm, one sec.",
        "Hang on.",
        "Right...",
        "Bear with me.",
        "Give me a second here.",
    ]

    def _filler_dir(self):
        import pathlib

        base = pathlib.Path(
            os.environ.get("XDG_DATA_HOME", "~/.local/share")
        ).expanduser()
        return base / "huan" / "fillers"

    async def prime_fillers(self):
        """Synthesize the filler clips once and cache them as raw PCM."""
        if not self.eleven_enabled:
            return
        import hashlib

        import httpx

        directory = self._filler_dir()
        directory.mkdir(parents=True, exist_ok=True)
        # settings are part of the hash: fillers rendered with default
        # voice_settings sounded like a different speaker than the replies
        settings_tag = json.dumps(self.eleven_voice_settings, sort_keys=True)
        wanted = {
            f"filler_{hashlib.sha1((p + settings_tag).encode()).hexdigest()[:12]}.pcm": p
            for p in self.FILLER_PHRASES
        }
        for stale in directory.glob("filler_*.pcm"):
            if stale.name not in wanted:
                stale.unlink()
        for name, phrase in wanted.items():
            target = directory / name
            if target.exists():
                continue
            try:
                async with httpx.AsyncClient(timeout=15.0) as http:
                    response = await http.post(
                        f"https://api.elevenlabs.io/v1/text-to-speech/{self.eleven_voice_id}",
                        params={"output_format": f"pcm_{ELEVEN_RATE}"},
                        headers={"xi-api-key": self._api_key},
                        json={
                            "text": phrase,
                            "model_id": self.eleven_model_id,
                            "voice_settings": self.eleven_voice_settings,
                        },
                    )
                    response.raise_for_status()
                target.write_bytes(response.content)
                log.info("cached filler %r", phrase)
            except Exception as exc:
                log.warning("filler synthesis failed (%s)", exc)
                return

    def play_filler(self):
        """Instantly play a cached thinking sound; no-op if already talking."""
        if self.speaking:
            return
        import random

        clips = sorted(self._filler_dir().glob("filler_*.pcm"))
        if not clips:
            return
        # variety guard: never the same filler twice in a row
        pool = [c for c in clips if c.name != getattr(self, "_last_filler", None)]
        choice = random.choice(pool or clips)
        self._last_filler = choice.name
        log.info("filler: %s", choice.stem)
        self._ensure_output_stream()
        self._enqueue(choice.read_bytes())

    async def _say_with_fallback(self, text: str):
        # v3 has no stream-input websocket; go straight to HTTP streaming
        if "v3" not in self.eleven_model_id:
            try:
                await self._say_eleven_ws(text)
                return
            except Exception as exc:
                log.warning("elevenlabs ws failed (%s); trying http", exc)
                self._ws = None
        try:
            await self._say_eleven(text)
        except Exception as exc:
            log.warning("elevenlabs failed (%s); falling back to piper", exc)
            await self._say_piper(_strip_tags(text))
