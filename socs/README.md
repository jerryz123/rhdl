<!-- Documents the repository's concrete coherent SoC compositions and focused tests. -->

# Example systems

`simple-soc.rhdl` composes the repository's initial coherent system:

```text
SimpleSoC
├── FESVR RN-I (NodeID 1)
├── Ricket
│   ├── L1I RN-F (NodeID 2)
│   └── L1D RN-F (NodeID 3)
├── SimpleRouter × 4 (REQ, RSP, SNP, and DAT)
├── CHIHNF (NodeID 5)
├── CHITransferFragmenter
└── CHIRam SN-F (NodeID 9)
```

FESVR loads memory through its RN-I endpoint, then hands the widened entry point
directly to Ricket. The SoC exposes the `loaded`, `entry`, and `exit` signals
consumed by [`support/TestDriver.sv`](../support/TestDriver.sv).
Ricket's controller-independent interrupt input is tied inactive in this
composition until the SoC gains an ACLINT timer or another platform source.

The RN-I and two RN-F relationships reuse one physical single-router topology
but independently compile validation, route keys, buffering, and allocation for
the four CHI channel planes. REQ is 3-to-1, RSP and DAT are 4-to-4, and SNP is
1-to-2 because only the two RN-Fs receive snoops. Router arity therefore follows
the permitted protocol paths instead of an all-node cross product.

Ricket exposes ready-valid `CHIRNChannels` bundles directly at its hierarchy
boundary, so the SoC connects both cache endpoints to the NoC without creating
internal credited links. The serialized HN-F translates coherent Ricket traffic
and authoritative dirty snoop packets into non-coherent subordinate
transactions, and the fragmenter expands 64-byte cache-line reads into the
RAM's one-DAT-beat transactions.

The FESVR transport implementation remains owned by
[`fesvr/`](../fesvr/README.md); `simple-soc.rhdl` owns its use in this concrete
system. A reusable external RN-I boundary can be introduced when another system
actually requires one.

## TiledSoC

`tiled-soc.rhdl` is the first distributed coherent system composition. Its pure
plan places eight `RicketTile`s in the lower two rows of a 4x3 mesh and four
`MemoryTile`s in the upper row. The system allocates 16 RN-F NodeIDs for the
eight L1I/L1D pairs, four HN-F NodeIDs, and four SN-F NodeIDs.

Four 8 KiB banks cover `0x80000000` through `0x80007fff` with 64-byte
cache-line striping. One shared `CHIHomeMap` maps successive lines to successive
HN-Fs. Each memory tile projects its sparse global bank addresses into a dense
local RAM address space before fragmentation. The 16 requester endpoints
connect to all four Homes, compiling 64 REQ, 128 RSP, 64 SNP, and 128 DAT routes
before any hardware elaborates.

Each tile owns one `CHIRouter`, which contains the independent REQ/RSP/SNP/DAT
`SimpleRouterFamily` instances and site-keyed CHI adapters. Every Ricket tile
uses one shared RTL specialization, and every memory tile uses another. The
parent drives one constant identity bundle per occurrence containing its router
site, endpoint NodeIDs, striped service base, and local RAM base; tiles contain
no system-wide identity table or runtime routing-mode selector. A `RicketTile`
attaches one Ricket's two RN-F ports; a `MemoryTile` attaches one HN-F and keeps
its address projector, transfer fragmenter, and CHIRam on the HN's direct
subordinate side.

Every tile exposes the family's uniform maximum of four incoming and four
outgoing physical links, each bundling the independent REQ/RSP/SNP/DAT
transports. `TiledSoC` alone applies the compiled `RouterFamilyLinkConnection`
manifest and explicitly closes unused edge and corner slots. There is no
whole-network RTL wrapper under `noc/`.

Run the pure planning and complete hierarchy tests with:

```sh
make -C socs tiled-plan-test
make -C socs tiled-elaboration-test
```

Run the focused elaboration test with:

```sh
make -C socs rtl-elaboration-test
```

The executable smoke additionally requires FESVR, CIRCT, Verilator, and an
RV32-capable `riscv64-unknown-elf-gcc`:

```sh
make -C socs e2e-test
```
