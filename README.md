# Livt.Math

`Livt.Math` provides fixed-size numeric primitives for Livt hardware-oriented
packages. It collects reusable arithmetic components that are useful across
application domains but are not specific to ML, crypto, networking, or signal
processing.

The 0.1.0 package surface is intentionally small:

- `Livt.Math.Sqrt.SqrtLUT`: 8-bit lookup-table integer square root.
- `Livt.Math.Sqrt.SqrtNewtonRaphson`: iterative integer square root for larger
  inputs.
- `Livt.Math.Arithmetic.MacUnit`: signed 16-bit saturating
  multiply-accumulate helper.
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

`SqrtNewtonRaphson` uses variable integer division. That keeps the component
compact and straightforward for simulation and early hardware exploration, but
callers should expect the generated divider to be more expensive than the
lookup-table implementation.

`Lcg16` is a configurable linear congruential generator:

- `new(seed, a, c, m)` constructs with explicit parameters (default: a=25173,
  c=13849, m=65536).
- `GetNext()` advances and returns the next value in `[0, m-1]`.
- `GetNextInRange(n)` returns the next value in `[0, n-1]`.
- `Seed(seed)` re-seeds the generator.

`Xorshift24` is a higher-quality 24-bit xorshift generator:

- `new(seed)` constructs with a seed in `[1, 16777215]` (zero auto-corrects to 1).
- `GetNext()` advances and returns the next value in `[1, 16777215]`.
- `GetNextInRange(n)` returns the next value in `[0, n-1]`.
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
- saturating arithmetic
- small reusable lookup tables

Projects that are more domain-specific should stay elsewhere:

- `Livt.ML.Linear.DotProduct` and `VecAdd` stay in `Livt.ML` because they are ML
  layer building blocks.
- `Sigmoid`, `Softmax`, `SiLU`, and `ReLU` stay in `Livt.ML.Activation`.
- FFT and FIR filter packages are better treated as signal-processing packages,
  not base math.

## Layout

```text
src/sqrt/         square-root implementations
src/arithmetic/   small arithmetic primitives
src/random/       pseudo-random number generators
tests/sqrt/       tests mirroring the source domain
tests/arithmetic/
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
- Make component range and overflow behavior visible in public constants,
  documentation, and boundary tests.
- Prefer deterministic fixed-size APIs over implicit variable-length behavior.

## Outlook

This package is intended to grow slowly around low-level arithmetic that is
reusable across Livt packages. Good future additions include fixed-point helper
components, reusable saturating arithmetic, small lookup tables, and integer
building blocks that are not tied to one application domain.

Domain-specific math should remain in its owning package: ML layer operations in
`Livt.ML`, activation functions in `Livt.ML.Activation`, crypto arithmetic in
`Livt.Crypto`, and FFT or FIR primitives in signal-processing packages.
