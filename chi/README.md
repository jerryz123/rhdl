<!-- Defines the standalone AMBA CHI package, its implemented layers, and non-coherent-first roadmap. -->

# AMBA CHI domain library

`chi/` is the standalone AMBA CHI domain library. It belongs beside RHDL
rather than under `rhdl/std`: CHI parameters, flits, node roles, transaction
rules, monitors, and components are protocol-specific. Only reusable transport
mechanisms belong in the generic standard library.

The initial implementation targets revision IHI 0050H of the AMBA CHI
Architecture Specification. This identifies the source used for the implemented
wire definitions; it is not a configurable parameter in the API.

The package currently implements the physical parameter and flit foundation,
protocol and coherence classifiers, node capabilities, credited node-role
links, link-local monitors, bounded initial non-coherent and RN-F transaction
checking, separate requester-side and home-side SAM metadata, an initial HN-I
bridge, and a non-coherent backing RAM. Its first NoC integration maps CHI
NodeIDs and symbolic protocol terminals onto independently validated REQ, RSP,
and DAT transports. SNP integration, coherent cache controllers, and HN-F
remain planned below.

## Architectural boundary

CHI separates its protocol, network, and link responsibilities. The library
will preserve those boundaries:

- `chi/` owns CHI node roles, exact REQ/RSP/SNP/DAT flits, opcodes,
  transactions, protocol credits, link activation, optional CHI features, and
  protocol monitoring.
- `rhdl/std` owns only protocol-neutral credited transport, buffering, ID and
  address sets, storage, and ordinary hardware utilities.
- `noc/` remains pure host-side topology and routing analysis. CHI consumes
  validated, materialized routing artifacts through its pure channel
  compilations and RTL endpoint adapters, but CHI RTL does not pull RHDL
  construction into the NoC model.
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

Closed protocol fields use nominal authoring types at their specified widths:
`CHITagOp`, `CHIOrder`, `CHIPAS`, `CHIRespErr`, and `CHITransferSize` are
hardware enums, while `CHIMemAttr` names the Allocate, Cacheable, Device, and
Early Write Acknowledge bits. This preserves the exact packed flits while
preventing unrelated same-width values from being connected accidentally.

CHI assigns several semantic names to the same physical bits depending on the
opcode. The RHDL records expose one deliberately explicit field for each such
physical location, including `snp_attr_or_do_dwt`,
`return_nid_or_stash_nid_or_data_target`, `dbid_or_group_id`, and
`dbid_or_mecid`. Protocol helpers and monitors interpret the aliases;
the flit type does not incorrectly allocate separate storage for them.
The REQ `size_or_num_req` location likewise remains a six-bit union;
`chi_req_size` returns its typed transfer-size view and `chi_req_num_req`
returns its complete NumReq view.

The opcode enums own their intrinsic classifiers as dot methods, including
atomic and non-snoopable request families, DBID allocation, data direction,
and snoop-response families. [`protocol.rhdl`](protocol.rhdl) owns the REQ
Size and NumReq views, rejects the reserved Size encoding, and derives physical
DAT packet counts and legal DataID values from `Data_Width`. Generic
`enum_valid` checks whether a channel opcode carries one of the encodings
declared by its CHI hardware enum; the link monitor further checks each
endpoint's advertised opcode capabilities.

[`coherence.rhdl`](coherence.rhdl) adds the state vocabulary needed by coherent
endpoints. `CHICacheState` owns its validity, dirty, shared, and unique queries.
Because the wire `Resp` field is opcode-dependent, coherent contexts explicitly
reinterpret it as the packed `CHICoherentResponse` view before reading `state`
or `pass_dirty`. The module also owns the complete ordinary SNP opcode set that
every RN-F endpoint must accept. These are classifiers and static capability
rules; they do not implement a cache-state machine.

## Node-role links

[`link.rhdl`](link.rhdl) models CHI interfaces from the node's point of view.
It provides three physical shapes matching the channel sets in B13.6:

