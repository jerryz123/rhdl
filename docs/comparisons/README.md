<!-- Indexes RHDL's language and compiler comparisons and defines the common rubric used by the suite. -->

# RHDL comparison guide

This directory compares the current RHDL implementation with hardware
languages, embedded construction libraries, research languages, and compiler
IRs that make materially different design choices. The goal is not to produce
a feature-count leaderboard. Each comparison starts from what a source program
denotes, then asks how time, state, concurrency, types, and reusable
abstractions compose—and how clearly the syntax exposes those semantics.

The comparisons describe the repository as of **2026-08-17**. RHDL and the
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
- Core IR separates readable definitions (`Value`) from bindable endpoints
  (`Place`). Every endpoint receives one effective driver, and hardware
  alternatives become explicit mux or guarded-effect logic rather than
  source-ordered last-connect behavior. The standard frontend presents both
  through a largely common hardware surface and selects the readable or
  bindable facet from context.
- Frontend layers add authoring policy and notation without defining a second
  hardware IR. The optional CIRCT backend consumes only verified core IR.
- Interfaces have nominal identities, named complementary roles, refinement,
  structural member checks, and linear topology handles.
- The standard flow layer interprets those generic handles as `Valid`,
  ready-valid, and credited paths. Ordinary unary functions compose serial,
  parallel, fan-in, fanout, rendezvous, routing, and buffering topology without
  adding flow-specific nodes to the core IR.
- The standard decode layer carries extension-defined exact literals into
  recursively typed aggregate patterns and then into unordered, non-overlapping
  relations with partially specified aggregate outputs. Relations compose as
  host data before one decoder is elaborated.
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
An internal IR distinction does not count as language expressivity by itself;
the guide credits it only when it changes what an author can state, compose,
or have checked.

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

RHDL's strongest language idea is its exact-construction discipline: exact
semantic types, one explicit effective driver per destination, priority stated
as selection or guarding, explicit current/next-state relationships, and
intentional module boundaries, all preserved in one verified IR. Among direct
RTL construction languages, that gives RHDL unusually local and reconstructable
meaning. Its price is real: explicit adaptation and selection take more syntax
than inferred widths, procedural update blocks, or default-then-override
assignment.

The core `Value`/`Place` split is a clean representation of that discipline,
not an independent expressivity advantage. A capability-aware unified signal
object can enforce the same read, bind, ownership, type, and exactly-one-driver
rules. RHDL's own frontend already moves in that direction: outputs, wires, and
registers use a common authoring surface whose read or drive interpretation
depends on context. The comparison therefore credits RHDL for explicit binding
and priority semantics, not for having two IR classes.

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

## Flow composition across the comparison set

