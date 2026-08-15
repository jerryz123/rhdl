<!-- Compares RHDL's exact construction semantics with SystemVerilog's core design language. -->

# RHDL and SystemVerilog

## Scope and thesis

Snapshot: 2026-08-15. “SystemVerilog” here means the core design semantics of
[IEEE Std 1800-2023](https://standards.ieee.org/ieee/1800/7743/). The standard
also defines event-driven testbench, assertion, coverage, object, and foreign
interface facilities, but those are outside this core-design comparison.

Two levels must remain separate. Full SystemVerilog denotes event-driven
simulation with four-state values and many constructs that do not synthesize.
Its common synthesizable RTL subset denotes gates, state, memories, and
hierarchy at roughly the same level as RHDL. Synthesis support is tool- and
target-dependent; the IEEE language definition is not itself a promise that
every construct maps to hardware.

Within the common RTL subset, SystemVerilog is compact and extraordinarily
expressive, but meaning often depends on procedural context, event controls,
assignment form, sizing, signedness, and four-state rules. RHDL deliberately
accepts a smaller model: deterministic host elaboration, exact hardware types,
one effective driver, dataflow combinational logic, and explicit state. The
trade is syntactic breadth for local predictability.

## Summary

| Concern | RHDL | SystemVerilog |
|---|---|---|
| Semantic unit | Elaborated module in a verified two-state dataflow IR | Module/interface design plus event-driven process semantics |
| Staging | Arbitrary Rhombus host computation constructs a concrete design | Parameters, constant expressions, generate, macros, and elaboration |
| Time | Explicit rising-edge registers and memory/effect operations | Event controls, procedural regions, blocking/nonblocking assignment, delays in full language |
| Assignment | One effective driver per `Place` | Variables follow procedural-driver rules; nets can resolve multiple drivers |
| Types | Exact semantic hardware types and explicit conversion | Rich two-/four-state, signed, packed/unpacked, aggregate, and context-sized types |
| Composition | Modules plus nominal complementary protocol roles | Modules, interfaces/modports, packages, and retained parameters |
| Compiler freedom | Preserve explicit cycle and resource structure | RTL synthesis preserves sequential boundaries; full behavioral syntax is broader than synthesis |
| Syntactic center | Circuit construction forms inside Rhombus | Declarations plus continuous and procedural HDL statements |

## Denotation and staging

RHDL executes Rhombus while elaborating a design. Host `if`, loops, functions,
and data structures decide which hardware exists. Hardware `when`, `switch`,
registers, memories, and connections create operations in one
[core IR](../../rhdl/core/README.md). The resulting module graph is the
semantic design; generated SystemVerilog is a lowering artifact.

SystemVerilog has its own compile-time and elaboration language. Parameters,
local parameters, constant functions, generate conditionals and loops, module
instances, interfaces, and preprocessor macros specialize hierarchy before
simulation. Unlike RHDL's host evaluation, retained parameters remain part of
the HDL module abstraction and can be selected by downstream instantiators.

After elaboration, SystemVerilog processes execute in standardized event
regions. Continuous assignments, `always_comb`, `always_ff`, `always_latch`,
`initial`, tasks, functions, and assertion sampling have distinct rules.
Synthesizers recognize a disciplined subset of those meanings as hardware.
RHDL has no authored event scheduler: operation order is not runtime order,
combinational logic is a graph, and state changes only through explicit
sequential operations.

This difference remains even when both sources synthesize to the same circuit.
SystemVerilog describes that circuit through a mixture of structural and
procedural language semantics. RHDL constructs a structural/dataflow object
directly.

## Types and intrinsic guarantees

Synthesizable SystemVerilog includes two-state and four-state integral values,
signed and unsigned packed arrays, unpacked arrays, structs, unions, enums, and
user typedefs. Nets and variables are separate categories. Full SystemVerilog
adds dynamic and object-oriented types that are not ordinary hardware data.

Expression width and signedness can be self-determined or supplied by context.
Unsized literals, assignment targets, casts, packed layouts, and mixed signed
operands all participate. This permits terse arithmetic and close control over
representation, but the meaning of an expression is not always readable from
its operands alone.

RHDL uses elaboration-known positive widths and exact types. `Bits`, `Bool`,
`SInt`, nominal enums, `OneHot`, clocks, resets, records, and vectors remain
distinct when their layers require it. Connections and ordinary operations do
not implicitly resize or reinterpret; extension, truncation, and equal-width
representation casts are explicit.

SystemVerilog's four-state values carry runtime `X` and `Z` behavior, including
defined equality, case, conditional, and edge rules. RHDL's normal data model
is two-state. Its synthesis don't-care denotes implementation freedom rather
than a source-level runtime unknown, even if the eventual SystemVerilog uses an
`X` token to convey that freedom to later tools.

## Time, state, and scheduling

SystemVerilog offers two complementary RTL styles. Continuous assignments and
instances are structural/dataflow-like. Procedural blocks use statements,
temporaries, `if`, `case`, and loops to describe combinational or sequential
behavior. `always_comb` supplies implicit sensitivity and intent restrictions;
`always_ff` restricts event controls and competing writers; `always_latch`
states intended level-sensitive storage.

Blocking versus nonblocking assignment is semantic, not merely stylistic. A
blocking assignment updates a procedural variable immediately within its
process, while a nonblocking assignment schedules an update for a later event
region. Nonblocking assignment is the standard sequential-RTL convention for
simultaneous state updates. Multiple processes remain concurrent even though
statements within a process are ordered.

RHDL replaces these procedural scheduling rules with explicit objects. A
register exposes readable current state and a driveable next-state place.
Hardware alternatives become muxes and guarded effects; every place has one
effective driver. The current sequential primitives choose rising-edge clocks
and optional active-high synchronous reset. Latches, falling-edge state, and
asynchronous reset are not alternate spellings of the same primitive in the
current language.

Neither ordinary synthesizable SystemVerilog nor RHDL is HLS at this level.
Once a register boundary is present, synthesis can optimize logic while
preserving observable sequential behavior, but it does not generally reinterpret
the source as an unconstrained algorithm and choose a different pipeline.

## Core composition unit and interfaces

The SystemVerilog module is both a reusable design unit and an elaborated
hierarchy boundary. Parameters allow one definition to retain a family of
specializations. Packages share types, constants, and functions. Interfaces
can bundle signals, parameters, continuous logic, tasks, functions, assertions,
and clocking blocks; modports expose named direction and access views.

RHDL host functions and circuit constructors specialize fresh concrete modules
during elaboration. The resulting core module does not retain a parameterized
source family. Frontend interfaces are separate nominal descriptors with two
complementary roles, nested directions, refinement, declared support, and
parameter compatibility. They lower away to records and ports before the
backend.

SystemVerilog interfaces are more syntactically self-contained: signal bundle,
local behavior, timing view, and verification statements can live together.
RHDL interfaces are narrower and more declarative. They state protocol identity
and direction while executable behavior remains in modules or reusable flow
constructors. Modports do not by themselves define RHDL-style nominal
refinement or elaboration-time linear consumption; RHDL interfaces do not
retain SystemVerilog-style behavioral members.

## Locality, predictability, and syntax

Disciplined SystemVerilog RTL can be exceptionally concise. `always_comb` with
local temporaries expresses a decode or arithmetic datapath directly;
`always_ff` places related state updates in one visible block; packed structs,
enums, interfaces, and generate forms reduce wiring repetition. For engineers
reading the synthesizable idiom, the surface is close to the resulting RTL.

Its breadth creates contextual load. The same `if` can run during constant
elaboration, procedural simulation, or a synthesizable process. An incomplete
combinational assignment can imply retained state; assignment operators change
event timing; expression context can change width or signedness; nets and
variables obey different driver rules. The source is predictable when a
project follows a well-defined subset and style, less so when the full language
is treated as one uniform semantic space.

RHDL makes dataflow distinctions explicit in syntax and object kind. Readable
values and driveable places are different objects, conversions are named, and
conditional driving is resolved before core verification. This is more verbose
than a compact procedural block, but a local operation has fewer ambient
language rules. Rhombus abstraction can remove repetition without changing
which circuit objects the expansion constructs.

## Language-level judgment

A disciplined synthesizable SystemVerilog subset is both expressive and
elegant. Procedural blocks, packed types, retained parameters, and interfaces
give common RTL proportionate notation, and explicit register boundaries keep
microarchitecture under author control. Its difficulty is not procedural syntax
alone; it is the interaction of several assignment, sizing, event, net, and
elaboration models within one language.

RHDL is more orthogonal within the circuits it denotes. Explicit conversion,
single-driver places, and explicit graph state reduce ambient rules. It is not
simply a cleaner spelling of all SystemVerilog RTL: the current primitive model
excludes legitimate circuit semantics such as latches, alternative clock/reset
events, and resolved nets. The smaller model is compelling only if extensions
preserve its local rules.

## Lessons for RHDL

1. The useful SystemVerilog comparison is its disciplined synthesizable RTL
   subset, not the union of every event-simulation and verification construct.
2. Procedural combinational syntax can be elegant, but RHDL should preserve a
   lowering in which ordering disappears and one final drive remains explicit.
3. If RHDL broadens clock, reset, latch, net, or four-state semantics, each
   should be a distinct primitive contract rather than an incidental backend
   spelling.
4. Retained HDL parameters and elaborated concrete modules serve different
   composition needs; adding one should preserve the meaning of the other.
5. RHDL's nominal protocol descriptors and SystemVerilog's behavior-bearing
   interfaces are complementary designs, not two syntaxes for an identical
   abstraction.

## Sources

- [IEEE Std 1800-2023 overview](https://standards.ieee.org/ieee/1800/7743/)
- [IEEE Xplore entry for IEEE Std 1800-2023](https://ieeexplore.ieee.org/document/10458102)
- [Accellera access to IEEE 1800-2023](https://www.accellera.org/downloads/ieee)
- RHDL [architecture](../../rhdl/README.md), [core semantics](../../rhdl/core/README.md),
  [frontend staging](../../rhdl/frontend/README.md), and
  [interface layer](../../rhdl/frontend/layers/README.md#interfaces)
