# Wide integer arithmetic

`Livt.Math.Arithmetic.WideArithmetic<OUTPUT_BITS = 24>` is a scheduled exact
64-bit arithmetic service with a portable VHDL backend. `logic[64]` transports
signed two's-complement words; `Sqrt` interprets its input as unsigned. Cast
bounded Livt `int` values explicitly before calling; never multiply in `int`
and widen an already-overflowed result.

- `Multiply` and `Add` detect signed overflow and return zero with `Failed()` set.
- `DivideEven` requires a positive signed-range divisor and rounds signed
  magnitudes to nearest, ties to even. The minimum signed 64-bit input is valid.
- `DivideFloor` requires a nonnegative signed-range dividend and positive divisor.
- `Sqrt` returns floor square root, including the entire unsigned 64-bit range.
- `Clamp` clips symmetrically to +/-((1 << (OUTPUT_BITS-1))-1), for 2..31 bits.

`Failed()` describes the most recent completed operation. Invalid operations
return zero. Serialize calls under one owner; reset cancels in-flight work and
clears the request/acknowledge state. The divider uses 64 restoring steps and
one rounding step; the root uses 32 trial bits. Multiply/add are registered
operations, not a guarantee of any particular FPGA clock rate or resource use.
The backend width remains 64 bits regardless of output clipping width.

`WideArithmeticTest` checks exact scalar oracles, signed extremes, tie cases,
roots and overflow. `tests/rtl/WideArithmeticResetTb.vhd` checks request/reset
behavior against the same synthesizable backend. Existing 32-bit helpers keep
their original APIs and semantics.
