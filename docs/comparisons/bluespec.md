<!-- Compares RHDL's exact-construction semantics with Bluespec's guarded atomic rules as language abstractions. -->

# RHDL and Bluespec: construction graphs versus guarded atomic actions

## Scope and thesis

*Snapshot: 2026-08-15.*

RHDL and Bluespec SystemVerilog (BSV) give source code different denotations.
An RHDL circuit generator elaborates into one particular graph of values,
destinations, operations, state elements, and module instances. A BSV module
elaborates into state, methods, and guarded atomic rules; the compiler then
chooses hardware that may execute compatible rules concurrently while
preserving a legal sequential ordering.

That difference is the comparison. It is not that one language can ultimately
form gates the other cannot. Bluespec makes an atomic state transition the
unit of composition and derives arbitration from it. RHDL makes the selected
datapath, enables, and arbitration the unit of construction. Bluespec is more
expressive when transactions should compose before their schedule is known;
RHDL is more local when the authored structure is itself the contract.

## Summary

| Question | RHDL | Bluespec |
|---|---|---|
| Source denotes | One deterministic, verified hardware graph | A statically elaborated system of guarded rules, methods, and state |
| Core composition unit | Explicit definition/binding edges and circuit instances | Atomic rules calling guarded interface methods |
| Concurrency | Circuit graph is concurrent; state edges are explicit | Compiler selects a serializable subset of rules per clock |
| Conflicting state effects | Rejected unless the author constructs explicit selection | Permitted across rules and resolved by scheduling |
| Static guarantees | Exact hardware types, one effective driver, legal ownership, no combinational cycles | Static types plus rule atomicity and method-schedule consistency |
| Main source of locality | The operation and enable graph is directly authored | A transaction is locally stated, but its realized schedule is global |
| Syntactic compression | Concise for direct datapaths; explicit for arbitration | Concise for concurrent control and shared resources |

## Denotation and staging

RHDL is a deep Rhombus embedding. Calling a `circuit` generator during
`elaborate` executes host computation and constructs the
[public core IR](../../rhdl/core/README.md). Host loops and parameters choose
structure. Hardware operators, `when`, `switch`, registers, and connections
create nodes in the resulting circuit. The order in which those nodes were
emitted is not a runtime execution order.

