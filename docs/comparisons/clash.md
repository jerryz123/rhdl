<!-- Compares RHDL's explicit construction language with Clash's typed functional synthesis semantics. -->

# RHDL and Clash: explicit construction versus typed functional synthesis

## Scope and thesis

*Snapshot: 2026-08-15.*

RHDL and Clash both describe synchronous circuits without asking an HLS
scheduler to choose register placement. They differ in what their source
language makes primary. RHDL executes Rhombus generators that construct an
explicit hardware graph. Clash compiles a synthesizable Haskell program in
which pure functions, algebraic data, and domain-indexed streams are the
hardware vocabulary.

Clash is more elegant when circuit structure follows functional composition:
map a function over a vector, lift it over time, or derive a state machine from
a pure transition function. RHDL is more explicit when circuit construction
itself is the subject: introduce a destination, drive it once, instantiate a
register, and preserve a chosen module boundary. The core question is whether
functional uniformity or explicit graph-construction semantics gives the
better local model for the design at hand.

## Summary

| Question | RHDL | Clash |
|---|---|---|
| Source denotes | Host elaboration that constructs one verified operation graph | A normalizable Haskell description of combinational or synchronous functions |
| Core composition unit | `Value`/`Place` connections and explicit circuit instances | Typed functions and function application |
| Time | Explicit registers, memories, clocks, and next-state drives | `Signal dom a` streams plus explicit state primitives and combinators |
| Static dimension | Realized hardware types checked during elaboration and verification | Widths, lengths, data types, and domains participate in Haskell types |
| Concurrency | The constructed graph is concurrent; no scheduler | Pure signal network is concurrent; no general operation scheduler |
| Main source of locality | Source forms say which hardware object is being constructed | One functional syntax composes values, structures, and temporal signals |
| Syntactic compression | Direct for named RTL structure and local control | High for generic datapaths, vectors, products, and state machines |

## Denotation and staging

An RHDL `circuit` is a Rhombus generator. During `elaborate`, ordinary host
functions, loops, collections, and parameters determine what hardware exists.
Hardware objects then create nodes in the
[single public IR](../../rhdl/core/README.md). Generation chooses structure,
while `when`, `switch`, and mux operations denote runtime hardware selection.

