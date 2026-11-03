# CORDIC sine and cosine

`Livt.Math.Trigonometry.CordicSinCosQ15` is a serialized rotation-mode CORDIC
worker for arbitrary phases. One call computes both sine and cosine.

## Numeric contract

- `phase` is a signed full-turn representation: `32768` phase units equal π
  radians. The accepted interval is `-32768..32767`, corresponding to
  `[-π, π)`.
- `GetSin()` and `GetCos()` return signed Q1.15 values in
  `-32768..32767`.
- The worker uses 16 iterations, gain compensation, symmetric final rounding,
  and Q1.15 saturation.
- Each result is within `MAX_ERROR_LSB` (4 LSB) of sine or cosine rounded to
  Q1.15.
- An invalid phase makes `Compute` return `false` and clears both observations.

The worker does not wrap out-of-range inputs. A caller with an accumulated or
periodic phase must reduce it modulo 65536 into the canonical accepted interval
before calling `Compute`; this keeps overflow and wrapping policy explicit at
the owning boundary.

The public constants `MIN_PHASE`, `MAX_PHASE`, `HALF_PI`, `QUARTER_PI`,
`ITERATIONS`, and `MAX_ERROR_LSB` make these limits available to consumers.

## Timing and lifecycle contract

`Compute` is scheduled and accepts one serialized request per component
instance. Every valid phase follows the same 16-step iteration schedule. The
results remain retained until the next request or reset. Reset cancels an active
call and clears both results. Callers must wait for scheduled-call completion
before reading the results or submitting another request.

## Choosing CORDIC or the lookup helper

Use `CordicSinCosQ15` when the phase is arbitrary and a multi-cycle shared
worker is acceptable. Use `Livt.Math.Lookup.TrigQ15` for its existing size-4
and size-8 constants when a tiny table and immediate common-angle lookup are a
better fit.
