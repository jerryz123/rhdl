<!-- Defines the width-parameterized Ricket core, cache boundary, pipeline contract, and verification. -->

# Ricket

Ricket is the repository's single-issue, in-order five-stage RV32I/RV64I
processor with M, Zicsr, Zifencei, and an initial M/S/U privileged control plane. The required `xlen :: XLen` host parameter selects `XLen.X32` or
`XLen.X64`; the same pipeline and cache implementation is specialized during
elaboration without admitting arbitrary integer widths.
Core-specific decode, architectural state, pipeline policy, and private L1
caches live here. Reusable execution components remain directly under
[`cores/`](../).

## Dependency boundary

```text
core.rhdl / core-flow.rhdl          explicit / flow-oriented IF/ID/EX/MEM/WB
  |--> bundles + decode + register-file + csr
  |--> ../{alu,branch-resolver,load-store,multiplier,divider}.rhdl
  |--> icache/protocol.rhdl
  |--> dcache/protocol.rhdl
  `--> ../../rhdl/std/scoreboard.rhdl
ricket.rhdl                         composition selects core-flow.rhdl
  |--> cache.rhdl                   fixed 64-byte private-L1 line geometry
  |--> chi.rhdl                     RN-F parameters and flit construction
  |--> refill.rhdl                  blocking ReadClean/CompData/CompAck engine
  |--> write-unique.rhdl             retryable WriteUniquePtl transaction engine
  |--> snoop.rhdl                    shared clean-line snoop and DVM engine
  |--> icache/cache.rhdl             instruction arrays, policy, and CHI routing
  `--> dcache/cache.rhdl             data arrays, policy, and CHI routing
```

`RicketCore` speaks only Ricket's semantic instruction and data access
protocols. Cache modules own line lookup, array arbitration, transaction
scheduling, CHI channel routing, byte masks, and load/store lane generation.
The shared transaction engines own protocol sequencing, retry state, response
stability, and DVM pairing. The wrapper composes the core and caches into two
ready-valid RN-F channel bundles; physical credited links belong to system
integration when the channels actually cross a CHI link boundary.

Ricket may consume RHDL, the pure RISC-V model, and reusable components from
`cores/`. It must not import another named core, a backend, examples, or test
implementations. See [`icache/README.md`](icache/README.md) and
[`dcache/README.md`](dcache/README.md) for their separate protocol and cache
contracts.

## Core variants

[`core.rhdl`](core.rhdl) is a direct RTL description. It uses ordinary
registers for fetch state, one explicit priority update chain, direct
ready-valid equations, and a shared forwarding mux policy. It retains only the
pipeline storage primitives and the real deferred-completion arbiter instead
of mechanically recreating flow transformations with helper instances.

[`core-flow.rhdl`](core-flow.rhdl) implements the same processor contract with
the standard flow vocabulary. [`ricket.rhdl`](ricket.rhdl) selects this version
for the integrated cache hierarchy. The standalone CIRCT fixtures run the same
architectural scenario against both implementations. A host test checks their
shared port contract and verifies that each keeps its intended explicit or
flow-oriented structure.

## Pipeline

Both core variants keep Fetch, Decode, Execute, Memory, and Writeback as logical
regions of one circuit. Individual stages are not module boundaries.
`Pipe(_, 1)` instances make IF/ID and ID/EX elastic, so instructions wait before
Execute until required operands and cache request capacity are available.
`ValidPipe(_, 1)` instances make EX/MEM and MEM/WB feed-forward: once an
instruction leaves Execute, no later stage can stall it.

Fetch keeps accepted PCs in a two-entry flushable metadata queue. The pipelined
L1I can therefore accept and return one hit per cycle. Redirects synchronously
flush the PC queue, lookup result, and buffered responses; a wrong-path refill
may finish internally but cannot return an instruction to Fetch.
The explicit core exposes `started` and `fetch_pc` directly. Redirect, initial
start, and completed request update `fetch_pc` in that priority order, while
paired valid equations make the L1I request and PC correlation queue advance
together. The flow core deliberately keeps the same explicit sequential state;
its abstraction boundary is the combinational interface topology around it.
Decode holds a token behind deferred loads, multiplies, or divides in ID/EX and EX/MEM
until they reach WB.
Execute owns forwarding, branch resolution, target and access alignment
checks, and synchronous-exception classification. In the explicit core, one
readiness equation combines cache capacity and arithmetic-unit reservations; branch
resolution and EX/MEM observe the resulting transfer together. The flow core
uses an atomic fork for the same five-way admission policy. A legal request
transfers at the same edge that places its instruction in EX/MEM. The L1D
registers its SRAM lookup result so a hit arrives with the
instruction in WB. WB is the ordered commit point: a load whose result has not
returned or long-latency arithmetic that starts there sets its destination in the standard
`Scoreboard` and releases the pipeline before its result returns.
ID/EX carries register indices rather than captured register data. Execute
reads the register file live, so an instruction held behind cache or arithmetic
capacity observes an older write even after that write's forwarding window has
passed.
Multiplication and division are reserved in Execute but issued only when the
instruction reaches WB, so redirects and older faults never need to kill
either arithmetic unit's state.
Decode stalls on
scoreboard RAW and WAW
hazards, while independent younger instructions may complete first. A returning
load, multiply, or divide clears its destination and writes through one element of the register
file's `Valid(RegisterFileWrite(xlen))` write array. Valid-flow filtering,
mapping, and fanout connect both update streams to the scoreboard without
making its continuously observable busy bitmap into a transaction stream. A
fixed-priority completion arbiter gives loads priority because they cannot be
backpressured; multiplier and divider responses remain stable until selected.
The
other array element independently accepts the ordinary MEM/WB result through
the same valid-only payload contract, so a load completion never backpressures
either feed-forward stage. A WB-aligned hit sets and clears the entry without
an extra busy cycle.
Scoreboard WAW gating prevents both write ports from validly targeting the same
register. Stores commit in WB; their address and alignment checks still occur
before cache acceptance.

