<!-- Compares RHDL's exact synchronous construction with Filament's timeline-typed pipeline language. -->

# RHDL and Filament: explicit cycles versus timeline-typed composition

## Scope and thesis

*Snapshot: 2026-08-15.*

RHDL and Filament are both structurally minded languages: neither treats a
software procedure as an unconstrained request for HLS. Their source programs
nevertheless state different structures. RHDL constructs concrete operations,
registers, memories, and connections. Filament constructs component instances
and invokes them at symbolic events, with types saying when every port is
available and how frequently a resource may be reused.

Filament's timeline types are a genuine increase in language expressivity.
RHDL can build a balanced pipeline or a resource-sharing controller, but it
cannot state their latency, initiation interval, or legal use windows as
compositional source contracts. Filament gains that power by specializing its
language around statically timed pipelines. RHDL remains more direct for
general synchronous RTL and dynamically stalled protocols.

## Summary

| Question | RHDL | Filament |
|---|---|---|
| Source denotes | One exact graph of operations, state, resources, and instances | A statically timed network of component instances and event-indexed invocations |
| Core composition unit | Typed value connected to a driveable place | Component invocation at a symbolic event |
| Time | Emerges from explicit state edges and protocol logic | Appears in port availability intervals and event expressions |
| Resource sharing | Author constructs arbitration, enables, and state | Repeated invocations checked against a component's initiation interval |
| Static guarantee | Concrete graph is typed, single-driver, and cycle-safe | Composed values and resource uses satisfy declared timeline constraints |
| Main source of locality | Exact register and connection structure is visible | Latency and use windows travel with component signatures |
| Syntactic compression | Direct for arbitrary RTL | High for balanced, statically scheduled pipelines |

## Denotation and staging

RHDL executes a Rhombus generator to construct the
[public hardware IR](../../rhdl/core/README.md). A register is a concrete
state element, a connection is a concrete driver relation, and module
instantiation creates a chosen structural boundary. If a result must arrive
two cycles later, the author builds the state and control that make that true.

