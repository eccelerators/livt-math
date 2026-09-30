# Wide arithmetic implementation measurements — 2026-09-30

The staged worker meets the isolated 50 MHz setup constraint and reduces DSP use.
Division-only capability selection removes all multiplier DSPs. These changes
preserve exact arithmetic; multiply latency and native LUT/register use increase.
No full-application rebuild, board timing closure or hardware inference is claimed.

## Routed native worker comparison

All variants use XC7A200T-FBG676-1, Vivado 2026.1, the same 20 ns OOC clock,
0/5 ns synthetic input/output delays, four threads and sequential flows under
20 GiB aggregate memory guards. They expose the same native operation interface.

| Native worker | LUTs | FFs | DSPs | Setup WNS | Internal setup slack | Hold WHS |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Previous implementation | 1157 | 430 | 20 | -3.990 ns | -0.708 ns | -1.555 ns |
| Staged, all operations | 1622 | 771 | 4 | +5.180 ns | +5.180 ns | -1.475 ns |
| Staged, division only | 628 | 335 | 0 | +7.141 ns | +7.141 ns | -1.190 ns |

The final full worker uses four 16x16 products over four operand digits. Native
multiply completion moves from the accepting edge to 21 cycles after it; public
Livt handshake overhead is additional. Root remains 32 iterations, now with
shift/compare/subtract instead of trial squaring. Do not describe this as a
throughput improvement: it exchanges latency and some fabric resources for DSP
savings and shorter combinational paths.

The OOC reset/clock model still produces hold violations; physical interface
pin locations and board clock/reset routing are absent. Setup slack is a useful
local comparison, not physical-board timing closure. Each synthesis flow checks
for unexpected latches. The baseline's worst internal path here is square-root
logic; the full application's worst Math path was multiplication. Both were
addressed, but these isolated counts cannot be substituted for application counts.

## Generated wrapper comparison

These are **synthesis** counts, with all public method ports exposed. Both full
variants use the same final native backend. Only the Execute return transport
changes between before/after; the capability mask is 31 in both. Hierarchical
counts are tool attribution and can shift with cross-boundary optimization.

| Generated wrapper plus native worker | LUTs | FFs | DSPs |
| --- | ---: | ---: | ---: |
| 64-bit Execute return | 3764 | 4358 | 4 |
| Completion-only Execute | 3942 | 3917 | 4 |
| Completion-only, division only | 2938 | 3479 | 0 |

The wrapper change saves 441 flip-flops but costs 178 LUTs in this experiment.
It removes an unnecessary 64-bit result channel and its registers; it does not
solve all generated call-storage/arbitration overhead. Measure packing and timing
in the complete application before claiming slice savings. Further wrapper work
should examine generated call arguments and arbitration with isolated evidence.

Explicit capability gating is necessary inside each operation phase: rejecting
requests alone left four DSPs in the division-only prototype. The archived final
worker gates the datapath as well; both native and generated division-only
measurements show zero DSPs. The rejected intermediate prototype is not used as
the final result.

## Verification and source scope

- 83 Math tests pass against the final worker, including disabled operations.
- 122 ML tests pass in a local dependency snapshot; 15 focused app arithmetic
  tests pass, including production nonlinear-table address rounding.
- The exact-reference runner checks 3,307 deterministic arithmetic vectors for
  each of five masks (31, 4, 0, 8, 1), held requests, reset cancellation at all
  operation phases, recovery, and the existing native reset bench.
- The full ML and initial app suites began before explicit datapath gating was
  added. The affected generated ML kernel/embedding and all five focused app
  test components were then replayed against the **final** native source in both
  synchronous and asynchronous wrapper reset modes. Their logs are archived.
- Source hashes preserve the exact VHDL used for the native and generated-wrapper
  measurements. The snapshots preserve the measured source bytes. Subsequent design-guide
  formatting of the library preserves the executable token stream.

No numeric oracle or failure contract was relaxed. Runtime timeouts were updated
only where the existing native reset test assumed a single-cycle multiply.
The normal Math test suite ran from its repository. Consumer snapshots used
local Math/ML dependencies so no unpublished registry version or stale package
was mistaken for the implementation under test. Published dependency pins and
locks in the consumer repos remain unchanged; publish Math, then ML, and refresh
consumer locks before building through registry dependencies.

Consumer changes are deliberately small: FixedPointMath selects mask 23
(multiply/add/divide/clamp); FlanT5Tables selects mask 4 (division only). Existing
WideArithmetic<OUTPUT_BITS> source callers still receive all operations by default.

## Reproduction

Native snapshots include baseline and final workers; generated-wrapper snapshots
preserve the before/after source bodies. Language-package snapshots already have
the existing Vivado preprocessing applied. From this directory, with Vivado on PATH:

```sh
systemd-run --user --scope -p MemoryMax=20G -p MemorySwapMax=0 \
  vivado -mode batch -notrace -nojournal -source reproduce-native.tcl
systemd-run --user --scope -p MemoryMax=20G -p MemorySwapMax=0 \
  vivado -mode batch -notrace -nojournal -source reproduce-wrapper.tcl
```

Run sequentially in a copy of the archive to preserve original reports. Scripts
set both general and synthesis thread limits to four. The original guarded runs
also used a 30-minute limit for each invocation. Full transient logs remain in
`/tmp/wide-improve`; source snapshots, reports, test results and checksums here
are the retained evidence. See results.json and source-sha256.json.

The portable exact-reference runner is tools/check_wide_arithmetic.py; its usage
is documented in ../../WideArithmetic.md. Verification XML and final RTL replay
logs are under verification/. The replay script records the actual temporary
snapshot paths used in this run; it is provenance, not an independent build of
the full consumer projects.
