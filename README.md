# Livt.Math

`Livt.Math` provides fixed-size numeric primitives for Livt hardware-oriented
packages. It collects reusable arithmetic components that are useful across
application domains but are not specific to ML, crypto, networking, or signal
processing.

## 📦 Package

```toml
[dependencies]
Livt.Math = "1.7.2"
```

`Livt.Math` depends on `Livt.Base 1.2.0`. See
[CHANGELOG.md](CHANGELOG.md) for release notes and compatibility guidance.

The package surface is intentionally small and practical:

- `Livt.Math.Sqrt.SqrtLUT`: 8-bit lookup-table integer square root.
- `Livt.Math.Sqrt.SqrtNewtonRaphson`: iterative integer square root for larger
  inputs.
- `Livt.Math.Arithmetic.MacUnit`: signed 16-bit saturating
  multiply-accumulate helper.
- `Livt.Math.Arithmetic.MacInt32`: non-saturating signed-int32 accumulator for
  bounded dot products whose mathematical sum is proven to fit.
- `Livt.Math.Arithmetic.CheckedBlockMac32`: checked block dot products and
  retained weighted sums with configurable numeric ranges and product stages.
- `Livt.Math.Arithmetic.IntegerMath`: context-free signed min/max, clamp,
  magnitude, absolute-value, and saturating add/subtract helpers.
- `Livt.Math.Arithmetic.UnsignedMath`: context-free uint saturating add/subtract
  helpers.
- `Livt.Math.Sqrt.SqrtInt32`: floor square root across the non-negative signed
  int32 range.
- `Livt.Math.FixedPoint.ReciprocalSqrtQ15`: reciprocal square root scaled by
  32768 for normalization datapaths.
- `Livt.Math.Approximation.TanhQ15`: interpolated Q8.8-input/Q1.15-output tanh.
- `Livt.Math.Approximation.LinearInterpolationQ15`: serialized Q0.15 linear
  interpolation for bounded signed endpoints.
- `Livt.Math.Approximation.Log2UQ15`: bounded UQ1.15-to-Q5.11 base-2 logarithm.
- `Livt.Math.Approximation.Exp2Q11`: bounded Q5.11-to-UQ1.15 base-2 exponential.
- `Livt.Math.FixedPoint.Q7`: compact signed Q1.7 fixed-point helpers.
- `Livt.Math.FixedPoint.Q15`: signed Q1.15 fixed-point helpers for normalized
  DSP coefficients.
- `Livt.Math.FixedPoint.UQ8`: unsigned Q0.8 fixed-point helpers for normalized
  values.
- `Livt.Math.FixedPoint.ReciprocalUQ15`: rounded reciprocal for normalized
  unsigned Q1.15 values.
- `Livt.Math.Complex.ComplexQ15`: reusable Q15 complex arithmetic helper.
- `Livt.Math.Lookup.TrigQ15`: small Q15 sine/cosine lookup for common angles.
- `Livt.Math.Trigonometry.CordicSinCosQ15`: scheduled 16-step Q15 sine/cosine
  for arbitrary signed full-turn phases.
- `Livt.Math.Trigonometry.CordicAtan2MagnitudeQ15`: scheduled Cartesian-to-polar
  conversion for signed Q1.15 vectors.
- `Livt.Math.Random.Lcg16`: 16-bit linear congruential generator (period 65 536).
- `Livt.Math.Random.Xorshift24`: 24-bit xorshift generator (period 2^24 − 1).
- `Livt.Math.Arithmetic.WideArithmetic`: exact scheduled 64-bit
  multiply/add/divide/root service with configurable timing tradeoffs.
- `Livt.Math.Arithmetic.UnsignedDivisionPipelinePrimitive`: direct valid/ready
  64-bit division with initiation interval one and owner-defined tag transport.
- `Livt.Math.Sqrt.UnsignedSqrt32PipelinePrimitive`: direct valid/ready 32-bit
  floor square root with initiation interval one.
- `Livt.Math.Statistics.StreamingMomentsInt16`: exact bounded count, sum, mean,
  population variance, and standard deviation for signed 16-bit samples.
