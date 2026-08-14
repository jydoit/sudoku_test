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


def soft_compress(samples: list[float], drive: float) -> list[float]:
    """Reduce transient crest factor while preserving a smooth musical contour."""
    safe_drive = max(1.0, drive)
    ceiling = math.tanh(safe_drive)
    return [math.tanh(sample * safe_drive) / ceiling for sample in samples]


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


def glass_sparkle(freq: float, duration: float, seed: int) -> list[float]:
    """A restrained crown shimmer that remains clear on phone speakers."""
    rng = random.Random(seed)
    phases = [rng.uniform(0.0, TAU) for _ in range(4)]
    ratios = [1.0, 2.01, 3.98, 6.12]
    gains = [0.62, 0.26, 0.12, 0.06]
    result: list[float] = []
    for index in range(seconds_to_samples(duration)):
        time = index / SAMPLE_RATE
        tone = 0.0
        for harmonic_index, ratio in enumerate(ratios):
            decay = math.exp(-(3.5 + harmonic_index * 0.9) * time / duration)
            tone += math.sin(TAU * freq * ratio * time + phases[harmonic_index]) * gains[harmonic_index] * decay
        result.append(tone)
    return apply_fades(result, 0.004, min(0.18, duration * 0.42))


def kalimba_tone(
    freq: float,
    duration: float,
    seed: int,
    brightness: float = 1.0,
) -> list[float]:
    """A soft toy-kalimba voice for the result-page melody."""
    rng = random.Random(seed)
    phases = [rng.uniform(0.0, TAU) for _ in range(5)]
    ratios = [1.0, 2.01, 3.98, 5.04, 6.97]
    gains = [0.82, 0.25, 0.11, 0.06, 0.035]
    result: list[float] = []
    for index in range(seconds_to_samples(duration)):
        time = index / SAMPLE_RATE
        attack = smoothstep(min(1.0, time / 0.006))
        body = 0.0
        for harmonic_index, ratio in enumerate(ratios):
            decay = math.exp(-(4.0 + harmonic_index * 1.25) * time / duration)
            harmonic_gain = gains[harmonic_index]
            if harmonic_index > 0:
                harmonic_gain *= brightness
            body += (
                math.sin(TAU * freq * ratio * time + phases[harmonic_index])
                * harmonic_gain
                * decay
            )
        body += (
            math.sin(TAU * freq * 0.5 * time + 0.15)
            * 0.10
            * math.exp(-5.2 * time / duration)
        )
        result.append(body * attack)
    return apply_fades(result, 0.005, min(0.19, duration * 0.35))


def warm_nature_pad(freqs: list[float], duration: float) -> list[float]:
    """A quiet, breathing acoustic bed without an electronic dance pulse."""
    result: list[float] = []
    for index in range(seconds_to_samples(duration)):
        time = index / SAMPLE_RATE
        envelope = smoothstep(min(1.0, time / 0.26))
        release = smoothstep(min(1.0, (duration - time) / 0.72))
        phrase_breath = 0.86 + 0.14 * math.sin(TAU * 0.31 * time - 0.5)
        value = 0.0
        for note_index, frequency in enumerate(freqs):
            drift = 1.0 + 0.0008 * math.sin(
                TAU * (0.13 + note_index * 0.025) * time + note_index
            )
            value += (
                math.sin(TAU * frequency * drift * time + note_index * 0.23)
                * (0.34 / len(freqs))
            )
            value += (
                math.sin(TAU * frequency * 2.0 * time + note_index * 0.17)
                * (0.045 / len(freqs))
            )
        result.append(value * envelope * release * phrase_breath)
    return result


def leaf_shaker(duration: float, seed: int) -> list[float]:
    """Sparse high-frequency texture resembling a small natural shaker."""
    rng = random.Random(seed)
    noise = band_limited_noise(duration, 1_400.0, 5_200.0, rng)
    result: list[float] = []
    for index, value in enumerate(noise):
        time = index / SAMPLE_RATE
        pulse = math.exp(-22.0 * time) + 0.38 * math.exp(-24.0 * abs(time - 0.15))
        result.append(value * pulse)
    return apply_fades(result, 0.008, 0.08)


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


