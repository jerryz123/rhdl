<!-- Compares RHDL's general construction semantics with HazardFlow's typed hazard-interface language. -->

# RHDL and HazardFlow: explicit RTL versus typed protocol flow

## Scope and thesis

*Snapshot: 2026-08-15.*

HazardFlow makes a bidirectional communication protocol the central object of
hardware composition. A hazard interface carries an optional forward payload,
a backward resolver, a predicate defining transfer, and a type-level account
of whether forward signals depend on backward signals. Modules consume and
produce those interfaces through Rust-shaped functions and combinators.

RHDL begins one level lower. Its source constructs arbitrary typed expressions,
explicit bindings, operations, state, and module ports. Ready/valid is one
protocol expressible over that core, not the denotation of every circuit.
HazardFlow is therefore more semantically economical for elastic pipelines;
RHDL is more orthogonal to protocols and more direct for hardware that does not
naturally form a flow graph.

## Summary

| Question | RHDL | HazardFlow |
|---|---|---|
| Source denotes | One verified RTL-style operation graph | A network of typed forward/backward interfaces and cycle functions |
| Core composition unit | Explicit definition/binding connections and circuit instances | A consumed interface transformed into another interface |
| Transfer semantics | Written as ordinary signal logic for a chosen protocol | Intrinsic `Hazard` payload, resolver, and ready predicate |
| State | Explicit registers and next-state bindings | Interface-attached FSM with explicit state transition callback |
| Dependency guarantee | Whole-design combinational-cycle verification after elaboration | Local `Helpful`/`Demanding` interface dependency types |
| Main source of locality | Every driver and state edge is directly represented | Payload, backpressure, and transfer behavior travel together |
| Syntactic compression | General but explicit | Very high for stream transformations and elastic pipelines |

## Denotation and staging

RHDL elaboration executes Rhombus host code to build the
[public core graph](../../rhdl/core/README.md). Host parameters and loops choose
structure; hardware expressions and effects create runtime circuit behavior.
The graph is protocol-neutral: a Boolean operation, a register, and a memory
retain the same meaning whether or not they participate in a handshake.

