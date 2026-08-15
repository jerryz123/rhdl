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
  |     |--> bundles + decode + register-file
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
not module boundaries. Three `Pipe(_, 1)` instances own the stallable IF/ID,
ID/EX, and EX/MEM boundaries; one `ValidPipe(_, 1)` owns the always-advancing
MEM/WB boundary.

Fetch has one epoch-tagged instruction request outstanding. Redirects consume
younger tokens and drain stale responses. Decode holds a load-use dependent
token. Execute owns forwarding, branch resolution, target and access alignment
checks, and architectural fault generation. Memory holds its EX/MEM token
until the data access returns exactly one response. Cache hit or miss latency
is consequently ordinary backpressure and does not alter pipeline state
semantics.

The integrated structured decoder emits the component control bundles
directly, without an intermediate instruction-kind enum. Unused controls stay
synthesis don't-cares while a separate valid bit determines whether decoded
values have architectural meaning.

## Top-level core

[`ricket.rhdl`](ricket.rhdl) defines
`Ricket(address_width, ~cache_sets: 64, ~line_bytes: 32)`. It exposes an
`Irrevocable(Bits(64))` start consumer, separate eight-byte `SimpleMemory`
instruction and data requester ports, and a sticky `fault` output. The two
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