- `Livt.Math.Statistics.PopulationVarianceNumeratorPipelinePrimitive`: exact
  pipelined preparation of `N*Q-S*S` and `N*N` for population variance.

## Package API Shape

`Livt.Math` exposes hardware components with explicit numeric and timing
contracts. Scheduled integer division also provides a generic interface so
consumers can select a worker without depending on its algorithm.

Square-root components return the floor of the mathematical square root:

- `SqrtLUT.Compute(n)` clamps `n` to `[0, 255]` and returns a value in `[0, 15]`.
- `SqrtNewtonRaphson.Compute(n)` clamps `n` to `[0, 32767]` and returns a value
  in `[0, 181]`.

`MacUnit` accumulates products into a signed 16-bit range:

- `Accumulate(a, b)` adds `a * b` to the accumulator.
- `GetResult()` returns the current accumulator.
- `Reset()` clears the accumulator.
- Results are clamped to `[-32768, 32767]` after each accumulation step.

`MacInt32` deliberately does not clamp to int16. It is appropriate for longer
quantized dot products when the caller has established that every intermediate
sum fits Livt's signed `int`. `SqrtInt32` and `ReciprocalSqrtQ15` provide the
wider normalization path required by 64-value LayerNorm implementations.

`IntegerMath` and `UnsignedMath` expose direct context-free helpers without
stored component state. `IntegerMath.Magnitude` returns `uint`, so it represents
the magnitude of signed `int` minimum exactly; `AbsSaturating` instead returns
`int` and maps that one unrepresentable magnitude to signed maximum. A reversed
`Clamp` range deterministically returns its supplied minimum. Saturating add and
subtract detect boundary crossings before evaluating their final signed result.

`TanhQ15.Apply(input)` accepts Q8.8 values, saturates outside `[-4, 4]`, and
linearly interpolates a 0.25-spaced lookup table. It is generic arithmetic;
model-specific GELU composition remains in `Livt.ML.Activation`.

The bounded special-function components target common FPGA scaling paths.
`Log2UQ15` and `Exp2Q11` form a paired logarithmic conversion path,
`ReciprocalUQ15` handles normalized reciprocal scaling, and
`LinearInterpolationQ15` provides their reusable serialized interpolation
mechanism. See [fixed-point special functions](docs/SpecialFunctions.md) for
formats, domains, and failure behavior. Generic `Pow`, unrestricted `Log` and
`Exp`, and model-level activations are intentionally outside this API.

Fixed-point helpers use explicit named formats instead of a generic framework:

- `Q7` stores compact signed normalized values with 7 fractional bits.
- `Q15` stores signed normalized values with 15 fractional bits and is suitable
  for DSP coefficients, twiddle constants, and phasors.
- `UQ8` stores unsigned normalized values with 8 fractional bits and is useful
  for duty cycles, brightness, and probability-like values.

Each format documents its scale/range convention and exposes public constants
for the range and common values. The public API has two practical forms:

- stateful component calls: `Clamp`, `AddSaturating`, `SubSaturating`, and `Mul`
  write the latest value into the component result, and `GetResult()` reads it
  back;
- direct static context-free helpers: `Q15.ClampValue(x)`, `Q15.MulValue(a, b)`,
  `Q7.AddSaturatingValue(a, b)`, and `UQ8.SubSaturatingValue(a, b)` return values
  without instantiating a helper component.

This keeps the package centered on small named formats instead of a generic
Q-format abstraction while still giving users and agents direct value APIs for
combinational helper logic.

`ComplexQ15` stores one Q15 complex value and writes operation results into
readable result fields. It supports set/read of the stored value, add, subtract,
complex multiply, and multiply by precomputed twiddle values. It also exposes
static context-free helpers such as `ComplexQ15.MulReal(...)`,
`ComplexQ15.MulImag(...)`, and `ComplexQ15.ClampPart(...)` for package-level
composition.

`TrigQ15` provides deterministic precomputed sine/cosine constants for common
size-4 and size-8 examples. Unsupported table sizes fall back to `cos = 1` and
`sin = 0` in Q15 form. Larger transform orchestration belongs in a
signal-processing package rather than in `Livt.Math`.

