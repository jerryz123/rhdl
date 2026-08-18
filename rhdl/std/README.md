<!-- Documents RHDL's optional protocols and reusable circuit-generator library. -->

# RHDL standard library

`rhdl/std` contains opt-in reusable hardware vocabulary written against the
public `#lang rhdl` language. It is not another language profile and adds no
core IR, elaboration, or backend behavior. Its dependency contract is listed
in [`../README.md`](../README.md).

## Typed decode patterns

[`decode/pattern.rhdl`](decode/pattern.rhdl) defines `Pattern`, an immutable
host-side bit cube over two `HardwareLiteral` values:

```rhombus
import:
  lib("rhdl/std/decode/pattern.rhdl") open

bundle Instruction():
  opcode: Bits(4)
  operands: Vec(2, Bits(4))

def instruction_pattern = pattern(Instruction()):
  opcode: bits(0b1010, 4)
  operands: pattern(Vec(2, Bits(4)), [bits(2, 4), _])
```

Within `pattern(T)`, a `HardwareLiteral` constrains the whole field, `_` leaves
the whole field unconstrained, and a nested `Pattern` preserves partial care.
Record fields are named, vector elements are positional, and both forms recurse
through nested aggregates. The underscore is host pattern syntax: it neither
creates hardware nor denotes a runtime X value.

`partial_pattern(T)` is the record form for sparse control descriptions. Every
listed field follows the same literal/nested-pattern rules, while omitted
fields are unconstrained:

```rhombus
def add_control = partial_pattern(Control()):
  result_select: ResultSelect.Arithmetic
  subtract: Bool(#false)
```

Unknown and duplicate fields remain errors.

`as_pattern(value)` normalizes values accepted by decode consumers: an
existing `Pattern` is retained, while a `HardwareLiteral` becomes a fully
cared exact pattern. Domain adapters can therefore accept both forms without
reimplementing packed care-mask construction.

The lower-level `Pattern(~value: ..., ~care: ...)` constructor remains useful
for partially cared scalar fields and extension libraries. A care bit of one
makes the corresponding value bit significant; zero makes it a don't-care.
`value` and `care` must have exactly equal hardware types, not merely equal
packed widths. Any `HardwareLiteral` type works, including `Bits`, `Bool`,
enums, `OneHot`, extension-defined flat data, and recursively nested records
and vectors. The generic `literal(T, packed_value)` form remains a low-level
escape hatch for arbitrary typed packed images; canonical aggregate examples
use named fields instead.

`Pattern` stores the common `type` and `width`, the packed `care_bits`, and the
canonical `value_bits = value & care`. It is ordinary host data rather than a
`HardwareLiteral`: declaring, comparing, or passing a pattern as a generator
parameter emits no hardware and it cannot be connected to a port.

The host-only relations support decode-table validation:

- `pattern.matches(literal)` tests membership.
- `pattern.overlaps(other)` reports whether two cubes share any value.
- `pattern.subsumes(other)` reports whether every value matched by `other` is
  also matched by `pattern`.

Pattern don't-cares describe static matching or optimization freedom. They are
never runtime unknown or X values. `Pattern` remains neutral host data between
input matching and partially specified decode outputs.

[`decode/pattern-value.rhdl`](decode/pattern-value.rhdl) is the separate output
consumer. `pattern_value(pattern)` materializes one hardware member of the
cube: cared bits retain `value_bits`, while uncared bits receive synthesis
freedom from `dont_care`. Keeping this policy out of `Pattern` preserves its
host-only architecture and allows future matching or optimization consumers
to choose different interpretations.

## Typed decode generation

[`decode.rhdl`](decode.rhdl) is the public facade for `Pattern`, `DecodeCase`,
`DecodeTable`, and `DecodeGen`. A table requires at least one case, one
explicit default output pattern, exact common input types, and exact common
output types. Input cubes may not overlap: the relation has no hidden row
priority.

```rhombus
import:
  lib("rhdl/std/decode.rhdl") open

def cases = decode_groups(Control()):
  [add_input]:
    operation: Operation.Add
    write: Bool(#true)

  [sub_input]:
    operation: Operation.Subtract
    write: Bool(#true)

def decoder = DecodeGen(cases, ~default: default_control)

circuit ControlPath():
  input instruction: Instruction()
  output control: Control()

  control <== decoder(instruction)
```

