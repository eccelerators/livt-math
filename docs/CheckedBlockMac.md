# Checked block multiply/accumulate

`Livt.Math.Arithmetic.CheckedBlockMac32<A_BITS, B_BITS, ACC_BITS, PRODUCT_STAGES>`
is a single-owner scheduled engine for 32-element integer vectors. It owns two
16-element left-operand blocks and 32 independent weighted accumulators. Calls
are serialized. It knows nothing about tensors, DDR, fixed-point fractions or
model addresses.

Each input block contains sixteen little-endian **signed int32** lanes in
`logic[512]`; lane zero occupies bits 31..0. Compile-time A/B widths (2..32)
are checked signed ranges, not permissions to truncate. Accumulator width is
2..64. The initial implementation uses a physical 32x32 multiplier; smaller
configured ranges do not promise proportional DSP savings. PRODUCT_STAGES is
1 (registered 32x32 product) or 2 (registered low/high partial products followed
by a registered join); it changes latency, never arithmetic.

## Scheduled interface

- `LoadLeft(block, values) -> bool`: load block 0 or 1; all lanes must fit A_BITS.
  A rejected load invalidates that block. Hardware reset invalidates both.
- `Dot(block, right, seed) -> logic[65]`: reduce exactly sixteen products into
  the supplied seed, in lane order. Bits 63..0 hold the sign-extended result;
  bit 64 indicates failure. A failed result is zero. A second block can use the
  first result as seed **only after checking its failure bit**.
- `Clear() -> bool`: zero all weighted accumulators and clear their poison flag.
  Query blocks remain loaded. Hardware reset also zeros the accumulators.
- `Accumulate(block, scalar, right) -> bool`: update sixteen independent sums
  at indexes block*16..block*16+15 with `scalar*right[i]`. Scalar must fit A_BITS.
- `Read(index) -> logic[65]`: read a retained weighted sum plus status. Index
  must be 0..31. No per-element Failed() call is required.

Every product is exact signed int32 multiplication. Every sum, including a dot
seed, must fit ACC_BITS; no rounding or saturation occurs. Overflow is checked
at **each prefix**, so later cancellation cannot hide it. Dot failure does not
poison the weighted bank. Failed weighted updates may leave a partial bank and
poison it: further updates and reads fail until Clear or hardware reset. Invalid
configuration also fails. Invalid read indexes do not change the bank.

## Native transaction and pipeline

The native worker uses a request/completion toggle. The producer holds all
command fields stable until acknowledgment equals request. Acknowledgment means
the whole block is complete; it is not an early input-accept signal. There is
one outstanding transaction and no output FIFO. Result and failure remain stable
until another command completes. A consumer applies backpressure by delaying
its next request. Hardware reset cancels pending work, clears acknowledgment to
zero, invalidates queries and resets accumulators; reset the producer's toggle
at the same time. No pre-reset completion can arrive afterward.

An operand register feeds the product pipeline; one lane is issued each clock.
Weighted accumulator bases and indexes travel beside the products. Dot products
update one accumulator in original order. No scheduled scalar methods are used
inside the block. Memory load and wrapper latency are part of the benchmark;
native latency alone does not predict full application speed.

## Package integration and acceptance

Livt.ML supplies a 32-element attention adapter. It pairs two blocks for Q·K and
probability×V, leaving softmax, scaling and division to the calling model.
Metis retains Q20 activations, checked int64 sums and its existing rounding
boundaries. Model layout and DDR access remain in the application.

Test independent integer oracles over mixed signs, signed extremes, small-width
configurations, both pipeline depths, overflow-before-cancellation, invalid
indexes/unloaded queries, partial-bank poisoning, recovery, result retention and
reset during every command type. Test generated Livt wrappers separately from
the native RTL. Before integration, compare complete scalar and block workflows
with identical loading and output consumption. Later synthesis must establish
100 MHz closure and actual resources; lane throughput is not a timing guarantee.

## Retained weighted storage

The native weighted bank uses one synchronous read port and one write port,
with a block-RAM inference attribute. Per-lane validity supplies logical zeros
after reset without resetting the physical RAM. A forwarding register handles
a read immediately after the final write of an update or clear. Query storage
and the arithmetic ordering are unchanged. A precompute cycle primes the RAM
read pipeline; initialized reads complete after the synchronous read. Callers
must use the completion handshake rather than assume a fixed cycle count.

The Metis integration report records actual inferred resources and timing;
requested memory style alone is not evidence of BRAM inference.

The worker selects lanes directly from the stable input port instead of retaining
a second 512-bit row copy. This uses the existing hold-until-completion contract;
callers must not change any payload while a command is outstanding.

## Completion and checked-data timing

The scheduled wrapper's private completion helper has no wide return payload.
After completion, each public method consumes the owned primitive's retained
result directly. The public bool/65-bit results and single-owner contract are
unchanged; this avoids extra 65-bit dispatcher response registers.

The native core latches prefix failure independently of its wide data registers.
Internal arithmetic/storage may continue after a failure within the current
transaction, but a failed result remains zero and a failed weighted bank stays
poisoned until clear/reset. Such internal values are never readable. This keeps
overflow detection out of the wide accumulator write-enable path without
allowing cancellation to hide an earlier overflow.

Generic widths and product-stage selection are wired as immutable constants,
including during reset; the native core still supports checked configuration
ports. Static wrappers do not allocate runtime configuration registers.
