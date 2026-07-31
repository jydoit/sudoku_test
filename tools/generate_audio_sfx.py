#!/usr/bin/env python3
"""Generate the warm wooden-toy and paper SFX candidate pack."""

from __future__ import annotations

import argparse
import math
import random
import struct
import wave
from pathlib import Path


SAMPLE_RATE = 44_100
TAU = math.tau


def seconds_to_samples(duration: float) -> int:
    return max(1, int(round(duration * SAMPLE_RATE)))


def silence(duration: float) -> list[float]:
    return [0.0] * seconds_to_samples(duration)


def smoothstep(value: float) -> float:
    value = max(0.0, min(1.0, value))
    return value * value * (3.0 - 2.0 * value)


def apply_fades(samples: list[float], attack: float, release: float) -> list[float]:
    attack_samples = max(1, seconds_to_samples(attack))
    release_samples = max(1, seconds_to_samples(release))
    length = len(samples)
    for index in range(length):
        gain = 1.0
        if index < attack_samples:
            gain *= smoothstep(index / attack_samples)
        remaining = length - 1 - index
        if remaining < release_samples:
            gain *= smoothstep(remaining / release_samples)
        samples[index] *= gain
    return samples


def lowpass(samples: list[float], cutoff: float) -> list[float]:
    alpha = 1.0 - math.exp(-TAU * cutoff / SAMPLE_RATE)
    result: list[float] = []
    state = 0.0
    for sample in samples:
        state += alpha * (sample - state)
        result.append(state)
    return result


def band_limited_noise(duration: float, low_cut: float, high_cut: float, rng: random.Random) -> list[float]:
    white = [rng.uniform(-1.0, 1.0) for _ in range(seconds_to_samples(duration))]
    upper = lowpass(white, high_cut)
    lower = lowpass(upper, low_cut)
    return [upper[index] - lower[index] for index in range(len(upper))]


def mix(duration: float, layers: list[tuple[float, list[float], float]]) -> list[float]:
    result = silence(duration)
    for offset_seconds, source, gain in layers:
        offset = seconds_to_samples(offset_seconds) if offset_seconds > 0.0 else 0
        for index, sample in enumerate(source):
            target = offset + index
            if target >= len(result):
                break
            result[target] += sample * gain
    return result


def normalize(samples: list[float], peak_db: float) -> list[float]:
    peak = max((abs(sample) for sample in samples), default=1.0)
    if peak <= 1e-9:
        return samples
    target = 10.0 ** (peak_db / 20.0)
    scale = target / peak
    return [max(-1.0, min(1.0, sample * scale)) for sample in samples]


def wood_tone(freq: float, duration: float, seed: int, warmth: float = 1.0) -> list[float]:
    rng = random.Random(seed)
    length = seconds_to_samples(duration)
    transient = band_limited_noise(duration, 120.0, 1_900.0, rng)
    result: list[float] = []
    phase = 0.0
    for index in range(length):
        time = index / SAMPLE_RATE
        position = time / duration
        attack = smoothstep(min(1.0, time / 0.014))
        pitch_bend = 1.0 + 0.010 * math.exp(-time / 0.035)
        phase += TAU * freq * pitch_bend / SAMPLE_RATE
        body = math.sin(phase) * math.exp(-4.4 * position)
        second = math.sin(phase * 2.01 + 0.25) * 0.20 * math.exp(-7.2 * position)
        wooden = math.sin(phase * 3.92 + 0.60) * 0.075 * math.exp(-10.0 * position)
        knock = transient[index] * 0.16 * math.exp(-22.0 * position)
        result.append((body + second + wooden + knock) * attack * warmth)
    return apply_fades(result, 0.010, min(0.10, duration * 0.35))


def metal_tap(freq: float, duration: float, seed: int) -> list[float]:
    """A clean, compact metal strike with a soft puzzle-game decay."""
    rng = random.Random(seed)
    transient = band_limited_noise(duration, 900.0, 4_200.0, rng)
    phases = [rng.uniform(0.0, TAU) for _ in range(4)]
    ratios = [1.0, 1.51, 2.08, 2.76]
    gains = [0.78, 0.34, 0.20, 0.10]
    result: list[float] = []
    for index in range(seconds_to_samples(duration)):
        time = index / SAMPLE_RATE
        attack = smoothstep(min(1.0, time / 0.0015))
        ring = 0.0
        for harmonic_index in range(len(ratios)):
            decay = math.exp(-(5.5 + harmonic_index * 1.7) * time / duration)
            ring += math.sin(TAU * freq * ratios[harmonic_index] * time + phases[harmonic_index]) * gains[harmonic_index] * decay
        strike = transient[index] * 0.14 * math.exp(-70.0 * time)
        result.append((ring + strike) * attack)
    return apply_fades(result, 0.001, 0.055)