| Interface | Node kinds | Node transmit channels | Node receive channels |
|---|---|---|---|
| `CHIRNLink` | RN-F, RN-D | REQ, RSP, DAT | RSP, DAT, SNP |
| `CHIRNILink` | RN-I | REQ, RSP, DAT | RSP, DAT |
| `CHISNLink` | SN-F, SN-I | RSP, DAT | REQ, DAT |

HN-F and HN-I are fabric identities rather than new physical endpoint shapes.
An HN-I terminates an RN-I-shaped link on its requester side and originates an
SN-I-shaped link on its subordinate side; its two sides therefore use the
existing role-specific link definitions.

Each protocol channel is a generic `Credited(flit, credit_limit)` interface.
The link parameter classes (`CHIRNLinkParams`, `CHIRNILinkParams`, and
`CHISNLinkParams`) carry the common `CHIFlitParams` and a natural-number Link
Credit count for every physically present channel.

The four activation wires use names relative to the node. The node drives
`tx_link_active_request` for its transmit channels and
`rx_link_active_ack` for its receive channels; the ICN drives the complementary
`tx_link_active_ack` and `rx_link_active_request`. One request/ack pair covers
all protocol channels in that direction, as specified in B14.5.

`CHINodeParams` and `CHIICNPortParams` give both sides the same NodeID and
`CHINodeKind` enum value while separately declaring channel opcodes emitted
and accepted through `CHIChannelCapabilities`. Construction rejects
capabilities on channels that
the selected node role does not possess; RN-D snoop capabilities are limited
to `SnpDVMOp`, while RN-F endpoints must accept every ordinary snoop opcode. A
connection is legal only when:

- both endpoints select the same node kind and NodeID, and the NodeID fits the
  physical width;
- every opcode emitted by either endpoint appears in the peer's accepted set;
- every flit parameter, including optional-field selections, matches exactly;
- corresponding per-channel credit limits match.

The RN-F/RN-D and SN-F/SN-I pairs intentionally share physical interface
types. Their exact kind remains endpoint metadata so later monitors can apply
the distinct protocol rules without duplicating identical wiring.

[`flow.rhdl`](flow.rhdl) provides node-side and ICN-side adapters for all three
physical link shapes. RN-I converts to the recursively composed
`CHIRNIDecoupled` REQ/RSP/DAT endpoint, while SN-F/SN-I use
`CHISNDecoupled`. RN-F/RN-D adapters expose their physical channel flows
separately because their RSP and DAT channels can carry both ordinary requester
traffic and snoop responses; the endpoint owns that arbitration. Link
activation and credit-drain status remain adapter outputs instead of
ready-valid subchannels. The RN node-side adapter also applies the physical
link monitor at this boundary; its bounded coherent-transaction checks can be
disabled independently for endpoint behavior they do not yet cover.

## Fabric and System Address Map parameters

[`fabric.rhdl`](fabric.rhdl) keeps routed service metadata separate from link
identity. `CHIRequestSupport` associates one REQ opcode with the
`TransferSizes` accepted by a target, while `CHISubordinateServiceParams`
associates those operation sizes and one or more `AddressSet` regions with an
SN-F or SN-I ICN port. This allows one subordinate to expose different service
profiles in disjoint address regions without changing its physical link.

`CHIHomeParams` gives HN-F and HN-I identities a NodeID and bounded transaction
capacity. `CHIHomeServiceParams` describes the operations and address regions
that an RN routes to a Home Node. `CHIFabricPortParams` pairs each RN or SN ICN
endpoint with the link parameter class required by its node kind.

`CHIFabricParams` accepts a common `CHIFlitParams`, physical ports, Home Nodes,
home services, and subordinate services. It derives two deliberately separate
maps: `rn_sam` routes requester addresses to `CHIHomeSAMEntry` targets, while
`hn_sam` routes Home Node traffic to `CHISubordinateSAMEntry` targets. A flat
RN-to-SN map would bypass the Home Node and is not a valid model of CHI
topology. Construction rejects duplicate or width-overflowing NodeIDs,
mismatched physical flit parameters, absent service targets, out-of-range
addresses, overlap within either map, duplicate service opcodes, and transfer
sizes that cannot be represented by CHI's Size field. These are host-side
topology parameters; they do not yet generate routing or arbitration RTL.