This is in-order commit with out-of-order register completion, not out-of-order
instruction issue. D-cache responses remain ordered, and a blocking miss still
prevents younger memory requests from entering the cache; only independent
non-memory work passes the outstanding load.

The integrated structured decoder selects the RV32IM+Zicsr+Zifencei or RV64IM+Zicsr+Zifencei catalog at host
elaboration and emits the component control bundles directly, without an
intermediate instruction-kind enum or parallel hardware decoders. Unused
controls stay synthesis don't-cares while a separate valid bit determines
whether decoded values have architectural meaning.

[`csr.rhdl`](csr.rhdl) owns the named machine and supervisor CSRs, current
privilege mode, synchronous trap entry, and `MRET`/`SRET`. CSR instructions
atomically return the old value and update state at WB. System instructions
serialize in Decode and wait for older deferred loads, multiplies, or divides before
entering the pipeline, so younger instructions cannot create side effects
before the system operation commits. Execute-detected exceptions immediately
squash younger work but carry the faulting instruction to WB, where the CSR
file records EPC, cause, and trap value and selects the direct `mtvec` or
`stvec` target. The first cut has no interrupts, PMP, counters, vectored trap
mode, or virtual memory; `satp` is a recognized WARL-zero CSR and translation
therefore remains Bare.

Base `FENCE` and `FENCE.I` share the same serialization boundary. Decode waits
for older deferred register completions and for the L1D to report that its
lookup, refill, and coherent write-through transaction are drained, then
prevents younger instructions from entering Execute until the fence reaches
WB. `FENCE.I`
additionally invalidates every L1I line at WB and redirects Fetch to the
fence's own `pc + 4`. The architectural invalidate is distinct from a
speculative fetch flush: an ordinary redirect discards wrong-path work without
destroying useful cache residency. An L1I refill already in flight is allowed
to drain after invalidation, but cannot install its line or return an
instruction.

Ricket stores implemented CSR data in one aggregate state register. The
RISC-V/RHDL `csr_bank` declaration is the single source for recognized IDs,
read values, direct storage, aliases, WARL masks, and write dispatch. Trap and
return updates remain an explicit prioritized transition because they
atomically affect privilege state and several CSRs instead of representing an
ordinary addressed write.

## Logical diagram

[`examples/ricket/core-diagram.rhdl`](../../examples/ricket/core-diagram.rhdl)
elaborates the flow-oriented RV64 `RicketCore` and extracts its module boundary,
child blocks, registers, typed interface channels, and named flow
transformations. Generate the focused JSON and Graphviz DOT files with:

```sh
mkdir -p /tmp/ricket-core-diagram
env PLTCOMPILEDROOTS="$(mktemp -d)" \
  racket -y -S "$PWD" tools/write-ricket-core-diagram.rhm \
  /tmp/ricket-core-diagram
```

The JSON is intended for interactive renderers. The DOT file is a compact
diagnostic view of the core module; child modules remain linked by name instead
of being flattened into the same graph.

## Top-level core

[`ricket.rhdl`](ricket.rhdl) defines
`Ricket(xlen, ~cache_sets: 64, ~chi: ...)`. `xlen` is an
`XLen` enum value. Architectural addresses and cache tags use
`xlen_width(xlen)` internally. Both private L1 caches use the architectural
64-byte line size from [`cache.rhdl`](cache.rhdl); line geometry is not a
top-level generator option. The RN-F boundary uses the explicit CHI request
address width and asserts that a wider accepted address fits before narrowing.
The core exposes an `Irrevocable(Bits(xlen_width(xlen)))` start consumer,
separate instruction and data `CHIRNChannels` node ports, and a sticky `fault`
output for a rejected misaligned external start address. Architectural
instruction exceptions enter the CSR trap machinery. L1I hits have one-cycle latency and
one-request-per-cycle throughput. In both caches, a one-stage lookup flow
carries request context beside the SRAM access; a miss is filtered and mapped
into the shared refill engine, which returns that context with the completed
line. L1I maps hits and live refill completions into response flows and merges
them before its response queue. L1D load hits have the same throughput and pass through a mandatory
non-backpressurable post-SRAM register while preserving a five-bit pipeline
completion tag. Stores complete through the registered response path and drain
through an ordered one-entry coherent write-through transaction. The two
external ports intentionally remain separate RN-F Request Nodes. Home Node,
fabric, and SoC integration remain outside the core. Ricket uses CHI's minimum
128-bit DAT width; each fixed 64-byte cache-line refill therefore completes
from four ordinary, unelided DAT packets before the cache returns `CompAck`.

## Verification

Run the focused host checks from the repository root:

```sh
make ricket-host-test
```

For only the changed core/cache hierarchy:

```sh
env PLTCOLLECTS="$PWD": raco test --direct \
  cores/ricket/tests/refill-test.rhm \
  cores/ricket/tests/icache-test.rhm \
  cores/ricket/tests/dcache-test.rhm \
  cores/ricket/tests/ricket-test.rhm
```

`make ricket-test` additionally runs RV32I and RV64I decode, ALU, pipeline,
cache, and load/store CIRCT fixtures plus the applicable Verilator fixtures.
