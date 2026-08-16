<!-- Documents the standalone TileLink domain library, its APIs, boundaries, and tests. -->

# TileLink domain library

`tilelink/` is an optional domain library built on RHDL's public authoring
surface. It is not part of the RHDL language implementation or generic
standard library. Import its public facade with:

```rhombus
import:
  lib("tilelink/main.rhdl") open
```

The package provides validated host parameter records, exact A-E payload
bundles, and directional uncached and cached interfaces with local
client-to-manager legality checks. Its source modules may depend on `#lang
rhdl` and protocol-neutral modules under `rhdl/std`; they must not import RHDL
core, frontend, or backend implementation modules.

## Package layout

| Module | Provides | Direct RHDL dependencies |
|---|---|---|
| [`params.rhdl`](params.rhdl) | Wire widths, endpoint and port descriptions, edge validation, and crossbar ID allocation | `rhdl/std/bits.rhdl`, `rhdl/std/interconnect.rhdl` |
| [`bundles.rhdl`](bundles.rhdl) | Exact TileLink A-E opcode and payload types | `params.rhdl` |
| [`protocol.rhdl`](protocol.rhdl) | Opcode groups, response mappings, and data-dependent physical beat counts | `rhdl/std/bits.rhdl`, `params.rhdl`, `bundles.rhdl` |
| [`link.rhdl`](link.rhdl) | Directional `TLUncached` and `TLCached` interfaces, local connection legality, and uncached manager monitoring | `rhdl/std/bits.rhdl`, `rhdl/std/ready-valid.rhdl`, `params.rhdl`, `bundles.rhdl` |
| [`ram.rhdl`](ram.rhdl) | Finite uncached RAM manager with generated endpoint parameters | `rhdl/std/bits.rhdl`, `rhdl/std/ready-valid.rhdl`, `rhdl/std/read-write.rhdl`, `rhdl/std/sync-ram.rhdl`, `rhdl/std/flow/queue.rhdl`, `params.rhdl`, `bundles.rhdl`, `link.rhdl` |
| [`main.rhdl`](main.rhdl) | Public TileLink facade | All modules above |

## Parameters and payloads

`TLBundleParams(address_width, data_bytes, size_width, source_width,
sink_width)` fixes the physical link widths. `data_bytes` must be a power of
two and determines both `data_width = data_bytes * 8` and `mask_width =
data_bytes`; every other wire width must be positive. These are host generator
parameters and do not add runtime configuration signals.

`TLAOperationSizes` describes A operations emitted by a client or supported by
a manager. `TLBOperationSizes` describes B operations emitted by a manager or
supported by a cached client. An operation field equal to `#false` is
unsupported. `TLClientParams` and `TLManagerParams` collect endpoint identity,
ID or address ownership, capabilities, and manager denial policy.
`TLUncached` and `TLCached` pair an endpoint description with shared physical
bundle parameters when their interface specialization is constructed. The
physical size field must be wide enough to encode the link's data beat.
`TLClientLinkParams` and `TLManagerLinkParams` remain the normalized singleton
records used by existing connection and monitor checks.

`TLClientPortParams` and `TLManagerPortParams` preserve collections of logical
endpoints behind one physical port, including the association between source
IDs and clients and between addresses, sink IDs, and managers. Their IDs and
addresses must be unambiguous within a port. `TLEdgeParams` combines normalized
client and manager ports with one physical bundle and validates that every ID
and address fits its wire width.

`TLXbarParams(bundle, clients, managers)` accepts nonempty lists of singleton
or port parameters. It assigns every client port an exact contiguous global
source range and every manager port an exact contiguous global sink range,
rejects insufficient wire widths and overlapping manager address regions, and
produces the shifted aggregate ports that a future crossbar exposes on its two
sides. Each `IdRangeMap` retains the original possibly nonzero local range for
reversible translation. This object describes and validates generated
topology; it does not yet instantiate routing hardware.

The channel payloads follow the TileLink A-E layouts. Opcode namespaces are
nominal and channel-specific (`TLAOpcode` through `TLDOpcode`); the E channel
contains only its sink ID. `param` remains raw `Bits` because its meaning
depends on the opcode.

