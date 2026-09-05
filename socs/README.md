<!-- Documents the repository's concrete coherent SoC compositions and focused tests. -->

# Example systems

`simple-soc.rhdl` composes the repository's primary single-core coherent system:

```text
SimpleSoC
├── External non-caching host RN-F (NodeID 1)
├── RV5Stage
│   ├── L1I RN-F (NodeID 2)
│   ├── L1D RN-F (NodeID 3)
│   └── Device RN-I (NodeID 4)
├── SimpleRouter × 4 (REQ, RSP, SNP, and DAT)
├── Memory CHIInclusiveHNF (NodeID 5)
│   └── external CHI SN-F (NodeID 9)
└── Device CHIHNI (NodeID 6)
    └── ACLINT SN-I (NodeID 10)
```

The external host loads and observes memory through its non-caching RN-F
endpoint and hands a 64-bit boot entry directly to RV5Stage. All SoC variants
expose this memory/start contract through `SoCHostInterface`; none contains DPI
calls or simulator behavior. Host `ReadClean` and `WriteUniquePtl`
transactions snoop the private caches, so simulator mailboxes may reside in
ordinary coherent memory.
The RV64 compositions accept a `~floating_point:` host specialization.
`SimpleSoC` defaults to `FloatingPointProfile.D`, so its ordinary simulation
configuration implements RV64D. The reusable `SimpleSoCFabric` and `TiledSoC`
boundaries retain the integer-only default and can select D explicitly;
`MiniSoC` currently inherits the fabric's integer-only default.
The ACLINT window occupies `0x02000000..0x0200ffff`. Its `mtime` counter drives
RV5Stage's `time` CSR, while hart 0's MTIP and MSIP levels drive the corresponding
machine interrupt inputs. The platform currently advances `mtime` once per SoC
clock; a later clock-rate adapter can replace that explicit tick policy. These
SoCs currently expose no external interrupt-controller input: supervisor and
external interrupt lines remain low until a platform interrupt device exists.

The one RN-I and three RN-F relationships reuse one physical single-router topology
but independently compile validation, route keys, buffering, and allocation for
the four CHI channel planes. REQ is 4-to-2, RSP and DAT are 6-to-6, and SNP is
1-to-3 because all three RN-Fs receive snoops. Router arity therefore follows
the permitted protocol paths instead of an all-node cross product.

RV5Stage exposes ready-valid `CHIRNChannels` bundles directly at its hierarchy
boundary, so the SoC connects both cache endpoints to the NoC without creating
internal credited links. The blocking inclusive HN-F caches subordinate lines,
snoops coherent requesters before replacing a line, and writes dirty snoop data
back to the subordinate. The external SN-F must accept native 64-byte reads and
writes, so this direct path needs no fragmenter.
Device addresses instead leave RV5Stage through its uncached RN-I, cross the
HN-I, re-enter the same physical fabric through the Home's subordinate-side
attachment, and terminate at the CHI-native ACLINT SN-I attachment.
Both paths are derived from one physical-region table. Each region pairs
RISC-V read, write, execute, cacheability, and atomic attributes with its CHI
Home; the SoC derives the `CHIHomeMap` from those same entries. Requests outside
the table therefore trap in RV5Stage instead of entering CHI without a Home.

The FESVR implementation and generated executable harness remain owned by
[`sims/`](../sims/README.md).

## MiniSoC

`SimpleSoCFabric` factors the processor, Home module, NoC, and ACLINT from the
final memory termination, and accepts that Home as an ordinary host circuit
parameter. `SimpleSoCParams` couples that fabric contract to the inclusive LLC
geometry. The default selects a 64-set, four-way blocking LLC and exports
line-capable `CHISNChannels` for SN-F NodeID 9 over the 1 GiB range
`0x80000000..0xbfffffff`. The SoC contains no RAM, fragmenter, or simulator
binding; an external subordinate owns the memory contents and response timing.

[`mini-soc.rhdl`](mini-soc.rhdl) defines `MiniSoC`, the small self-contained
variant used for compact RTL and physical-design experiments. It specializes
the same fabric with a 64 KiB range, uses the forwarding `CHIHNF`, and terminates
the native memory boundary directly in an on-chip, line-capable `CHIRam`. Its
RV64 instruction and data caches are each explicitly 32-set, one-way
direct-mapped caches with 2 KiB of line storage; `SimpleSoC` retains RV5Stage's
default 64-set cache geometry.

## TiledSoC

TiledSoC separates author intent from derived network and hardware parameters:

```text
TiledSoCSpec -> compile_tiled_soc_plan -> compile_tiled_soc -> TiledSoC
 layout           placements/routes       CHI/tile params      structure
 node IDs
 backing memory and LLC geometry
```

The author-facing layout uses rows in visual north-to-south order and supports
compact runs of like tiles:

```rhm
def layout = tile_grid:
  row [llc(4)]
  row [host, aclint, transit(2)]
  row [rv5stage(4)]
  row [rv5stage(4)]
```

`TiledSoCSpec` combines that immutable `TileGrid` with a `TiledNodeIdPlan` and
separate `StripedMemorySpec` and `TiledLLCSpec` geometries.
`compile_tiled_soc_plan` is pure host code: it derives mesh coordinates,
occurrence ordering, endpoint IDs, CHI relationships, routes, and the shared
physical-link manifest. `compile_tiled_soc` then derives the CHI, router, LLC,
backing-memory, and tile parameters and returns one `TiledSoCConfig`. The RTL
accepts that configuration directly as `TiledSoC(config)`. Tile occurrences
therefore carry their placement and component parameters together instead of
depending on parallel global arrays. The default `tiled_soc_config` preserves
the repository's 4x4 system, while the focused hierarchy test also elaborates a
2x3 system from the same pipeline.

The default pure plan places eight `RV5StageTile`s in the lower two rows, four
service routers in the middle row, and four `LLCTile`s in the upper row.
One service router colocates the shared eight-hart ACLINT with both sides of
its HN-I, another owns the external host RN-F, and the other two are
transit-only. The HN requester side, HN subordinate side, and ACLINT SN-I are
independent local attachments to the same router rather than a direct
HN-to-device wire. The system
allocates 16 RN-F NodeIDs for the eight L1I/L1D pairs, eight RN-I NodeIDs for
uncached device traffic, one host RN-F, four HN-Fs, one HN-I, four SN-Fs, and
one ACLINT SN-I.

Four 8 KiB banks cover `0x80000000` through `0x80007fff` with 64-byte
cache-line striping. Each LLC tile contains a 16-set, four-way cache, giving
4 KiB per bank and 16 KiB of aggregate inclusive LLC capacity. One shared
physical-region table maps successive lines to successive HN-Fs and derives the
CHI Home map. Each LLC indexes its sets with the dense per-bank projected
address while retaining the complete global line address as its tag. Its
subordinate projector then maps sparse global bank addresses into the dense
local backing RAM before fragmentation. The 16 coherent requester
endpoints plus the host RN-F connect to all four HN-Fs, while the eight uncached
requester endpoints connect to the ACLINT HN-I and its subordinate side
connects to the ACLINT SN-I. Together they compile 77 REQ, 153 RSP, 68 SNP,
and 154 DAT routes before any hardware elaborates.

Each tile owns one `CHIRouter`, which contains the independent REQ/RSP/SNP/DAT
`SimpleRouterFamily` instances and site-keyed CHI adapters. Every RV5Stage tile
uses one shared RTL specialization, every LLC tile uses another, and the
service row adds one `AclintTile`, one `HostTile`, and one transit
specialization. Their implementations and parameter contracts live under
[`tiles/`](tiles/). The parent drives one constant identity bundle per occurrence
containing its router site, hart ID, endpoint NodeIDs, striped service base, and
local RAM base; tiles
contain no system-wide identity table or runtime routing-mode selector. A
`RV5StageTile` attaches one RV5Stage's two RN-F ports and its RN-I device port. A
`LLCTile` attaches one blocking `CHIInclusiveHNF` and keeps its address
projector, transfer fragmenter, and CHIRam on the HN's direct subordinate side.
The ACLINT HN-I is reachable only through the uncached RN-I routes; its MSIP and
MTIP vectors and shared `mtime` value return directly to their corresponding
RV5Stage tiles.

Every tile exposes the family's uniform maximum of four incoming and four
outgoing physical links, each bundling the independent REQ/RSP/SNP/DAT
transports. `TiledSoC` alone applies the compiled `RouterFamilyLinkConnection`
manifest and explicitly closes unused edge and corner slots. There is no
whole-network RTL wrapper under `noc/`.

Run every SoC planning, configuration, tile, and hierarchy test from the
repository root with:

```sh
make soc-test
```

Use the package-local focused targets when iterating on one area:

```sh
make -C socs tiled-plan-test
make -C socs tiled-elaboration-test
```

Run the focused elaboration test with:

```sh
make -C socs rtl-elaboration-test
```

The focused SimpleSoC and MiniSoC elaboration tests cover the external-channel
and internal-memory variants.

Executable harness workflows are documented under [`sims/`](../sims/README.md).
