# Changelog

All notable changes to this package are documented here.

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