## Link-local monitoring

`monitor_chi_rn`, `monitor_chi_rni`, and `monitor_chi_sn` explicitly instrument
one selected endpoint. Each function observes both node-to-ICN and ICN-to-node
paths and uses the supplied link and endpoint parameters to interpret them.

[`monitor.rhdl`](monitor.rhdl) checks the four-state activation handshake in
each direction, permits flits only after the receiver acknowledges activation,
and permits credit returns only while running or on the first deactivation
cycle. Every physical channel has an independent balance checked through the
generic credited-transport checker. Reaching STOP requires all granted credits
to have been consumed or returned.

On a valid flit, the monitor checks:

- that the opcode is a declared encoding and is either `LCrdReturn` or appears
  in the transmitting endpoint's advertised capabilities;
- that ordinary node-transmitted flits carry the node's `SrcID`, and ordinary
  node-received REQ, RSP, and DAT flits carry its `TgtID`;
- that `LCrdReturn` occurs during deactivation and carries a zero `TxnID`;
- that an ordinary REQ has a legal Size encoding with reserved Size bits zero;
- that an ordinary DAT has a `DataID` legal for the configured data width.

For an RN-F advertising the initial coherent capability profile, the same
monitor also enables the bounded coherent requester checker described below.
Opcode-dependent rules outside the implemented transaction profiles and
general ordering remain later stateful-monitor milestones.

## Initial RN-F transaction monitoring

[`coherent-transaction.rhdl`](coherent-transaction.rhdl) implements the first
bounded coherent requester profile. It accepts legal-size `ReadShared` and
`ReadClean` requests, derives their complete DataID set from Size, address, and
DAT width, and rejects unexpected and duplicate packets. A first attempt must
permit retry; the bounded checker recognizes a repeated request by a deasserted
`AllowRetry` and a retained live TxnID. Endpoint logic remains responsible for
associating that repetition with `RetryAck` and `PCrdGrant`. The checker accepts
a matching `CompAck` after the first data packet, as CHI permits, but keeps the
transaction live until both the acknowledgement and the complete DataID set
have arrived. Live requester TxnIDs are otherwise unique and bounded by the
endpoint's `max_outstanding` resource.

The same checker tracks every ordinary incoming SNP transaction by Home Node
and TxnID. A non-forward snoop completes on a matching `SnpResp` or snoop DAT
response. A forward snoop remains live until both the response to the Home Node
and the forwarded `CompData` to the designated requester have appeared. It
checks bounded allocation, duplicate snoop IDs, response association, and the
single-flit DataID/NumDat/Replicate contract.

This substrate deliberately does not decide a cache response, store tags or
data, change line state, arbitrate shared RSP/DAT producers, or implement
coherent writes, evictions, separated read responses, or multibeat snoop data.
It permits retry opcodes and retry-shaped request repetition, while the endpoint
still owns RetryAck/PCrdGrant association. Those policies belong in an RN-F
cache endpoint. HN-F directory, snoop generation, and completion aggregation
are likewise outside this first step.

## Initial non-coherent transaction monitoring

Every `CHINodeParams` and `CHIICNPortParams` supplies an endpoint resource
bound through `~max_outstanding`. The value must be from 1 through CHI's
architectural maximum of 1024 outstanding transactions, and corresponding
node and ICN-port descriptions must agree. It gives stateful monitors a finite
CAM size without introducing a checker-specific profile or a hidden capacity.

The RN-I and SN monitor functions also add the initial transaction checker when
the advertised request, response, and data opcode capabilities are wholly
within the non-coherent subset below. At least one supported request opcode is
required. Capabilities remain the single description of protocol behavior;
`max_outstanding` describes only endpoint capacity.

The requester and subordinate views both check these exact successful flows:

| Operation | Checked packet sequence |
|---|---|
| Read | `ReadNoSnp` then exactly one `CompData` |
| Full write | `WriteNoSnpFull`, `DBIDResp`, exactly one `NonCopyBackWriteData`, then `Comp` |
| Partial write | `WriteNoSnpPtl`, `DBIDResp`, exactly one `NonCopyBackWriteData`, then `Comp` |

