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
| [`params.rhdl`](params.rhdl) | Wire widths, operation capabilities, and endpoint descriptions | `rhdl/std/bits.rhdl`, `rhdl/std/interconnect.rhdl` |
| [`bundles.rhdl`](bundles.rhdl) | Exact TileLink A-E opcode and payload types | `params.rhdl` |
| [`link.rhdl`](link.rhdl) | Directional `TLUncached` and `TLCached` interfaces and local connection legality | `rhdl/std/bits.rhdl`, `rhdl/std/ready-valid.rhdl`, `params.rhdl`, `bundles.rhdl` |
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
`TLClientLinkParams` and `TLManagerLinkParams` pair those descriptions with the
shared physical bundle parameters.

The channel payloads follow the TileLink A-E layouts. Opcode namespaces are
nominal and channel-specific (`TLAOpcode` through `TLDOpcode`); the E channel
contains only its sink ID. `param` remains raw `Bits` because its meaning
depends on the opcode.

| Interface | Client to manager | Manager to client |
|---|---|---|
| `TLUncached(endpoint)` | A | D |
| `TLCached(endpoint)` | A, C, E | B, D |

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
    TLUncached(TLClientLinkParams(bundle, client_params)),
    ~role: manager
  )
  interface manager(
    TLUncached(TLManagerLinkParams(bundle, manager_params)),
    ~role: client
  )
  manager <=> client
```

## Verification

Run `make tilelink-test` for package boundaries, parameter and link tests, and
all package-owned invalid connection cases. `make host-test` includes this
target.