BSV also has static checking and elaboration, but its dynamic meaning is a
rule system. The
[BSV Language Reference Guide](https://github.com/B-Lang-org/bsc/releases/latest/download/BSV_lang_ref_guide.pdf)
defines a rule's enabled condition as its explicit predicate combined with the
implicit conditions of every method it calls. Its reference semantics
repeatedly chooses one enabled rule and applies that rule atomically. That
semantics intentionally denotes a set of legal behaviors rather than one
fully chosen schedule.

The BSV compiler may implement several rules in one clock when their net effect
matches some legal sequential execution. Compiler scheduling is therefore not
an optimization hidden below an otherwise fixed circuit: it completes the
source program's concurrency semantics. RHDL has no corresponding semantic
step. Once elaboration has produced a verified graph, concurrency is already
the ordinary concurrency of that graph.

## Core composition unit and syntax

RHDL's small syntactic vocabulary mirrors its graph model. A declaration such
as `output sum: Bits(width)` introduces a driveable destination, and
`sum <== a + b` supplies its one driver. `reg state(...)` introduces explicit
state, while `when` and `switch` collect alternatives into mux or enable logic.
Circuit calls create definitions, and explicit `inst` operations create
hierarchy. These forms compose uniformly because they all reduce to operations,
definition results, binding destinations, and resources. The expressive
contrast with Bluespec begins above that exact-IR normal form.

BSV's high-leverage form is the rule: a guard next to a sequence of method
calls and state updates. Methods are value, `Action`, or `ActionValue`
operations, and subinterfaces nest the same abstraction. A method's readiness
condition is implicitly conjoined into every calling rule, so a component can
expose an operation without requiring each client to reproduce its enable
logic. BSV and Bluespec Haskell provide different surface syntaxes for this
same model; the semantic economy comes from the rule, not from punctuation.

The contrast is sharp around a shared resource. In RHDL, clients, arbitration,
priority, muxes, and enables are ordinary constructed hardware. In BSV,
clients can state independent rules and let method conflicts participate in a
derived schedule. Bluespec removes repeated control plumbing, but the meaning
of a call now includes facts declared by the callee and decisions made by the
whole-module scheduler. RHDL writes more source in that case, while keeping the
composition result visible at the use site.

## Time, state, and concurrency

RHDL state is structurally explicit. A register has a current readable value
and a next-state destination; an omitted guarded update means hold. Every
destination has one effective driver after conditional alternatives are
canonicalized. Combinational cycles are rejected across the elaborated design.
There is no concept of two updates racing and later being serialized by a
scheduler.

In BSV, separately authored rules may read and update the same state. Atomic
rule semantics supplies the reasoning model, while scheduling analysis
determines which compatible rules can fire together and which conflicts need
an order or exclusion. Scheduling attributes can constrain urgency,
preemption, and asserted relationships. This is elegant because the language
turns a cross-cutting race problem into a semantic obligation of the compiler.

The guarantee has a precise boundary. Bluespec guarantees that the chosen
parallel hardware behavior is consistent with legal rule orderings and method
schedules. It does not, merely from atomicity, guarantee fairness, liveness, or
the throughput an author intended. Those properties still require examining
guards, conflicts, annotations, and the compiler's reported schedule. RHDL
offers less scheduling abstraction but makes the implemented priority and
throughput paths ordinary circuit structure.

## Types and intrinsic guarantees

RHDL stores positive, elaboration-known widths in hardware type objects.
Connections require exact types; extension, truncation, and representation
casts are explicit. Its open capability hierarchy lets records, vectors,
signed values, enums, and one-hot selectors opt into appropriate operations.
The verifier checks the realized graph rather than proving a family of
generators before elaboration.

BSV has a substantially richer static type language: polymorphic functions and
modules, tagged unions, type classes, numeric types, and provisos such as
`Bits#(t, n)`. Numeric relationships can be stated as part of a reusable
definition instead of being checked only after a host integer parameter has
selected one instance. Actions, rules, modules, and interfaces also participate
in the static language, making hardware fragments first-class elaboration
objects.

These guarantees operate at different layers. RHDL intrinsically guarantees
the ownership and connectivity of the concrete circuit it built. Bluespec
intrinsically guarantees the static consistency of a richer generic program
and the atomic interpretation of its scheduled effects. Neither guarantee
substitutes for a functional proof of the design.

## Locality and predictability

RHDL has strong structural locality. Following a destination's single binding
reveals the selected expression or state enable, and unrelated operations do
not silently acquire a shared scheduling relationship. The cost is that a
protocol or resource policy is repeated as graph structure unless the author
packages it behind a circuit abstraction.

Bluespec has stronger transactional locality. A rule states one coherent
operation even when it spans several module interfaces. But realized
concurrency is less local: a new rule, a changed method schedule, or an urgency
annotation can alter which transactions share a cycle. Schedule reports are
therefore part of understanding the generated design, not merely diagnostic
noise.

This is a principled exchange, not a cleanliness defect in either language.
RHDL makes spatial structure predictable and asks the author to own scheduling.
Bluespec makes atomic intent predictable and asks the compiler to reconcile
global concurrency.

## Language-level judgment

Bluespec's guarded atomic action is the more semantically ambitious and more
compressive abstraction. Guard, readiness, shared-state conflict, and atomic
commit form one coherent model, so rules and guarded methods compose with high
leverage. The abstraction is especially elegant for control-dominated designs
whose natural specification is a set of possible transactions.

RHDL's exact-construction policy is smaller and more literal than Bluespec's
rule semantics. It requires final bindings, priority, and state boundaries to
be explicit rather than hiding arbitration behind method calls. That makes
datapaths, exact pipeline structure, and local priority easy to audit, but it
offers no language-level way to postpone a scheduling choice while retaining
an atomic specification.

The crucial distinction is representational. RHDL can construct the circuit
produced by a Bluespec schedule, but its current language cannot state a set of
atomic rules and require a compiler to choose a serializable implementation.
That is a missing semantic layer, not a missing mux primitive.

## Lessons for RHDL

1. Keep atomic actions distinct from connection semantics. If RHDL adopts
   rules, they should elaborate through an explicitly named scheduling layer
   into ordinary verified RHDL IR.
2. Preserve a compact, verified definition/binding normal form for exact
   construction regardless of the authoring surface or any transaction layer
   above it.
3. Treat guards as contracts that compose with an operation, not as detached
   Boolean conventions. Bluespec methods show the expressive value of carrying
   readiness with the action it controls.
4. Make any inferred schedule inspectable as a first-class result. Atomicity
   alone does not communicate priority, achievable parallelism, or starvation.
5. Borrow rule syntax only with rule semantics. Superficial action blocks that
   still require handwritten arbitration would add vocabulary without gaining
   Bluespec's central abstraction.

## Sources

- RHDL [core semantics](../../rhdl/core/README.md) and
  [frontend model](../../rhdl/frontend/README.md)
- [Bluespec Compiler project](https://github.com/B-Lang-org/bsc)
- [BSV Language Reference Guide](https://github.com/B-Lang-org/bsc/releases/latest/download/BSV_lang_ref_guide.pdf)
- [Official Bluespec language materials](https://github.com/BSVLang/Main)
