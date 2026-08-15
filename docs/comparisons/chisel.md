<!-- Compares the core denotation and authoring semantics of RHDL and Chisel. -->

# RHDL and Chisel

## Scope and thesis

*Snapshot: 2026-08-15.*

This comparison is about the languages' central authoring models. It uses the current
[Chisel documentation](https://www.chisel-lang.org/docs) and
[Chisel 7.14 API](https://www.chisel-lang.org/api/latest/).

RHDL and Chisel share the same broad denotation: a host-language program runs
to construct synchronous hardware. Their most important difference is the
semantic unit presented to the author. Chisel presents bound `Data` objects
whose connections accumulate during Scala elaboration. RHDL presents readable
`Value`s and driveable `Place`s that become a small, verified, typed IR. Chisel
is terser when inference and default-then-override wiring are helpful. RHDL is
more local when the question is exactly what drives a destination and what
width or semantic type crosses an operation.

## Summary

| Concern | RHDL | Chisel |
|---|---|---|
| Source denotation | Rhombus evaluation constructs one public core IR | Scala evaluation constructs a hardware graph lowered through FIRRTL/CIRCT |
| Hardware object | Separate readable `Value` and driveable `Place` | `Data` object whose binding determines whether it is a type, wire, port, or register |
| Width policy | Positive explicit widths; exact types at operations and connections | Widths may be unknown and inferred; operators and connections have sizing rules |
| Assignment | One effective driver; alternatives become one selected drive | Repeated connections are legal and the last connection wins |
| State | Current value plus a distinct next-state place | `Reg` is read and connected through the usual `Data` surface |
| Hierarchy | Circuit generators create definitions; instances cross explicit ports | Scala `Module` construction creates hierarchy; `RawModule` removes ambient clock/reset |
| Interface relation | Nominal identity, named roles, refinement, and support | Aggregate structure, orientation, `Flipped`, and `Connectable` relations |
| Primary abstraction tools | Rhombus functions, macros, classes, frontend layers, semantic type capabilities | Scala functions, classes, traits, generics, collections, and compiler-supported `Data` APIs |

## Denotation and staging

Chisel is a Scala library: executing constructors and operators builds a
hardware graph rather than computing hardware results. Its
[introduction](https://www.chisel-lang.org/docs) describes a Scala program as
constructing a circuit graph. Scala `if`, loops, collections, and methods run
during elaboration; `when`, `Mux`, and Chisel operators construct runtime
hardware.

RHDL makes the same phase distinction with Rhombus. Ordinary Rhombus control
and data choose generated structure, while `when`, `switch`, and hardware
operators construct circuit behavior.

After elaboration, both graphs denote concurrent hardware. Host statement
order does not schedule operations across cycles; it matters only where an API
uses elaboration order to define structure or connection priority.

The object models differ more sharply. Chisel distinguishes a *Chisel type*
from hardware bound to a circuit, but both are represented by `Data` objects.
Binding supplies direction and location, and some invalid combinations are
therefore diagnosed when the Scala program elaborates rather than by Scala's
type checker. The official
[Chisel type versus Scala type guide](https://www.chisel-lang.org/docs/explanations/chisel-type-vs-scala-type)
documents this distinction.

RHDL host descriptions and type objects are not circuit values. A `Value`
already belongs to a module and denotes a readable result; a `Place` denotes a
legal destination. Frontend profiles, macros, and the direct builder all
produce the same [core IR](../../rhdl/core/README.md). This makes the
post-elaboration meaning unusually explicit, while Chisel keeps a more uniform
author-facing object vocabulary.

## Expressions, types, and widths

RHDL operations consume complete hardware types. `Bits(8)`, `SInt(8)`, a
particular enum, a one-hot control, and an eight-bit packed record remain
distinct even when their representations have the same width. Ordinary
arithmetic is modular and preserves its declared result type. Growth,
truncation, and equal-width representation casts are requested explicitly.
Open core capabilities determine which operations a frontend-defined type may
support.

Chisel provides `Bool`, `UInt`, `SInt`, clocks, resets, `Vec`, `Bundle`, enums,
and user-defined aggregate types. Widths can be explicit or initially unknown;
the compiler solves width constraints using the documented
[width-inference rules](https://www.chisel-lang.org/docs/explanations/width-inference).
Operators encode intent through variants such as modular `+` and expanding
`+&`. This is concise for parameterized arithmetic because intermediate widths
can follow the expression, but a reader may need operator and connection rules
to recover the exact result width.

Connection syntax also reflects Chisel's preference for contextual
composition. General connections can pad or truncate according to Chisel's
rules. The newer
[`Connectable`](https://www.chisel-lang.org/docs/explanations/connectable)
operators are more explicit about aligned and flipped members and reject a
potentially truncating aligned connection unless the author opts into
squeezing. RHDL instead requires exact type equality at the connection itself;
adaptation is a separate expression.

RHDL's nominal one-hot and enum types preserve control intent through the IR.
Chisel can encode the same hardware with `ChiselEnum`, wrappers, `Mux1H`, or a
project type, but its ground `Data` operations are the more general building
blocks. The tradeoff is semantic specificity versus a smaller number of
widely composable primitives.

## State, assignment, and priority

RHDL treats connection as definition. A place has exactly one effective
driver. Hardware conditionals collect alternatives and lower them to a mux,
enable, or guard followed by one final drive. Priority is therefore attached
to `when`/`else` structure, not to unrelated statement order. A register
exposes its current value separately from its next-state place; an uncovered
next-state branch means hold, while a combinational destination must be
covered.

Chisel uses repeated connection as a control idiom. The normal rule is that
the last connection to a sink wins, including connections nested under
`when`. A default followed by conditional overrides is compact and familiar,
and source order deliberately expresses priority. The same economy means that
moving a connection can change the selected driver without changing the local
expression at the sink. Chisel's
[probe documentation](https://www.chisel-lang.org/docs/explanations/probes)
contrasts ordinary last-connect hardware with probes, which require one
definition.

Registers fit naturally into each model. Chisel `Reg`, `RegInit`, and
`RegEnable` use the ordinary expression/connection vocabulary and a `Module`'s
implicit clock and reset unless a more explicit form is selected; see the
[sequential-circuit guide](https://www.chisel-lang.org/docs/explanations/sequential-circuits).
RHDL registers carry an explicit clock and optional synchronous active-high
reset in core, with `sync_circuit` providing ambient convenience. Chisel's
unified syntax is economical; RHDL's current/next split makes dataflow and
state boundaries visible in the semantic graph.

## Hierarchy, interfaces, and composition

Chisel hierarchy follows Scala object construction. A class extending
`Module` defines hardware, and `Module(new Child(...))` creates a child
instance. Ordinary modules receive implicit clock and reset; `RawModule`
removes them. Ports are bound `Data`, usually grouped in `Bundle`s. This model
is direct and works naturally with Scala constructor parameters and object
composition. The
[module guide](https://www.chisel-lang.org/docs/explanations/modules) explains
the hierarchy and binding rules.

An RHDL `circuit` call during elaboration creates a module definition, and an
instance is a separate IR object with input places and output values. Hardware
crosses generator boundaries through ports; host values may be captured while
constructing definitions. Explicit binding can reuse one definition. This
separates definition generation from instantiation more visibly than Chisel's
constructor idiom.

For aggregate connection, Chisel combines `Bundle`, member orientation,
`Flipped`, and `Connectable`. Compatibility is principally structural and
relative to member alignment, with explicit operators for directional or
bidirectional bulk connection. RHDL interfaces are nominal protocol
descriptors: they name two roles, orient members, and can refine or support
other interface contracts. Linear handles add a single-consumption discipline
for topology-building APIs. Chisel's model adapts structural aggregates more
freely; RHDL's model can state that two similarly shaped interfaces mean
different protocols or that one nominal protocol supports another.

## Abstraction, locality, and predictability

Chisel inherits Scala's mature abstraction vocabulary. Higher-order
functions, collections, inheritance, traits, implicit parameters, and generic
classes can all generate hardware. Libraries can also wrap module creation in
an `apply` method so a component looks like a function, as shown in the
[functional module creation guide](https://www.chisel-lang.org/docs/explanations/functional-module-creation).
This yields very compact generators, although the meaning of a `Data` value may
depend on binding, direction, inferred width, and prior connections.

RHDL inherits Rhombus functions, classes, pattern matching, macros, and
language composition. Frontend layers may add surface syntax and semantic
types, but hardware operations still end in the same public IR.
Pure combinational helpers can return values without introducing hierarchy;
stateful or intentionally structural boundaries remain circuits. The
`Value`/`Place` split and exact-width connections make individual expressions
more self-describing, at the cost of more explicit adaptation and less
default-override shorthand.

## Language-level judgment

Chisel is cleaner when syntactic economy and fluent generator construction are
the priority: one `Data` vocabulary, contextual widths, and ordered connections
make common RTL compact. RHDL is cleaner when the source should expose the
final circuit locally: read versus drive capability, exact result types, and
the point where priority enters are explicit. Chisel's abstractions are broader
and smoother; RHDL's ordinary denotation is smaller and easier to reconstruct
without replaying surrounding elaboration order.

## Lessons for RHDL

1. Keep exact types and the `Value`/`Place` distinction; they are the clearest
   explanation of RHDL's local semantics.
2. Add concise authoring forms only when they still elaborate to one visible
   driver and do not make priority depend on ambient statement order.
3. Preserve the separation between inline value composition and intentional
   module hierarchy while making reusable-definition syntax economical.
4. Keep semantic type and protocol invariants visible in ordinary authoring,
   rather than relying on project conventions over raw aggregates.

## Sources

- [Chisel documentation](https://www.chisel-lang.org/docs)
- [Chisel types versus Scala types](https://www.chisel-lang.org/docs/explanations/chisel-type-vs-scala-type)
- [Chisel width inference](https://www.chisel-lang.org/docs/explanations/width-inference)
- [Chisel modules](https://www.chisel-lang.org/docs/explanations/modules)
- [Chisel sequential circuits](https://www.chisel-lang.org/docs/explanations/sequential-circuits)
- [Chisel interfaces and connections](https://www.chisel-lang.org/docs/explanations/interfaces-and-connections)
- [Chisel `Connectable`](https://www.chisel-lang.org/docs/explanations/connectable)
- [RHDL core semantics](../../rhdl/core/README.md)
- [RHDL frontend semantics](../../rhdl/frontend/README.md)
- [RHDL frontend layers](../../rhdl/frontend/layers/README.md)
