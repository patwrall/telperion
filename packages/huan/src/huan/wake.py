import asyncio
import logging

from wyoming.audio import AudioChunk, AudioStart
from wyoming.client import AsyncClient
from wyoming.wake import Detect, Detection

from .audio import Microphone

log = logging.getLogger("huan.wake")

RECONNECT_DELAY_S = 5


async def listen(mic: Microphone, uri: str, names: list[str], on_detect, suppress=None):
    """Stream mic audio to wyoming-openwakeword; call on_detect(name) on hits.

    While suppress() is true (our own TTS playing) silence is streamed in
    place of mic audio, so huan can't wake itself. Reconnects forever so
    the daemon survives the wake service restarting.
    """
    while True:
        try:
            await _listen_once(mic, uri, names, on_detect, suppress)
        except asyncio.CancelledError:
            raise
        except Exception as exc:
            log.warning(
                "wake service connection lost (%s); retrying in %ss",
                exc,
                RECONNECT_DELAY_S,
            )
            await asyncio.sleep(RECONNECT_DELAY_S)


async def _listen_once(
    mic: Microphone, uri: str, names: list[str], on_detect, suppress
):
    async with AsyncClient.from_uri(uri) as client:
        await client.write_event(Detect(names=names).event())
        await client.write_event(
            AudioStart(rate=mic.sample_rate, width=2, channels=1).event()
        )
        log.info("wake listener connected to %s (names=%s)", uri, names)

        async def pump():
            async for chunk in mic.chunks():
                if suppress is not None and suppress():
                    chunk = b"\x00" * len(chunk)
                await client.write_event(
                    AudioChunk(
                        rate=mic.sample_rate, width=2, channels=1, audio=chunk
                    ).event()
                )

        pump_task = asyncio.create_task(pump())
        try:
            while True:
                event = await client.read_event()
                if event is None:
                    raise ConnectionError("wake service closed the connection")
                if Detection.is_type(event.type):
                    detection = Detection.from_event(event)
                    await on_detect(detection.name)
        finally:
            pump_task.cancel()
