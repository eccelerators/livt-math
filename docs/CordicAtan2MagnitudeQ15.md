# CORDIC phase and magnitude

`Livt.Math.Trigonometry.CordicAtan2MagnitudeQ15` converts a Cartesian Q1.15
vector into its canonical phase and unsigned magnitude.

## Numeric contract

- `x` and `y` accept signed Q1.15 values in `-32768..32767`.
- Phase uses 32768 units per π radians and is returned in the canonical interval
  `-32768..32767`, corresponding to `[-π, π)`.
- Magnitude is unsigned with 15 fractional bits. Its range is `0..46341`, so it
  represents the complete diagonal magnitude of two Q1.15 coordinates.
- Phase is within `MAX_PHASE_ERROR` (4 phase units) of `Atan2(y, x)` rounded to
  the phase representation.
- Magnitude is within `MAX_MAGNITUDE_ERROR` (4 LSB) of the Euclidean magnitude
  rounded to 15 fractional bits.
- The zero vector has no defined phase. It makes `Compute` return `false` and
  clears both observations.
- Coordinates outside the Q1.15 input range also return `false` and clear both
  observations.

## Timing and lifecycle contract

`Compute` is scheduled and accepts one serialized request per component
instance. Every valid vector follows the same bounded normalization, vectoring,
and gain-correction schedule. Results remain retained until the next request or
reset. Reset cancels an active call and clears both results. Callers must wait
for scheduled-call completion before reading the results or submitting another
request.

`CordicAtan2MagnitudeQ15` is independent of `CordicSinCosQ15`; adding vectoring
does not add mode selection or latency to the sine/cosine worker.