`CordicSinCosQ15` complements that small lookup with an iterative full-circle
worker. Its signed phase maps 32768 units to π radians and returns both Q1.15
outputs from one scheduled call. Valid calls use 16 shared shift/add iterations,
retain their result until the next call or reset, and guarantee at most 4 LSB
error. See [CORDIC sine and cosine](docs/CordicSinCosQ15.md) for the complete
numeric and lifecycle contracts.

`CordicAtan2MagnitudeQ15` provides the inverse Cartesian operation without
changing the sine/cosine worker. It returns canonical `Atan2` phase and an
unsigned magnitude that preserves the full Q1.15 diagonal range. The zero
vector and coordinates outside Q1.15 are rejected. See
[CORDIC phase and magnitude](docs/CordicAtan2MagnitudeQ15.md) for the complete
numeric and lifecycle contracts.

`SqrtNewtonRaphson` uses the scheduled unsigned divider for its Newton steps.
It preserves floor-square-root results while trading additional cycles for a
bounded arithmetic step.

`Lcg16` is a configurable linear congruential generator:

- `new(seed, a, c, m)` constructs with explicit parameters. The recommended
  full-period parameters are `a=25173`, `c=13849`, and `m=65536`.
- `GetNext()` advances and returns the next value in `[0, m-1]`.
- `GetNextInRange(n)` returns the next value in `[0, n-1]`, or `0` when
  `n <= 0`.
- `Seed(seed)` re-seeds the generator.

`Xorshift24` is a higher-quality 24-bit xorshift generator:

- `new(seed)` constructs with a seed in `[1, 16777215]` (zero auto-corrects to 1).
- `GetNext()` advances and returns the next value in `[1, 16777215]`.
- `GetNextInRange(n)` returns the next value in `[0, n-1]`, or `0` when
  `n <= 0`.
- `Seed(seed)` re-seeds the generator.

Both generators are hardware-safe (no int32 overflow) and suitable for
simulation stimulus, weight initialization, and test fixture seeding. They are
not cryptographically secure.

### Exact wide integer arithmetic

`WideArithmetic` provides exact signed 64-bit multiply, add, division, square
root and symmetric clipping through `logic[64]` transport. Version 1.4.0 adds
compile-time selection of three or four rounding stages, an optional exact
power-of-two division fast path and optional registered dispatch groups.

Existing type arguments retain the previous behavior. The new trailing options
change latency and generated hardware without changing numeric results. See
[WideArithmetic](docs/WideArithmetic.md) for generics, division latency, failure
semantics and configuration tradeoffs.

### Scheduled division and modulo

[Integer division](docs/IntegerDivision.md) defines the shared exact API:
`IntegerDivision<BITS>`, `UnsignedDivision<BITS>`, and `IIntegerDivision<T>`.
Compute quotient and remainder together, or use the `Divide` and `Remainder`
convenience calls. `ModuloEuclidean` explicitly requests nonnegative modulo.

### Bounded stream statistics

`StreamingMomentsInt16<MAX_SAMPLES>` summarizes a finite signed-16 stream
without sample storage. It retains exact count, sum, and sum of squares, then
finalizes a nearest-even integer mean, floor population variance, and floor
standard deviation through one shared scheduled arithmetic worker. See
[streaming signed-16 moments](docs/StreamingMomentsInt16.md) for its numeric and
lifecycle contract.

Moving-window statistics and median filters are intentionally reserved for
`Livt.Signal`, where storage and stream timing form part of the public API.

## Package Boundary

Good candidates for `Livt.Math` are low-level arithmetic primitives that other
packages can reuse directly:

- square root
- multiply-accumulate
- pseudo-random number generators
- integer/fixed-point helper functions
- complex arithmetic over fixed-point values
- saturating arithmetic exposed by concrete fixed-point formats
- small reusable lookup tables

Projects that are more domain-specific should stay elsewhere:

- `Livt.ML.Linear.DotProduct` and `VecAdd` stay in `Livt.ML` because they are ML
  layer building blocks.