`protocol.rhdl` classifies data-carrying and coherence opcodes on every
channel, checks the legal A-to-D, B-to-C, and Release-to-ReleaseAck opcode
relationships, and computes `beats - 1` from `size`, opcode, and physical beat
width. Returning the remaining-beat count makes every no-data or single-beat
message zero while retaining enough width for the largest encoded transfer.

| Interface | Client to manager | Manager to client |
|---|---|---|
| `TLUncached(bundle, endpoint_params)` | A | D |
| `TLCached(bundle, endpoint_params)` | A, C, E | B, D |

Each channel uses `Decoupled(TLChannelX(...))`. TileLink permits an unaccepted
first beat to be withdrawn or replaced, so these interfaces do not claim the
stronger `Irrevocable` contract. Clock and reset belong to circuits using the
link rather than to the protocol interface.

## Connection legality

Bulk connection treats the client specialization as the provider regardless
of `<=>` operand order. Every client-emitted A operation must fit the matching
manager-supported `TransferSizes`. Cached links also require manager-emitted B
operations to fit the client's supported ranges. Source IDs, sink IDs, manager
address sets, and transfer sizes must fit the physical encodings. Uncached
links reject Acquire and manager-emitted B traffic.

These checks cover the capabilities represented by the current parameter
records. They do not perform graph-wide negotiation, routing, width or ID
adaptation, complete C/E coherence negotiation, or endpoint behavior.

An uncached manager endpoint can opt into the `TLUncached` whole-link monitor
with `~monitor`. While A is valid, the monitor checks its opcode and size
against the manager's advertised support, requires zero `param` for Get and
Put operations, checks single-beat alignment and mask shape, and requires the
address to match one of the manager's address sets. These observational checks
do not drive `ready` or otherwise change link behavior. Corruption checking is
currently deferred.

```rhombus
import:
  lib("tilelink/main.rhdl") open

def bundle = TLBundleParams(32, 8, 4, 3, 2)
def transfers = TransferSizes(1, 8)
def client_params = TLClientParams(
  "cpu",
  IdRange(0, 4),
  ~emits: TLAOperationSizes(~get: transfers)
)
def manager_params = TLManagerParams(
  "ram",
  [AddressSet(0x80000000, 0x0fffffff)],
  IdRange(0, 4),
  ~supports: TLAOperationSizes(~get: TransferSizes(1, 64))
)

circuit TileLinkBoundary():
  interface client(
    TLUncached(bundle, client_params),
    ~role: manager
  )
  interface manager(
    TLUncached(bundle, manager_params),
    ~role: client
  )
  manager <=> client
```

## RAM manager

`TLRam(name, bundle, size_bytes, ~base_address: 0)` is a finite uncached
manager backed by `SyncRam1RW`. Its naturally aligned power-of-two region
supports single-beat `Get`, `PutFullData`, and `PutPartialData` operations from
one byte through `bundle.data_bytes`. The circuit derives and advertises its
`TLManagerParams` directly from those physical parameters.

The RAM converts byte addresses into word indices, maps each A-channel write
mask onto the byte lanes of the shared 1RW storage, and returns `AccessAckData`
for reads or `AccessAck` for writes. D responses preserve the request `size`
and `source`; `param`, `sink`, `denied`, and `corrupt` are zero. A two-entry
`CompletionQueue` reserves D capacity when A transfers, then exposes the
accepted request through `fork_valid`. One `map_valid` branch drives the RAM
request while the other crosses a one-cycle `valid_pipe` and maps the RAM result
into the matching D completion. This standard flow composition allows one
request per cycle until D-channel backpressure fills the reservation window,
without losing the storage wrapper's nonstallable one-cycle read result.

`TLRam` opts into the uncached manager monitor. `PutFullData` and `Get` require
the complete naturally addressed mask; `PutPartialData` permits any subset of
that mask. The RAM's A-channel readiness depends only on reserved response
capacity; protocol assertions remain observational and corruption metadata is
ignored for now.

## Verification

Run `make tilelink-test` for package boundaries, parameter and link tests, and
all package-owned invalid connection cases. `make host-test` includes this
target.