Clash is not a deep embedding with a separate signal AST presented as a
library value. It uses Haskell syntax and GHC's typed program representation,
then normalizes the definitions reachable from a synthesizable top entity.
The [Clash FAQ](https://docs.clash-lang.org/compiler-user-guide/general/faqs.html)
therefore describes ordinary `if`, guards, pattern matching, higher-order
functions, and algebraic data as potential circuit description. The types and
normalization context determine which expressions become structure and which
are evaluated during compilation.

Clash's uniformity is a genuine language advantage: the same abstraction
mechanisms used for pure software functions organize hardware. Its staging
boundary is correspondingly less syntactically prominent. RHDL requires more
hardware-specific notation, but a reader can identify elaboration-time and
runtime constructs without first following normalization and specialization.

## Core composition unit and syntax

RHDL composition is constructive. `sum <== a + b` reads as a structural claim:
the output place `sum` is driven by this expression. `reg state(...)` introduces
a state element. A circuit call creates a fresh module definition; `inst`
creates an instance boundary. Records and vectors remain hardware values, while
the `Value`/`Place` distinction says which expressions are readable and which
are driveable.

Clash composition is applicative. A combinational circuit commonly has type
`a -> b`; a synchronous circuit has a type involving `Signal dom a`. Function
composition wires components, higher-order functions generate repeated
structure, and `Vec n a` makes regular hardware look like ordinary functional
programming. `Bundle` relates products of signals to signals carrying products,
so structural rearrangement remains typed function composition.

This syntax has exceptional economy for regular datapaths. A vector `map` or
`fold` states the mathematical structure without naming every intermediate
wire. RHDL can use host functions and loops to generate the same network, but
the result is expressed through construction actions rather than by giving the
network a pure functional denotation. Conversely, RHDL's explicit destination
syntax is clearer when output ownership, final connectivity, or a chosen
module boundary is the important fact.

## Time, state, and concurrency

Clash gives synchronous time a first-class type constructor. The tutorial
describes `Signal dom a` as an infinite sequence of `a` samples, one per tick in
domain `dom`. `register` delays a signal by a cycle, while `mealy` and `moore`
lift pure state-transition functions into sequential machines. Feedback is
expressed through the functional network, with state primitives breaking the
cycle.

RHDL instead represents the state object directly. A register exposes current
state as a readable value and next state as a driveable place. Guarded writes
become enables or muxes; absence of a guarded register write means hold. The
clock is an explicit hardware value, although `sync_circuit` can provide an
ambient clock/reset policy as authoring shorthand.

Neither language performs general latency scheduling. In both, adding a
register changes the authored cycle behavior. Clash's compiler normalizes the
functional program into a netlist, so exact sharing and hierarchy are not the
primary source contract. RHDL constructs those graph and hierarchy choices
directly. Clash gives a cleaner equational account of time; RHDL gives a more
literal account of the state elements implementing it.

## Types and intrinsic guarantees

Clash's strongest language-level advantage is the reach of its static types.
`Unsigned n`, `Signed n`, `BitVector n`, `Index n`, and `Vec n a` put widths and
cardinalities in types. Algebraic data types and `BitPack` relate semantic
values to packed representations. Polymorphic functions can quantify over
sizes, element types, and constraints, so one definition can state
relationships among an entire family of circuits.

The domain parameter of `Signal dom a` is equally important. A synthesis domain
records an identity, period, active edge, reset synchrony and polarity, and
initialization behavior. Distinct domain indices cannot be directly confused,
and crossings require an operation whose type explicitly relates the domains.
That is a strong composition guarantee; it does not by itself prove the analog
correctness or metastability behavior of an arbitrary CDC construction.

RHDL uses elaboration-time hardware type objects such as `Bits(width)`, records,
vectors, signed values, enums, and one-hot selectors. Connections require exact
types, conversions are explicit, and the verifier checks the concrete graph.
Its open capabilities state which operations a type supports without reducing
every type to bits. But widths and clock-domain relationships are not
propositions in a static source type system, and current `Clock` and `Reset`
values carry no domain index.

The difference is not simply “more typing.” Clash proves generic relationships
before netlist construction; RHDL verifies ownership and realized types after
construction. Clash's inferred types can make a compact definition unusually
powerful, while RHDL's explicit type objects make the final representation
easy to inspect.

## Locality and predictability

Clash offers semantic locality at the function boundary. A pure function's
result depends only on its arguments, and a transition function can be tested
without procedural update ordering. Strong inference removes annotation noise.
The cost is structural distance: specialization, normalization, inlining, and
sharing decisions stand between a source expression and the eventual netlist.

RHDL offers structural locality. A `<==` names a destination and its driver;
register creation and hierarchy are explicit; one effective driver is a global
invariant. The cost is syntactic ceremony for transformations that are
mathematically just function composition. Host-generated repetition can also
look less declarative than a typed `map` over `Vec n a`.

Protocol composition exposes another boundary. RHDL has nominal two-role
interfaces whose directions and identities survive authoring composition.
Clash's base composition unit is a function over typed data or signals; a
handshake discipline is not implied by `Signal` itself. Clash can encode such
disciplines in types, but they are not part of the core signal denotation.

## Language-level judgment

Clash has the more unified surface language. Pure functions, products,
algebraic data, higher-order structure, and temporal signals form a small set
of orthogonal concepts with unusually high reuse. Its best abstractions feel
like mathematics that happens to synthesize. Domain-indexed signals also make
an important physical distinction statically visible.

RHDL has the more explicit construction semantics. `Value`, `Place`, one
driver, explicit state, and dedicated hardware control form a compact language
for saying exactly which RTL graph should exist, and it preserves intentional
structure without depending on normalization.

The systems therefore optimize different forms of elegance. Clash minimizes
the conceptual distance between reusable functions and circuits. RHDL
minimizes the conceptual distance between source construction and the realized
hardware graph. Neither should be judged by whether it can manually reproduce
the other's final Boolean network.

## Lessons for RHDL

1. Make clock domains semantic descriptors rather than unrelated clock/reset
   values. Domain identity and reset policy should compose as one contract.
2. Let generic circuit APIs state relationships among widths and shapes, not
   merely validate each concrete host parameter after entry.
3. Preserve RHDL's explicit realized types and graph even if richer static
   contracts are added; they answer a different and valuable question.
4. Prefer pure, expression-oriented helpers for combinational transformations.
   Clash shows how much syntax disappears when reusable datapaths denote
   functions instead of construction procedures.
5. Do not adopt `Signal` as decorative terminology. Making time part of a type
   changes the denotation of composition and should be done only with domain
   and state semantics that justify it.

## Sources

- RHDL [core semantics](../../rhdl/core/README.md),
  [frontend model](../../rhdl/frontend/README.md), and
  [frontend layers](../../rhdl/frontend/layers/README.md)
- [Clash compiler model](https://docs.clash-lang.org/compiler-user-guide/general/index.html)
- [Clash FAQ](https://docs.clash-lang.org/compiler-user-guide/general/faqs.html)
- [Clash Prelude: signals, domains, and state](https://docs.clash-lang.org/compiler-user-guide/developing-hardware/prelude.html)
- [Clash first-circuit tutorial](https://docs.clash-lang.org/tutorial/first-steps/first-circuit.html)
