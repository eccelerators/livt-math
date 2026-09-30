# Scheduled integer division and modulo

Use `IntegerDivision<BITS>` for signed `int` operands and
`UnsignedDivision<BITS>` for unsigned `uint` operands. Both implement
`IIntegerDivision<T>`. These are exact scheduled components: a call may take many
clock cycles. Neither implementation contains a runtime `/` or `%` operator.

## Consumer API

```livt
using Livt.Math.Arithmetic

component Ratio
{
    // Own this worker; serialize calls and observations.
    divider: IntegerDivision<32>

    new()
    {
        divider = new IntegerDivision<32>()
    }

    public fn Quotient(numerator: int, denominator: int) int
    {
        return divider.Divide(numerator, denominator)
    }
}
```

When both results are needed, use one computation:

```livt
if (!divider.Compute(numerator, denominator)) {
    return false
}

var quotient = divider.GetQuotient()
var remainder = divider.GetRemainder()
```

`Divide`, `Remainder`, and `ModuloEuclidean` each start a new computation.
`GetQuotient` and `GetRemainder` observe the latest result without repeating the
arithmetic. Readers are scheduled methods, not guaranteed combinational ports.
Use explicit `as uint` conversions for unsigned operands, particularly signed
variables and large integer constants. An unsigned worker accepts the entire
uint32 range when BITS is 32, unlike the older UnsignedDivideInt32 adapter.

Libraries can accept a borrowed `DIVIDER: IIntegerDivision<uint>` (or `<int>`)
type parameter and instance from their composition root. That permits alternate
implementations without exposing the algorithm to consumers. The owner must
serialize all requests and retain ownership until it has read the needed
results/status. Independent callers need separate workers or explicit arbitration.

## Numeric contract

| Operation | Signed result for -7, 3 | Meaning |
| --- | ---: | --- |
| Divide | -2 | Quotient truncated toward zero |
| Remainder | -1 | Remainder satisfying a = q*b + r |
| ModuloEuclidean | 2 | Nonnegative residue less than abs(b) |

For unsigned operands, floor and truncation coincide, as do remainder and
Euclidean modulo. Signed remainder is zero or has the dividend's sign. Euclidean
modulo is nonnegative for negative divisors too; it is deliberately named rather
than silently changing the meaning of `%`. The stored remainder always remains
the truncating remainder, even after a ModuloEuclidean call.

`Compute` returns false on division by zero, an operand outside the configured
width, or signed MIN / -1. It clears quotient/remainder to zero and sets Failed.
The convenience methods return zero on failure: inspect Failed to distinguish
that from a valid zero result. All entry points share the same failure contract,
including Remainder and ModuloEuclidean for MIN / -1. Successful computation
clears Failed. Signed BITS is 2..32; unsigned BITS is 1..32.

Reset cancels a pending transaction and clears results/status. After reset,
Failed is false but no computation has completed. A caller must reset/abort its
own pending transaction too; there is no promised completion of a canceled call.

## Hardware and latency

The unsigned core uses restoring division, consuming one dividend bit per
explicit state iteration. Compare-before-shift avoids an overflowing 33-bit
intermediate even for full-width uint operands. The signed adapter converts
magnitudes using unsigned two's-complement arithmetic, including INT_MIN, then
restores quotient and remainder signs. It does not duplicate the divider.

BITS controls accepted range and iteration count. Setup, loop scheduling, signed
adaptation, and function handshakes add cycles; BITS is not an exact call-latency
promise. External values and arithmetic temporaries use 32-bit Livt integers,
so narrower BITS does not itself promise proportionally narrower mapped logic.
Do not place a scheduled call inside a context-free/static inline function or a
single-cycle protocol state and assume its timing contract is unchanged.

The existing WideArithmetic service remains the 64-bit path, including explicit
nearest-even fixed-point division. Its rounding contract must not be replaced
with truncation. It already uses iterative division; this change does not
replace its native implementation or add another divider to it.

## Rule across base libraries

- Compile-time division/remainder, including static assertions and generic
  geometry, remains an ordinary operator.
- Runtime variable divisors in scheduled code use an owned/borrowed division
  worker. Compute quotient/remainder together instead of duplicating arithmetic.
- Power-of-two operations may use shifts/masks when sign and range prove
  equivalence. Arithmetic right shift is not truncating division for negative
  values. Do not rewrite signed expressions mechanically.
- Constant non-power-of-two divisors still require cost/timing review; constants
  alone do not make division free. Decimal formatting is one example.
- Static inline and signal-level APIs keep their existing cycle contracts until
  a separately designed scheduled alternative or state-machine integration is
  available. Explicitly document remaining combinational arithmetic.
- Enable the compiler's `variable-divisor` warning during review. A suppression
  needs a reason; it is not evidence that generated hardware is inexpensive.

Livt.Math depends on Livt.Base. Do not introduce a reverse dependency from
Livt.Base to Livt.Math. Base bit helpers should use equivalent bit operations;
base formatting needs bounded conversion algorithms or a separate scheduled
formatting service in a higher-level package. A shared policy does not require
all foundational code to depend on a math worker.

## Migration status

Migrated in Livt.Math: UnsignedDivideInt32 (compatible adapter),
SqrtNewtonRaphson, ReciprocalSqrtQ15, and range sampling in Lcg16/Xorshift24.
TrigQ15's private four/eight-entry wrapping uses an equivalent mask. Existing
fixed-point power-of-two expressions retain their signed rounding semantics.

Livt.ML's FLAN-T5 weight/attention dimension guards use the worker. The projection
overflow guard is omitted for MAX_WIDTH <= 32767, where the existing row bound
65536 proves the product fits int32; larger widths retain a scheduled check.

The audit also found legacy variable divisions in ML normalization/regression,
softmax, streaming LayerNorm, and requantization, plus variable-power-of-two
operations in Base.Bits. These are not blanket-converted: streaming handshakes,
static inline contracts, rounding, and pre-existing overflow behavior require
individual migration tests. This API establishes the common implementation and
consumer contract; it does not claim that every historical `/` or `%` has gone.

## Validation

Run `livt test --run IntegerDivisionTest` for exhaustive four-bit signed and
unsigned pairs, full-width signed/unsigned boundaries, failure/recovery, and
remainder/modulo semantics. Run the entire math suite after migrating consumers.
`tests/rtl/IntegerDivisionResetTb.vhd` checks cancellation and recovery against the
generated 32-bit worker with synchronous and asynchronous resets. Focused Vivado
synthesis assesses the full exposed API; no full FLAN-T5 build is implied.