`DecodeGen` is an ordinary callable host value and can be passed as a circuit
parameter. Construction validates and retains the typed relation; calling the
generator always emits one typed `rtl.decode` operation. The standard library
does not choose a physical implementation or invoke external tools. Raw
`hw_decode` emits the same core operation directly.

The CIRCT backend requires the `espresso` executable whenever a design contains
`rtl.decode`. It partitions output bits by their zero, one, or don't-care
default, minimizes each nonempty partition, merges identical input products,
and emits shared product-term ANDs and per-output ORs. There is no fallback or
frontend optimizer configuration. `ValidDecodeGen` therefore keeps validity
and payload in one semantic relation even though their different defaults
normally place them in separate minimization runs.

Input and output patterns may use different scalar, aggregate, or
extension-defined hardware types. The core operation preserves output
don't-cares until backend lowering, where Espresso uses them while choosing a
concrete cover. See [`../../examples/std/decode.rhdl`](../../examples/std/decode.rhdl)
for an aggregate input/output example.

`decode_groups(T)` constructs ordinary `DecodeCase` values while allowing one
sparse record output pattern to serve several input patterns. Its optional
`~input` host function adapts domain descriptions into `Pattern` values without
making the decode library depend on that domain. A bracketed row enumerates its
inputs directly. A `group inputs:` row accepts any nonempty host `List`, so a
domain library can name and compose instruction families without wrapping the
result pattern in a one-off constructor. `ValidDecodeGen(cases)` treats the
cases as a partial mapping and returns `DecodeResult(T)`, asserting `valid` for
matches and leaving the unmatched value as synthesis freedom.

Decode relations compose as ordinary case lists before constructing a
`DecodeGen`. Row extension is list concatenation; the final `DecodeTable`
rejects overlaps and inconsistent types. `lift_decode_inputs(cases, lift)`
explicitly embeds every input cube into a wider type while retaining its output
cube. The lift function returns the replacement input `Pattern`, so added input
fields can be cared or unconstrained without an inferred packing policy.

`zip_decode_cases(left, right, combine)` forms an output product. Both inputs
must contain exactly the same input cubes, although their row order may differ.
The combiner receives the two output patterns and returns one aggregate output
pattern; nested patterns preserve each side's care bits. Missing, extra, or
duplicate counterparts are errors. This deliberately avoids implicit priority,
sparse joins, or input-partition refinement:

```rhombus
def extended_inputs = lift_decode_inputs(
  base_cases,
  fun (opcode):
    partial_pattern(ExtendedInstruction()):
      opcode: opcode
)

def combined_outputs = zip_decode_cases(
  base_cases,
  custom_cases,
  fun (base, custom):
    pattern(CombinedControl()):
      base: base
      custom: custom
)
```

[`../../examples/std/decode-composition.rhdl`](../../examples/std/decode-composition.rhdl)
shows all three independent extensions in one executable example: concatenated
rows, zipped output fields, and lifted input fields.

## Ready-valid protocols

Import the protocol family directly:

```rhombus
import:
  lib("rhdl/std/ready-valid.rhdl") open
```

| Interface | Contract |
|---|---|
| `Valid(T)` | Every asserted cycle carries one payload; no backpressure |
| `DecoupledCtrl()` | Offer/accept control; transfer occurs when `ready` and `valid` are asserted |
| `IrrevocableCtrl()` | A decoupled offer cannot be withdrawn before transfer |
| `Decoupled(T)` | Payload-bearing decoupled transfer without a pre-transfer stability guarantee |
| `Irrevocable(T)` | A valid payload remains asserted and stable until transfer |

`Decoupled` refines `DecoupledCtrl`; `Irrevocable` refines
`IrrevocableCtrl`, which transitively refines `DecoupledCtrl`.
`Irrevocable(T)` also declares support for the weaker `Decoupled(T)` contract.
The temporal difference is currently documentation rather than generated
protocol assertions.

`fire(endpoint)` accepts any endpoint supporting `DecoupledCtrl` and
returns `endpoint.valid and endpoint.ready`.

