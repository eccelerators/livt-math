# Livt.Math

`Livt.Math` provides fixed-size numeric primitives for Livt hardware-oriented
packages. It collects reusable arithmetic components that are useful across
application domains but are not specific to ML, crypto, networking, or signal
processing.

The package surface is intentionally small and practical:

- `Livt.Math.Sqrt.SqrtLUT`: 8-bit lookup-table integer square root.
- `Livt.Math.Sqrt.SqrtNewtonRaphson`: iterative integer square root for larger
  inputs.
- `Livt.Math.Arithmetic.MacUnit`: signed 16-bit saturating
  multiply-accumulate helper.
- `Livt.Math.Arithmetic.MacInt32`: non-saturating signed-int32 accumulator for
  bounded dot products whose mathematical sum is proven to fit.
- `Livt.Math.Sqrt.SqrtInt32`: floor square root across the non-negative signed
  int32 range.
- `Livt.Math.FixedPoint.ReciprocalSqrtQ15`: reciprocal square root scaled by
  32768 for normalization datapaths.
- `Livt.Math.Approximation.TanhQ15`: interpolated Q8.8-input/Q1.15-output tanh.
- `Livt.Math.FixedPoint.Q7`: compact signed Q1.7 fixed-point helpers.
- `Livt.Math.FixedPoint.Q15`: signed Q1.15 fixed-point helpers for normalized
  DSP coefficients.
- `Livt.Math.FixedPoint.UQ8`: unsigned Q0.8 fixed-point helpers for normalized
  values.
- `Livt.Math.Complex.ComplexQ15`: reusable Q15 complex arithmetic helper.
- `Livt.Math.Lookup.TrigQ15`: small Q15 sine/cosine lookup for common angles.
- `Livt.Math.Random.Lcg16`: 16-bit linear congruential generator (period 65 536).
- `Livt.Math.Random.Xorshift24`: 24-bit xorshift generator (period 2^24 − 1).

## Package API Shape

`Livt.Math` exposes concrete hardware components rather than generic numeric
traits. Each component has an explicit fixed-size contract so callers can reason
about range, clamping, and synthesis cost.

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

`TanhQ15.Apply(input)` accepts Q8.8 values, saturates outside `[-4, 4]`, and
linearly interpolates a 0.25-spaced lookup table. It is generic arithmetic;
model-specific GELU composition remains in `Livt.ML.Activation`.

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

`SqrtNewtonRaphson` uses variable integer division. That keeps the component
compact and straightforward for simulation and early hardware exploration, but
callers should expect the generated divider to be more expensive than the
lookup-table implementation.

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
src/random/       pseudo-random number generators
tests/sqrt/       tests mirroring the source domain
tests/arithmetic/
tests/fixedpoint/
tests/approximation/
tests/complex/
tests/lookup/
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

## 📄 License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
