<!-- Documents RHDL's optional protocols and reusable circuit-generator library. -->

# RHDL standard library

`rhdl/std` contains opt-in reusable hardware vocabulary written against the
public `#lang rhdl` language. It is not another language profile and adds no
core IR, elaboration, or backend behavior. Its dependency contract is listed
in [`../README.md`](../README.md).

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
