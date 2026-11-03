#!/usr/bin/env python3
"""Compare the vectoring CORDIC integer model with atan2 and hypot."""

import math
import random


ATAN_PHASE = (
    131072, 77376, 40884, 20753,
    10417, 5213, 2607, 1304,
    652, 326, 163, 81,
    41, 20, 10, 5,
)
GAIN_INVERSE_Q18 = 159188
MAX_PHASE_ERROR = 4
MAX_MAGNITUDE_ERROR = 4


def round_shift(value: int, bits: int) -> int:
    half = 1 << (bits - 1)
    if value >= 0:
        return (value + half) >> bits
    return -((-value + half) >> bits)


def cordic(x_value: int, y_value: int) -> tuple[int, int]:
    x = x_value << 2
    y = y_value << 2
    normalization = 0

    while max(abs(x), abs(y)) < 65536:
        x <<= 1
        y <<= 1
        normalization += 1

    if x < 0:
        x = -x
        y = -y
        phase = 524288 if y_value >= 0 else -524288
    else:
        phase = 0

    for iteration, angle in enumerate(ATAN_PHASE):
        old_x = x
        old_y = y
        if old_y >= 0:
            x = old_x + (old_y >> iteration)
            y = old_y - (old_x >> iteration)
            phase += angle
        else:
            x = old_x - (old_y >> iteration)
            y = old_y + (old_x >> iteration)
            phase -= angle

    result_phase = round_shift(phase, 4)
    if result_phase >= 32768:
        result_phase -= 65536
    elif result_phase < -32768:
        result_phase += 65536

    x >>= normalization
    magnitude = round_shift(x * GAIN_INVERSE_Q18, 20)
    return result_phase, min(magnitude, 46341)


def reference(x_value: int, y_value: int) -> tuple[int, int]:
    phase = round(math.atan2(y_value, x_value) * 32768.0 / math.pi)
    if phase >= 32768:
        phase -= 65536
    return phase, round(math.hypot(x_value, y_value))


def phase_error(actual: int, expected: int) -> int:
    return abs(((actual - expected + 32768) % 65536) - 32768)


def points():
    special = (
        -32768, -32767, -30000, -23170, -16384, -8192, -1024, -255,
        -16, -3, -2, -1, 0, 1, 2, 3, 16, 255, 1024, 8192, 16384,
        23170, 30000, 32766, 32767,
    )
    for x_value in special:
        for y_value in special:
            if x_value != 0 or y_value != 0:
                yield x_value, y_value

    for value in range(-32768, 32768):
        for fixed in (-32768, -1, 0, 1, 32767):
            if value != 0 or fixed != 0:
                yield value, fixed
                yield fixed, value

    random_source = random.Random(0xC0D1C)
    for _ in range(1_000_000):
        x_value = random_source.randrange(-32768, 32768)
        y_value = random_source.randrange(-32768, 32768)
        if x_value != 0 or y_value != 0:
            yield x_value, y_value


def main() -> int:
    maximum_phase_error = 0
    maximum_magnitude_error = 0
    count = 0

    for x_value, y_value in points():
        actual_phase, actual_magnitude = cordic(x_value, y_value)
        expected_phase, expected_magnitude = reference(x_value, y_value)
        maximum_phase_error = max(
            maximum_phase_error,
            phase_error(actual_phase, expected_phase),
        )
        maximum_magnitude_error = max(
            maximum_magnitude_error,
            abs(actual_magnitude - expected_magnitude),
        )
        count += 1

    print(
        f"{count:,} vectors checked; maximum phase error "
        f"{maximum_phase_error}, maximum magnitude error "
        f"{maximum_magnitude_error} LSB"
    )
    if maximum_phase_error > MAX_PHASE_ERROR:
        return 1
    return 0 if maximum_magnitude_error <= MAX_MAGNITUDE_ERROR else 1


if __name__ == "__main__":
    raise SystemExit(main())