Ready-valid flow helpers classify protocols through the same nominal
refinement and `supports` relation used by interface connections. A differently
named refinement is accepted and normalized to its canonical `Decoupled(T)`,
`Irrevocable(T)`, or `Valid(T)` contract; an unrelated declaration is rejected
even if it reuses one of those display names. Control-only helpers additionally
require the exact payloadless control-plane member shape, so a payload-bearing
protocol is not silently treated as a `Ctrl` flow.

## Credited transport

[`credited.rhdl`](credited.rhdl) defines `Credited(T, credit_limit)` for a
bounded single-hop payload channel. The transmitter drives `valid` and `bits`;
the receiver returns one credit with each asserted `credit` pulse. Every valid
cycle transfers one payload and consumes a credit received on an earlier edge.
There is no ready signal, and a same-edge credit cannot authorize a transfer
from a zero pre-edge balance.

The positive host `credit_limit` is a semantic interface parameter rather than
a wire field, and connections require the same limit. Calling
`monitor_credited(endpoint)` explicitly instruments one endpoint: every
transfer must own a prior credit, grants must remain within the configured
limit, and the tracked balance must stay in range. Protocol monitors that own
several channel balances can call
`check_credited(valid, credit, credit_limit, balance)` to reuse the same checks
and update rule without allocating multiple identically named registers.

[`flow/credit.rhdl`](flow/credit.rhdl) provides the transport adapters.
`CreditSender(T, credit_limit)` accepts `Decoupled(T)`, tracks returned
credits, and emits credited traffic only while its registered balance is
nonzero. `CreditBuffer(T, depth)` owns the receiver capacity, accepts every
legal credited transfer into a pipelined queue, and emits `Irrevocable(T)`.
Its `grant_enable` input controls new grants without revoking credits already
held remotely. The buffer initially grants empty capacity one credit per cycle
and recycles a credit when an item leaves its egress.

`credit_sender(credit_limit)` and `credit_buffer(depth)` are configured unary
flow stages. They make a credited hop compose as `Decoupled -> CreditSender ->
Credited -> CreditBuffer -> Irrevocable`; a source supplies the payload and
protocol through `|>`. Mapping, arbitration, and routing stay in the
ready-valid domain between hop boundaries rather than acquiring duplicate
credited variants. `CreditCounter` is the shared bounded accounting circuit
used by the adapters.

## Generic interconnect parameters

[`interconnect.rhdl`](interconnect.rhdl) owns protocol-neutral host-side sets
used to describe interconnect endpoints. `IdRange(start, end)` is a nonempty
half-open range of nonnegative IDs. `AddressSet(base, mask)` describes every
nonnegative address formed by varying the one bits of `mask`; canonical bases
keep those bits clear. `TransferSizes(min_bytes, max_bytes)` is an inclusive
power-of-two byte-size range. These are immutable elaboration-time values and
do not create hardware. `IdRange.fits_unsigned_width(width)` and
`AddressSet.fits_unsigned_width(width)` report whether every represented value
fits a nonnegative unsigned host width. Both set types provide `overlaps` for
host-time topology validation. `allocate_id_ranges` assigns exact contiguous
global ranges to a nonempty list of local ranges and returns reversible
`IdRangeMap` records without requiring the local ranges to begin at zero.

## Bit-vector alignment

[`bits.rhdl`](bits.rhdl) provides reusable alignment operations over hardware
`Bits` values:

```rhombus
import:
  lib("rhdl/std/bits.rhdl") open

def aligned = is_aligned(address, 8)
def base = align_down(address, 8)

fun bank_index_width(bank_count :: Pow2Int):
  alignment_bits(bank_count)
```

`Pow2Int` composes Rhombus's built-in `PosInt` annotation with the
power-of-two predicate. Annotated generator parameters remain ordinary
integers, so host arithmetic and specialization use the original value without
wrapping.
`power_of_two(value)` is the corresponding predicate for conditional queries;
it returns false for non-integers, zero, negative integers, and other
non-power-of-two values.
`unsigned_value_count(width)` returns the number of distinct values represented
by a nonnegative unsigned width, including one value for width zero.
The alignment is a positive power-of-two host parameter and must fit the
value's width. `is_aligned` checks that the corresponding low bits are zero;
`align_down` clears them while preserving the input width. Alignment to one is
the identity for `align_down` and always true for `is_aligned`.
`alignment_bits(alignment)` exposes the exact host-side base-two width for
protocols and generators that need to size or remove those low bits.

