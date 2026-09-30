# Wide integer arithmetic

`Livt.Math.Arithmetic.WideArithmetic<OUTPUT_BITS = 24, OPERATIONS = 31>` provides
serialized exact 64-bit arithmetic. Existing one-parameter callers retain all
operations. `logic[64]` transports signed two's-complement words; Sqrt treats its
input as unsigned. OUTPUT_BITS controls clipping, not the internal operand width.

| Operation | Contract | Native cycles after request acceptance |
| --- | --- | ---: |
| Multiply | Signed product; overflow returns zero and sets Failed | 21 |
| Add | Signed sum; overflow returns zero and sets Failed | 0 |
| DivideEven | Positive divisor; signed nearest rounding, ties to even | 65 |
| DivideFloor | Nonnegative signed-range dividend, positive divisor | 65 |
| Sqrt | Floor square root of the entire unsigned 64-bit range | 32 |
| Clamp | Symmetric clipping to +/-((1 << (OUTPUT_BITS-1))-1), 2..31 bits | 0 |

Latency counts exclude the accepting clock edge and the generated Livt call
handshake. Invalid or disabled operations complete on the accepting edge with
zero and Failed set. These counts describe the native implementation, not a
fixed-latency public API. Wait for method completion; do not assume a multiply
completes in one cycle. The minimum signed 64-bit dividend is valid for DivideEven.

Failed describes the most recently completed operation. One caller owns a worker;
serialize calls and keep native request operands stable until acknowledgment.
Reset cancels pending work and clears request/acknowledgment and result state.
Reset the owner and worker together; a request held different from reset's zero
acknowledgment is a fresh request after reset. Cast bounded Livt int values before
calling: widening an already-overflowed int product cannot recover its value.

## Compile-time operation selection

OPERATIONS is a mask supplied as a constant to the native worker. Combine the
following bits by addition or bitwise OR:

| Bit value | Enabled operation |
| ---: | --- |
| 1 | Multiply |
| 2 | Add |
| 4 | DivideEven and DivideFloor |
| 8 | Sqrt |
| 16 | Clamp |

Examples: `WideArithmetic<24, 4>` is division-only;
`WideArithmetic<24, 23>` enables multiply/add/divide/clamp without root;
`WideArithmetic<24>` enables everything. The range 0..31 is checked statically.
Disabled public methods remain callable but return zero with Failed set.
Selection reduces instantiated capabilities without silently narrowing operands.
The native opaque interface's operations input must be driven by the owner;
WideArithmetic supplies it automatically. Direct VHDL instantiations that omit
the new trailing port retain the default mask of 31.

## Implementation and resource tradeoffs

Multiply reuses four 16x16 products over four digits of the second operand.
Separate registers hold the products, pair sums, joined term, and low/high
accumulation. A final stage checks the full magnitude for signed overflow and
restores the sign, including MIN_INT64. This replaces the single-cycle 64x64
multiply/overflow chain. It trades additional latency and registers for fewer
DSPs and a shorter critical path.

Sqrt consumes two input bits per cycle using a restoring shift/compare/subtract
recurrence. It no longer squares a trial candidate. Division remains a 64-step
restoring divider followed by rounding/sign restoration. The generated Execute
helper now returns completion only; public methods read the stable native result
directly, avoiding a redundant 64-bit result channel and its storage/multiplexing.

See the [implementation measurements](evidence/wide-arithmetic-improvements/README.md)
and the [original analysis](WideArithmeticTiming.md). Isolated results are not
whole-application fit or board timing guarantees.

## Verification

Run `livt test` for the package tests. The exact-reference runner generates 3,307
deterministic boundary/random vectors and checks five capability masks, held
requests, cancellation across operation phases and recovery. It also runs the
existing native reset bench:

```sh
python3 tools/check_wide_arithmetic.py \
  --work /tmp/wide-arithmetic-checks \
  --generated-lib out/debug/lib --ghdl ghdl
```

Build the package first to generate the context/language packages. Set GHDL_PREFIX
when using a relocated simulator installation. The runner preserves simulator
logs and fails on compile errors, arithmetic mismatches or protocol timeouts.
