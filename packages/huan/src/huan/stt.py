import gc
import logging
import time

import numpy as np

log = logging.getLogger("huan.stt")


class SpeechToText:
    """Lazy-loaded faster-whisper wrapper.

    load/unload exist for the manual sleep toggle: unload frees the GPU
    (VRAM back to games etc.), and the next transcribe() pays a cold-start
    reload, which the daemon logs so the cost stays visible.
    """

    def __init__(self, model: str, device: str, compute_type: str):
        self.model_name = model
        self.device = device
        self.compute_type = compute_type
        self._model = None

    @property
    def loaded(self) -> bool:
        return self._model is not None

    def load(self):
        if self._model is not None:
            return
        from faster_whisper import WhisperModel

        t0 = time.perf_counter()
        self._model = WhisperModel(
            self.model_name,
            device=self.device,
            compute_type=self.compute_type,
        )
        log.info(
            "loaded %s on %s in %.1fs",
            self.model_name,
            self.device,
            time.perf_counter() - t0,
        )

    def unload(self):
        if self._model is None:
            return
        self._model = None
        gc.collect()
        log.info("unloaded %s", self.model_name)

    def transcribe(self, audio: np.ndarray) -> str:
        self.load()
        segments, _info = self._model.transcribe(
            audio,
            language="en",
            beam_size=1,
            vad_filter=True,
        )
        return " ".join(s.text.strip() for s in segments).strip()
