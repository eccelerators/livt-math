# Wide arithmetic timing and resource review

The A200T application reports confirm a Livt.Math timing problem in the wide
multiply path. The public scheduled API serializes requests, but its native
worker does not bound all operations to a short amount of work per clock.
This is the pre-change baseline review. The subsequent implementation is described
in [WideArithmetic](WideArithmetic.md) and its linked measurement archive.

| Finding | Evidence | Priority |
| --- | --- | --- |
| Wide multiply has insufficient internal staging | Worst listed Math path: 20.963 ns, -0.961 ns slack at 50 MHz | First timing change |
| Square root squares a candidate on every iteration | Four unpipelined DSPs in the inspected worker; explicit synthesis pipeline warning | Replace trial squaring with digit-by-digit root |
| Unused operations remain in shared workers | All three workers retain 20 DSPs, including the division-only table consumer | Separate workers or compile-time operation capabilities |
| Call wrappers cost more LUTs than native workers | 9,215 wrapper LUTs versus 3,355 native-worker LUTs in aggregate | Review generated scheduling and operand storage |
| Output width does not size the datapath | OUTPUT_BITS only controls Clamp; operands remain 64-bit | Keep width contracts explicit |

## Confirmed multiply path

`src/arithmetic/WideArithmeticPrimitive.vhd:71` computes a signed 64x64 product
into 128 bits, checks signed-64 overflow, selects zero or the result and
acknowledges the request in the same clocked branch. The enclosing scheduled
`WideArithmetic.Execute` waits for completion; that waiting does not pipeline
the combinational arithmetic inside the worker.

The routed weight worker path runs from DSP `ARG__11` through `ARG__12`,
`ARG__13` and `ARG__14`, carry logic and result selection to
`ctor_result_reg[10]`. Its data delay is 20.963 ns: 14.391 ns logic and
6.572 ns routing, with 23 CARRY4 cells and 32 reported logic levels. Slack is
-0.961 ns at 20 ns. A kernel-worker result path also fails at -0.949 ns.
These are genuine internal arithmetic paths, distinct from the attention
controller's much larger routing outlier.

Read-only inspection of the routed checkpoint traces ARG DSP inputs to Execute's
operand registers; the root DSPs instead trace to root/index registers. Thus the
reported ARG chain belongs to Multiply, not the iterative divider or square root.
In the inspected weight worker, 16 ARG DSPs implement multiplication. Twelve have
AREG/BREG=2 and MREG/PREG=0; four have AREG/BREG=0, MREG=1, PREG=0. Synthesis has
absorbed some surrounding registers, but this is not a fully pipelined result
chain. Do not claim that all DSP registers are disabled.

Recommended first experiment: retain the public handshake and exact 64-bit
contract, introduce explicit internal multiply stages, and separate product
formation from overflow checking/result publication. A product register alone
might leave a long multiplication path; measure the staged partial products and
carry accumulation. A limb-based serial multiplier can reduce DSP use at the
cost of latency; compare it against a pipelined multiplier rather than assuming
one policy suits every library consumer. Never truncate the high product before
checking signed overflow. Keep MIN_INT64, MIN_INT64 * -1, zero and mixed-sign
behavior unchanged.

## Square root and other operation costs

The rooting branch at line 61 performs `candidate*candidate <= radicand` for each
of 32 trial bits. It is iterative across bits but contains a complete 32x32 square
and comparison within each iteration. Four root DSPs in the inspected instance
have AREG=BREG=MREG=PREG=0. The existing Vivado log explicitly warns at line 61
that there are zero pipeline registers after this wide multiplier and recommends
four levels. This is separate evidence from the multiply critical path.

Prefer an exact digit-by-digit restoring square root using shift, compare and
subtract, processing two radicand bits per step. It can retain 32 iterations for
unsigned 64-bit inputs while eliminating the candidate multiplier. Livt.Math's
SqrtInt32 already demonstrates the mathematical approach; verify actual cycle
boundaries and intermediate widths in a new 64-bit implementation. Preserve
floor(sqrt(x)) through UINT64_MAX. CORDIC is unnecessary for this integer contract.
DSP/LUT savings remain predictions until measured.

