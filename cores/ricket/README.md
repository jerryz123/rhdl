<!-- Defines the width-parameterized Ricket core, cache boundary, pipeline contract, and verification. -->

# Ricket

Ricket is the repository's single-issue, in-order five-stage RV32I/RV64I
processor. The required `xlen :: XLen` host parameter selects `XLen.X32` or
`XLen.X64`; the same pipeline and cache implementation is specialized during
elaboration without admitting arbitrary integer widths.
Core-specific decode, architectural state, pipeline policy, and private L1
caches live here. Reusable execution components remain directly under
[`cores/`](../).

## Dependency boundary

```text
ricket.rhdl                         composition only
  |--> core.rhdl                    IF/ID/EX/MEM/WB logic
  |     |--> bundles + decode + register-file
  |     |--> ../{alu,branch-resolver,load-store}.rhdl
  |     |--> icache/protocol.rhdl
  |     |--> dcache/protocol.rhdl
  |     `--> ../../rhdl/std/scoreboard.rhdl
  |--> icache/cache.rhdl            instruction access -> SimpleMemory(8 B)
  `--> dcache/cache.rhdl            data access -> SimpleMemory(8 B)
        `--> ../load-store.rhdl
```

`RicketCore` does not import `SimpleMemory`: it speaks Ricket's semantic
instruction and data access protocols. Cache modules own line lookup, refill,
beat alignment, byte masks, and load/store lane generation. The wrapper is the
only place that composes the core and caches into the external Harvard
memory boundary.

Ricket may consume RHDL, the pure RISC-V model, and reusable components from
`cores/`. It must not import another named core, a backend, examples, or test
implementations. See [`icache/README.md`](icache/README.md) and
[`dcache/README.md`](dcache/README.md) for their separate protocol and cache
contracts.

## Pipeline

[`core.rhdl`](core.rhdl) keeps Fetch, Decode, Execute,
Memory, and Writeback as logical regions of one circuit. Individual stages are
not module boundaries. `Pipe(_, 1)` instances make IF/ID and ID/EX elastic, so
instructions wait before Execute until required operands and cache request
capacity are available. `ValidPipe(_, 1)` instances make EX/MEM and MEM/WB
feed-forward: once an instruction leaves Execute, no later stage can stall it.

Fetch keeps accepted PCs in a two-entry flushable metadata queue. The pipelined
L1I can therefore accept and return one hit per cycle. Redirects synchronously
flush the PC queue, lookup result, and buffered responses; a wrong-path refill
may finish internally but cannot return an instruction to Fetch.
Decode holds a token behind loads in ID/EX and EX/MEM until they reach WB.
Execute owns forwarding, branch
resolution, target and access alignment checks, and architectural fault
generation. A legal data-cache request transfers at the same edge that places
its instruction in EX/MEM. The L1D registers its SRAM lookup result so a hit
arrives with the instruction in WB. WB is the ordered commit point: a load whose
result has not returned sets its destination in the standard `Scoreboard` and
releases the pipeline before its tagged result returns. Decode stalls on
scoreboard RAW and WAW
hazards, while independent younger instructions may complete first. A returning
load clears its destination and writes through the register file's second write
port. The first write port independently accepts the ordinary MEM/WB result, so
a load completion never backpressures either feed-forward stage. A WB-aligned
hit sets and clears the entry without an extra busy cycle. Scoreboard WAW
gating prevents both write ports from validly targeting the same register.
Stores commit in WB; their earlier cache acceptance is safe because all Ricket
faults have already been resolved before EX/MEM.

This is in-order commit with out-of-order register completion, not out-of-order
instruction issue. D-cache responses remain ordered, and a blocking miss still
prevents younger memory requests from entering the cache; only independent
non-memory work passes the outstanding load.

The integrated structured decoder selects the RV32I or RV64I catalog at host
elaboration and emits the component control bundles directly, without an
intermediate instruction-kind enum or parallel hardware decoders. Unused
controls stay synthesis don't-cares while a separate valid bit determines
whether decoded values have architectural meaning.

## Top-level core

[`ricket.rhdl`](ricket.rhdl) defines
`Ricket(xlen, address_width, ~cache_sets: 64, ~line_bytes: 32)`. `xlen` is an
`XLen` enum value, and `address_width` must not exceed `xlen_width(xlen)`. The
core exposes an `Irrevocable(Bits(xlen_width(xlen)))` start consumer, separate
eight-byte `SimpleMemory` instruction and data requester ports, and a sticky
`fault` output. L1I hits have one-cycle latency and one-request-per-cycle
throughput. L1D load hits have the same throughput and pass through a mandatory
non-backpressurable post-SRAM register while preserving a five-bit pipeline
completion tag. A one-stage lookup flow carries request context beside the SRAM
access and holds it across refill; stores complete through the registered
response path and drain through an ordered one-entry write buffer. The two
external ports intentionally remain separate; SoC arbitration and integration
are outside the core. The backing-memory data width stays fixed at 64 bits in
both specializations; only the architectural and core-facing values follow
`xlen`.

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

`make ricket-test` additionally runs RV32I and RV64I decode, ALU, pipeline,
cache, and load/store CIRCT fixtures plus the applicable Verilator fixtures.
