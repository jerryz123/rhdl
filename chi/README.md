<!-- Defines the planned standalone AMBA CHI package, its non-coherent-first scope, and required generic credit-flow support. -->

# AMBA CHI domain library

`chi/` is the planned standalone AMBA CHI domain library. Like
[`tilelink/`](../tilelink/), it belongs beside RHDL rather than under
`rhdl/std`: CHI parameters, flits, node roles, transaction rules, monitors,
and components are protocol-specific. Only reusable transport mechanisms
belong in the generic standard library.

The initial implementation targets
[AMBA CHI Architecture Specification Issue H](https://documentation-service.arm.com/static/68d13eb5bd7cab51328bee7a).
The selected issue is part of the elaborated interface specialization, not a
runtime signal. Earlier CHI issues have physically incompatible channel
layouts, so connections must require the same supported issue rather than
silently widening both sides to a union of all revisions.

This directory currently records the package contract. It contains no CHI RTL
yet.

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

The planned public facade is `chi/main.rhdl`. Package modules may import the
public `#lang rhdl` surface, protocol-neutral modules under `rhdl/std`, and
other `chi/` modules. They must not import RHDL core, frontend, or backend
implementation modules.

## Non-coherent-first scope

The first executable endpoint will be `CHIRam`, a finite backing-memory
Subordinate Node. It is not a Home Node and does not implement coherence. A
Home Node performs any required ordering and coherence work before issuing a
non-snoopable transaction to this RAM.

Issue H defines both SN-F and SN-I Subordinate Nodes as possible completers for
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
responses. Issue H permits a combined `CompDBIDResp` before the write data is
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
zero, cache maintenance, and optional Issue H features without changing the
meaning of the initial subset. Coherent RN-F/HN-F behavior is a separate
milestone layered above this backing-memory endpoint.

## Credited channel abstraction

CHI channels are not ready-valid. A transmitter asserts a valid flit only
after the receiver has granted a Link Credit, and each transmitted flit
consumes one previously granted credit. Link Credits cover one physical hop.
They are distinct from CHI Protocol Credits, which are transaction messages
used to guarantee that a retried request will be accepted.

The generic standard library should therefore add a minimal protocol-neutral
interface resembling:

```rhombus
interface Credited(T):
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

The interface describes the wire contract; buffering and accounting should be
ordinary reusable modules rather than hidden interface behavior:

| Proposed utility | Responsibility |
|---|---|
| `CreditSender(T, max_credits)` | Adapt internal `Decoupled(T)` traffic to `Credited(T)`, track the received-credit balance, and expose `ready` only when a credit is available |
| `CreditBuffer(T, depth)` | Accept every legal credited transfer into real storage, expose an internal `Irrevocable(T)` dequeue, grant initial credits, and return a credit whenever a slot is freed |
| `CreditCounter(max_credits)` | Reusable bounded balance primitive with simultaneous grant/consume support |
| `monitor_credited(link, max_credits)` | Assert credit underflow, overflow, and conservation without driving either direction |

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
| `params.rhdl` | Issue H wire parameters, node capabilities, Node IDs, address ownership, port descriptions, and legal edge construction |
| `flits.rhdl` | Exact Issue H REQ, RSP, SNP, and DAT payloads and nominal opcode namespaces |
| `protocol.rhdl` | Opcode groups, permitted field values, ID flows, response relationships, and data-flit counts |
| `link.rhdl` | CHI node-role interfaces composed from credited channels, link activation, and static connection compatibility |
| `monitor.rhdl` | Link-credit, channel, endpoint-transaction, ordering, retry, and eventually coherence checks |
| `ram.rhdl` | The non-snooping SN-F `CHIRam` backing-memory endpoint |
| `fabric.rhdl` | Node routing, arbitration, per-hop credit termination and regeneration, and generated crossbar/ring/mesh fabrics |
| `main.rhdl` | Public CHI facade |

## Implementation order

1. Add and verify `Credited`, `CreditSender`, `CreditBuffer`, credit accounting,
   and their monitors under `rhdl/std`.
2. Define Issue H parameters and the exact four flit payload families.
3. Define the minimal SN-F link specialization and static capability checks.
4. Add link-credit and non-coherent request/data/response monitoring.
5. Implement the single-flit `CHIRam` read and write flows over `SyncRam1RW`.
6. Add multi-flit data and the remaining non-coherent operations.
7. Add generated transport fabrics and comprehensive channel monitors.
8. Add coherent Request and Home Node behavior only after the non-coherent
   endpoint and transport foundations are stable.

Each milestone requires host elaboration tests, invalid-parameter and invalid
connection tests, generated CIRCT verification, and a cycle-level Verilator
test of the supported transaction flows.

## Specification references

- [AMBA CHI Architecture Specification Issue H](https://documentation-service.arm.com/static/68d13eb5bd7cab51328bee7a)
- [Introducing AMBA CHI](https://documentation-service.arm.com/static/68590853961937560be90eb2)
- [Arm AMBA specifications](https://www.arm.com/architecture/system-architectures/amba/amba-specifications)
