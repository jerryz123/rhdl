<!-- Indexes RHDL's language and compiler comparisons and defines the common rubric used by the suite. -->

# RHDL comparison guide

This directory compares the current RHDL implementation with hardware
languages, embedded construction libraries, research languages, and compiler
IRs that make materially different design choices. The goal is not to produce
a feature-count leaderboard. Each comparison starts from what a source program
denotes, then asks how time, state, concurrency, types, and reusable
abstractions compose—and how clearly the syntax exposes those semantics.

The comparisons describe the repository as of **2026-08-15**. RHDL and the
other projects are evolving, so capability claims should be read as
snapshot-specific.

## Method

These are semantic comparisons rebuilt from the current supported models. For
each system, the analysis proceeds in this order:

1. Establish RHDL's current behavior from the live core, frontend language,
   verifier, and lowering contract.
2. Establish the other system's model from its official manual, reference,
   papers, and primary repository.
3. Compare systems at the same level. An accelerator IR is not treated as
   though it were a complete RTL authoring language, and a host library is not
   credited with semantics supplied only by a downstream tool.
4. Separate circuit expressivity from abstraction expressivity, static
   guarantees, and syntactic economy.

The conclusions are about supported public models, not whether either system
could be modified until it implements the other.

## Current RHDL baseline

The individual documents compare against the same RHDL model:

- Rhombus host computation elaborates hardware into one public,
  backend-independent IR.
- Hardware data has elaboration-known, explicit widths. Ordinary connections,
  arithmetic, and representation casts do not silently resize values.
- Readable `Value`s and driveable `Place`s are distinct, and every place has
  one effective driver. Hardware alternatives become explicit mux or guarded
  effect logic rather than source-ordered last-connect behavior.
- Frontend layers add authoring policy and notation without defining a second
  hardware IR. The optional CIRCT backend consumes only verified core IR.
- Interfaces have nominal identities, named complementary roles, refinement,
  structural member checks, and linear topology handles.
- Current sequential policy is deliberately narrow: rising-edge clocks and,
  when reset is present, active-high synchronous reset, without clock-domain
  identities in the type system.

The implementation architecture is documented in
[`rhdl/README.md`](../../rhdl/README.md), detailed core semantics in
[`rhdl/core/README.md`](../../rhdl/core/README.md), frontend behavior in
[`rhdl/frontend/README.md`](../../rhdl/frontend/README.md), and reusable
protocols in [`rhdl/std/README.md`](../../rhdl/std/README.md).

## What this guide means by expressivity

Two languages can ultimately describe the same circuit while differing
radically in what programmers can say directly. The comparisons distinguish:

1. **Circuit expressivity:** which hardware behaviors the core semantics can
   denote.
2. **Abstraction expressivity:** whether reusable functions, modules, rules,
   interfaces, protocols, or timing contracts preserve the important meaning
   when composed.
3. **Static expressivity:** which relationships can be stated and checked in
   types or other compile-time contracts.
4. **Syntactic economy:** how much ceremony and nonlocal knowledge ordinary
   designs require, and whether concise syntax still has predictable meaning.

The essays focus on these language-level questions. Library inventories,
vendor integrations, and ecosystem maturity are intentionally out of scope.

“Clean” and “elegant” have concrete meanings here:

- **Orthogonality:** a small set of rules explains many constructs.
- **Closure under composition:** an abstraction's result can be nested, passed,
  transformed, and connected without dropping to a privileged lower layer.
- **Local reasoning:** types and nearby syntax explain priority, timing, state,
  and ownership without hidden global action at a distance.
- **Proportionate notation:** common hardware is concise without making unusual
  hardware implicit or ambiguous.
- **Semantic leverage:** a high-level construct rules out real classes of bad
  hardware rather than merely shortening spelling.

## Overall judgment

RHDL's strongest language idea is the combination of readable `Value`,
driveable `Place`, one effective driver, exact semantic types, and intentional
module boundaries. Those concepts reinforce one another and remain visible in
one verified IR. Among direct RTL construction languages, that gives RHDL
unusually local and reconstructable meaning. Its price is real: explicit
adaptation and selection take more syntax than inferred widths, unified signal
objects, procedural update blocks, or default-then-override assignment.

Several comparison systems have a genuinely stronger abstraction in a narrower
domain. Hardcaml can interpret one combinational description concretely or as a
signal graph. Clash states dimensions and clock domains in a powerful static
type system. Bluespec composes guarded atomic actions before choosing their
schedule. HazardFlow makes transfer and backpressure one interface algebra.
Filament makes relative time and resource reuse compositional types. Calyx,
DSLX/XLS, and PyMTL3 each retain a useful semantic level that RHDL deliberately
does not model.

