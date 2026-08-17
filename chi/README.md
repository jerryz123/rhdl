<!-- Defines the planned standalone AMBA CHI package, its non-coherent-first scope, and required generic credit-flow support. -->

# AMBA CHI domain library

`chi/` is the planned standalone AMBA CHI domain library. Like
[`tilelink/`](../tilelink/), it belongs beside RHDL rather than under
`rhdl/std`: CHI parameters, flits, node roles, transaction rules, monitors,
and components are protocol-specific. Only reusable transport mechanisms
belong in the generic standard library.

The initial implementation targets revision IHI 0050H of the AMBA CHI
Architecture Specification. This identifies the source used for the implemented
wire definitions; it is not a configurable parameter in the API.

The package currently implements the physical parameter and flit foundation,
protocol classifiers, node capabilities, and credited node-role links.
Monitors, fabrics, and endpoints remain planned below.

## Architectural boundary

CHI separates its protocol, network, and link responsibilities. The library
will preserve those boundaries:

- `chi/` owns CHI node roles, exact REQ/RSP/SNP/DAT flits, opcodes,
  transactions, protocol credits, link activation, optional CHI features, and
  protocol monitoring.
- `rhdl/std` owns only protocol-neutral credited transport, buffering, ID and
  address sets, storage, and ordinary hardware utilities.
- `noc/` remains pure host-side topology and routing analysis. A future CHI
  fabric may consume validated, materialized routing artifacts, but CHI RTL
  must not pull RHDL construction into the NoC model.
- RHDL core and frontend need no CHI-specific operations. Bundles, parameterized
  interfaces, connection compatibility, registers, memories, and assertions
  can express the initial implementation.

The public facade is [`main.rhdl`](main.rhdl). Package modules may import the
public `#lang rhdl` surface, protocol-neutral modules under `rhdl/std`, and
other `chi/` modules. They must not import RHDL core, frontend, or backend
implementation modules.

## Wire foundation

Import the implemented foundation with:

```rhombus
import:
  lib("chi/main.rhdl") open
```

[`params.rhdl`](params.rhdl) defines `CHIFlitParams`, the physical configuration
shared by all four protocol flits. It validates `NodeID_Width`,
`Req_Addr_Width`, `Data_Width`, MPAM, PBHA, MECID,
StreamID/SecSID1, REQ and DAT RSVDC widths, DataCheck, and Poison selections.
The standard defaults produce 137-bit REQ, 71-bit RSP, 94-bit SNP, and 240-bit
DAT flits. Optional fields are physically absent when disabled; they are not
represented by placeholder one-bit fields.

[`flits.rhdl`](flits.rhdl) defines every non-reserved REQ, RSP, SNP, and DAT
opcode from Tables B13.12 through B13.16. `CHIReqFlit`, `CHIRspFlit`,
`CHISnpFlit`, and `CHIDatFlit` construct exact packed record types from a
`CHIFlitParams`. Their fields are declared most-significant first so the
specification's first field, QoS, occupies bits `[3:0]`.
REQ, SNP, and DAT use the generic bundle layer's elaboration-conditional field
groups, so disabled CHI options are absent from both the record and its
packed representation. RSP is an ordinary bundle because all of its fields
are always present.

CHI assigns several semantic names to the same physical bits depending on the
opcode. The RHDL records expose one deliberately explicit field for each such
physical location, including `snp_attr_or_do_dwt`,
`return_nid_or_stash_nid_or_data_target`, `dbid_or_group_id`, and
`dbid_or_mecid`. Protocol helpers and future monitors interpret the aliases;
the flit type does not incorrectly allocate separate storage for them.

[`protocol.rhdl`](protocol.rhdl) classifies atomics, non-snoopable reads and
writes, DBID responses, and DAT message direction, rejects the reserved Size
encoding, and derives physical DAT packet counts and legal DataID values from
`Data_Width`. Generic `enum_valid` checks whether a channel opcode carries one
of the encodings declared by its CHI hardware enum; later monitors add the
node-role and negotiated-feature constraints. These helpers are hardware
expressions intended for endpoint construction and later monitors.

## Node-role links

[`link.rhdl`](link.rhdl) models CHI interfaces from the node's point of view.
It provides three physical shapes matching the channel sets in B13.6:

| Interface | Node kinds | Node transmit channels | Node receive channels |
|---|---|---|---|
| `CHIRNLink` | RN-F, RN-D | REQ, RSP, DAT | RSP, DAT, SNP |
| `CHIRNILink` | RN-I | REQ, RSP, DAT | RSP, DAT |
| `CHISNLink` | SN-F, SN-I | RSP, DAT | REQ, DAT |