The monitor rejects live TxnID reuse, table overflow, a response without the
required transaction phase, DBID reuse while the initial transaction remains
live, write data before its DBID response, mismatched response identifiers,
and completion before write data. The subordinate view also checks the
Home-to-Subordinate `ReturnNID` and `ReturnTxnID` flow for read data and rejects
Direct Write Transfer in this initial subset.

The initial checker requires a transfer size no wider than one physical DAT flit,
`DataID = 0`, `NumDat = 0`, and no replication. It also fixes the currently
unsupported structural options to no multi-request, no ordering requirement,
zero Protocol Credit type, no completion acknowledge, and invalid `TagOp`.
Control Link Credit Return flits remain link-local and do not allocate
transaction state.

## Non-coherent-first scope

[`ram.rhdl`](ram.rhdl) implements `CHIRam`, a finite backing-memory
Subordinate transaction engine. Its `CHISNDecoupled` boundary groups the
ready-valid flows into independently connectable `.req`, `.rsp`, and `.dat`
channel interfaces, so it does not own physical CHI link activation or credit
state. It is not a Home Node and does not implement coherence. A Home Node
performs any required ordering and coherence work before issuing a
non-snoopable transaction to it.

[`home.rhdl`](home.rhdl) implements the first bounded HN-I as
`CHIHNI`. It operates through a `CHIHNIDecoupled` interface containing
ready-valid requester- and subordinate-side channel interfaces, allocates a
Home-owned transaction slot, and translates both transaction-ID namespaces.
REQ, RSP, and DAT can each attach to an independent transport. Reads restore
the RN's
ReturnTxnID and data target. Writes expose the Home slot as the RN-facing DBID,
retain the subordinate's DBID internally, translate write data to that DBID,
and restore the original RN TxnID on completion. Paired transaction translation
is monitored inside the module. Physical CHI link adapters, activation, and
credit state belong to the integrating system, so a NoC can connect channel
transports directly without creating internal CHI links or credit loops. This
is still a non-coherent Home Node, not yet a generated interconnect or coherent
Home Node.

CHI defines both SN-F and SN-I Subordinate Nodes as possible completers for
non-snoopable reads, writes, atomics, exclusive variants, and cache maintenance
operations. SN-F is the normal-memory backing role; SN-I additionally covers
peripherals and explicitly non-coherent memory. `CHIRam` therefore
defaults to an SN-F endpoint while permitting `~kind: CHINodeKind.SNI` for the
same small common Subordinate subset. Selecting SN-F does not make the RAM
coherent: an upstream HN-F owns coherence and sends the SN-F only
non-snoopable traffic.

| Operation | Initial transaction flow |
|---|---|
| Read | Receive `ReadNoSnp` on REQ, read storage, return `CompData` on DAT |
| Full write | Receive `WriteNoSnpFull`, return `DBIDResp`, receive `NonCopyBackWriteData`, commit storage, then return `Comp` |
| Partial write | Receive `WriteNoSnpPtl`, use byte enables when committing `NonCopyBackWriteData`, then return `Comp` |

The initial write path deliberately uses separate `DBIDResp` and `Comp`
responses. CHI permits a combined `CompDBIDResp` before the write data is
sent, but completing only after the RAM update gives `CHIRam` the same
observable storage discipline for reads that follow a completed write.

The initial implementation has these explicit limits:

- One power-of-two, naturally aligned address region containing at least two
  physical data beats and backed by `SyncRam1RW`.
- All supported physical data widths, restricted to transfers that fit in one
  DAT flit.
- A reusable subordinate transaction-slot module bounds outstanding reads and
  writes. Allocation and matched write DAT use ready-valid flows; DBID-sent and
  completion notifications are valid-only events because they cannot be
  backpressured after the corresponding channel transfer.
- DBIDs are occupied slot indices held through completion; only writes waiting
  for DAT retain their original REQ payload in the write-request table.