def make_final_correct(seed: int) -> list[float]:
    """A compact final placement tick that leaves room for the victory phrase."""
    return mix(
        0.235,
        [
            (0.000, wood_tone(392.00, 0.210, seed, 0.72), 0.55),
            (0.045, metal_tap(784.00, 0.150, seed + 1), 0.12),
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
    # Matches GameBoard's 2.30 second celebration: initial crown confirmation,
    # rising lion wave, golden sweep, then a held resolving chord.
    notes = [261.63, 329.63, 392.00, 523.25, 659.25]
    offsets = [0.000, 0.300, 0.540, 0.780, 1.020]
    layers: list[tuple[float, list[float], float]] = []
    for index, (frequency, offset) in enumerate(zip(notes, offsets)):
        layers.append((offset, wood_tone(frequency, 0.600, seed + index, 0.92), 0.58))
    layers.extend(
        [
            (0.360, glass_sparkle(784.00, 1.300, seed + 8), 0.16),
            (1.360, wood_tone(261.63, 0.900, seed + 10, 0.82), 0.34),
            (1.360, wood_tone(392.00, 0.900, seed + 11, 0.78), 0.30),
            (1.360, wood_tone(523.25, 0.900, seed + 12, 0.70), 0.24),
            (1.380, glass_sparkle(1_046.50, 0.880, seed + 13), 0.22),
        ]
    )
    return mix(2.300, layers)


def make_wrong_heart(seed: int) -> list[float]:
    """One readable negative phrase instead of two boosted sounds colliding."""
    return mix(
        0.720,
        [
            (0.000, wood_tone(220.00, 0.300, seed, 0.78), 0.58),
            (0.120, wood_tone(185.00, 0.300, seed + 1, 0.72), 0.54),
            (0.300, wood_tone(146.83, 0.390, seed + 2, 0.88), 0.62),
        ],
    )


def make_crown_reveal(seed: int) -> list[float]:
    return mix(
        0.760,
        [
            (0.000, wood_tone(329.63, 0.330, seed, 0.86), 0.58),
            (0.120, metal_tap(659.25, 0.300, seed + 1), 0.34),
            (0.210, glass_sparkle(880.00, 0.530, seed + 2), 0.25),
        ],
    )


def make_block_pickup(seed: int, frequency: float) -> list[float]:
    return mix(
        0.170,
        [
            (0.000, wood_tone(frequency, 0.150, seed, 0.44), 0.55),
            (0.018, metal_tap(frequency * 2.0, 0.100, seed + 1), 0.16),
        ],
    )


def make_block_snap(seed: int) -> list[float]:
    return mix(0.120, [(0.000, metal_tap(620.00, 0.110, seed), 0.32)])


def make_block_place(seed: int, frequency: float, weight: float) -> list[float]:
    return mix(
        0.330,
        [
            (0.000, wood_tone(frequency, 0.270, seed, weight), 0.76),
            (0.026, wood_tone(frequency * 1.50, 0.210, seed + 1, 0.48), 0.24),
        ],
    )


def make_block_reject(seed: int) -> list[float]:
    return mix(
        0.280,
        [
            (0.000, wood_tone(174.61, 0.220, seed, 0.54), 0.42),
            (0.085, wood_tone(155.56, 0.190, seed + 1, 0.44), 0.30),
        ],
    )


def make_block_return(seed: int) -> list[float]:
    return mix(
        0.320,
        [
            (0.000, glass_sparkle(520.00, 0.230, seed), 0.10),
            (0.120, wood_tone(246.94, 0.190, seed + 1, 0.44), 0.45),
        ],
    )


def make_region_complete(seed: int) -> list[float]:
    return mix(
        0.620,
        [
            (0.000, wood_tone(293.66, 0.350, seed, 0.72), 0.52),
            (0.130, wood_tone(392.00, 0.390, seed + 1, 0.70), 0.52),
            (0.250, glass_sparkle(783.99, 0.350, seed + 2), 0.18),
        ],
    )


def make_deadlock(seed: int) -> list[float]:
    return mix(
        0.660,
        [
            (0.080, wood_tone(164.81, 0.380, seed, 0.88), 0.56),
            (0.270, wood_tone(123.47, 0.360, seed + 1, 0.78), 0.48),
        ],
    )


def make_revive(seed: int) -> list[float]:
    return mix(
        0.760,
        [
            (0.000, glass_sparkle(440.00, 0.340, seed), 0.12),
            (0.180, wood_tone(329.63, 0.390, seed + 1, 0.70), 0.48),
            (0.330, wood_tone(493.88, 0.410, seed + 2, 0.70), 0.50),
        ],
    )


def make_assembly_complete(seed: int) -> list[float]:
    return mix(
        1.050,
        [
            (0.000, make_block_place(seed, 155.56, 0.92), 0.64),
            (0.170, wood_tone(261.63, 0.560, seed + 3, 0.76), 0.42),
            (0.330, wood_tone(392.00, 0.600, seed + 4, 0.72), 0.44),
            (0.410, glass_sparkle(783.99, 0.620, seed + 5), 0.25),
        ],
    )


def make_block_clear(seed: int) -> list[float]:
    return mix(
        0.520,
        [
            (0.000, make_block_return(seed), 0.44),
            (0.130, make_block_return(seed + 3), 0.34),
            (0.250, make_block_return(seed + 6), 0.25),
        ],
    )


def make_petal_scatter(seed: int) -> list[float]:
    """A short non-musical flutter and sparkle burst for the petal shower."""
    duration = 1.75
    rng = random.Random(seed)
    airy_noise = band_limited_noise(duration, 650.0, 5_600.0, rng)
    airy: list[float] = []
    for index, sample in enumerate(airy_noise):
        time = index / SAMPLE_RATE
        envelope = math.exp(-1.55 * time)
        flutter = 0.38 + 0.30 * (0.5 + 0.5 * math.sin(TAU * 9.2 * time))
        flutter += 0.18 * (0.5 + 0.5 * math.sin(TAU * 15.7 * time + 0.8))
        airy.append(sample * envelope * flutter)
    airy = apply_fades(airy, 0.018, 0.24)

    layers: list[tuple[float, list[float], float]] = [(0.0, airy, 0.34)]
    for flutter_index, offset in enumerate([0.04, 0.22, 0.46, 0.73, 1.03]):
        layers.append(
            (
                offset,
                leaf_shaker(0.34, seed + 10 + flutter_index),
                0.16 - flutter_index * 0.012,
            )
        )
    # Sparse sparkles indicate celebration without forming a melody or a beat.
    for sparkle_index, (offset, frequency) in enumerate(
        [(0.08, 1_160.0), (0.31, 1_520.0), (0.62, 1_340.0), (0.98, 1_740.0)]
    ):
        layers.append(
            (
                offset,
                glass_sparkle(frequency, 0.42, seed + 100 + sparkle_index),
                0.10,
            )
        )
    return soft_compress(mix(duration, layers), 2.2)


def make_coin_arrive(seed: int) -> list[float]:
    """A clear two-coin metal collision for each arrival at the balance icon."""
    return mix(
        0.220,
        [
            (0.000, metal_tap(1_080.0, 0.205, seed), 0.48),
            (0.012, metal_tap(1_620.0, 0.170, seed + 1), 0.27),
            (0.030, metal_tap(620.0, 0.165, seed + 2), 0.16),
        ],
    )


def make_coin_reel(seed: int) -> list[float]:
    """A one-second metal ratchet that slows with the visual number reel."""
    layers: list[tuple[float, list[float], float]] = []
    offsets = [0.000, 0.055, 0.112, 0.173, 0.239, 0.311, 0.390, 0.478, 0.577, 0.690, 0.820, 0.958]
    for index, offset in enumerate(offsets):
        progress = index / max(1, len(offsets) - 1)
        frequency = 780.0 - progress * 230.0 + (36.0 if index % 2 == 0 else -22.0)
        gain = 0.20 + progress * 0.08
        layers.append((offset, metal_tap(frequency, 0.105 + progress * 0.035, seed + index), gain))
    return mix(1.080, layers)


def make_coin_settle(seed: int) -> list[float]:
    return mix(
        0.285,
        [
            (0.000, metal_tap(720.00, 0.260, seed), 0.42),
            (0.045, metal_tap(1_440.00, 0.220, seed + 1), 0.28),
        ],
    )


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
        "wood_correct_final.wav": (make_final_correct(420), -14.0),
        "wood_wrong.wav": (make_wrong(510), -13.0),
        "wood_heart_lost.wav": (make_heart_lost(610), -12.5),
        "wood_hint.wav": (make_hint(710), -12.0),
        "paper_clear.wav": (make_clear(810), -15.0),
        "wood_victory_v2.wav": (make_victory(910), -9.5),
        "wood_ui_tap.wav": (make_ui_tap(1010), -17.0),
        "wood_wrong_heart.wav": (make_wrong_heart(1110), -12.0),
        "crown_reveal.wav": (make_crown_reveal(1210), -12.0),
        "block_pickup_01.wav": (make_block_pickup(1310, 310.00), -17.0),
        "block_pickup_02.wav": (make_block_pickup(1410, 338.00), -17.0),
        "block_snap.wav": (make_block_snap(1510), -19.0),
        "block_place_small.wav": (make_block_place(1610, 246.94, 0.66), -14.0),
        "block_place_medium.wav": (make_block_place(1710, 207.65, 0.78), -13.0),
        "block_place_large.wav": (make_block_place(1810, 174.61, 0.90), -12.5),
        "block_reject.wav": (make_block_reject(1910), -17.0),
        "block_return.wav": (make_block_return(2010), -16.0),
        "block_region_complete.wav": (make_region_complete(2110), -12.5),
        "block_deadlock.wav": (make_deadlock(2210), -13.5),
        "block_revive.wav": (make_revive(2310), -12.5),
        "block_assembly_complete.wav": (make_assembly_complete(2410), -10.5),
        "block_clear.wav": (make_block_clear(2510), -15.0),
        "petal_scatter.wav": (make_petal_scatter(4250), -12.0),
        "coin_arrive.wav": (make_coin_arrive(4300), -12.0),
        "coin_reel.wav": (make_coin_reel(4400), -13.5),
        "coin_settle.wav": (make_coin_settle(4500), -13.0),
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