Those are not mere conveniences. Each would add a new proposition—about
interpretation, generic types, atomicity, transfer, timing, scheduling, or
modeling level—that needs its own semantics and a named lowering into exact
RHDL hardware. At the direct-construction level, Chisel, Amaranth, SpinalHDL,
Hardcaml, and disciplined SystemVerilog expose the more immediate design trade:
RHDL usually gains locality and loses syntactic economy.

## Comparison map

| Comparison | Kind | Primary question for RHDL |
|---|---|---|
| [Chisel](chisel.md) | Scala construction language | Which model makes widths, connection priority, hierarchy, and parameterized structure more direct and predictable? |
| [Amaranth](amaranth.md) | Python construction language | How do assignment, shape, domain, and structural abstractions compare while both languages remain transparent RTL construction systems? |
| [SpinalHDL](spinalhdl.md) | Scala construction language | How do its data objects, assignment rules, direction inference, and clock-domain scopes compare with RHDL's explicit destinations and roles? |
| [Bluespec](bluespec.md) | Rule-based hardware language | Should state conflicts remain explicit in wiring, or become guarded atomic actions scheduled by the compiler? |
| [Clash](clash.md) | Functional synthesizing language | Which invariants should live in a powerful static type system rather than an explicit construction IR? |
| [Hardcaml](hardcaml.md) | OCaml construction library | Can derived host-language interfaces and a direct signal graph offer a simpler compositional API? |
| [HazardFlow](hazardflow.md) | Typed dataflow research language | Can ready-valid behavior, backpressure, and protocol transformation be expressed as one typed interface algebra? |
| [Filament](filament.md) | Timing-typed accelerator language | Should latency, initiation interval, and resource availability become statically checked authoring contracts? |
| [Calyx](calyx.md) | Accelerator compiler IR | Does the `cells` / `wires` / `control` split express scheduled actions more cleanly than constructing their controller RTL directly? |
| [DSLX and XLS](dslx.md) | Functional dataflow language and HLS compiler | When should scheduling and pipelining be compiler decisions rather than exact source-visible structure? |
| [PyMTL3](pymtl3.md) | Multi-level Python modeling framework | Can update blocks and method interfaces unify functional, cycle-level, and RTL models without obscuring which model denotes hardware? |
| [SystemVerilog](systemverilog.md) | Standard hardware language | Does RHDL's smaller expression-and-place model improve compositional reasoning over continuous assignments, procedural blocks, nets, and variables? |

## Highest-value reading paths

For the closest tests of RHDL's current construction model, start with
[Amaranth](amaranth.md), [SpinalHDL](spinalhdl.md), and
[Hardcaml](hardcaml.md).

For fundamentally different semantics, read [Bluespec](bluespec.md),
[Clash](clash.md), [HazardFlow](hazardflow.md), and
[Filament](filament.md). These comparisons ask whether transactions, domains,
protocol hazards, or time should become first-class static abstractions.

For different abstraction levels and scheduling semantics, read
[Calyx](calyx.md), [DSLX/XLS](dslx.md), and [PyMTL3](pymtl3.md). They evaluate
RHDL's commitment to exact construction and one public RTL-oriented denotation.

[SystemVerilog](systemverilog.md) is the conventional-language baseline. Its
mixture of continuous, procedural, event-driven, net, and variable semantics
makes it a useful test of whether RHDL's smaller core is genuinely clearer or
merely less expressive.

## Common evaluation rubric

Every comparison covers the following questions:

- What does a source program denote, and which decisions happen before the
  resulting hardware runs?
- Are widths, domains, directions, and interface identities inferred,
  structural, nominal, or statically typed?
- How are state updates, assignment conflicts, priority, and concurrency
  represented?
- Do reusable abstractions compose as expressions, signal bundles, modules,
  methods, rules, streams, or typed transformations?
- How local is the meaning of a line of code? Which surrounding scopes,
  scheduling rules, or inference passes can change it?
- Where does RHDL need fewer concepts or make hardware structure and contracts
  more direct, and where is its syntax merely more verbose?
- What core behaviors, abstractions, or static relationships can the comparison
  system state that RHDL cannot?
- Which ideas fit RHDL's exact-construction model, and which would change that
  model rather than extend it?

The documents cite official language manuals, project documentation, standards
pages, or primary project repositories. Conclusions about RHDL are grounded in
the current repository rather than inferred from its project description
alone.
