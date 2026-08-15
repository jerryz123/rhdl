<!-- Compares RHDL's exact RTL construction model with Calyx's control-oriented accelerator IR. -->

# RHDL and Calyx: exact RTL and scheduled accelerator control

## Scope and thesis

Snapshot: 2026-08-15. This comparison uses the checked-in RHDL implementation
and Calyx's current official language documentation.

Calyx is a compiler intermediate language for accelerators, not primarily a
surface RTL language. A Calyx component combines instantiated resources,
guarded connections, and a control program that activates groups of those
connections. An RHDL module is already an exact circuit: its combinational
graph, registers, memories, effects, hierarchy, and cycle boundaries have been
chosen during elaboration.

The central difference is retained scheduling intent. Calyx preserves a
multi-cycle action schedule that later compiler steps turn into controller
hardware. RHDL core begins after that choice: a generator must construct the
controller and datapath explicitly. Calyx is more concise and malleable for
scheduled accelerator actions; RHDL makes the resulting RTL structure and its
protocol boundaries more local and predictable.

## Summary

| Concern | RHDL | Calyx |
|---|---|---|
| Semantic unit | Exact RTL module in a verified dataflow IR | Accelerator component with cells, wiring groups, and control |
| Time | Registers, memories, and enables fix cycle behavior | Dynamic go/done actions or exact-latency static control |
| Control | Muxes and guarded effects are already circuitry | `seq`, `par`, `if`, `while`, `repeat`, group activation, and `invoke` |
| Assignment | One final binding per driveable destination | Guarded assignments may share a destination when mutually exclusive |
| Types | Exact semantic types, records, vectors, and nominal protocols | Concrete-width ports, parameters, and semantic attributes |
| Composition | Module hierarchy plus directional protocol interfaces | Component invocation and caller-supplied `ref` cells |
| Compiler freedom | Cycle boundaries are author-selected | Control and static schedules remain available for lowering |
| Syntactic center | Circuit construction embedded in Rhombus | Explicit `cells` / `wires` / `control` sections |

## Denotation and staging

RHDL executes Rhombus host code to elaborate one concrete design. Host values
choose structure; circuit expressions and connections describe runtime
hardware. All frontend layers lower into the same
[core IR](../../rhdl/core/README.md), where operation order is not execution
order and registers or memories mark temporal boundaries.

