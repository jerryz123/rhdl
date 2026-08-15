<!-- Compares RHDL with PyMTL3 across embedded RTL syntax and multi-level modeling semantics. -->

# RHDL and PyMTL3

## Scope and thesis

Snapshot: 2026-08-15. This comparison uses the checked-in RHDL implementation
and PyMTL3's current official documentation and primary repository.

At the synthesizable RTL level, RHDL and PyMTL3 are close peers: both execute a
host language to elaborate hierarchy and both describe cycle-accurate hardware
rather than asking an HLS scheduler to invent a pipeline. Their semantic
centers differ. RHDL elaborates into one explicit hardware graph with separate
readable values and driveable places. PyMTL3 elaborates an executable Python
component model whose concurrent update blocks are scheduled for simulation
and translated from a defined Python RTL subset.

PyMTL3 also supports functional-level and cycle-level models. That wider
modeling vocabulary matters for composition and syntax, but it should not be
mistaken for automatic refinement: an FL or CL component is a different model,
not a high-level program that PyMTL3 necessarily synthesizes into an RTL
component. RHDL is narrower and more explicit; PyMTL3 is more uniform across
executable modeling levels.

## Summary

| Concern | RHDL | PyMTL3 |
|---|---|---|
| Semantic unit | Static hardware module in a verified dataflow IR | Executable Python `Component` with connectivity and update blocks |
| Staging | Host forms generate structure; hardware forms construct graph nodes | `construct` elaborates; decorated blocks describe model behavior |
| Time | Explicit register and memory operations | `@update_ff` state transition plus simulator ticks; CL methods can model cycle timing |
| Control | Hardware `when` / `switch` lower to muxes and guards | Python `if` / `for` in a decorated, translatable block |
| Types | Exact semantic hardware types and separate `Value` / `Place` | Concrete `BitsN`, `BitStruct`, ports, wires, and Python values |
| Composition | Modules plus nominal two-role interface descriptors | Components plus hierarchical signal or method interfaces |
| Scheduling | Source fixes every sequential boundary | RTL source fixes boundaries; simulator schedules concurrent update blocks |
| Syntactic center | Dedicated circuit forms inside Rhombus | Familiar Python statements under decorators and overloaded operators |

## Denotation and staging

RHDL is a deep embedding in Rhombus. Ordinary Rhombus values decide widths,
module structure, and generator control. Circuit `Value`s and `Place`s build
the operations and connections of the same
[core IR](../../rhdl/core/README.md) from every frontend profile.

