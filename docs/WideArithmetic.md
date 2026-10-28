# WideArithmetic

`Livt.Math.Arithmetic.WideArithmetic` provides exact signed 64-bit arithmetic
through `logic[64]` transport. One caller owns the scheduled worker. Methods wait
for acknowledgment; reset cancels outstanding work. Results and error flags
remain stable until the next request. Invalid division and overflowing add or
multiply return zero and set `Failed()`.

```livt
// Existing behavior: all operations, 24-bit symmetric output clipping.
wide = new WideArithmetic<24>()
// Four rounding stages and exact power-of-two acceleration.
fast = new WideArithmetic<31, 31, 4, true, true>()
```

| Generic | Default | Contract |
| --- | --- | --- |
| `OUTPUT_BITS` | 24 | Symmetric clamp width, 2..31 |
| `OPERATIONS` | 31 | Capability mask: multiply=1, add=2, divide=4, root=8, clamp=16 |
| `ROUNDING_STAGES` | 3 | 3 separate decision/increment/sign stages; 4 distance/decision/increment/sign stages |
| `POWER_OF_TWO_FAST_PATH` | false | Detect positive power-of-two divisors and use exact shifts and masking |
| `PIPELINED_DISPATCH` | false | Add registered binary/unary dispatch groups to reduce operand-selector fan-in |

The defaults preserve the previous package behavior and division latency. The
options are compile-time constants passed to the native worker, allowing
synthesis to remove unused branches. They change resource use and latency, never
numeric results. Pipelined dispatch adds wrapper scheduling latency; the native
division clock table below excludes that latency. More stages can improve timing but do not guarantee a clock
frequency on any device. The fast path needs additional detection and shift
hardware. It accelerates both `DivideEven` and `DivideFloor`; non-power-of-two
divisors incur one extra classification clock when enabled.

`DivideEven` rounds signed division to nearest, ties to even. Divisors must be
positive. `DivideFloor` accepts only nonnegative numerators and positive divisors.
Square root interprets its input as unsigned. Clamp uses the symmetric range
`[-(2^(OUTPUT_BITS-1)-1), +(2^(OUTPUT_BITS-1)-1)]`.

Division clocks after acceptance (excluding Livt wrapper scheduling):

| Rounding stages | Fast path disabled | Enabled, power-of-two divisor | Enabled, other divisor |
| --- | ---: | ---: | ---: |
| 3 (default) | 67 | 5 | 68 |
| 4 | 68 | 6 | 69 |

Run `livt test --run WideArithmeticTest` for the existing contract and
`livt test --run WideArithmeticPipelineTest` for generic wrapper integration.
After a Livt build generates context packages, run
`python tests/rtl/test_wide_pipeline.py` for 5,232 independent integer-oracle
checks across all four configurations, including reset cancellation and retention.
The RTL test also instantiates the default native interface without the new
optional ports to check compatibility with existing native consumers.