## Scoreboard

[`scoreboard.rhdl`](scoreboard.rhdl) provides a reusable occupancy bitmap with
one nonbackpressured `Valid` set operation, one nonbackpressured `Valid` clear
operation, and a combinational `busy` bitmap:

```rhombus
import:
  lib("rhdl/std/flow.rhdl") open
  lib("rhdl/std/scoreboard.rhdl") open

inst hazards(Scoreboard(32))
def reserve_filter = filter_valid(operation => operation.reserve)
def reserve_index = map_valid(operation => operation.destination)
def completion_index = map_valid(completion => completion.tag)
(reservations |> reserve_filter |> reserve_index) <=> hazards.set
(completions |> completion_index) <=> hazards.clear
def permitted = requests |> gate_flow(!scoreboard_busy(32, hazards.busy, source))
```

The power-of-two entry count must be at least two. Reset empties the scoreboard.
The `busy` output includes current-cycle operations, so consumers see a set or
clear without an extra cycle; clear wins when both operations address the same
entry. Assertions reject setting an occupied entry and clearing a free entry,
except for a simultaneous opposite operation on that entry. The component has
no reserved-entry policy: callers that treat an index such as register zero as
permanently free must filter that policy at their own boundary.

## Fixed-latency synchronous RAM

[`read-write.rhdl`](read-write.rhdl) defines
`ReadWritePort(address_width, T, n)`. `T` is one data-lane type and `n` is the
number of lanes. Its single `request` flow carries a `Bits(address_width)`
address, a read/write selector, `Vec(n, T)` data, and a `Bits(n)` mask. The
`response` flow returns `Vec(n, T)`. Request data and mask are meaningful only
for writes; response data is meaningful only for reads.

[`sync-ram.rhdl`](sync-ram.rhdl) applies that interface to a word-indexed shared
1RW physical memory. `SyncRam1RW(depth, T, n)` stores `n` lanes of `T` per
word, and each mask bit controls the corresponding lane:

```rhombus
import:
  lib("rhdl/std/read-write.rhdl") open
  lib("rhdl/std/sync-ram.rhdl") open

inst tags(SyncRam1RW(64, Bits(20), 1))
tags.port.request.valid <== lookup ||| update
tags.port.request.bits <== ReadWriteRequest(6, Bits(20), 1):
  address: index
  write: update
  data: vec(new_tag)
  mask: bits(1, 1)
```

Every asserted request is accepted; there is no readiness or retry state. A
read produces `response.valid` exactly one cycle later. Writes produce no
response, and response bits are meaningful only while valid is asserted.
Addresses are word indices. A one-lane RAM uses `n = 1`; asserting its sole
mask bit writes the complete `T` value.

The wrapper maps each lane to a raw-memory mask granularity of `T.bit_width()`.
It neither initializes storage nor changes the raw primitive's behavior for
dynamically out-of-range addresses. A separate 1R1W wrapper remains deferred
until its read-during-write collision policy is explicit.

Use raw `sync_mem` when physical port shape or timing must remain explicit.
Use this wrapper for fixed-latency internal arrays whose callers naturally
produce `Valid` accesses. Use `SimpleMemoryRam` when byte addressing,
backpressure, ordered request/response transactions, or multiple outstanding
operations are required.

## Memory transactions

[`simple-memory.rhdl`](simple-memory.rhdl) defines `SimpleMemory(address_width,
data_bytes)`, a deliberately small requester/responder protocol for connecting
a processor or host shim to memory-like hardware:

```rhombus
import:
  lib("rhdl/std/simple-memory.rhdl") open

interface memory(SimpleMemory(32, 8), ~role: requester)
```

`address_width` is the width of the full byte address. `data_bytes` is the
number of bytes in each transfer, must be a power of two, and determines both
the `Bits(data_bytes * 8)` data width and the `Bits(data_bytes)` write-mask
width. A set mask bit enables the corresponding byte lane on a write; the mask
is ignored on reads. An all-zero write mask is therefore a legal no-op write.