PyMTL3 runs a component's `construct` method to create children, ports, wires,
interfaces, connections, and update blocks. An `@update` block denotes
combinational behavior; an `@update_ff` block denotes edge-triggered state
updates. Simulation passes derive an execution schedule for those concurrent
blocks. The [quick start](https://pymtl3.readthedocs.io/en/latest/intro/quickstart.html)
therefore reads like ordinary executable Python while still denoting hardware
inside the decorators.

Translation introduces a second boundary. Only the documented
[translatable RTL subset](https://pymtl3.readthedocs.io/en/latest/ref/passes-translation-intro.html)
of Python types, expressions, statements, loops, helper calls, and update
blocks denotes synthesizable RTL. A model can be valid Python and executable in
PyMTL3 without belonging to that subset. RHDL's dedicated circuit forms map
directly to graph construction, while PyMTL3's executable Python surface is
broader and its synthesizability more contextual.

PyMTL3's functional and cycle-level models use the same component framework to
express less structural behavior, including method-level transactions. Their
relationship to an RTL implementation is supplied by the designer and tests,
not by an automatic FL-to-RTL or CL-to-RTL lowering. RHDL currently standardizes
only the exact RTL denotation.

## Types and intrinsic guarantees

RHDL requires exact hardware types at operations and connections. `Bits`,
`Bool`, `SInt`, enums, `OneHot`, clocks, resets, records, and vectors can remain
distinct despite equal packed widths. Extension, truncation, and
representation casts are explicit. The separate `Value` and `Place` classes
also put read-versus-drive capability into the construction API.

PyMTL3's [`Bits` types](https://pymtl3.readthedocs.io/en/latest/ref/datatypes.html)
are fixed-width concrete values usable both in models and tests. `BitsN`
operations have defined width behavior, implicit truncation is rejected, and
some Python-integer or narrower-value contexts are inferred or zero-extended.
`BitStruct` gives packed fields a named aggregate type, while explicit helpers
cover concatenation, extension, and truncation.

PyMTL3 gains syntactic continuity from using the same concrete values during
execution, message construction, and RTL modeling. RHDL represents circuit
expressions as graph-owned symbolic values. Its nominal protocol identity also
lives outside the packed data type, while a PyMTL3 interface is primarily a
Python composition object containing signals or methods.

## Time, state, and scheduling

PyMTL3 groups combinational behavior into `@update` blocks. Ordinary Python
assignments to local temporaries and Python `if` or bounded `for` statements
provide behavioral RTL syntax; `@=` updates combinational signals. `@update_ff`
and `<<=` state the next value installed at a clock step. Component clock and
reset signals supply the conventional temporal context.

Those blocks are concurrent even though Python executes them sequentially in a
derived simulation schedule. Dependencies between reads and writes, plus any
explicit scheduling constraints, determine a valid order. The schedule is an
execution technique for a cycle-accurate model; it does not authorize the RTL
translator to move logic across an `@update_ff` boundary.

RHDL removes procedural block scheduling from its hardware denotation.
Combinational operations form a dataflow graph, operation listing order has no
runtime meaning, and pure combinational cycles are rejected. A register exposes
current state and a single next-state `Place`. Conditional assignments are
captured and become one final muxed drive; effects receive explicit guards.

Thus both RTL languages preserve author-chosen cycles, but they make
combinational intent differently local. PyMTL3 presents a process body that is
convenient for algorithms and direct execution. RHDL presents use/definition
and destination ownership relationships that are convenient for inspecting
the constructed circuit.

## Core composition unit and interfaces

PyMTL3 `Component`s compose hierarchically. Signal-level `Interface` objects
can contain ports, nested interfaces, arrays, and messages, and `//=` expresses
structural connections. At higher modeling levels, method ports and
method-based interfaces can represent transactions without committing to an
RTL handshake bundle.

RHDL separates hierarchy from protocol description. Modules own physical
ports and instances. A frontend interface descriptor adds nominal identity,
two complementary named roles, nested directions, refinement, supported
contracts, and parameter compatibility. Its endpoint lowers to ordinary
records and ports; linear handles can additionally require a ready-valid
topology value to be consumed once during elaboration.

PyMTL3's structural interface objects make it easy to keep a recognizable
component shape across FL, CL, and RTL models. RHDL's nominal descriptors make
same-shaped but semantically different RTL protocols noninterchangeable. The
former favors model substitution by convention; the latter favors static
protocol identity after physical signals have been chosen.

## Locality, predictability, and syntax

PyMTL3's greatest syntactic advantage is familiarity. A combinational block
looks like a short Python procedure, loops and conditions reuse Python grammar,
and concrete `BitsN` values print and execute naturally. Decorators and the
`@=` / `<<=` distinction provide a compact visual marker for combinational and
sequential intent.

The cost is contextual meaning. Python `if` in `construct` chooses generated
structure; Python `if` in `@update` denotes a mux-like hardware alternative;
the same code in an unrestricted helper may be simulation-only. Whether a
construct is translatable depends on the enclosing block and accepted subset.
Understanding drive ownership or block ordering can also require examining the
whole component schedule rather than only one assignment.

RHDL uses less familiar graph-construction forms. `Value` versus `Place` makes
an expression's direction explicit, and runtime alternatives use dedicated
selection forms. A source-level connection immediately constructs an IR edge,
so the generated structure is predictable. This adds ceremony for simple
behavioral logic, while Rhombus functions and macros provide abstraction
without changing the final RTL semantics.

## Language-level judgment

PyMTL3 offers the more economical surface for executable behavioral RTL. A
small amount of Python syntax covers elaboration, update logic, concrete
values, and multiple modeling levels, and decorated blocks are a natural unit
for related equations. That reuse is powerful, but it is context-sensitive:
the enclosing phase and accepted subset determine what otherwise ordinary
Python denotes.

RHDL is more orthogonal as an exact RTL construction language. Exact types and
the `Value` / `Place` split expose ownership and final connectivity without
consulting a simulator schedule or translation subset. PyMTL3's wider modeling
continuum is genuine abstraction expressivity, however; RHDL's smaller core
does not replace the ability to state useful non-RTL models in the same
component vocabulary.

## Lessons for RHDL

1. PyMTL3 demonstrates that executable FL, CL, and RTL models can share a
   component vocabulary without claiming that the higher levels synthesize to
   the lower one. RHDL could adopt such models as separate denotations.
2. Update-block syntax is economical for behavioral combinational logic, but a
   compatible RHDL form should still lower immediately to explicit values,
   places, muxes, and effects.
3. Concrete executable bit values improve examples, testing, and direct
   interpretation; they can coexist with graph-owned symbolic values.
4. Structural model substitution and nominal protocol compatibility solve
   different composition problems. RHDL should preserve the latter even if it
   adds higher-level executable models.

## Sources

- PyMTL3 [official documentation](https://pymtl3.readthedocs.io/)
- PyMTL3 [quick start](https://pymtl3.readthedocs.io/en/latest/intro/quickstart.html)
- PyMTL3 [hardware data types](https://pymtl3.readthedocs.io/en/latest/ref/datatypes.html)
- PyMTL3 [RTL translation language](https://pymtl3.readthedocs.io/en/latest/ref/passes-translation-intro.html)
- PyMTL3 [primary repository](https://github.com/pymtl/pymtl3)
- PyMTL3 [multi-level modeling paper](https://www.csl.cornell.edu/~cbatten/pdfs/batten-pymtl3-nvidia2023.pdf)
- RHDL [architecture](../../rhdl/README.md), [core semantics](../../rhdl/core/README.md),
  [frontend staging](../../rhdl/frontend/README.md), and
  [interface layer](../../rhdl/frontend/layers/README.md#interfaces)
