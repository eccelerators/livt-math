#!/usr/bin/env python3
"""Check bounded fixed-point special functions against floating-point references."""

import math


LOG_TABLE = (
    0, 179, 348, 508, 659, 803, 941, 1072, 1198,
    1319, 1435, 1546, 1653, 1757, 1857, 1954, 2048,
)
EXP_TABLE = (
    16384, 17109, 17867, 18658, 19484, 20347, 21247, 22188, 23170,
    24196, 25268, 26386, 27554, 28774, 30048, 31379, 32768,
)
MAX_LOG_ERROR = 3
MAX_EXP_ERROR = 16


def interpolate(lower: int, upper: int, fraction: int) -> int:
    product = (upper - lower) * fraction
    if product >= 0:
        adjustment = (product + 16384) >> 15
    else:
        adjustment = -((-product + 16384) >> 15)
    return lower + adjustment


def log2_uq15(value: int) -> int:
    highest_bit = value.bit_length() - 1
    exponent = highest_bit - 15
    normalized = value << (15 - highest_bit)
    offset = normalized - 32768
    index = offset >> 11
    remainder = offset & 2047
    fractional = interpolate(LOG_TABLE[index], LOG_TABLE[index + 1], remainder << 4)
    return (exponent << 11) + fractional


def exp2_q11(value: int) -> int:
    exponent = value >> 11
    remainder = value - (exponent << 11)
    index = remainder >> 7
    substep = remainder & 127
    result = interpolate(EXP_TABLE[index], EXP_TABLE[index + 1], substep << 8) << 1
    if exponent < 0:
        shift = -exponent
        result = (result + (1 << (shift - 1))) >> shift
    elif exponent > 0:
        result <<= exponent
    return min(result, 65535)


def main() -> int:
    maximum_log_error = 0
    for value in range(1, 65536):
        expected = round(math.log2(value / 32768.0) * 2048.0)
        maximum_log_error = max(maximum_log_error, abs(log2_uq15(value) - expected))

    maximum_exp_error = 0
    for value in range(-30720, 2049):
        expected = min(65535, round((2.0 ** (value / 2048.0)) * 32768.0))
        maximum_exp_error = max(maximum_exp_error, abs(exp2_q11(value) - expected))

    maximum_reciprocal_error = 0
    for value in range(16384, 32769):
        actual = min(65535, ((1 << 30) + (value >> 1)) // value)
        expected = min(65535, round((1 << 30) / value))
        maximum_reciprocal_error = max(
            maximum_reciprocal_error,
            abs(actual - expected),
        )

    print(
        f"log2 max error {maximum_log_error} Q5.11 units; "
        f"exp2 max error {maximum_exp_error} UQ1.15 LSB; "
        f"reciprocal max error {maximum_reciprocal_error} UQ1.15 LSB"
    )
    if maximum_log_error > MAX_LOG_ERROR or maximum_exp_error > MAX_EXP_ERROR:
        return 1
    return 0 if maximum_reciprocal_error == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
