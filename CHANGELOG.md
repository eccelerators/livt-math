# Changelog

All notable changes to this package are documented here.

## 1.7.0 - 2026-11-06

### Added

- `Arithmetic.CheckedBlockMac32<A_BITS, B_BITS, ACC_BITS, PRODUCT_STAGES>`
  and its native `CheckedBlockMacPrimitive`: checked dot products and retained
  weighted sums for 32-element vectors processed in sixteen-int32 blocks.
- Configurable signed input ranges (2..32 bits), accumulator range (2..64 bits),
  and one- or two-stage product pipelines. Pipeline choice changes latency,
  never arithmetic results or overflow checks.
- Packed 65-bit result/status, ordered prefix-overflow detection, poisoned-bank
  recovery, reset cancellation and retained completion results.
- A BRAM-backed weighted accumulator bank with validity bits and immediate-read
  forwarding; live input lane selection avoids redundant wide row registers.
- Native integer-oracle and generated-wrapper tests covering numeric limits,
  both product pipelines, reset, retention, failure and recovery.

### Compatibility

- Existing arithmetic APIs and defaults are unchanged. The new worker is
  single-owner: serialize calls and hold native transaction inputs until
  completion. No fixed-point scaling, rounding or saturation is introduced.
- Timing, DSP usage and BRAM inference depend on the target and integration;
  configured numeric ranges do not imply proportional hardware savings.

## 1.6.0 - 2026-11-03

### Added

- A globally stallable 64-stage unsigned division pipeline with exact quotient,
  remainder, divide-by-zero status, tag transport, and initiation interval one.
- A globally stallable 16-stage unsigned floor square-root pipeline with tag
  transport and initiation interval one.
- A two-stage exact population-variance numerator and denominator preparation
  pipeline for continuous moving-statistics datapaths.

### Compatibility

- Existing scheduled arithmetic APIs remain unchanged. The new direct
  valid/ready primitives are additive and intended for cycle-sensitive owners.

## 1.5.0 - 2026-11-03

### Added

- `IntegerMath` context-free signed minimum, maximum, clamp, magnitude,
  saturating absolute-value, addition, and subtraction helpers.
- `UnsignedMath` context-free saturating uint addition and subtraction helpers.
- Full-width boundary tests and usage documentation for the new integer helpers.
- `CordicSinCosQ15`, a serialized 16-step rotation-mode worker for arbitrary
  signed full-turn phases with Q1.15 sine/cosine outputs and a 4-LSB error bound.
- Numeric and lifecycle documentation for `CordicSinCosQ15`.
- A narrow resource-shared CORDIC primitive with reset and retained-result
  behavior.
- `CordicAtan2MagnitudeQ15`, a separate serialized vectoring worker for
  canonical phase and full-range unsigned magnitude from Q1.15 coordinates.
- FPGA-oriented fixed-point special functions: serialized Q15 interpolation,
  normalized reciprocal, and paired base-2 logarithm/exponential components.
- `StreamingMomentsInt16`, an exact bounded finite-stream accumulator for
  signed-16 mean, population variance, and standard deviation.

### Changed

- `TanhQ15` reuses the serialized interpolation primitive used by the bounded
  special-function components.

### Compatibility

- Existing `Livt.Math 1.4.0` APIs retain their public signatures and default
  behavior. The new components and helpers are additive.
- Moving-window statistics and median filters remain outside this package and
  are reserved for `Livt.Signal`.

## 1.4.0

### Added

- Configurable three- or four-stage division rounding in `WideArithmetic`.
- An optional exact fast path for positive power-of-two divisors using shifts
  and masks.
- Optional registered unary/binary dispatch groups for reducing wide operand
  selector fan-in.
- Scheduled wrapper tests for configured division, disabled operations, failure
  reporting and recovery.
- Native RTL oracle coverage across every rounding/fast-path combination,
  including exact results, latency, reset cancellation and retained output.

### Changed

- `WideArithmetic` now has trailing `ROUNDING_STAGES`,
  `POWER_OF_TWO_FAST_PATH` and `PIPELINED_DISPATCH` parameters.
- `WideArithmeticPrimitive` accepts constant synthesis controls for rounding
  stages and power-of-two classification. Its new native ports have defaults for
  compatibility with existing instantiations.
- The power-of-two fast path accelerates both nearest-even and floor division.
  Other divisors require one classification clock when the fast path is enabled.

### Compatibility and behavior

- Existing `WideArithmetic<OUTPUT_BITS, OPERATIONS>` construction retains the
  previous result behavior and default division latency.
- Configuration affects latency and generated hardware, never numeric results.
- Three rounding stages remain the default. The fast path and registered
  dispatch are disabled by default.
- Timing and resource effects depend on the target and synthesis tool; no routed
  clock-frequency or area claim is made by this package release.

### Validation

- The package test suite covers the public scheduled API and existing arithmetic
  components.
- The native RTL oracle runs 5,232 exact comparisons across four configurations,
  including boundary values, random operands, reset cancellation and recovery.

## Earlier releases

Earlier release history remains available in Git.