Flow composition is an important exception to the claim that RHDL generally
trades concision for locality. The current
[`std/flow`](../../rhdl/std/README.md#flow-control-circuits) surface is itself a
compact topology language. A configured stage is an ordinary unary host
function, so the same `|>` notation composes concrete endpoints and detached
paths. The result may change cardinality, split into independent parallel
branches, terminate at a sink, or use explicit adapters among selected
`Valid`, `Decoupled`, `Irrevocable`, and credited paths. Pure adapters remain
direct wiring, while stateful or structurally meaningful stages remain visible
instances rather than hidden scheduling.

This abstraction is intentionally implemented by the generic frontend
[`InterfaceHandle`](../../rhdl/frontend/layers/interface.rhm), not by a second
flow graph or new core operations. It is evidence for the project's layering
claim: a minimal exact IR can support a substantially richer composition
language that elaborates away.

| Comparison system | Flow-composition judgment |
|---|---|
| Chisel | Standard ready-valid interfaces and components do not form one comparably uniform topology algebra; RHDL makes nontrivial transport graphs more direct. |
| SpinalHDL | The closest direct peer: `Stream` composition is at least as fluent and more mature in timing control, while RHDL makes protocol strength and single-use topology ownership more explicit. |
| Amaranth | Its deliberately minimal stream contract is stricter than `Decoupled`, but RHDL provides a much broader closed composition surface. |
| Hardcaml | `hardcaml_handshake` has the purer host-typed reusable arrow; RHDL's nominal endpoints and flow stages express much richer ready-valid meaning while topology materialization remains one-shot. |
| PyMTL3 | Ready-valid interfaces connect cleanly, but larger paths remain explicit component wiring rather than first-class transformations. |
| HazardFlow | Its payload/resolver/transfer abstraction and generic FSM form the more general handshake algebra; RHDL instead verifies the complete realized combinational graph. |
| Clash Protocols | `Circuit` is the more general reusable typed circuit algebra; RHDL gives buffering, readiness paths, ownership, and module boundaries more source-visible structure. |
| Bluespec | Guarded atomic rules compose multi-resource transactions and let the compiler schedule conflicts; RHDL is more predictable for author-controlled elastic microarchitecture. |
| Filament | Timeline and initiation-interval types provide stronger fixed-schedule guarantees; RHDL handles runtime stalls and backpressure that are outside Filament's design center. |
| Calyx | Calyx composes multi-cycle actions and control schedules rather than continuously active token paths. |
| DSLX/XLS | Proc channels default to a higher-level behavioral network; metadata and code-generation policy can constrain buffering during lowering, while RHDL exposes the exact transport topology in source. |
| SystemVerilog | Interfaces and assertions can encode and check any chosen convention, but the language defines no standard first-class ready-valid composition algebra. |

The current weakness is semantic enforcement rather than structural reach.
`Irrevocable` stability is documented but not backed by generated assertions.
Moreover, [`map_flow`](../../rhdl/std/flow/map.rhdl) and
[`demux_flow`](../../rhdl/std/flow/demux.rhdl) preserve an irrevocable protocol
even though their bodies may capture changing ambient hardware. Those helpers
can therefore promise stability that their implementation does not establish.
The layer also has no generic arbitrary forward/backward protocol algebra and
no compositional latency, initiation-interval, deadlock, fairness, or liveness
contracts.

The principled next step is consequently not a flow-specific core IR or a
larger component inventory. It is an enforceable distinction between
payload-only transformations and transformations that observe live hardware,
followed by a protocol-polymorphic stage abstraction over the existing generic
interface subsystem.

## Decode, patterns, and literals across the comparison set

Decode is one area where RHDL gains both locality and syntactic economy. The
abstraction is a sequence of three ordinary, separately meaningful layers:

1. [`HardwareLiteral`](../../rhdl/frontend/support/hardware-literal.rhm) is an
   open host protocol for one exact packed image of a semantic hardware type.
   Built-in scalars, enums, records, vectors, and extension-defined packable
   types use the same protocol.
2. [`Pattern`](../../rhdl/std/decode/pattern.rhdl) is a host-side typed bit cube,
   deliberately not a connectable hardware value. Exact literals constrain all
   bits; `_` leaves a field or element unconstrained; nested patterns preserve
   partial care; and `partial_pattern` gives sparse named record syntax.
3. [`DecodeTable`](../../rhdl/std/decode/table.rhdl) turns input and output
   patterns into an unordered relation with exact common types, an explicit
   default, and pairwise-disjoint input cubes. Rows concatenate as lists,
   `lift_decode_inputs` changes the input domain, and `zip_decode_cases` forms an
   output product before one callable `DecodeGen` is elaborated.

The individual mechanisms are established ideas. Typed literals, masked bit
patterns, truth tables, output don't-cares, and Espresso minimization all exist
elsewhere. Exact aggregate constants in particular are routine in several
comparison systems; RHDL's literal-level distinction is the open protocol that
lets built-in and extension-defined semantic types feed the same recursive
pattern machinery. Its broader contribution is their integration as one typed
relation abstraction: the same pattern vocabulary describes named aggregate
selectors and sparse named aggregate results, independent control relations
can be combined before hardware exists, and one decoder plan can account for
validity and every output field.

| Comparison system | Decode-relation judgment |
|---|---|
| Chisel | The closest peer. [`BitPat`, `TruthTable`, and `DecodeTable`](https://www.chisel-lang.org/docs/explanations/decoder) also support partial inputs and outputs, typed result fields, multi-output Espresso, and QMC fallback. RHDL adds recursive semantic aggregate patterns, exact input/output type identity, explicit relation lifting/zipping, and uniform overlap rejection; Chisel's `BitSet` algebra and column-oriented `DecodeField` model are stronger in other directions. |
| SpinalHDL | [`MaskedLiteral`](https://spinalhdl.github.io/SpinalDoc-RTD/master/SpinalHDL/Data%20types/bits.html) and [`DecodingSpec`](https://spinalhdl.github.io/SpinalDoc-RTD/master/SpinalHDL/Libraries/utils.html) provide flat masked selectors and Boolean minimization. RHDL's recursively typed aggregate relation and structured partial outputs are more general. |
| Amaranth | [`Value.matches` and `Switch`/`Case`](https://amaranth-lang.org/docs/amaranth/latest/guide.html#control-flow) give concise flat masked matching and ordered choice. They do not form a standard typed partial-output relation or multi-output decoder generator. |
| SystemVerilog | `casez`, `case inside`, packed aggregates, and `unique`/`priority` cover a broader range of local decisions. They remain control-flow syntax rather than one reusable relation value with composition and frontend minimization. |
| Bluespec | Nested typed patterns, wildcard bit literals, bindings, and guards make one match expression more general than `DecodeGen`. RHDL is narrower but makes the complete finite relation first-class, unordered, and directly optimizable. |
| Clash | Haskell patterns and [`bitPattern`](https://hackage-content.haskell.org/package/clash-prelude-1.8.2/docs/Clash-Sized-BitVector.html) support algebraic matching and bit capture. Clash has no standard equivalent to RHDL's typed partial-output table algebra. |
| DSLX/XLS | DSLX [`match`](https://google.github.io/xls/dslx_reference/#match) supports nested patterns, bindings, alternatives, and ranges, while XLS performs general multi-level optimization. RHDL's matching language is less general but its decoder-specific input and output care is more explicit. |
| Hardcaml and PyMTL3 | Both have typed aggregate constants and can generate comparisons and muxes through host code, but neither standard authoring model provides a recursively masked aggregate relation with partial outputs and multi-output minimization. |
| HazardFlow, Calyx, and Filament | Their central abstractions concern transfer hazards, scheduled actions, and timeline types. Equivalent decoder hardware can be constructed, but these languages expose no comparable standard decode-relation abstraction. |

This specialization is a real source-language advantage, not greater Boolean
expressivity. RHDL directly states finite constant relations; it does not bind
wildcarded fields, attach arbitrary guards, compute row results from captures,
express ranges as primitives, or represent ordered priority between overlapping
rows. Bluespec, Clash, DSLX, and SystemVerilog are more expressive for those
general matching tasks. RHDL's restriction is what makes global validation and
minimization straightforward.

The hardware-quality claim is similarly bounded. `DecodeGen` can use output
don't-cares, minimize same-default output groups together, merge identical
products across groups, and elaborate balanced product AND and output OR
trees. Validity and payload remain one semantic table, but their different
defaults normally put them in separate minimization runs. The current
[RV64I ALU relation](../../cores/ricket/decode/alu-ctrl.rhdl) demonstrates a
more compact shared two-level cover than RHDL's own unminimized mux-chain
fallback: in the snapshot audit, its 28-row relation became 20 shared PLA
products, while the 52-row complete relation became 31; fallback lowering
retained one masked comparison and mux arm per row. Those are structural
counts, not gate-count, area, or timing measurements. They do not establish
universal PPA superiority: Chisel uses the same class of multi-output Espresso
optimization, Espresso is a target-independent two-level heuristic, and a
strong downstream optimizer may choose a better multi-level or LUT-specific
implementation.

The current seams are important. `Pattern` denotes only one cube rather than a
set algebra. `zip_decode_cases` requires exactly identical input partitions
instead of refining compatible cubes. The low-level `Pattern(~value, ~care)`
constructor also requires the care mask to have the value's semantic type even
though care is representation-level information. Automatic Espresso discovery
makes the chosen IR environment-dependent, and the returned cover is checked
for syntax and dimensions but not semantic equivalence to the original
relation. The optimized path also commits output don't-cares before
target-aware synthesis, whereas the core
[`rtl.decode`](../../rhdl/core/README.md#operation-model) contract can
preserve that freedom longer.

The principled next steps are therefore a first-class pattern-set algebra,
partition-refining relation products, deterministic optimizer selection, and
equivalence checking. Keeping the semantic relation intact until a backend pass
chooses PLA, mux, AIG, or LUT structure would preserve RHDL's strongest part:
one concise typed specification without pretending that one lowering is always
best hardware.

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

For the flow-composition thread specifically, start with
[SpinalHDL](spinalhdl.md) as the closest direct peer, then
[HazardFlow](hazardflow.md) and [Clash](clash.md) for more general protocol
algebras, [Bluespec](bluespec.md) for atomic transaction composition, and
[Filament](filament.md) for static timing guarantees.

For typed pattern and decoder construction, start with [Chisel](chisel.md) as
the closest direct peer, then [SpinalHDL](spinalhdl.md) and
[Amaranth](amaranth.md) for masked RTL matching, and [Bluespec](bluespec.md),
[Clash](clash.md), and [DSLX/XLS](dslx.md) for more general pattern languages.

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
- Does an internal representation distinction produce an author-visible,
  compositional guarantee, or only a convenient compiler normal form?
- How are state updates, assignment conflicts, priority, and concurrency
  represented?
- Are exact literals, partial patterns, and decode tables merely syntax, or do
  they form typed values that can be validated, transformed, and optimized as
  a relation before hardware construction?
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
