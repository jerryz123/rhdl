<!-- Compares the core denotation and authoring semantics of RHDL and SpinalHDL. -->

# RHDL and SpinalHDL

## Scope and thesis

*Snapshot: 2026-08-15.*

This comparison uses the current
[SpinalHDL documentation](https://spinalhdl.github.io/SpinalDoc-RTD/master/index.html)
and concentrates on the language's ordinary RTL model.

SpinalHDL and RHDL both aim to make constructed hardware predictable rather
than emulate an event-driven HDL. SpinalHDL builds a mutable netlist through a
fluent Scala API and checks many structural mistakes after elaboration. RHDL's
frontend presents a common hardware surface, while core factors readable
`Value`s from driveable `Place`s. SpinalHDL is syntactically economical; RHDL
is more explicit about exact types, one final binding, conditional priority,
and current/next-state semantics.

## Summary

| Concern | RHDL | SpinalHDL |
|---|---|---|
| Source denotation | Rhombus evaluation constructs one public core IR | Scala evaluation constructs an in-memory netlist that later passes transform/check phases |
| Hardware object | Common frontend hardware surface; core factors readable `Value` from driveable `Place` | Mutable-reference-like `Data` objects denote signals and destinations |
| Width policy | Positive explicit widths; exact types at connections | Widths may be explicit or inferred; assignment widths are checked; `.resized` is contextual |
| Assignment | One effective driver; alternatives become one selected drive | Same-scope overlap normally rejects; under conditional muxing the last active assignment wins |
| State | Current value plus distinct next-state place | `Reg` declaration makes state; assignment syntax remains uniform |
| Hierarchy | Circuit definitions and instances; pure helpers stay inline | `Component` makes hierarchy; `Area` groups inline structure |
| Interface relation | Nominal roles, refinement, support, and linear handles | `Bundle` structure, port directions, `IMasterSlave`, and inferred bulk connection |
| Primary abstraction tools | Rhombus functions, macros, classes, frontend layers, semantic type capabilities | Scala functions, classes, traits, generics, collections, `Area`, and library-defined data types |

## Denotation and staging

SpinalHDL is a regular Scala library. Running the Scala program calls
constructors and overloaded operators that build an in-memory graph. Once the
top-level `Component` has been instantiated, compiler phases transform, check,
and serialize that graph. The official
[Scala interaction guide](https://spinalhdl.github.io/SpinalDoc-RTD/master/SpinalHDL/Getting%20Started/Scala%20Guide/interaction.html)
states this model directly.

Scala computation chooses generated structure. Scala loops, collections,
methods, and ordinary booleans run during elaboration; Spinal `Bool`, `when`,
`switch`, and signal operators build circuit behavior. Because hardware
objects are references into the graph, passing one to a Scala function and
assigning it there affects the same signal.

The resulting graph denotes concurrent hardware. Scala execution order builds
that graph; it is not a cycle-by-cycle schedule, except where ordered
assignments deliberately encode mux priority.

RHDL also runs its host program to construct hardware, but its completed
denotation is a documented [core IR](../../rhdl/core/README.md). Frontend
profiles and language layers present a common hardware vocabulary and all
produce that representation. Core then uses `Value` for a readable result and
`Place` for a destination. This makes ownership and direction explicit in the
completed graph, although a unified graph object with checked capabilities can
enforce the same policy.

Both systems are deterministic construction languages in the ordinary case.
SpinalHDL exposes more of elaboration as mutation of shared graph references;
RHDL exposes more of the result as creation of typed values and final drives.

## Expressions, types, and widths

SpinalHDL provides `Bool`, raw `Bits`, arithmetic `UInt` and `SInt`, enums,
`Vec`, and `Bundle`. A hardware type combines a Scala class with the parameters
stored in its instance, so a parameterized bundle class is also a reusable
hardware type. Values can be cloned from an existing type object. This makes
ordinary object-oriented definitions a natural way to introduce structured
hardware.

Widths can be stated or inferred. For example, `Bits()` may obtain its width
from its assignments. SpinalHDL normally requires assignment bit counts to
match, automatically widening only weakly sized literals that fit. Explicit
`resize` may widen or narrow, while `.resized` asks the surrounding assignment
for the target width. These rules are documented in the
[`Bits` guide](https://spinalhdl.github.io/SpinalDoc-RTD/master/SpinalHDL/Data%20types/bits.html)
and
[assignment semantics](https://spinalhdl.github.io/SpinalDoc-RTD/master/SpinalHDL/Semantic/assignments.html).

RHDL requires every width to be a positive host integer at construction.
Connections and ordinary operators require complete type equality; extension,
truncation, and representation casts are separate expressions. Its packed
types may expose bitwise, arithmetic, or signed-arithmetic capabilities while
remaining nominally distinct. Thus an enum, one-hot control, signed integer,
and raw bit vector need not become interchangeable merely because their widths
match.

SpinalHDL occupies a middle ground between pervasive inference and strict
explicitness: most mismatches are errors, yet declarations and contextual
`.resized` expressions can leave size to surrounding statements. RHDL makes
the implemented width more local, while SpinalHDL saves repetition when the
destination is already the clearest size specification.

## State, assignment, and priority

In SpinalHDL, declaration determines whether a signal is combinational or
sequential. `UInt(8 bits)` creates a combinational signal; wrapping the type in
`Reg(...)` creates a register. The same `:=` syntax drives either. A register
captures the ambient clock domain when it is created, so its clocking semantics
come from construction context rather than the later assignment site.

SpinalHDL's
[assignment rules](https://spinalhdl.github.io/SpinalDoc-RTD/master/SpinalHDL/Semantic/assignments.html)
distinguish two cases. Two ordinary `:=` assignments from the same scope are
treated as an overlap and rejected by default. Within `when` or other mux
construction, the last active assignment wins, which gives compact
default-then-override and priority logic. The separate `\=` operator updates a
combinational graph reference immediately for deliberately imperative
construction.

RHDL instead gives each destination one final binding. `when` and `switch`
capture branch alternatives and lower them to one selected value or guarded
effect. Read and drive contexts select a register's current and next state;
core records those as a value and a place. A conditionally uncovered next state
holds. This removes connection order as an ambient source of priority, but
requires alternatives from separate helpers to be brought together explicitly.

SpinalHDL's `ClockDomain` makes clock, reset, edge, polarity, and enable policy
an ambient construction context, and `ClockingArea` scopes it. RHDL registers
carry an explicit clock in core and may use the `sync_circuit` convention for
an ambient clock/reset pair. SpinalHDL's domain context is more expressive and
compact for groups of state; RHDL's operand-level clock is simpler to recover
from an individual register node.

## Hierarchy, interfaces, and composition

A SpinalHDL `Component` creates a hardware module. Instantiating a component
inside another component creates hierarchy, and its ports are connected after
construction. An `Area` instead groups logic and naming without requiring a
module boundary. This gives authors a clear choice between structural hierarchy
and inline organization. The
[component guide](https://spinalhdl.github.io/SpinalDoc-RTD/master/SpinalHDL/Structuring/components_hierarchy.html)
also defines which parent and child ports may be read.

RHDL makes a similar distinction through functions and circuits. Pure helpers
over values add operations directly to the containing circuit. Calling a
`circuit` generator creates a definition, and an explicit instance creates the
hierarchical relationship. Hardware crosses through ports; host parameters
shape the generated definition.

SpinalHDL `Bundle`s collect named hardware fields. Port directions live on the
members, `IMasterSlave` can assign complementary directions for a reusable
interface, and `<>` infers how matching members should connect. This is a
structural and directional model built from Scala classes and signal metadata.

RHDL interfaces are nominal protocol descriptions. They define two named
roles, orient members by role, and may refine or support other protocol
identities. Linear handles can make a topology object single-use. SpinalHDL's
approach is lightweight and lets ordinary bundle methods become a fluent
interface API. RHDL's approach carries more compatibility meaning than field
shape and direction alone.

## Abstraction, locality, and predictability

SpinalHDL derives much of its elegance from the fact that hardware types are
Scala objects. Methods can be placed directly on bundles, constructors can
validate parameters, functions can return signals or `Area`s, and collections
can generate regular structure. Since operations mutate an in-memory graph,
an abstraction may contribute assignments to objects it receives instead of
returning a complete value.

The compiler compensates with broad design checks. Its documented checks
include assignment overlap, clock crossing, hierarchy violation,
combinational loops, latches, undriven signals, and width mismatch; see
[Design errors](https://spinalhdl.github.io/SpinalDoc-RTD/master/SpinalHDL/Design%20errors/index.html).
The language is therefore not merely permissive mutation: it accepts concise
construction idioms, then validates global graph properties.

RHDL's frontend largely presents one hardware category, with driveability
checked when `<==` is elaborated. Core's source/sink factoring then gives the
verifier direct categories for ownership and direction. The stronger
language-level policies are that connection adaptation is explicit, each
destination has one final binding, and ordinary connection order cannot
override it. This improves local predictability but makes some incremental
construction patterns more verbose.

## Language-level judgment

SpinalHDL is the strongest compromise between terse embedded-HDL syntax and
predictable RTL among these Scala-style designs. Its overlap checks, width
checks, `Component`/`Area` distinction, and explicit resize forms show that a
unified `Data` surface can be disciplined. RHDL is cleaner where exact type,
one final binding, explicit conditional priority, and current/next state should
be recoverable without replaying assignment order. SpinalHDL wins syntactic
economy; RHDL wins locality of denotation.

## Lessons for RHDL

1. Retain one effective driver, but keep conditional authoring concise enough
   that explicit priority does not become ceremony.
2. Preserve the distinction between inline helpers and hierarchy; SpinalHDL's
   `Area`/`Component` split shows the value of making both choices ergonomic.
3. If clock domains become first-class, make their construction context and
   register-level denotation equally inspectable.
4. Continue deriving rich protocol composition from nominal interfaces rather
   than accumulating unrelated connection operators.

## Sources

- [SpinalHDL documentation](https://spinalhdl.github.io/SpinalDoc-RTD/master/index.html)
- [SpinalHDL and Scala interaction](https://spinalhdl.github.io/SpinalDoc-RTD/master/SpinalHDL/Getting%20Started/Scala%20Guide/interaction.html)
- [SpinalHDL assignments](https://spinalhdl.github.io/SpinalDoc-RTD/master/SpinalHDL/Semantic/assignments.html)
- [SpinalHDL bit vectors](https://spinalhdl.github.io/SpinalDoc-RTD/master/SpinalHDL/Data%20types/bits.html)
- [SpinalHDL bundles](https://spinalhdl.github.io/SpinalDoc-RTD/master/SpinalHDL/Data%20types/bundle.html)
- [SpinalHDL components and hierarchy](https://spinalhdl.github.io/SpinalDoc-RTD/master/SpinalHDL/Structuring/components_hierarchy.html)
- [SpinalHDL clock domains](https://spinalhdl.github.io/SpinalDoc-RTD/master/SpinalHDL/Structuring/clock_domain.html)
- [SpinalHDL design checks](https://spinalhdl.github.io/SpinalDoc-RTD/master/SpinalHDL/Design%20errors/index.html)
- [RHDL core semantics](../../rhdl/core/README.md)
- [RHDL frontend semantics](../../rhdl/frontend/README.md)
- [RHDL frontend layers](../../rhdl/frontend/layers/README.md)
