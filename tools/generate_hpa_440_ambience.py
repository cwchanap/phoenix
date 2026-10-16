"""Generate the HPA-440 river and rain ambience source WAVs.

Single-purpose provenance script: writes assets/audio/river-ambience.wav and
assets/audio/rain-ambience.wav as mono signed PCM-16 at 22050 Hz, exactly
5.0 s (110250 frames). Python stdlib only; no external samples.

Each asset is one seeded periodic white-noise buffer shaped by a few stable
one-pole filters. Every filter is warmed across whole buffer periods and only
the final pass is retained, so filter state is the periodic steady state and
the retained buffer loops without a seam. LFO frequencies are 0.2 Hz
multiples, so their phase also repeats every 5 seconds. Output gains are
fixed constants; there is no normalization step and the absolute sample peak
must stay below 0.30 full scale.
"""

import math
import random
import struct
import wave

SAMPLE_RATE = 22050
DURATION = 5.0
FRAMES = 110250

WARMUP_PASSES = 6

RIVER_SEED = 44001
RIVER_PATH = "assets/audio/river-ambience.wav"
RIVER_BANDS = [(85.0, 800.0, 800.0, 1.0), (900.0, 2200.0, 0.0, 0.22)]
RIVER_LFOS = [(0.4, 0.12), (1.2, 0.05)]
RIVER_GAIN = 0.42

RAIN_SEED = 44002
RAIN_PATH = "assets/audio/rain-ambience.wav"
RAIN_BANDS = [(700.0, 7000.0, 7000.0, 1.0), (140.0, 650.0, 0.0, 0.7)]
RAIN_LFOS = [(1.0, 0.10), (2.2, 0.05)]
RAIN_GAIN = 0.16


def one_pole_coeff(cut_hz: float) -> float:
    return 1.0 - math.exp(-2.0 * math.pi * cut_hz / SAMPLE_RATE)


def noise_period(seed: int) -> list[float]:
    rng = random.Random(seed)
    return [rng.uniform(-1.0, 1.0) for _ in range(FRAMES)]


def bandpass_period(x: list[float], hp_cut: float, lp_cut: float, lp_extra: float) -> list[float]:
    """One-pole highpass into one or two cascaded one-pole lowpasses, warmed
    over whole periods; lp_extra > 0 adds the second lowpass stage."""
    hp_a = one_pole_coeff(hp_cut)
    lp_a = one_pole_coeff(lp_cut)
    lp2_a = one_pole_coeff(lp_extra)
    low_of_in = 0.0
    low_of_hp = 0.0
    low_of_lp2 = 0.0
    out = [0.0] * FRAMES
    for _ in range(WARMUP_PASSES + 1):
        for i in range(FRAMES):
            xi = x[i]
            low_of_in += hp_a * (xi - low_of_in)
            low_of_hp += lp_a * (xi - low_of_in - low_of_hp)
            y = low_of_hp
            if lp_extra > 0.0:
                low_of_lp2 += lp2_a * (low_of_hp - low_of_lp2)
                y = low_of_lp2
            out[i] = y
    return out


def lfo_period(specs: list[tuple[float, float]]) -> list[float]:
    lfo = [1.0] * FRAMES
    for freq, depth in specs:
        for i in range(FRAMES):
            lfo[i] += depth * math.sin(2.0 * math.pi * freq * i / SAMPLE_RATE)
    return lfo


def write_wav(path: str, samples: list[float]) -> None:
    frames = bytearray()
    for s in samples:
        v = int(round(s * 32767.0))
        frames += struct.pack("<h", max(-32768, min(32767, v)))
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(bytes(frames))


def render(seed: int, bands, lfos, out_gain: float, path: str) -> tuple[float, float]:
    noise = noise_period(seed)
    mixed = [0.0] * FRAMES
    for hp_cut, lp_cut, lp_extra, band_gain in bands:
        band = bandpass_period(noise, hp_cut, lp_cut, lp_extra)
        for i in range(FRAMES):
            mixed[i] += band_gain * band[i]
    lfo = lfo_period(lfos)
    samples = [mixed[i] * lfo[i] * out_gain for i in range(FRAMES)]
    write_wav(path, samples)
    peak = max(abs(s) for s in samples)
    rms = math.sqrt(sum(s * s for s in samples) / FRAMES)
    print("%s: duration=%.3fs peak=%.4f rms=%.5f" % (path, FRAMES / SAMPLE_RATE, peak, rms))
    return peak, rms


def main() -> None:
    render(RIVER_SEED, RIVER_BANDS, RIVER_LFOS, RIVER_GAIN, RIVER_PATH)
    render(RAIN_SEED, RAIN_BANDS, RAIN_LFOS, RAIN_GAIN, RAIN_PATH)


if __name__ == "__main__":
    main()