- No snoopable requests, snoop channel, cache-state tracking, or Home Node
  behavior.
- No atomics, exclusives, cache maintenance, DVM, request retry, direct memory
  transfer, direct cache transfer, direct write transfer, data separation, or
  memory tagging in the first implementation.
- Unsupported opcodes and field combinations are rejected by the advertised
  capabilities and checked by the selected endpoint monitor; they are not silently
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
| `CreditSender(T, max_credits)` | Adapt internal `Decoupled(T)` traffic to `Credited(T, max_credits)`, expose `ready` only when a prior credit is available, and report the credit count |
| `CreditBuffer(T, depth)` | Accept every legal credited transfer into real storage, expose an internal `Irrevocable(T)` dequeue, and report buffered and reserved counts |
| `CreditCounter(max_credits)` | Reusable bounded balance primitive with simultaneous grant/consume support |
| `check_credited(valid, credit, max_credits, balance)` | Apply the generic credit assertions and update caller-owned balance state |
| `monitor_credited(valid, credit, max_credits)` | Allocate balance state and apply `check_credited` for a single monitored channel |

Activation is intentionally outside the generic interface. The CHI-specific
[`flow.rhdl`](flow.rhdl) adapter gates initial credit grants with link
activation, derives deactivation readiness from the existing credit and
reservation counts, and presents internal ready-valid flows. Link Credit
Return flits remain CHI payloads supplied through those flows; Protocol
Credits remain CHI RSP messages and must not be represented by `Credited`.

`CompletionQueue` is not this abstraction. It reserves local response capacity
at a ready-valid request handshake; it neither transports Link Credits nor
turns an externally credited flit channel into a buffered internal flow.

## Planned package layout

| Module | Responsibility |
|---|---|
| [`params.rhdl`](params.rhdl) | Implemented physical wire parameters and derived widths; node and edge capabilities come with role interfaces |
| [`flits.rhdl`](flits.rhdl) | Implemented exact parameterized REQ, RSP, SNP, and DAT payloads and nominal closed-field namespaces |
| [`protocol.rhdl`](protocol.rhdl) | Implemented operation groups, typed Size and NumReq views, Size checking, and DAT packetization |
| [`coherence.rhdl`](coherence.rhdl) | Implemented cache/response states, coherent opcode families, and mandatory RN-F snoop capability set |
| [`link.rhdl`](link.rhdl) | Implemented node capabilities, role-specific credited links, activation, and static connection compatibility |
| [`decoupled.rhdl`](decoupled.rhdl) | Ready-valid channel interfaces recursively composed into RN-I, SN, and HN-I contracts, alongside the full snoop-capable RN and HN shapes |
| [`noc-authoring.rhm`](noc-authoring.rhm) | Pure RN/SN sites and logical CHI connections compiled directly into independent validated REQ, RSP, and DAT channel results with derived route keys |
| [`noc-adapter.rhdl`](noc-adapter.rhdl) | REQ, RSP, and DAT target decoding plus flow-form injection/ejection stages derived from pure channel compilations, without topology or router ownership |
| [`monitor.rhdl`](monitor.rhdl) | Implemented explicit endpoint monitors and link-local activation, credit, opcode, NodeID, Size, and DataID checks |
| [`transaction.rhdl`](transaction.rhdl) | Implemented bounded initial non-coherent TxnID, DBID, response, and single-flit completeness checks; general ordering and retry remain planned |
| [`coherent-transaction.rhdl`](coherent-transaction.rhdl) | Implemented bounded RN-F `ReadShared`/`ReadClean` packet, retry-shaped repetition, paired DVM, and snoop-response lifetime checks |
| [`flow.rhdl`](flow.rhdl) | Node-side and ICN-side RN-F/RN-D/RN-I/SN channel conversion between credited CHI transport and internal ready-valid flows, with CHI activation control |
| [`subordinate-slots.rhdl`](subordinate-slots.rhdl) | Bounded subordinate transaction request/result allocation and write-DAT association over ready-valid flows |
| [`ram.rhdl`](ram.rhdl) | Implemented non-snooping SN-F/SN-I `CHIRam` backing-memory transaction engine |
| [`home.rhdl`](home.rhdl) | Implemented `CHIHNI` transaction bridge for the initial single-flit non-coherent profile |
| [`fabric.rhdl`](fabric.rhdl) | Implemented fabric ports, Home Nodes, services, and separate validated RN/HN SAM metadata; routing, arbitration, and generated topologies remain planned |
| [`main.rhdl`](main.rhdl) | Implemented public facade for the available foundation |