`SimpleMemoryReq` bundles `address`, `write`, `data`, and `mask`.
`SimpleMemoryResp` contains `data`, which is meaningful only for reads.
`SimpleMemory` composes these payloads as oppositely directed nested
`Irrevocable` channels: `request.valid`, `request.ready`, and `request.bits`
carry requests, while the corresponding `response` members carry responses.
The nested channels reuse the standard ready-valid compatibility and transfer
semantics. Their irrevocable contract requires the producer to hold an offer
and its payload stable until transfer. Import `ready-valid.rhdl` directly to
use the ordinary `fire(port.request)` and `fire(port.response)` helpers for
each channel.

Multiple accepted requests may await responses. Every request, including a
write, produces exactly one response, and responses must occur in request
order. This ordering rule relates the two channels, so it remains a behavioral
`SimpleMemory` contract rather than a property of either `Irrevocable` channel.
Strict ordering avoids transaction IDs while allowing pipelined responders.

Every request address must be aligned to `data_bytes`. The protocol retains a
full byte address so it composes directly with processor addresses and software
images; it does not silently discard low bits. Import
[`bits.rhdl`](bits.rhdl) and use `is_aligned(address, data_bytes)` for a
hardware alignment check. The interface type validates its host parameters
during construction.
See [`../../examples/std/simple-memory-flow.rhdl`](../../examples/std/simple-memory-flow.rhdl)
for a bidirectional adapter that applies the ordinary `queue` and `pipe`
helpers independently to the request and response channels.

[`simple-memory/ram.rhdl`](simple-memory/ram.rhdl) defines
`SimpleMemoryRam(address_width, data_bytes, size_bytes, ~base_address: 0)`, a
finite concrete responder backed by one byte-masked shared 1RW synchronous
memory port. It accepts one operation per cycle while either of its two
outstanding slots remains, gives reads and writes equal response latency, and
queues their responses strictly in request order. Reset clears pipeline and
queue state but does not initialize storage. The configured region must fit
the address width, and invalid or misaligned requests are not accepted because
the deliberately small response payload has no error indication. Internal
assertions check that the outstanding count remains bounded and that every
transferred response corresponds to an outstanding request.

## Flow-control circuits

[`flow.rhdl`](flow.rhdl) re-exports the independently importable generators
under [`flow/`](flow/):

| Valid-only generator | Behavior |
|---|---|
| `ValidPipe(T, stages)` | Fixed-latency registered valid/payload pipeline with no backpressure |

| Transaction generator | Behavior |
|---|---|
| `CompletionQueue(Request, Response, depth)` | Reserves response capacity at a ready-valid request handshake, emits a nonstallable issue, and buffers the matching nonstallable completion |

| Credited transport generator | Behavior |
|---|---|
| `CreditSender(T, credit_limit)` | Converts ready-valid ingress to credited transport using only previously registered credits |
| `CreditBuffer(T, depth)` | Owns receiver capacity, returns credits, and converts credited transport to an irrevocable egress |
| `CreditCounter(limit)` | Tracks a bounded resource balance with simultaneous increment and decrement |

| Allocation generator | Behavior |
|---|---|
| `GreedyMatcher(inputs, outputs)` | Fixed-priority maximal matching over an input-major request matrix |

| Payload generator | Control-only generator | Behavior |
|---|---|---|
| `Pipe(T, stages)` | `CtrlPipe(stages)` | Registered elastic pipeline with stable output under backpressure |
| `Queue(T, depth)` | `CtrlQueue(depth)` | Configurable FIFO with occupancy count |
| `Arbiter(T, n)` | `CtrlArbiter(n)` | Fixed-priority, index-zero-first arbitration |
| `RRArbiter(T, n)` | `CtrlRRArbiter(n)` | Fair round-robin arbitration |
| `Demux(T, n)` | `CtrlDemux(n)` | Selected one-to-many routing with invalid-selector blocking |
| `GrantDemux(T, outputs)` | -- | Optional-one-hot grant routing to ready-valid outputs |
| `GrantMerge(T, inputs)` | -- | Optional-one-hot grant selection from ready-valid inputs |
| `GrantCrossbar(T, inputs, outputs)` | -- | Grant-controlled one-to-one ready-valid payload traversal; configured `grant_crossbar(outputs, ~grants)` stage |
| `Join(T, n)` | `CtrlJoin(n)` | Atomic join that never partially consumes inputs |
| `Broadcast(T, n)` | `CtrlBroadcast(n)` | Buffered exactly-once delivery tracked independently per recipient |
| `AtomicFork(T, n)` | `CtrlAtomicFork(n)` | Combinational fanout where every recipient transfers together or none do |

