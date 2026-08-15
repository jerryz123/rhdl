<!-- Defines the Ricket RV64I core, its cache boundary, pipeline contract, and verification. -->

# Ricket

Ricket is the repository's single-issue, in-order five-stage RV64I processor.
Core-specific decode, architectural state, pipeline policy, and private L1
caches live here. Reusable execution components remain directly under
[`cores/`](../).

## Dependency boundary

```text
ricket.rhdl                         composition only
  |--> core-pipeline.rhdl           IF/ID/EX/MEM/WB logic
  |     |--> bundles + decode + register-file + scoreboard
  |     |--> ../{alu,branch-resolver,load-store}.rhdl
  |     |--> icache/protocol.rhdl
  |     `--> dcache/protocol.rhdl
  |--> icache/cache.rhdl            instruction access -> SimpleMemory(8 B)
  `--> dcache/cache.rhdl            data access -> SimpleMemory(8 B)
        `--> ../load-store.rhdl
```

The pipeline does not import `SimpleMemory`: it speaks Ricket's semantic
instruction and data access protocols. Cache modules own line lookup, refill,
beat alignment, byte masks, and load/store lane generation. The wrapper is the
only place that composes the pipeline and caches into the external Harvard
memory boundary.

Ricket may consume RHDL, the pure RISC-V model, and reusable components from
`cores/`. It must not import another named core, a backend, examples, or test
implementations. See [`icache/README.md`](icache/README.md) and
[`dcache/README.md`](dcache/README.md) for their separate protocol and cache
contracts.

## Pipeline

[`core-pipeline.rhdl`](core-pipeline.rhdl) keeps Fetch, Decode, Execute,
Memory, and Writeback as logical regions of one circuit. Individual stages are
not module boundaries. `Pipe(_, 1)` instances make IF/ID and ID/EX elastic, so
instructions wait before Execute until required operands and cache request
capacity are available. `ValidPipe(_, 1)` instances make EX/MEM and MEM/WB
feed-forward: once an instruction leaves Execute, no later stage can stall it.

Fetch keeps accepted PCs and epochs in a two-entry ordered metadata queue.
The pipelined L1I can therefore accept and return one hit per cycle. Redirects
consume younger tokens and drain stale responses without confusing their PCs.
Decode holds a load-use dependent token. Execute owns forwarding, branch
resolution, target and access alignment checks, and architectural fault
generation. A legal data-cache request transfers at the same edge that places
its instruction in EX/MEM. Memory is the ordered commit point: a committed load
sets its destination in `RicketScoreboard` and releases the pipeline before its
tagged result returns. Decode stalls on scoreboard RAW and WAW hazards, while
independent younger instructions may complete first. A returning load clears
its destination and writes through the register file's second write port. The
first write port independently accepts the ordinary MEM/WB result, so a load
completion never backpressures either feed-forward stage. A same-cycle hit sets
and clears the entry without an extra busy cycle. If both write ports target
the same register, the load port wins because that load is the younger
instruction; scoreboard WAW gating prevents the inverse age ordering. Stores
commit after the cache accepts them because all Ricket faults have already
been resolved.

This is in-order commit with out-of-order register completion, not out-of-order
instruction issue. D-cache responses remain ordered, and a blocking miss still
prevents younger memory requests from entering the cache; only independent
non-memory work passes the outstanding load.

The integrated structured decoder emits the component control bundles
directly, without an intermediate instruction-kind enum. Unused controls stay
synthesis don't-cares while a separate valid bit determines whether decoded
values have architectural meaning.

## Top-level core

[`ricket.rhdl`](ricket.rhdl) defines
`Ricket(address_width, ~cache_sets: 64, ~line_bytes: 32)`. It exposes an
`Irrevocable(Bits(64))` start consumer, separate eight-byte `SimpleMemory`
instruction and data requester ports, and a sticky `fault` output. L1I hits
have one-cycle latency and one-request-per-cycle throughput. L1D load hits have
the same throughput and preserve a five-bit pipeline completion tag through
their two-entry response queue; stores complete to the pipeline at lookup and
drain through an ordered one-entry write buffer. The two
external ports intentionally remain separate; SoC arbitration and integration
are outside the core.

## Verification

Run the focused host checks from the repository root:

```sh
make ricket-host-test
```

For only the changed core/cache hierarchy:

```sh
env PLTCOLLECTS="$PWD": raco test --direct \
  cores/ricket/tests/icache-test.rhm \
  cores/ricket/tests/dcache-test.rhm \
  cores/ricket/tests/ricket-test.rhm
```

`make ricket-test` additionally runs the reusable RV64I decode, ALU, and
load/store CIRCT/Verilator fixtures.
