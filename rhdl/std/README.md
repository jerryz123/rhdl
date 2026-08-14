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

def decoder = DecodeGen(
  [DecodeCase(add_input, add_control),
   DecodeCase(sub_input, sub_control)],
  ~default: default_control
)

circuit ControlPath():
  input instruction: Instruction()
  output control: Control()

  control <== decoder(instruction)
```

`DecodeGen` is an ordinary callable host value and can be passed as a circuit
parameter. Calling it during elaboration creates one typed `rtl.decode`
operation; it does not invoke Espresso or pre-minimize the relation. Input and
output patterns may use different scalar, aggregate, or extension-defined
hardware types. CIRCT carries output freedom to downstream synthesis, which
is responsible for selecting and optimizing a concrete implementation. See
[`../../examples/decode.rhdl`](../../examples/decode.rhdl) for an aggregate
input/output example.

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

## Memory transactions

[`memory-port.rhdl`](memory-port.rhdl) defines `MemoryPort(address_width,
data_bytes)`, a deliberately small requester/responder protocol for connecting
a processor or host shim to memory-like hardware:

```rhombus
import:
  lib("rhdl/std/memory-port.rhdl") open

interface memory(MemoryPort(32, 8), ~role: requester)
```

`address_width` is the width of the full byte address. `data_bytes` is the
number of bytes in each transfer, must be a power of two, and determines both
the `Bits(data_bytes * 8)` data width and the `Bits(data_bytes)` write-mask
width. A set mask bit enables the corresponding byte lane on a write; the mask
is ignored on reads. An all-zero write mask is therefore a legal no-op write.

Requests use `request_valid`/`request_ready`; responses use
`response_valid`/`response_ready`. The requester must hold every request field
stable until the request transfers, and the responder must hold response data
stable until the response transfers. At most one accepted request may await a
response, and every request, including a write, produces exactly one response.
`response_data` is meaningful only for reads. This simple ordering contract
avoids IDs, bursts, and multiple outstanding transactions.

Every request address must be aligned to `data_bytes`. The protocol retains a
full byte address so it composes directly with processor addresses and software
images; it does not silently discard low bits. Use
`memory_address_aligned(address, data_bytes)` for a hardware alignment check.
The interface type validates its host parameters during construction.

## Flow-control circuits

[`flow.rhdl`](flow.rhdl) re-exports the independently importable generators
under [`flow/`](flow/):

| Payload generator | Control-only generator | Behavior |
|---|---|---|
| `Pipe(T, stages)` | `CtrlPipe(stages)` | Registered elastic pipeline with stable output under backpressure |
| `Queue(T, depth)` | `CtrlQueue(depth)` | Configurable FIFO with occupancy count |
| `Arbiter(T, n)` | `CtrlArbiter(n)` | Fixed-priority, index-zero-first arbitration |
| `RRArbiter(T, n)` | `CtrlRRArbiter(n)` | Fair round-robin arbitration |
| `Demux(T, n)` | `CtrlDemux(n)` | Selected one-to-many routing with invalid-selector blocking |
| `Join(T, n)` | `CtrlJoin(n)` | Atomic join that never partially consumes inputs |
| `Broadcast(T, n)` | `CtrlBroadcast(n)` | Buffered exactly-once delivery tracked independently per recipient |

Import the aggregate when several components are needed:

```rhombus
import:
  lib("rhdl/std/flow.rhdl") open

inst buffered(Queue(Bits(8), 4, ~pipe: #true, ~flow: #false))
```

Lowercase helpers form typed endpoint pipelines when intermediate instance
handles are unnecessary:

```rhombus
def buffered = ingress |> queue(_, 4, ~pipe: #true) |> pipe(_, 2)
egress <=> buffered
```

`queue` and `pipe` infer payload type from a `Decoupled` or `Irrevocable`
endpoint, instantiate in the ambient `sync_circuit` domain, connect the input,
and return the downstream endpoint with static interface information intact.
`Pipe` produces an `Irrevocable` endpoint. Use an explicit `Queue` instance
when its `count` output or instance handle is needed.

The corresponding `ctrl_queue` and `ctrl_pipe` helpers accept
`DecoupledCtrl` or `IrrevocableCtrl` endpoints and retain the same static
interface information without manufacturing a dummy payload. Control-only
streams carry indistinguishable tokens; they are not a detachable control half
of a payload-bearing transaction. `CtrlPipe` produces `IrrevocableCtrl`, while
`CtrlQueue` remains conservatively `DecoupledCtrl` because flow-through mode
can expose its input offer directly.

`Queue(T, depth)` defaults to a registered, non-flow-through FIFO.
`~pipe: #true` permits enqueue when a full queue dequeues in the same cycle;
`~flow: #true` lets an empty queue present its input directly. `count` has type
`Bits(index_width(depth + 1))`. Current queues use asynchronous reads, and
depths greater than one compose two `Counter(depth)` pointer instances.

See [`../../examples/flow-control.rhdl`](../../examples/flow-control.rhdl) for
pipe, queue, fixed-priority arbitration, and chaining, and
[`../../examples/flow-topology.rhdl`](../../examples/flow-topology.rhdl) for
round-robin arbitration, demux, join, and broadcast. The parallel token-only
family is materialized in
[`../../examples/ctrl-flow.rhdl`](../../examples/ctrl-flow.rhdl).

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
`n - 1`, immediately before the next edge returns the value to zero.