Import the aggregate when several components are needed:

```rhombus
import:
  lib("rhdl/std/flow.rhdl") open

inst buffered(Queue(Bits(8), 4, ~pipe: #true, ~flow: #false))
```

Every lowercase flow-stage helper is configured first and receives its input only
through Rhombus `|>`. This makes every stage an ordinary unary host function:

```rhombus
def buffered = ingress |> queue(4, ~pipe: #true) |> pipe(2)
egress <=> buffered
```

With a concrete endpoint source, each operation connects immediately and
returns its far endpoint shape. A disconnected topology begins with its
payload or protocol type exactly once and returns an ordinary `InterfaceHandle`:

```rhombus
def path = Request()
           |> pipe(1)
           |> queue(4)
def buffered = ingress |> path
```

Use an explicit `Decoupled(T)` or `Irrevocable(T)` seed when the disconnected
path must retain that exact contract. Later stages infer the protocol and
payload from the preceding endpoint or handle; they never repeat it.

`InterfaceTransformResult` is the generic interface layer's single dependent
static-information rule behind these operations. A statically known endpoint
produces the operation's connected shape, an endpoint array produces the
cardinality-changing connected shape, and a type seed or existing handle
produces a handle. A conservative topology annotation covers generic
instance-member expressions. Consequently `.bits`, `[0].bits`, array
destructuring, and handle `.right` remain available under `use_static` without
corrective `:: Endpoint` annotations.

Fan-in helpers take an ordinary host `Array`. `rr_arbiter()` infers the input
count from a connected array. A disconnected topology states its protocol once
and its cardinality in the configured arbiter:

```rhombus
def selected = Array(first_request, second_request)
               |> rr_arbiter()
               |> pipe(1)

def selector = Request()
               |> rr_arbiter(2)
               |> pipe(1)
```

Use an explicit `RRArbiter` instance when its `chosen` output is needed.
Inputs must be a nonempty array of mutually compatible `Decoupled` or
`Irrevocable` endpoints.

`atomic_fork` returns an indexable array of `Decoupled` endpoints and permits a
transfer only when every output can accept it. This is useful when one logical
transaction must atomically update multiple downstream flows. In contrast,
`Broadcast` stores per-recipient delivery state so recipients may accept the
same item in different cycles.

`map_flow(payload => expression)` configures an inline payload mapping while
forwarding valid and ready. The binder retains precise bundle field
information, and the result type is inferred from the body. The colon form
supports multiline mappings. For an `Irrevocable` input, the body must remain
stable while an offer is stalled; transformations that observe changing
sidebands should start from or produce an explicit `Decoupled` stage instead:

```rhombus
def tagging:
  map_flow(payload => TaggedRequest()):
    request: payload
    processor: Bool(#false)

def tagged = ingress |> tagging
```

`map_valid(payload => expression)` is the corresponding inline payload map for
`Valid` flows. `filter_valid(payload => predicate)` drops asserted events whose
predicate is false, and `fork_valid(n)` copies every retained event to all `n`
outputs in the same cycle. None adds an instance or a readiness path:

```rhombus
def enabled_filter = filter_valid(request => request.enabled)
def request_map = map_valid(request => translate(request))
def mapped = issued |> enabled_filter |> request_map
def copies = mapped |> fork_valid(2)
```

`to_valid()` explicitly converts a `Decoupled(T)` or `Irrevocable(T)` flow into
same-cycle `Valid(T)` events. It permanently asserts input readiness and adds
neither storage nor hierarchy. Use it only where losing downstream
backpressure is intentional:

```rhombus
source |> to_valid()
  |> eject_flow(~valid: sink_valid, ~bits: sink_bits)
```