- `Sigmoid`, `Softmax`, `SiLU`, and `ReLU` stay in `Livt.ML.Activation`.
- FFT and FIR filter packages are better treated as signal-processing packages,
  not base math. They can reuse `Livt.Math.FixedPoint`, `Livt.Math.Complex`,
  and `Livt.Math.Lookup` primitives.

## Layout

```text
src/sqrt/         square-root implementations
src/arithmetic/   small arithmetic primitives
src/fixedpoint/   named fixed-point formats
src/approximation/ bounded reusable function approximations
src/complex/      fixed-point complex arithmetic
src/lookup/       small reusable lookup constants
src/trigonometry/ iterative trigonometric workers
src/statistics/   bounded finite-stream statistics
src/random/       pseudo-random number generators
tests/sqrt/       tests mirroring the source domain
tests/arithmetic/
tests/fixedpoint/
tests/approximation/
tests/complex/
tests/lookup/
tests/trigonometry/
tests/statistics/
tests/random/
docs/             short usage examples and package notes
```

All production `.lvt` files use the domain namespace that matches their folder,
for example:

```livt
namespace Livt.Math.Sqrt
```

All test `.lvt` files mirror that below `Livt.Math.Tests`, for example:

```livt
namespace Livt.Math.Tests.Sqrt

using Livt.Math.Sqrt
```

## Building and Testing

Build the package:

```bash
livt build
```

Run the configured test components:

```bash
livt test
```

The test list is defined in `livt.toml`. Short call-order examples live in
[`docs/usage.md`](docs/usage.md).

## Development Notes

- Keep reusable arithmetic components in a domain folder under `src/` and place
  matching tests under the same domain folder in `tests/`.
- Use nested `Livt.Math.<Domain>` namespaces for source components and
  `Livt.Math.Tests.<Domain>` for tests.
- Make range and overflow behavior visible in public constants where components
  expose them, plus documentation and boundary tests for every helper.
- Prefer deterministic fixed-size APIs over implicit variable-length behavior.
- Prefer direct static context-free helpers for reusable arithmetic that does not
  need component state, and keep stateful component methods where sequencing or
  stored results are part of the contract.

## Outlook

This package is intended to grow slowly around low-level arithmetic that is
reusable across Livt packages. Future additions should extend the practical
named-format approach before introducing a generic configurable fixed-point
framework.

Direct context-free fixed-point helpers are now part of the package API through
small named formats such as `Q15`, `Q7`, `UQ8`, and `ComplexQ15`. Future work
should extend this named-format approach before adding a configurable generic
Q-format framework.

Domain-specific math should remain in its owning package: ML layer operations in
`Livt.ML`, activation functions in `Livt.ML.Activation`, crypto arithmetic in
`Livt.Crypto`, and FFT or FIR orchestration in signal-processing packages.
`Livt.Math` should provide the reusable primitives those packages build on, such
as Q15 arithmetic, complex multiply parts, lookup constants, and MAC units.

## Checked block arithmetic

`Arithmetic.CheckedBlockMac32<A_BITS, B_BITS, ACC_BITS, PRODUCT_STAGES>`
processes sixteen signed int32 lanes per packed 512-bit block. It retains a
32-element left vector and 32 independent weighted sums. Input widths are
checked ranges from 2 to 32 bits; accumulator width is 2 to 64 bits. Results
carry a failure flag in bit 64 and a sign-extended value in bits 63..0.

Set `PRODUCT_STAGES` to 1 (default) or 2 to select the product pipeline without
changing numeric behavior. Dot sums check every prefix for overflow; weighted
update failure poisons the bank until clear/reset. Calls are serialized, and
native input fields must remain stable until completion. The weighted bank uses
BRAM inference with logical zeroing and forwarding for immediate reads. Actual
resources and timing must be measured in the consumer design.

The worker performs no fixed-point scaling, rounding or saturation. Existing
arithmetic APIs remain unchanged. See [the block MAC contract](docs/CheckedBlockMac.md)
for packing, ownership, overflow, reset and result-lifetime details.

Validation commands (Livt compiler/simulator and GHDL respectively):

```sh
livt test --run CheckedBlockMac32Test
python3 tests/rtl/test_checked_block_mac.py
```

## 📄 License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
