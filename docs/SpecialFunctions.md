# Fixed-point special functions

Livt.Math provides bounded fixed-point components for common FPGA scaling and
compression paths. Each component uses an explicit format and finite domain.

## LinearInterpolationQ15

`LinearInterpolationQ15.Compute(lower, upper, fraction)` interpolates between
signed endpoints using a Q0.15 fraction. Endpoints are clamped to
`-32768..32768`; fractions are clamped to `0..32768`. The serialized worker uses
shift/add multiplication. `ROUND_NEAREST` defaults to `true`; select `false` at
construction when an existing datapath requires truncation toward zero. This is
a compile-time choice and does not add runtime selection logic.

## ReciprocalUQ15

`ReciprocalUQ15.Compute(input)` accepts normalized unsigned Q1.15 values from
`16384` through `32768`, representing `[0.5, 1.0]`. It returns the rounded
reciprocal with 15 fractional bits, saturated to `65535`. Inputs outside the
normalized domain return zero.

Callers with wider dynamic range should normalize the input, retain its binary
exponent, and restore that exponent after computing the reciprocal.

## Log2UQ15

`Log2UQ15.Compute(input)` accepts unsigned Q1.15 values from `1` through `65535`.
On success, `GetResult()` returns signed Q5.11 `log2(input / 32768)` in
`-30720..2048`. The maximum error is `MAX_ERROR` (3 Q5.11 units). Zero is
undefined: `Compute` returns `false` and clears the retained result.

## Exp2Q11

`Exp2Q11.Compute(input)` accepts signed Q5.11 exponents from `-30720` through
`2048`, representing `[-15, 1]`. On success, `GetResult()` returns unsigned
Q1.15 `2^(input / 2048)`, saturated to `65535`. The maximum error is
`MAX_ERROR` (16 UQ1.15 LSB). Out-of-domain inputs return `false` and clear the
retained result.

`Log2UQ15` and `Exp2Q11` use 17-point piecewise-linear tables and the shared
serialized interpolation worker. Their formats are intentionally paired for
logarithmic gain, sensor compression, and approximation pipelines.