The flow facade retains `inject_flow(protocol, ...)` and `eject_flow(...)` as
convenience aliases for the interface layer's generic `inject_interface` and
`eject_interface` boundaries. Each named binding corresponds to a declared
protocol member. A `Decoupled(T)` boundary therefore names `~valid`, `~bits`,
and `~ready`, while a `Valid(T)` boundary names only `~valid` and `~bits`:

```rhombus
inject_flow(
  Decoupled(Request()),
  ~valid: source_valid,
  ~bits: source_bits,
  ~ready: source_ready
)
  |> pipe(1)
  |> map_flow(request => translate(request))
  |> eject_flow(~valid: sink_valid, ~bits: sink_bits, ~ready: sink_ready)
```

On injection, forward arguments are readable hardware values and return-path
arguments are driveable places. Ejection reverses those requirements: forward
arguments are driveable places and return-path arguments are readable values.
Nested interface members use `flow_fields(~field: value, ...)` to group their
named leaves. The helpers work from declared member directions, including
custom protocols and control-only interfaces; they add neither storage nor
hierarchy.
Neither boundary helper changes the protocol; use an explicit transformation
such as `to_valid()` before ejection when the circuit-side contract differs.

`filter_flow(payload => predicate)` consumes an offered token without producing
an output when the hardware predicate is false. Its input is ready for a
rejected token regardless of downstream backpressure. `gate_flow(enabled)`
instead blocks both input readiness and output validity while
disabled, preserving the token upstream. Because either decision may observe
live sideband state, both helpers conservatively return `Decoupled` even when
their input is `Irrevocable`; a following `pipe` can re-establish stability:

```rhombus
def stable = buffered
             |> filter_flow(payload => !squash)
             |> gate_flow(!hazard)
             |> pipe(1)
```

`demux_flow(n, payload => selector)` is a one-to-many routing stage whose
selector is derived from the offered payload. It retains the input protocol and
returns an array of `n` endpoints; an out-of-range selector blocks the input.
This distinguishes exclusive routing from `atomic_fork(n)`, which requires
every output to accept the same item.

`GreedyMatcher(inputs, outputs)` maps an input-major Boolean request matrix to
a Boolean one-to-one grant matrix. Lower input indices have priority, and each
input takes its lowest still-unclaimed requested output. The result is maximal
but not fair; readiness and the application-specific meaning of rows and
columns remain outside the matcher.

`GrantDemux(T, outputs)` routes one input according to an optional-one-hot grant
row, while `GrantMerge(T, inputs)` selects one input according to an
optional-one-hot grant column. A zero grant blocks the corresponding flow;
asserting multiple bits violates each primitive's contract.

`GrantCrossbar(T, inputs, outputs)` structurally composes one `GrantDemux` per
input with one `GrantMerge` per output around an externally generated
one-to-one grant matrix. It does not perform routing, arbitration, or
buffering. Because grants may change while an output is stalled, all three
primitives expose `Decoupled` outputs; add a queue or pipe when the consumer
requires an irrevocable pending offer. The configured
`grant_crossbar(output_count, ~grants)` stage infers the payload and input
count from its input array and returns an output endpoint array:

```rhombus
(buffered_inputs
 |> grant_crossbar(output_count, ~grants: allocator.grants)
) <=> egress
```

`zip_flow(left_payload, right_payload => expression)` atomically consumes a
two-element source array and maps the pair to one inferred result type. Neither
input can transfer by itself:

```rhombus
def response_join = Array(Response(), Bool)
  |> zip_flow(response, owner):
    TaggedResponse():
      response: response
      owner: owner

def tagged_response = Array(memory_response, owners) |> response_join
```

Disconnected results are ordinary `InterfaceHandle` values from the frontend
interface layer, not a flow-specific graph. Inline adapters use local
`interface_link` wires and add no module hierarchy. Handles and sinks remain
linear; configured unary functions are reusable and construct a fresh stage on
each application.

`parallel` combines independent handles into one array-shaped handle, or
independent terminated sinks into one array-shaped sink. This lets fan-in,
buffering, fanout, heterogeneous projections, and their destinations form one
path. A call cannot mix handles and sinks:

```rhombus
def request_path:
  Array(Request(), Request())
  |> parallel(tag_fesvr, tag_processor)
  |> rr_arbiter()
  |> pipe(1)
  |> atomic_fork(2)
  |> parallel(
       (TaggedRequest() |> map_flow(tagged => tagged.request))
         <=> memory_request,
       (TaggedRequest() |> map_flow(tagged => tagged.processor))
         <=> owner_queue.ingress
     )

Array(fesvr_request, processor_request) |> request_path
```

The arrow form is especially useful for routing in the middle of a chain:

```rhombus
buffered
|> demux_flow(2, tagged => tagged.processor)
|> parallel(
     (Irrevocable(TaggedResponse()) |> map_flow(tagged => tagged.response))
       <=> fesvr_response,
     (Irrevocable(TaggedResponse()) |> map_flow(tagged => tagged.response))
       <=> processor_response
   )
```

The endpoint, handle, and sink shapes must match recursively. A
`handle <=> endpoint` branch closes that handle's output immediately while
leaving its input available to the surrounding `parallel`. `zip_flow` is
deliberately binary; homogeneous multi-input rendezvous remains the role of
`Join(T, n)`.

`valid_pipe(stages)` infers its eventual input payload, instantiates in the
ambient `sync_circuit` domain, and delays every asserted cycle by exactly the
configured number of stages. There is no readiness or pending-offer state.

`queue(depth, ...)` and `pipe(stages)` similarly infer their eventual
ready-valid input. `Pipe` and a non-flowing `Queue` produce an `Irrevocable`
endpoint; `queue(depth, ~flow: #true)` remains `Decoupled` because it may expose
its input offer directly. Use an explicit `Queue` instance when its `count`
output or instance handle is needed.

The corresponding `ctrl_queue(depth)`, `ctrl_pipe(stages)`, and
`ctrl_atomic_fork(n)` configured helpers accept `DecoupledCtrl` or
`IrrevocableCtrl` sources and retain the same dependent static information
without manufacturing a dummy payload. A disconnected control topology starts
with `DecoupledCtrl()` or `IrrevocableCtrl()`. Control-only streams carry
indistinguishable tokens; they are not a detachable control half of a
payload-bearing transaction. `CtrlPipe` and a non-flowing `CtrlQueue` produce
`IrrevocableCtrl`; flow-through queues remain `DecoupledCtrl`.

`Queue(T, depth)` defaults to a registered, non-flow-through FIFO.
`~pipe: #true` permits enqueue when a full queue dequeues in the same cycle;
`~flow: #true` lets an empty queue present its input directly. `count` has type
`Bits(index_width(depth + 1))`. Current queues use asynchronous reads, and
depths greater than one compose two `Counter(depth)` pointer instances. Those
queues assert that occupancy stays within the configured depth. Round-robin
arbiters similarly assert that their rotating priority remains in range.

`CompletionQueue(Request, Response, depth)` couples a ready-valid request path
to a nonbackpressured implementation. Each request handshake reserves one
slot and appears immediately on the `Valid` `issue` endpoint. The implementation
must later produce exactly one `Valid` `completion`; completed responses emerge
in arrival order through the `Irrevocable` `response` endpoint. Assertions
detect unreserved completions, unavailable completion slots, and reservation
counts outside the configured depth.

See [`../../examples/std/flow-control.rhdl`](../../examples/std/flow-control.rhdl) for
pipe, queue, fixed-priority arbitration, and chaining, and
[`../../examples/std/flow-topology.rhdl`](../../examples/std/flow-topology.rhdl) for
round-robin arbitration, demux, join, atomic fork, payload mapping, and
broadcast. The parallel token-only family is materialized in
[`../../examples/std/ctrl-flow.rhdl`](../../examples/std/ctrl-flow.rhdl).

## Counter

The bounded counter is independent of ready-valid flow control:

```rhombus
import:
  lib("rhdl/std/counter.rhdl") open

inst timer(Counter(10))
timer.enable <== tick
expired <== timer.wrap
```

`Counter(n)` synchronously resets to zero and, while enabled, counts through
the `n` states from zero to `n - 1`. `value` has type
`Bits(index_width(n))`. `wrap` is asserted during an enabled cycle at
`n - 1`, immediately before the next edge returns the value to zero. An
internal assertion checks that the state remains within that range.