def paper_rub(duration: float, seed: int) -> list[float]:
    """A low, uneven back-and-forth eraser rub."""
    rng = random.Random(seed)
    noise = band_limited_noise(duration, 90.0, 850.0, rng)
    result: list[float] = []
    for index, sample in enumerate(noise):
        time = index / SAMPLE_RATE
        direction = 0.46 + 0.34 * (0.5 + 0.5 * math.sin(TAU * 8.5 * time - 0.6))
        pressure = 0.78 + 0.12 * math.sin(TAU * 15.0 * time)
        eraser_body = 0.16 * math.sin(TAU * 118.0 * time + 0.2)
        result.append(sample * direction * pressure * 0.38 + eraser_body * direction)
    return apply_fades(result, 0.025, 0.075)


def make_erase(seed: int) -> list[float]:
    return mix(
        0.310,
        [
            (0.015, paper_rub(0.245, seed), 0.56),
            (0.080, paper_rub(0.180, seed + 1), 0.22),
        ],
    )


def make_correct(seed: int) -> list[float]:
    return mix(
        0.480,
        [
            (0.000, wood_tone(329.63, 0.330, seed, 0.95), 0.74),
            (0.135, wood_tone(440.00, 0.340, seed + 1, 0.92), 0.70),
        ],
    )


def make_wrong(seed: int) -> list[float]:
    return mix(
        0.430,
        [
            (0.000, wood_tone(220.00, 0.300, seed, 0.82), 0.66),
            (0.125, wood_tone(185.00, 0.300, seed + 1, 0.78), 0.62),
        ],
    )


def make_heart_lost(seed: int) -> list[float]:
    return mix(
        0.500,
        [
            (0.000, wood_tone(164.81, 0.360, seed, 0.95), 0.72),
            (0.155, wood_tone(146.83, 0.320, seed + 1, 0.72), 0.48),
        ],
    )


def make_hint(seed: int) -> list[float]:
    return mix(
        0.920,
        [
            (0.000, wood_tone(293.66, 0.520, seed, 0.88), 0.56),
            (0.170, wood_tone(392.00, 0.560, seed + 1, 0.90), 0.58),
            (0.360, wood_tone(523.25, 0.555, seed + 2, 0.82), 0.50),
        ],
    )


def make_clear(seed: int) -> list[float]:
    return mix(
        0.520,
        [
            (0.000, paper_rub(0.260, seed), 0.42),
            (0.105, paper_rub(0.235, seed + 1), 0.40),
            (0.225, paper_rub(0.245, seed + 2), 0.30),
        ],
    )


def make_victory(seed: int) -> list[float]:
    notes = [261.63, 329.63, 392.00, 523.25]
    offsets = [0.000, 0.240, 0.480, 0.760]
    layers: list[tuple[float, list[float], float]] = []
    for index, (frequency, offset) in enumerate(zip(notes, offsets)):
        layers.append((offset, wood_tone(frequency, 0.620, seed + index, 0.92), 0.62))
    layers.extend(
        [
            (1.080, wood_tone(261.63, 0.760, seed + 10, 0.82), 0.34),
            (1.080, wood_tone(392.00, 0.760, seed + 11, 0.78), 0.30),
            (1.080, wood_tone(523.25, 0.760, seed + 12, 0.70), 0.24),
        ]
    )
    return mix(1.880, layers)


def make_ui_tap(seed: int) -> list[float]:
    return mix(0.160, [(0.010, wood_tone(233.08, 0.135, seed, 0.48), 0.56)])


def write_wav(path: Path, samples: list[float], peak_db: float) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    normalized = normalize(samples, peak_db)
    encoded = b"".join(struct.pack("<h", int(round(sample * 32_767.0))) for sample in normalized)
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(encoded)


def build_pack(output_dir: Path) -> None:
    candidates = {
        "metal_mark_01.wav": (metal_tap(790.0, 0.230, 110), -14.0),
        "metal_mark_02.wav": (metal_tap(860.0, 0.220, 210), -14.0),
        "paper_erase.wav": (make_erase(310), -16.0),
        "wood_correct.wav": (make_correct(410), -11.0),
        "wood_wrong.wav": (make_wrong(510), -13.0),
        "wood_heart_lost.wav": (make_heart_lost(610), -12.5),
        "wood_hint.wav": (make_hint(710), -12.0),
        "paper_clear.wav": (make_clear(810), -15.0),
        "wood_victory.wav": (make_victory(910), -9.5),
        "wood_ui_tap.wav": (make_ui_tap(1010), -17.0),
    }
    for filename, (samples, peak_db) in candidates.items():
        write_wav(output_dir / filename, samples, peak_db)
        print(f"generated {filename}: {len(samples) / SAMPLE_RATE:.3f}s, peak {peak_db:.1f} dBFS")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=Path("assets/audio/candidates"))
    args = parser.parse_args()
    build_pack(args.output)


if __name__ == "__main__":
    main()