HazardFlow gives modules a more specialized denotation. Its
[tutorial](https://kaist-cp.github.io/hazardflow/book/tutorial/tutorial.html)
models one module cycle as a function from ingress forward signals, egress
backward signals, and current state to egress forward signals, ingress backward
signals, and next state. An interface transformation therefore denotes both
directions of a communicating pipeline stage at once.

The Rust-like surface should not be mistaken for ordinary Rust values driving
an external circuit builder. Hardware signal types, interface traits, and the
`fsm` operation have specialized HDL meaning. Its source vocabulary is built
around one recurring pipeline equation, so functions and method chains are
smoother than RHDL's general graph-construction forms.

## Core composition unit and syntax

RHDL composes a circuit by binding source expressions to explicit destinations.
The expression `destination <== source` has one direction and one ownership
effect. This definition/binding normal form is not itself a protocol
abstraction. A bidirectional protocol is represented by an interface descriptor
with complementary endpoint roles, but connecting it ultimately performs a set
of ordinary bindings. The general circuit model does not define a transfer
event.

HazardFlow treats a function implementing `FnOnce(Ingress) -> Egress`, where
both sides implement `Interface`, as a module. The idiomatic syntax chains
transformations on a consumed interface: payload maps, resolver maps, forks,
joins, registers, and FSMs all return another typed interface. This is an
elegant use of method chaining because the receiver is not incidental data;
it is the communication edge being consumed and replaced.

The [`Hazard` trait](https://kaist-cp.github.io/hazardflow/book/lang/interface.html)
is the key semantic compression. It associates a payload type `P`, a resolver
type `R`, and `ready(P, R)`. A transfer occurs exactly when a valid payload is
present and that predicate holds. Ready/valid becomes one instance of a more
general algebra instead of three related wires whose meaning must be restated
by each combinator.

RHDL's nominal protocol identity answers a different question: which named
contract do these two endpoints claim to implement? HazardFlow's hazard type
answers how a transfer is computed. Nominality and transfer algebra are
orthogonal; neither makes the other redundant.

## Time, state, and concurrency

Both languages remain cycle-explicit. HazardFlow does not schedule abstract
operations into an arbitrary number of cycles. Its generic FSM callback
computes forward output, backward output, and next state for the current cycle,
and the chosen combinator determines when state advances under transfer or
stall. Backpressure is therefore part of the state-transition expression, not
an external convention.

RHDL state is an explicit graph primitive. A register separates current state
from one selected next-state binding; guarded updates become muxes or enables.
An author writes `valid`, `ready`, and state-hold equations directly. That is
more verbose for a standard elastic stage, but it also exposes the precise
hardware when state does not advance on the same event as an interface
transfer.

Concurrency in both systems is the concurrency of the resulting network, not
a Bluespec-style rule schedule. The major difference is which cycle invariant
is factored out. HazardFlow packages the relation among payload, resolver,
transfer, and state. RHDL packages only the lower-level ownership and operation
semantics, leaving transfer coupling to the protocol definition and circuit.

## Types and intrinsic guarantees

HazardFlow signal types include arbitrary-width `U<N>`, Boolean values, enums,
tuples, structs, and arrays. Its distinctive guarantee comes from
`I<H, D>`: the hazard `H` defines transfer, while dependency type `D` describes
the backward-to-forward path. `Helpful` means forward signals do not depend on
backward signals. `Demanding` permits that dependence and additionally requires
that a present payload satisfy the ready predicate.

This type information can rule out some compositions that would create a
combinational loop. A sink that drives its backward result from the forward
payload, for example, can require a `Helpful` input. The
[dependency documentation](https://kaist-cp.github.io/hazardflow/book/advanced/dependency.html)
also states the limit precisely: the classification records only
intra-interface dependency. It does not detect every inter-interface loop,
including the documented fork/join pattern, and one invariant relies on using
the standard combinators correctly.

RHDL has no corresponding dependency type. It instead verifies the complete
elaborated dependency graph, including hierarchy and aggregate paths, and
rejects combinational cycles there. That catches loops outside HazardFlow's
two-point classification, but only after composition; it cannot tell a caller
from an interface type alone whether a proposed transformation is safe.

RHDL's other guarantees are broader and lower-level: exact hardware types,
one effective driver, legal resource ownership, and explicit conversions.
HazardFlow's guarantee is narrower and more protocol-aware. The strongest
language design would not confuse these layers: a local dependency type is a
composition aid, while whole-graph cycle verification remains the final fact.

## Locality and predictability

HazardFlow gives excellent protocol locality. The payload, feedback information,
transfer test, and dependency direction appear in one interface type, and a
combinator signature states how that package changes. A fluent pipeline can be
read left to right without manually tracing `valid` and `ready` through every
stage.

That economy weakens when behavior crosses several interfaces. Forward and
backward paths create a graph whose dependencies are not always captured by
the local `Helpful`/`Demanding` label. The fork/join limitation is important
because it shows that a compact interface type is an abstraction of the graph,
not the graph itself.

RHDL has the opposite profile. The final dependencies are explicit and checked,
but protocol meaning is distributed over ordinary equations unless a higher
authoring abstraction gathers it. Its linear interface handles make topology
consumption local during elaboration, and nominal roles prevent accidental
shape-only compatibility, yet the type does not carry a generic transfer
predicate or ready-dependency fact.

## Language-level judgment

HazardFlow's hazard interface is a strong, orthogonal abstraction for elastic
hardware. Payload, resolver, validity, readiness, and dependency are not five
unrelated features; they describe one communication event. Encoding them
together produces both syntactic economy and reusable semantic guarantees.
The fluent `Interface -> Interface` style matches that denotation unusually
well.

Its specialization is also its boundary. Not every register, memory port, or
control relation is most naturally understood as a stream transformation, and
the two-valued dependency summary cannot replace full circuit analysis. RHDL's
smaller graph primitives are less expressive about protocols but compose
uniformly across arbitrary RTL.

RHDL can construct the same handshake equations and state machines, but it
cannot currently state “this interface's transfer predicate is part of its
type” or “forward data is independent of backward resolution.” Those are real
language-level contract gaps, not missing Boolean expressivity.

## Lessons for RHDL

1. Represent a transfer protocol as one coherent contract containing payload,
   backward information, and the transfer predicate. Do not make each adapter
   rediscover their relationship from field names.
2. Add compositional dependency metadata only as a conservative summary, and
   retain whole-design combinational-cycle verification as the authority.
3. Keep nominal protocol identity and hazard behavior separate. One states
   meaning and compatibility; the other states transfer mechanics.
4. Provide an expression-oriented `Interface -> Interface` vocabulary for
   protocol transformations while leaving stateful or structurally meaningful
   boundaries explicit.
5. Do not force the general RHDL circuit model into a universal stream model.
   HazardFlow's elegance comes from a focused semantic domain, not from making
   every hardware object an interface.

## Sources

- RHDL [core semantics](../../rhdl/core/README.md),
  [frontend model](../../rhdl/frontend/README.md), and
  [standard interfaces](../../rhdl/std/README.md)
- [HazardFlow project](https://github.com/kaist-cp/hazardflow)
- [HazardFlow signal types](https://kaist-cp.github.io/hazardflow/book/lang/signal.html)
- [HazardFlow interface and hazard model](https://kaist-cp.github.io/hazardflow/book/lang/interface.html)
- [HazardFlow module model](https://kaist-cp.github.io/hazardflow/book/lang/module.html)
- [HazardFlow dependency types and limitations](https://kaist-cp.github.io/hazardflow/book/advanced/dependency.html)
