#!/usr/bin/env python3
"""HPA-440 ambience source-container check (Python stdlib `wave` only).

Enforces the locked source contract for the committed ambience WAVs:
mono, 16-bit signed PCM, 22050 Hz, exactly 110250 frames (5.0 s), and
absolute sample peak below 0.30 full scale. Prints measured peak and RMS
for the assets/audio/README.md handoff record.

Exit 0 on success; exit 1 naming the first violation.
"""

import struct
import sys
import wave
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
PATHS = [
    REPO / "assets/audio/river-ambience.wav",
    REPO / "assets/audio/rain-ambience.wav",
]


def fail(path: Path, message: str) -> None:
    print(f"FAIL {path.name}: {message}", file=sys.stderr)
    sys.exit(1)


def main() -> None:
    for path in PATHS:
        with wave.open(str(path), "rb") as w:
            if w.getnchannels() != 1:
                fail(path, "must be mono")
            if w.getsampwidth() != 2:
                fail(path, "must be 16-bit PCM")
            if w.getframerate() != 22050:
                fail(path, "must be 22050 Hz")
            if w.getnframes() != 110250:
                fail(path, "must be exactly 110250 frames (5.0 s)")
            raw = w.readframes(w.getnframes())
        count = len(raw) // 2
        samples = struct.unpack(f"<{count}h", raw)
        peak = max(abs(s) for s in samples) / 32768.0
        rms = (sum(s * s for s in samples) / count) ** 0.5 / 32768.0
        if peak >= 0.30:
            fail(path, f"peak {peak:.4f} must be below 0.30")
        print(f"OK {path.name}: peak {peak:.4f} rms {rms:.5f}")


if __name__ == "__main__":
    main()