Filament components are parameterized by symbolic events. In a declaration
such as `comp C<'G: 1>(x: ['G, 'G+1] 32)`, `'G` names a start event, the
interval says when `x` is available, and the event delay states the component's
initiation interval. Instantiating a component creates hardware; invoking that
instance at an event states when the hardware performs one use. The
[Filament overview](https://filamenthdl.com/) presents those distinctions as
the language's central model.

The source therefore contains a schedule, but not as a flat list of absolute
cycles. Event expressions describe relative time and component signatures
abstract over a caller's start event. The compiler checks and realizes that
schedule; it is not free to choose arbitrary operation latency or register
placement. RHDL fixes time by explicit graph construction, while Filament fixes
time by a checked symbolic contract that later determines graph control.

## Core composition unit and syntax

RHDL syntax names hardware ownership directly. `output out: Bits(32)` creates
a destination, `out <== value` supplies its driver, and `reg state(...)`
introduces a state element. `when` and `switch` describe runtime selection that
lowers to muxes and enables. Composition is uniform because all of these forms
end in the same values, places, and operations.

Filament syntax separates three ideas that conventional structural HDLs often
conflate: component declaration, physical instantiation, and timed invocation.
`A := new Add[32]` creates one adder; `a0 := A<'G>(x, y)` uses that particular
adder at event `'G`. Port types carry intervals such as `['G, 'G+1]`, so the
invocation result brings its valid time into subsequent composition.

This separation is syntactically economical precisely when hardware is reused
over time. A second invocation communicates sharing without manually exposing
the mux, enable, and controller at every use site, while the event argument
makes the scheduling decision visible. RHDL requires those implementation
objects to be constructed explicitly. Filament writes less control structure,
but its source is less literal about the final registers and controller states.

## Time, state, and concurrency

RHDL has conventional synchronous semantics. Registers advance on explicit
clocks, combinational logic relates current values within a cycle, and guarded
next-state drives determine holds and updates. Parallel operations are simply
parallel regions of the graph. There is no language-level latency associated
with an ordinary circuit port.

Filament makes relative time part of every component boundary. An output can be
consumed only during an interval covered by its availability, and a shared
instance cannot be invoked at overlapping times forbidden by its initiation
interval. A register is used when a value must remain available into a later
interval. Timeline checking therefore catches unbalanced pipeline paths and
structural resource hazards as composition errors.

This is not the same abstraction as dynamic backpressure. A timeline contract
says at which relative cycles a value exists and when new work may begin. A
ready/valid protocol decides at runtime whether a transfer occurs and may stall
for an unbounded, data-dependent number of cycles. RHDL directly expresses the
latter through signal and state equations; Filament's most elegant core model
addresses the former. Treating one as a weaker version of the other obscures
their different denotations.

## Types and intrinsic guarantees

Filament's distinctive type is a bit width paired with an availability
interval over events. Type checking establishes that each source value is
available for the destination's required interval and that uses of a component
respect its declared delay. The declaration checks an implementation against
the latency and initiation interval it promises, making timing compositional
across component boundaries.

The guarantee extends beyond one concrete unrolling. Filament parameters,
constraints, generative `if`/`for`, and index-dependent
[bundles](https://filamenthdl.com/docs/meta/loops-and-bundles.html) let timing
relationships be expressed symbolically. The language checks allowed
parameterizations with arithmetic constraints rather than merely testing one
expanded circuit. This is a family-level timing guarantee that unrestricted
RHDL host generation does not attempt.

RHDL's type system records a different set of facts: exact packed and
aggregate structure, semantic distinctions such as signed, enum, and one-hot
values, operation capabilities, and driveability. The verifier checks those
facts plus one-driver ownership and combinational acyclicity in the realized
design. Its types do not carry temporal intervals, and module signatures do not
promise latency or initiation interval.

The representational boundary is important. RHDL can implement the same
pipeline and even generate host-side checks for a particular instance, but the
public language cannot quantify over a symbolic event or require callers to
respect a time-indexed port contract. Filament's advantage is not a more
convenient register helper; it is a different static proposition.

## Locality and predictability

Filament makes timing local at component boundaries. A caller can see when an
input is required, when an output appears, and how soon the component can be
invoked again without inspecting its internal pipeline. Relative events make
this information compose through nested invocations instead of devolving into
comments about cycle numbers.

The price is a more abstract relationship to the final control graph. A short
sequence of timed invocations can imply guards, pipeline enables, and controller
state that are not named in the source. Constraint errors may also involve
symbolic interval relationships spanning several calls. The schedule is still
author-visible, but the mechanism implementing it is compiler-derived.

RHDL has the inverse locality. Registers, muxes, and enables are easy to locate
and their connectivity is predictable, but latency is an emergent path property
that does not survive as an interface contract. A module can be structurally
transparent yet temporally opaque to its caller.

## Language-level judgment

Timeline types are elegant because Filament does not bolt independent
`latency`, `valid_from`, and `initiation_interval` annotations onto a structural
language. Events, intervals, invocations, and component delay form one algebra:
the same event expression explains value availability and legal resource reuse.
That orthogonality gives a small syntax unusually high leverage for static
pipelines.

RHDL's construction language is more general and more literal. Its
`Value`/`Place` model accommodates elastic control, arbitrary state machines,
memories, and ordinary datapaths without translating them into a timeline.
The cost is that timing intent above the register level is not expressible as a
checked contract.

The right comparison is therefore not which language has “more timing.” RHDL
owns exact cycle implementation; Filament owns symbolic timing composition.
Filament is more expressive and concise where a design admits a static
schedule. RHDL is more predictable where runtime control, not a timeline, is
the natural specification.

## Lessons for RHDL

1. If RHDL adds fixed-latency contracts, base them on composable symbolic events
   or equivalent relations, not disconnected integer annotations.
2. Distinguish physical instantiation from logical invocation when a language
   layer intentionally shares resources. The distinction exposes reuse without
   requiring scheduling to masquerade as wiring.
3. Verify any timing contract against the constructed implementation; a type
   that callers trust must not be documentary metadata.
4. Keep statically timed and elastic interfaces as distinct regimes. A
   fixed-latency event contract and a dynamically stalled transfer protocol
   make different promises.
5. Preserve exact RHDL IR beneath any timeline layer. Inferring control from
   events should be a named elaboration step, not a silent change to ordinary
   connection semantics.

## Sources

- RHDL [core semantics](../../rhdl/core/README.md),
  [frontend model](../../rhdl/frontend/README.md), and
  [frontend layers](../../rhdl/frontend/layers/README.md)
- [Filament language overview](https://filamenthdl.com/)
- [Filament language tutorial](https://filamenthdl.com/docs/lang/tutorial.html)
- [Filament loops and timed bundles](https://filamenthdl.com/docs/meta/loops-and-bundles.html)
- [Modular Hardware Design with Timeline Types](https://www.cs.cornell.edu/~asampson/media/papers/filament-pldi2023-preprint.pdf)