Each protocol channel is a generic `Credited(flit, credit_limit)` interface.
The link parameter classes (`CHIRNLinkParams`, `CHIRNILinkParams`, and
`CHISNLinkParams`) carry the common `CHIFlitParams` and an explicit positive
credit limit for every physically present channel.

The four activation wires use names relative to the node. The node drives
`tx_link_active_request` for its transmit channels and
`rx_link_active_ack` for its receive channels; the ICN drives the complementary
`tx_link_active_ack` and `rx_link_active_request`. One request/ack pair covers
all protocol channels in that direction, as specified in B14.5. This milestone
defines the activation contract's wires; the next monitor milestone checks the
four-phase state transitions and gates legal credit and flit activity.

`CHINodeParams` and `CHIICNPortParams` give both sides the same NodeID and
`CHINodeKind` enum value while separately declaring channel opcodes emitted
and accepted through `CHIChannelCapabilities`. Construction rejects
capabilities on channels that
the selected node role does not possess; RN-D snoop capabilities are limited
to `SnpDVMOp`. A connection is legal only when:

- both endpoints select the same node kind and NodeID, and the NodeID fits the
  physical width;
- every opcode emitted by either endpoint appears in the peer's accepted set;
- every flit parameter, including optional-field selections, matches exactly;
- corresponding per-channel credit limits match.

The RN-F/RN-D and SN-F/SN-I pairs intentionally share physical interface
types. Their exact kind remains endpoint metadata so later monitors can apply
the distinct protocol rules without duplicating identical wiring.

## Non-coherent-first scope

The first executable endpoint will be `CHIRam`, a finite backing-memory
Subordinate Node. It is not a Home Node and does not implement coherence. A
Home Node performs any required ordering and coherence work before issuing a
non-snoopable transaction to this RAM.

CHI defines both SN-F and SN-I Subordinate Nodes as possible completers for
non-snoopable reads, writes, atomics, exclusive variants, and cache maintenance
operations. SN-F is the normal-memory backing role; SN-I additionally covers
peripherals and explicitly non-coherent memory. `CHIRam` will therefore
advertise an SN-F endpoint while initially supporting only the small common
Subordinate subset analogous to `TLRam`. This does not make the RAM coherent:
the upstream HN-F owns coherence and sends the SN-F only non-snoopable traffic.

| Operation | Initial transaction flow |
|---|---|
| Read | Receive `ReadNoSnp` on REQ, read storage, return `CompData` on DAT |
| Full write | Receive `WriteNoSnpFull`, return `DBIDResp`, receive `NonCopyBackWriteData`, commit storage, then return `Comp` |
| Partial write | Receive `WriteNoSnpPtl`, use byte enables when committing `NonCopyBackWriteData`, then return `Comp` |

The initial write path deliberately uses separate `DBIDResp` and `Comp`
responses. CHI permits a combined `CompDBIDResp` before the write data is
sent, but completing only after the RAM update gives `CHIRam` the same
observable storage discipline as `TLRam`.

The first profile will have these explicit limits:

- One power-of-two, naturally aligned address region backed by `SyncRam1RW`.
- Configurable physical data width, initially restricted to transfers that fit
  in one DAT flit.
- A bounded number of outstanding transactions with DBIDs allocated from the
  actual write-data reservation table.
- No snoopable requests, snoop channel, cache-state tracking, or Home Node
  behavior.
- No atomics, exclusives, cache maintenance, DVM, request retry, direct memory
  transfer, direct cache transfer, direct write transfer, data separation, or
  memory tagging in the first profile.
- Unsupported opcodes and field combinations are rejected by the advertised
  capabilities and checked by the interface monitor; they are not silently
  treated as ordinary reads or writes.

Later non-coherent milestones can add multi-flit data, ordering and
`ReadReceipt`, request retry and Protocol Credits, atomics, exclusives, write
zero, cache maintenance, and optional CHI features without changing the
meaning of the initial subset. Coherent RN-F/HN-F behavior is a separate
milestone layered above this backing-memory endpoint.

## Credited channel abstraction

CHI channels are not ready-valid. A transmitter asserts a valid flit only
after the receiver has granted a Link Credit, and each transmitted flit
consumes one previously granted credit. Link Credits cover one physical hop.
They are distinct from CHI Protocol Credits, which are transaction messages
used to guarantee that a retried request will be accepted.

The generic standard library provides the protocol-neutral interface:

```rhombus
interface Credited(T, credit_limit):
  role transmitter
  role receiver
  provider transmitter

  transmitter -> receiver:
    valid: Bool
    bits: T

  receiver -> transmitter:
    credit: Bool
```

The contract is:

- `valid` transfers exactly one payload on that clock edge; there is no
  receiver `ready` signal.
- A `credit` pulse grants permission for one future transfer.
- A transfer consumes one credit. A simultaneous grant and transfer leave the
  transmitter's balance unchanged.
- The transmitter must never send with a zero balance.
- The receiver must never grant more credits than its real buffering can
  absorb, including credits already granted but not yet consumed.
- Reset does not invent credits. The receiver explicitly grants its initial
  empty-buffer capacity when the surrounding protocol allows the link to run.

`credit_limit` is an elaboration-time connection and monitoring contract; it
does not add a physical field. The interface describes the wire contract;
buffering and accounting are ordinary reusable modules rather than hidden
interface behavior:

| Utility | Responsibility |
|---|---|
| `CreditSender(T, max_credits)` | Adapt internal `Decoupled(T)` traffic to `Credited(T, max_credits)`, track the received-credit balance, and expose `ready` only when a credit is available |
| `CreditBuffer(T, depth)` | Accept every legal credited transfer into real storage, expose an internal `Irrevocable(T)` dequeue, grant initial credits, and return a credit whenever a slot is freed |
| `CreditCounter(max_credits)` | Reusable bounded balance primitive with simultaneous grant/consume support |
| `monitor_credited(valid, credit, max_credits)` | Assert credit underflow, overflow, and conservation without driving either direction |

Activation is intentionally outside the generic interface. CHI-specific link
code will gate initial credit grants with CHI link activation and add any CHI
pending or low-power signals. Likewise, Protocol Credits remain CHI RSP
messages and must not be represented by `Credited`.

`CompletionQueue` is not this abstraction. It reserves local response capacity
at a ready-valid request handshake; it neither transports Link Credits nor
turns an externally credited flit channel into a buffered internal flow.

## Planned package layout

| Module | Responsibility |
|---|---|
| [`params.rhdl`](params.rhdl) | Implemented physical wire parameters and derived widths; node and edge capabilities come with role interfaces |
| [`flits.rhdl`](flits.rhdl) | Implemented exact parameterized REQ, RSP, SNP, and DAT payloads and nominal opcode namespaces |
| [`protocol.rhdl`](protocol.rhdl) | Implemented initial operation groups, Size checking, and DAT packetization; transaction relationships remain planned |
| [`link.rhdl`](link.rhdl) | Implemented node capabilities, role-specific credited links, link activation wires, and static connection compatibility |
| `monitor.rhdl` | Link-credit, channel, endpoint-transaction, ordering, retry, and eventually coherence checks |
| `ram.rhdl` | The non-snooping SN-F `CHIRam` backing-memory endpoint |
| `fabric.rhdl` | Node routing, arbitration, per-hop credit termination and regeneration, and generated crossbar/ring/mesh fabrics |
| [`main.rhdl`](main.rhdl) | Implemented public facade for the available foundation |

## Implementation order

1. **Complete:** Add and verify `Credited`, `CreditSender`, `CreditBuffer`,
   credit accounting, and their monitors under `rhdl/std`.
2. **Complete:** Define validated physical parameters, every defined
   opcode, exact parameterized flit layouts, and initial protocol classifiers.
3. **Complete:** Define node capabilities, node-role interfaces, link
   activation signals, and static connection legality.
4. Add link-local activation, credit, opcode, conditional-field, and NodeID
   monitoring.
5. Add bounded TxnID/DBID, response, retry, ordering, and data-completeness
   transaction monitors.
6. Define `CHIFabricParams`, validate the System Address Map, and generate a
   small credit-terminating crossbar.
7. Implement the RN-I-facing non-coherent memory subsystem and `CHIRam` over
   `SyncRam1RW`, first for single-flit reads and writes and then multibeat
   traffic.
8. Add RN-F/HN-F coherence and snoop tracking, followed by optional CHI
   features as independently verified vertical slices.

Each milestone requires host elaboration tests, invalid-parameter and invalid
connection tests, generated CIRCT verification, and a cycle-level Verilator
test of the supported transaction flows.

Run `make chi-test` for package boundaries, parameters, flit layouts,
classifiers, link contracts, and invalid connections. Run
`FIXTURES='chi-foundation chi-link' bash tests/backend/run-circt.sh` for CIRCT
lowering and cycle-level classifier and link simulations.

## Specification references

- [AMBA CHI Architecture Specification Issue H](https://developer.arm.com/documentation/ihi0050/h/)
- [Introducing AMBA CHI](https://documentation-service.arm.com/static/68590853961937560be90eb2)
- [Arm AMBA specifications](https://www.arm.com/architecture/system-architectures/amba/amba-specifications)
