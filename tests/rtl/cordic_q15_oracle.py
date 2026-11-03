#!/usr/bin/env python3
"""Exhaustively compare the Livt CORDIC integer model with sin/cos."""

import math


MIN_PHASE = -32768
MAX_PHASE = 32767
HALF_PI = 16384
ANGLE_GUARD_BITS = 4
COORDINATE_GUARD_BITS = 2
INTERNAL_PI = 524288
INITIAL_X = 79594
MAX_ERROR_LSB = 4
ATAN_PHASE = (
    131072, 77376, 40884, 20753,
    10417, 5213, 2607, 1304,
    652, 326, 163, 81,
    41, 20, 10, 5,
)


def clamp_q15(value: int) -> int:
    return max(-32768, min(32767, value))


def round_coordinate(value: int) -> int:
    if value >= 0:
        return (value + 2) >> COORDINATE_GUARD_BITS
    return -((-value + 2) >> COORDINATE_GUARD_BITS)


def cordic(phase: int) -> tuple[int, int]:
    x = INITIAL_X
    y = 0
    z = phase << ANGLE_GUARD_BITS

    if phase > HALF_PI:
        x = -x
        z -= INTERNAL_PI
    elif phase < -HALF_PI:
        x = -x
        z += INTERNAL_PI

    for iteration, angle in enumerate(ATAN_PHASE):
        old_x = x
        old_y = y
        if z >= 0:
            x = old_x - (old_y >> iteration)
            y = old_y + (old_x >> iteration)
            z -= angle
        else:
            x = old_x + (old_y >> iteration)
            y = old_y - (old_x >> iteration)
            z += angle

    return clamp_q15(round_coordinate(y)), clamp_q15(round_coordinate(x))


def reference(phase: int) -> tuple[int, int]:
    radians = phase * math.pi / 32768.0
    sine = clamp_q15(round(math.sin(radians) * 32768.0))
    cosine = clamp_q15(round(math.cos(radians) * 32768.0))
    return sine, cosine


def main() -> int:
    maximum = 0
    worst_phase = 0
    worst_axis = ""

    for phase in range(MIN_PHASE, MAX_PHASE + 1):
        actual = cordic(phase)
        expected = reference(phase)
        for axis, actual_value, expected_value in zip(
            ("sin", "cos"), actual, expected
        ):
            error = abs(actual_value - expected_value)
            if error > maximum:
                maximum = error
                worst_phase = phase
                worst_axis = axis

    print(
        f"65,536 phases checked; maximum error {maximum} LSB "
        f"at phase {worst_phase} ({worst_axis})"
    )
    return 0 if maximum <= MAX_ERROR_LSB else 1


if __name__ == "__main__":
    raise SystemExit(main())
