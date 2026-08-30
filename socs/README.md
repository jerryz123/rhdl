<!-- Documents the repository's concrete coherent SoC compositions and focused tests. -->

# Example systems

`simple-soc.rhdl` composes the repository's initial coherent system:

```text
SimpleSoC
├── External host RN-I (NodeID 1)
├── Ricket
│   ├── L1I RN-F (NodeID 2)
│   ├── L1D RN-F (NodeID 3)
│   └── Device RN-I (NodeID 4)
├── SimpleRouter × 4 (REQ, RSP, SNP, and DAT)
├── Memory CHIHNF (NodeID 5)
│   └── CHITransferFragmenter → CHIRam SN-F (NodeID 9)
└── Device CHIHNI (NodeID 6)
    └── ACLINT SN-I (NodeID 10)
```

The external host loads memory through its RN-I endpoint and hands a 64-bit boot
entry directly to Ricket. Both concrete SoCs expose this memory/start contract
through `SoCHostInterface`; neither contains DPI calls or simulator behavior.
The ACLINT window occupies `0x02000000..0x0200ffff`. Its `mtime` counter drives
Ricket's `time` CSR, while hart 0's MTIP and MSIP levels drive the corresponding
machine interrupt inputs. The platform currently advances `mtime` once per SoC
clock; a later clock-rate adapter can replace that explicit tick policy. Both
SoCs currently expose no external interrupt-controller input: supervisor and
external interrupt lines remain low until a platform interrupt device exists.

The two RN-I and two RN-F relationships reuse one physical single-router topology
but independently compile validation, route keys, buffering, and allocation for
the four CHI channel planes. REQ is 4-to-2, RSP and DAT are 6-to-6, and SNP is
1-to-2 because only the two RN-Fs receive snoops. Router arity therefore follows
the permitted protocol paths instead of an all-node cross product.

Ricket exposes ready-valid `CHIRNChannels` bundles directly at its hierarchy
boundary, so the SoC connects both cache endpoints to the NoC without creating
internal credited links. The serialized HN-F translates coherent Ricket traffic
and authoritative dirty snoop packets into non-coherent subordinate
transactions, and the fragmenter expands 64-byte cache-line reads into the
RAM's one-DAT-beat transactions.
Device addresses instead leave Ricket through its uncached RN-I, cross the
HN-I, and terminate directly at the CHI-native ACLINT SN-I.

The FESVR implementation and generated executable harness remain owned by
[`sims/`](../sims/README.md).

## TiledSoC

`tiled-soc.rhdl` is the first distributed coherent system composition. Its pure
plan places eight `RicketTile`s in the lower two rows of a 4x4 mesh, four
service routers in the middle row, and four `MemoryTile`s in the upper row.
One service router owns the shared eight-hart ACLINT behind an HN-I, another
owns the external host RN-I, and the other two are transit-only. The system
allocates 16 RN-F NodeIDs for the eight L1I/L1D pairs, eight RN-I NodeIDs for
uncached device traffic, one host RN-I, four HN-Fs, one HN-I, four SN-Fs, and
one ACLINT SN-I.

Four 8 KiB banks cover `0x80000000` through `0x80007fff` with 64-byte
cache-line striping. One shared `CHIHomeMap` maps successive lines to successive
HN-Fs. Each memory tile projects its sparse global bank addresses into a dense
local RAM address space before fragmentation. The 16 coherent requester
endpoints and host RN-I connect to all four HN-Fs, while the eight uncached
requester endpoints connect to the ACLINT HN-I. Together they compile 76 REQ,
152 RSP, 64 SNP, and 152 DAT routes before any hardware elaborates.

Each tile owns one `CHIRouter`, which contains the independent REQ/RSP/SNP/DAT
`SimpleRouterFamily` instances and site-keyed CHI adapters. Every Ricket tile
uses one shared RTL specialization, every memory tile uses another, and the
service row adds one `AclintTile`, one `HostTile`, and one transit
specialization. The parent drives one constant identity bundle per occurrence
containing its router site, hart ID, endpoint NodeIDs, striped service base, and
local RAM base; tiles
contain no system-wide identity table or runtime routing-mode selector. A
`RicketTile` attaches one Ricket's two RN-F ports and its RN-I device port. A
`MemoryTile` attaches one HN-F and keeps its address projector, transfer
fragmenter, and CHIRam on the HN's direct subordinate side. The ACLINT HN-I is
reachable only through the uncached RN-I routes; its MSIP and MTIP vectors and
shared `mtime` value return directly to their corresponding Ricket tiles.

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

Executable harness workflows are documented under [`sims/`](../sims/README.md).
