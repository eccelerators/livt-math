# Scheduled division validation — 2026-09-30

The full Livt.Math suite passed 82 tests, including five new division tests.
A separate local-dependency consumer passed, including a generic caller and an
explicit unsigned INT_MAX operand. Tests use GHDL 4.1.0 and the installed Livt
compiler. No package was published.

The generated 32-bit worker passed `tests/rtl/IntegerDivisionResetTb.vhd` with
both LVT_RESET_ASYNC=false and true. Each run reported cancellation and recovery
PASS at 1745 ns. These checks reset during an active divide, then verify 100/7.
Run after `livt test` has generated and analyzed the HDL:

```sh
ghdl -a --std=08 -frelaxed-rules --workdir=.livt/ghdl tests/rtl/IntegerDivisionResetTb.vhd
ghdl -r --std=08 -frelaxed-rules --workdir=.livt/ghdl integer_division_reset_tb --assert-level=error
ghdl -r --std=08 -frelaxed-rules --workdir=.livt/ghdl integer_division_reset_tb -gASYNC_RESET=true --assert-level=error
```

## Focused synthesis

Vivado 2026.1 synthesized the complete exposed UnsignedDivision<31> interface
out of context for xc7a100tcsg324-1 at 20 ns, using four threads, one run, a 20 GiB
aggregate memory limit and a 600-second timeout. It completed in 240 seconds.

- 1,218 LUTs, 1,487 FFs, zero DSPs and zero BRAM.
- Zero inferred/final netlist latches.
- Internal pre-route setup WNS +11.188 ns and hold WHS +0.256 ns.
- The wrapper exposes all public operations. Integration can prune unused methods.

This is synthesized internal timing only: input/output delays and a physical
clock source were not supplied for this microbenchmark. Unconstrained boundary
ports are reported. There was no placement/routing or full-model build, and these
numbers do not establish timing closure of a consumer or a board.

The generated VHDL input set combines `out/debug/main/*.vhd` and
`out/debug/lib/*.vhd`. The retained Tcl records reading, preprocessing and
synthesis options; its `/tmp` paths describe this run and need relocation when
reproducing. Source and generated-input hashes are retained. The original
attempt omitted the language-library files and failed elaboration; this evidence
is from the corrected complete-input run.
