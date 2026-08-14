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

def instruction_value = record(Instruction()):
  opcode: bits(0b1010, 4)
  operands: vec(bits(2, 4), bits(0, 4))

def instruction_care = record(Instruction()):
  opcode: bits(0b1111, 4)
  operands: vec(bits(0b1111, 4), bits(0, 4))

def instruction_pattern = Pattern(
  ~value: instruction_value,
  ~care: instruction_care
)
```

A care bit of one makes the corresponding value bit significant; zero makes
it a don't-care. `value` and `care` must have exactly equal hardware types, not
merely equal packed widths. Any `HardwareLiteral` type works, including
`Bits`, `Bool`, enums, `OneHot`, extension-defined flat data, and recursively
nested records and vectors. The generic `literal(T, packed_value)` form can
express an arbitrary typed care image when a semantic constructor exposes only
named values.

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

## Ready-valid protocols

Import the protocol family directly:

```rhombus
import:
  lib("rhdl/std/ready-valid.rhdl") open
```

| Interface | Contract |
|---|---|
| `Valid(T)` | Every asserted cycle carries one payload; no backpressure |
| `DecoupledControl()` | Offer/accept control; transfer occurs when `ready` and `valid` are asserted |
| `IrrevocableControl()` | A decoupled offer cannot be withdrawn before transfer |
| `Decoupled(T)` | Payload-bearing decoupled transfer without a pre-transfer stability guarantee |
| `Irrevocable(T)` | A valid payload remains asserted and stable until transfer |

`Decoupled` refines `DecoupledControl`; `Irrevocable` refines
`IrrevocableControl`, which transitively refines `DecoupledControl`.
`Irrevocable(T)` also declares support for the weaker `Decoupled(T)` contract.
The temporal difference is currently documentation rather than generated
protocol assertions.

`fire(endpoint)` accepts any endpoint supporting `DecoupledControl` and
returns `endpoint.valid and endpoint.ready`.

## Flow-control circuits

[`flow.rhdl`](flow.rhdl) re-exports the independently importable generators
under [`flow/`](flow/):

| Generator | Behavior |
|---|---|
| `Pipe(T, stages)` | Registered elastic pipeline with stable output under backpressure |
| `Queue(T, depth)` | Configurable FIFO with occupancy count |
| `Arbiter(T, n)` | Fixed-priority, index-zero-first arbitration |
| `RRArbiter(T, n)` | Fair round-robin arbitration |
| `Demux(T, n)` | Selected one-to-many routing with invalid-selector blocking |
| `Join(T, n)` | Atomic homogeneous join that never partially consumes inputs |
| `Broadcast(T, n)` | Buffered exactly-once delivery tracked independently per recipient |

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

`Queue(T, depth)` defaults to a registered, non-flow-through FIFO.
`~pipe: #true` permits enqueue when a full queue dequeues in the same cycle;
`~flow: #true` lets an empty queue present its input directly. `count` has type
`Bits(index_width(depth + 1))`. Current queues use asynchronous reads, and
depths greater than one compose two `Counter(depth)` pointer instances.

See [`../../examples/flow-control.rhdl`](../../examples/flow-control.rhdl) for
pipe, queue, fixed-priority arbitration, and chaining, and
[`../../examples/flow-topology.rhdl`](../../examples/flow-topology.rhdl) for
round-robin arbitration, demux, join, and broadcast.

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