## Implementation order

1. **Complete:** Add and verify `Credited`, `CreditSender`, `CreditBuffer`,
   credit accounting, and their monitors under `rhdl/std`.
2. **Complete:** Define validated physical parameters, every defined
   opcode, exact parameterized flit layouts, and initial protocol classifiers.
3. **Complete:** Define node capabilities, node-role interfaces, link
   activation signals, and static connection legality.
4. **Complete:** Add link-local activation, credit, opcode, conditional-field,
   and NodeID monitoring.
5. **Initial non-coherent subset complete:** Add bounded TxnID/DBID,
   response, and single-flit data-completeness transaction monitors. General
   ordering, retry and Protocol Credits, and other transaction families remain.
6. **Parameters complete:** Define `CHIFabricParams`, Home Node identities, and
   separate requester-to-home and home-to-subordinate System Address Maps.
   Independently validated one-router REQ, RSP, and DAT transports now connect
   the FESVR RN-I to the requester side of its HN-I. The HN-I subordinate side
   connects directly to the local SN-I transaction engine. Generic NoC compilation joins an
   independently authored physical topology, terminal placement, route-class
   set, and routing policy. CHI separately maps NodeIDs to the symbolic
   terminals and derives only target decode and flow adaptation. Pure RN and
   RN-ICN site values declare each transported endpoint's NodeID and
   router attachment once. The logical RN-to-ICN connection expands into the
   directionally correct REQ, RSP, and DAT flows before each plane is compiled
   and validated independently. The system instantiates each generic router
   directly; CHI does not define an aggregate router or own topology or routing
   policy. `connect_chi_rni` connects the corresponding nested CHI fields to
   three independently instantiated router interface arrays through the
   compiled injection and ejection adapters. It neither constructs an
   aggregate router nor owns topology or routing. Each local ejection drives
   allocator availability from its registered ejection queue; physical links
   remain responsible for the targets they attach. SNP remains for a coherent
   profile.
7. **Initial non-coherent path complete:** Implement `CHIRam` over
   `SyncRam1RW` and a bounded `CHIHNI` for single-flit reads and
   writes. Transaction engines expose ready-valid flows; a system adds credited
   link adapters only where its physical boundaries require them. Next, connect
   multiple ports through the generated crossbar and then add multibeat traffic.
8. **Initial RN-F substrate complete:** Add RN-F node/ICN flow adapters,
   mandatory snoop capability validation, cache/response classifiers, and
   bounded `ReadShared`/`ReadClean` plus snoop-response lifetime monitoring.
   Ricket now provides the first clean-only RN-F cache endpoint over this
   substrate. Next, add HN-F directory and snoop aggregation behavior. Optional
   CHI features follow as independently verified vertical slices.

Each milestone requires host elaboration tests, invalid-parameter and invalid
connection tests, generated CIRCT verification, and a cycle-level Verilator
test of the supported transaction flows.

Run `make chi-test` for package boundaries, parameters, flit layouts,
classifiers, link contracts, and invalid connections. Run
`FIXTURES='chi-foundation chi-link chi-monitor chi-transaction chi-transaction-sn chi-ram chi-home' bash tests/backend/run-circt.sh`
for CIRCT lowering and cycle-level classifier, link, and monitor simulations.

## Specification references

- [AMBA CHI Architecture Specification Issue H](https://developer.arm.com/documentation/ihi0050/h/)
- [Introducing AMBA CHI](https://documentation-service.arm.com/static/68590853961937560be90eb2)
- [Arm AMBA specifications](https://www.arm.com/architecture/system-architectures/amba/amba-specifications)