The divider is already iterative, but its 65-bit compare/subtract and final
rounding/increment/sign restoration also deserve per-operation timing checks.
Add includes a 65-bit sum and overflow selection. Clamp has runtime width-derived
limits in the native interface even though OUTPUT_BITS is constant in the wrapper;
verify constant propagation before redesigning it. None of these operations is
established as the current worst Math path by the available top-20 report.

## Resource duplication and generated wrappers

Counts below are attributed by the routed hierarchy; cross-boundary synthesis
optimizations mean they are not standalone cost guarantees.

| Consumer | Wrapper LUTs, excluding native worker | Native LUTs | Total FFs | DSPs |
| --- | ---: | ---: | ---: | ---: |
| Transformer kernels | 3,819 | 1,159 | 3,122 | 20 |
| Nonlinear tables | 2,588 | 1,015 | 1,811 | 20 |
| Weight reconstruction | 2,808 | 1,181 | 2,488 | 20 |
| Total | 9,215 | 3,355 | 7,421 | 60 |

The table consumer only calls DivideEven, yet its worker retains 20 DSPs.
The weight worker retains root DSPs although FixedPointMath does not call Sqrt.
The runtime opcode interface and generated call machinery do not eliminate those
capabilities in this build. Exactly why constant operation sets are not pruned
requires a separate generated-RTL review; do not label this a compiler bug yet.

Keep a convenient composite API, but investigate separate operation workers or
compile-time capability parameters so a division-only user does not instantiate
multiply/root hardware. Use generics for real operand widths and implementation
policies where useful. OUTPUT_BITS is a clipping width, not an operand-width
parameter; changing it must not silently weaken the existing 64-bit contract.

The wrapper overhead also warrants review of Execute argument storage, arbitration
and state scheduling. Native arithmetic improvements alone cannot remove those
9,215 wrapper LUTs. Sharing one worker across independent consumers would require
explicit arbitration and throughput analysis; it is not automatically safe.

## Verification before another whole-application build

1. Capture isolated operation and composite-worker baselines at the same device,
   clock and constraints, including the generated Livt wrapper. Record resources,
   cycles per operation, setup/hold and internal paths.
2. Implement and compare staged exact multiplication; test overflow boundaries,
   random exact integer oracles, request toggles and reset during every new phase.
3. Compare multiplier-free square root with the current implementation using
   zero, UINT64_MAX, perfect squares and adjacent values. Check the property
   r*r <= x < (r+1)*(r+1) in a sufficiently wide host oracle.
4. Verify that division-only specialization actually eliminates DSPs. Preserve
   rounded division, signed extremes, failure status and serialized ownership.
5. Run WideArithmeticTest, update latency-sensitive RTL reset checks, then run
   the focused ML/app consumers. Only then repeat the guarded full A200T flow.

Other Math source families (Q7/Q15/UQ8, ComplexQ15 and MAC helpers) retain
multiplication and multiply/add/scale chains. They deserve separate width and
throughput measurements, but this application report does not establish that
they fail timing. Do not replace every multiply or power-of-two divide blindly.

## Evidence and limits

See [internal paths](evidence/wide-arithmetic-analysis/routed_internal_paths.rpt),
[hierarchy](evidence/wide-arithmetic-analysis/routed_hierarchical.rpt),
[DSP register settings and operand cones](evidence/wide-arithmetic-analysis/dsp-cones.txt),
[checkpoint inspection script](evidence/wide-arithmetic-analysis/inspect.tcl), and
[source provenance](evidence/wide-arithmetic-analysis/provenance.json).
The current native VHDL matches the routed source byte for byte. The original
pipeline warning remains in the board project's
`work/a200t-arithmetic-rebuild/vivado.log` (Synth 8-12192, line 61).

No new synthesis, simulation or arithmetic implementation was performed for this
analysis. The prior application tests establish the baseline only. Its OOC
clock/reset model limits physical-board timing conclusions. Do not attribute
the entire 96.10% slice occupancy to Livt.Math or claim timing closure from a
local change before measuring it.