Calyx is designed as an intermediate language that higher-level frontends can
generate. A component's `cells` instantiate resources. Its `wires` contain
continuous assignments and named groups of guarded assignments. Its `control`
section says when groups run and when subcomponents are invoked. The
[language tutorial](https://docs.calyxir.org/tutorial/language-tut.html) and
[reference](https://docs.calyxir.org/lang/ref.html) deliberately retain both
datapath structure and an imperative schedule.

Consequently, source-level Calyx sits above RHDL core in one important
dimension. Calyx control still has to become enables, state, and multiplexing.
The closest apples-to-apples artifact is a lowered Calyx design after that
control becomes circuitry. RHDL does not retain the earlier schedule as a
separate representation, so its backend can optimize the circuit while
preserving behavior but cannot reinterpret the author's actions across cycles.

## Types and intrinsic guarantees

RHDL operations carry hardware types rather than only packed widths. `Bits`,
`Bool`, `SInt`, nominal enums, `OneHot`, clocks, resets, records, and vectors
remain distinguishable where their frontend layers require it. Connections
require exact types; representation casts, extension, and truncation are
explicit. A type can implement open operation capabilities without defining a
second IR.

Calyx ports carry concrete bit widths. Primitive signatures can be
parameterized, and attributes can identify facts such as clock, reset, go,
done, stability, or timing relationships. Those are useful facts at an
accelerator-IR boundary, but they are not a general semantic data-type algebra.
A frontend that distinguishes an enum, signed quantity, or one-hot selector
must discharge that distinction before Calyx or preserve it with its own
conventions.

This choice makes Calyx a relatively neutral target for different frontends.
The tradeoff is that fewer source-level distinctions remain available to later
passes. RHDL chooses the reverse: its supported semantic types survive in the
same IR that states the final circuit.

## Time, state, and scheduling

In RHDL, state is a physical resource. A register exposes its current value and
an explicit next-state binding; memory operations expose concrete port and
clock behavior. Hardware `when` and `switch` collect prioritized alternatives
and lower them to muxes, enables, and guarded effects before core verification.
Every driveable destination has exactly one final binding, including through
aggregate connections.

Calyx groups package assignments with a completion condition. Dynamic control
uses go/done handshakes: `seq` orders actions, `par` permits overlap, `if` and
`while` select or repeat them, and `invoke` runs a subcomponent. Physical state
resides in instantiated cells while the control program coordinates access to
those cells. Multiple guarded assignments may target the same input port; the
program is well formed only when simultaneously active guards do not conflict.

Dynamic control intentionally avoids cycle-level lockstep: `seq` guarantees
completion order, while `par` does not guarantee that its children begin on the
same cycle. Static `seq` and `par` add those exact relative-timing guarantees.
This is concurrency over latency-insensitive actions, not merely concise syntax
for a synchronous fork or a hand-written FSM.

Calyx also has a separate
[static timing language](https://docs.calyxir.org/lang/static.html). A static
group or component promises an exact latency, and timing guards identify
subintervals within that latency. This lets the compiler lower a known schedule
without dynamic completion on every action. RHDL can construct the same
fixed-latency pipeline or go/done controller, but it has no schedule object on
which a compiler can prove or rewrite those relationships.

## Core composition unit and interfaces

Calyx's principal composition boundary is component invocation: start a
component, keep its go signal asserted as required, and observe done. `ref`
cells allow an invoked component to operate on a resource supplied by its
caller; compatibility is based on the required port structure. These forms
compose scheduled actions and shared accelerator resources.

RHDL modules have no implicit transaction protocol. They expose ports or
frontend interface endpoints. An RHDL interface has nominal identity,
complementary named roles, nested directional members, refinement, and local
parameter compatibility. Linear handles give ready-valid composition an
elaboration-time ownership rule. Interface descriptors lower away to ordinary
records, ports, and wires before core verification.

The two mechanisms therefore compose different things. Calyx composes actions
and resource use while retaining an execution schedule. RHDL composes physical
module boundaries and protocol roles after cycle scheduling is already fixed.
A continuously operating elastic network is natural in RHDL; an
invoke-to-completion accelerator step is natural in Calyx.

## Locality, predictability, and syntax

Calyx's three-section syntax is economical for its semantic level. `cells`
shows available resources, `wires` shows how they can be used, and `control`
shows sequencing without spelling out the controller state machine. Naming a
group gives a compact action vocabulary, while `seq` and `par` make temporal
composition visually apparent.

That economy deliberately hides the final controller structure. The amount of
multiplexing, enabling, and controller state induced by a control expression is
not fully local to that expression; it depends on lowering and resource use
elsewhere in the component. Guard exclusivity is similarly a property of the
active schedule and guards together.

RHDL spends more syntax on the realized microarchitecture. A register, mux,
queue, or handshake stage is explicit; connections require exact types, and
conditional assignments resolve to one final binding. Rhombus functions and
macros can recover authoring economy, but they elaborate immediately to
concrete hardware. That makes a local source edit more predictably structural,
at the cost of requiring the author to formulate repetitive controllers that
Calyx can derive. The resulting graph is easy to verify; its author-facing
predictability comes from the binding policy rather than a special source
abstraction.

## Language-level judgment

Calyx is the more elegant language when the reusable unit is a scheduled
action over shared resources. Groups bind wiring to completion, and control
combinators obtain substantial semantic leverage from a small vocabulary. The
compiler is allowed to choose controller structure because the source has not
claimed that structure yet.

RHDL is the more coherent language when the reusable unit is an exact circuit.
Its one-driver and explicit-state rules apply uniformly to combinational logic,
hierarchy, and protocols, whereas Calyx must relate a spatial `wires` section
to a temporal `control` section. RHDL's extra controller syntax is justified
only when those cycles and resources are genuinely part of the architecture.
Neither model subsumes the other without adding a semantic level.

## Lessons for RHDL

1. Calyx-style control would be a new schedule-bearing level, not a missing
   convenience form in RHDL core. If introduced, it should have an explicit
   lowering boundary to exact RTL.
2. Named groups are an elegant unit for action-level reuse because they bind
   guarded wiring to completion. RHDL should borrow that unit only where an
   action schedule is genuinely the intended abstraction.
3. Static latency, dynamic go/done, and continuously operating ready-valid
   behavior are distinct temporal contracts; their syntax should not imply
   interchangeability merely because all eventually become wires and state.
4. Any higher scheduling layer should preserve RHDL's semantic data and
   protocol types until its lowering obligations require a packed form.

## Sources

- Calyx [project documentation](https://docs.calyxir.org/)
- Calyx [language tutorial](https://docs.calyxir.org/tutorial/language-tut.html)
- Calyx [language reference](https://docs.calyxir.org/lang/ref.html)
- Calyx [static timing reference](https://docs.calyxir.org/lang/static.html)
- Calyx [frontend tutorial](https://docs.calyxir.org/tutorial/frontend-tut.html)
- Calyx [primary repository](https://github.com/calyxir/calyx)
- RHDL [architecture](../../rhdl/README.md), [core semantics](../../rhdl/core/README.md),
  and [frontend interfaces](../../rhdl/frontend/layers/README.md#interfaces)
