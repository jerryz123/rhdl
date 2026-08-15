<!-- Compares RHDL's exact-construction semantics with Chisel and records the tradeoffs those choices create. -->

# RHDL and Chisel: design tradeoffs

RHDL and Chisel are both host-language hardware construction systems, but they
make different default choices. Chisel emphasizes breadth, flexible generation,
and a mature hardware ecosystem. RHDL emphasizes *exact construction*: explicit
hardware types, one effective driver, typed protocol relationships, and a small
backend-independent semantic core.

This document describes where current RHDL is cleaner or provides a useful
abstraction beyond base Chisel. It does not claim that equivalent hardware is
impossible to implement in Chisel. Many RHDL advantages can be recreated with
careful Chisel conventions or project-specific libraries; RHDL makes them part
of the default model.

## Summary

| Concern | RHDL default | Chisel default |
|---|---|---|
| Connections | One effective driver for each driveable `Place` | Multiple connects with last-connect semantics |
| Widths and conversions | Exact widths and types; explicit resize and cast | Width inference and context-dependent padding or truncation |
| Hardware objects | Readable `Value` and driveable `Place` are distinct | One `Data` hierarchy whose binding determines hardware status and direction |
| Semantic packed types | Open capability interfaces; typed one-hot values and enums | Built-in ground types plus user aggregates, enums, opaque wrappers, and library conventions |
| Protocol compatibility | Nominal identity, named roles, refinement, and supported contracts | Structural shape, relative alignment, `Flipped`, `Connectable`, and views |
| Topology composition | Linear interface handles and sinks | Ordinary Scala references and connection APIs |
| Generator graph negotiation | No graph-wide negotiation layer | Rocket Chip Diplomacy negotiates parameters across a generator graph |
| Decode | Unordered typed relations over scalar or aggregate patterns | `BitPat`, truth tables, structured decode fields, and optional minimizers |
| Synthesis freedom | Typed value with a complete driver and no runtime-X meaning | `DontCare` participates in Chisel's invalidation/unconnected model |

## One definition and one effective driver

The core distinguishes a readable
[`Value`](../rhdl/core/README.md#values-and-places)
from a driveable `Place`. Module inputs and child outputs are values. Module
outputs, child inputs, register next-state inputs, and internal destinations are
places. A place must have one effective driver of exactly the same hardware
type.

Normal Chisel hardware supports multiple connections with the last connection
winning. Chisel describes this explicitly in its
[probe documentation](https://www.chisel-lang.org/docs/explanations/probes).
That behavior makes convenient default-then-override code possible, but it also
makes connection priority depend on elaboration order.

RHDL expresses alternatives through hardware `when`, `switch`, or explicit
muxes. The frontend canonicalizes conditional alternatives into selection logic
and one final drive. Consequently:

- source reordering cannot silently change which ordinary connection wins;
- input-like values cannot accidentally be used as destinations;
- complete field-wise aggregate construction becomes one whole-value drive;
- partial aggregate drives and mixed whole/field drive modes are rejected; and
- priority, when present, is localized in a construct that explicitly denotes
  it.

The cost is that incremental software-style assignment is intentionally less
convenient.

## Exact widths, types, and control kinds

RHDL's [core width rules](../rhdl/core/README.md#width-rules) require positive,
elaboration-known widths. Connections and ordinary modular arithmetic require
exact hardware types. Extension, truncation, and equal-width representation
casts are explicit operations.

Chisel deliberately supports
[width inference](https://www.chisel-lang.org/docs/explanations/width-inference)
and connection-time resizing. Its documentation recommends specifying port and
register widths manually to avoid surprises and calls truncating addition a
common gotcha. A disciplined Chisel project can impose stricter conventions;
RHDL makes those conventions universal and verifies them in its public IR.

RHDL also keeps `Clock` and `Reset` outside ordinary `DataType`. They cannot be
selected by an ordinary data mux or accidentally participate in arithmetic.
Chisel permits casts such as `Bool.asClock`, with an explicit warning that clock
construction requires care in its
[data-type documentation](https://www.chisel-lang.org/docs/explanations/data-types).
RHDL still permits an explicit equal-width representation cast to `Clock` or
`Reset`, so this is a default barrier rather than proof-level separation. RHDL
does not yet provide richer clock-gating or clock-generation abstractions.

## Open semantic types and one-hot intent

The core type model is capability-based. `FlatDataType`, `BitwiseType`,
`ArithmeticType`, and `SignedArithmeticType` describe operations a packed type
supports. Frontend-defined `Bool`, `SInt`, enums, one-hot types, and compatible
extension-defined types use those capabilities without adding backend-specific
node cases.

The [`OneHot`](../rhdl/frontend/layers/README.md#one-hot-values) abstraction is a useful
example. `OneHot(n)` is distinct from `Bits(n)`, and a nominal one-hot hardware
enum is distinct from both. One-hot types do not expose arbitrary bitwise
operations because those operations do not preserve exactly-one intent.
`mux_onehot` accepts an appropriate selector type, and keyed nominal-enum arms
must cover every declared member exactly once.

Chisel provides `ChiselEnum`, opaque wrappers, and
[`Mux1H`](https://www.chisel-lang.org/docs/explanations/muxes-and-input-selection).
Those facilities can build the same datapath, but `Mux1H` normally accepts a
general `UInt` or sequence of `Bool` selectors. RHDL directly couples the
semantic selector type, its legal operations, and its selection primitive.
Runtime zero-hot and multi-hot values remain a caller precondition in both
models.

## Nominal protocols and linear topology

RHDL [interfaces](../rhdl/frontend/layers/README.md#interfaces) are protocol descriptors,
not merely aggregate data types. They provide:

- stable nominal identity, including for parameterized protocols;
- two explicitly named roles and a declared provider role;
- transitive refinement and structurally checked supported contracts;
- nested directional interfaces and compatible bulk connection; and
- operand-order-independent connection between complementary endpoints.

Chisel's
[`Connectable`](https://www.chisel-lang.org/docs/explanations/connectable) model
is powerful and more flexible in several dimensions, but its base vocabulary is
structural shape, relative aligned/flipped members, views, waived or excluded
fields, and a family of directional connection operators. RHDL can state that a
richer producer protocol nominally supports a weaker contract rather than only
that two aggregate shapes can be connected.

RHDL also provides linear `InterfaceHandle` and `InterfaceSink` values. A handle
can be consumed only once, because consuming it twice would drive a destination
twice. The [flow library](../rhdl/std/README.md#flow-control-circuits) uses the same
generic handle protocol for mapping, filtering, gating, zipping, arbitration,
buffering, fanout, and parallel branches:

- combinational adapters become direct wiring in the containing circuit;
- queues and pipes retain module hierarchy because they own state;
- transformations preserve or conservatively weaken `Decoupled` and
  `Irrevocable` contracts; and
- payloadless `DecoupledCtrl` and `IrrevocableCtrl` paths do not manufacture a
  dummy payload.

Chisel has mature `ReadyValidIO`, `Decoupled`, `Irrevocable`, `Queue`, `Pipe`,
and arbiter utilities. RHDL's additional contribution is one linear composition
vocabulary spanning both inline transformations and stateful stages. The
linearity check currently occurs during elaboration rather than through a
static linear type system. These handles compose already-typed endpoints; they
do not negotiate parameters, cardinality, or capabilities across a generator
graph, nor do they provide Rocket Chip Diplomacy's adapter and monitor
ecosystem.

## Typed decode relations and synthesis freedom

RHDL's [decode library](../rhdl/std/README.md#typed-decode-patterns) treats a decoder as
an unordered typed relation. A `Pattern` can recursively describe `Bits`,
`Bool`, enums, one-hot types, records, vectors, and compatible extension-defined
types. Input cubes must not overlap, so row order never introduces hidden
priority. Output patterns can care only about fields meaningful to a matching
input.

Decode cases are ordinary immutable host values. Before materialization they
support:

- row-set extension;
- typed lifting into a wider input domain; and
- row-aligned products of independently defined output controls.

Calling a `DecodeGen` produces one typed `rtl.decode` operation. The core keeps
the relation and output freedom intact for the backend and downstream synthesis
instead of forcing a particular mux or gate network.

Chisel has capable
[`BitPat`, `TruthTable`, and DecodeTable`](https://www.chisel-lang.org/docs/explanations/decoder)
APIs, along with Espresso and QMC minimizers. RHDL's differentiator is the
uniform aggregate pattern type and relation-composition API, not the mere
existence of decoder generation. Chisel currently has the stronger dedicated
minimization tooling.

RHDL also separates synthesis freedom from missing wiring. A typed
`dont_care(T)` is still a fully driven value; it grants synthesis freedom for
its bits but has no runtime four-state meaning. Chisel's
[`DontCare`](https://www.chisel-lang.org/docs/explanations/unconnected-wires)
is the source for its invalidation API and marks a destination as intentionally
not driven. RHDL's narrower distinction keeps assignment completeness,
synthesis optimization, and runtime unknown-state semantics separate.

## Host descriptions, language layers, and one public IR

RHDL's frontend supports
[deferred host descriptions](../rhdl/frontend/README.md#deferred-host-descriptions).
Static literals, enum members, patterns, and other reusable descriptions can be
passed through host computation without allocating circuit IR. They become
ordinary core values only when a hardware operation consumes them.

The direct Builder, construction kernel, composed `#lang rhdl/base` profile,
and standard `#lang rhdl` profile all construct the same public IR. Frontend
layers can add notation, typed literals, field behavior, or connection policy
without creating frontend-only hardware operations. Backends consume only the
verified core and never import frontend syntax. The enforced dependency model
is documented in the [implementation architecture](../rhdl/README.md).

This is a smaller and more inspectable boundary than Chisel's full frontend,
compiler-plugin, FIRRTL/CIRCT, annotation, and transform ecosystem. It is not
yet a maturity advantage: Chisel's compiler APIs are much more capable, while
RHDL's public-IR immutability and extension contracts still require hardening.

## Concrete use in Ricket

The [Ricket RV64I core](../cores/ricket/README.md) exercises these abstractions
outside isolated examples:

- independently owned 52-row decode relations are combined into one aggregate
  control pattern;
- pipeline state stores only typed leaf controls used downstream;
- irrelevant controls remain synthesis freedom behind a separate valid bit;
- `Pipe` and `ValidPipe` modules mark stateful pipeline boundaries;
- inline flow filtering implements squash, while explicit ready-valid gating
  implements load-use hazard policy without processor-specific queue variants;
  and
- nominal instruction- and data-access protocols keep pipeline logic
  independent of the private caches and external memory protocol.

The example does not prove that RHDL produces better quality of results than an
equivalent Chisel design. It shows that the semantic abstractions compose into
a complete five-stage processor rather than existing only as small language
demonstrations.

## Where Chisel remains stronger

RHDL's stricter model is not a substitute for Chisel's breadth. Current Chisel
and Rocket Chip remain substantially stronger in:

- external RTL modules, vendor primitives, and source/resource packaging;
- analog, bidirectional, and attached nets;
- asynchronous and abstract reset plus richer clock/reset-domain support;
- initialized and general multi-port SRAM descriptions;
- assumptions, coverage, temporal properties, probes, logging, and stopping;
- annotations, compiler intrinsics, user transforms, and implementation hooks;
- module specialization, separate compilation, and production tooling; and
- protocol, cache, coherence, interconnect, and SoC-generator ecosystems.

Rocket Chip is more than a collection of Chisel language idioms. It provides
Diplomacy parameter negotiation, production TileLink buses and adapters,
cores and coherent memory-system components, configuration infrastructure,
devices, debug and interrupt integration, simulation harnesses, and complete
SoC assembly. RHDL's current
[TileLink support](../rhdl/std/README.md#tilelink-definitions) is deliberately
definition-only: parameter records, A-E bundles, and directional link types,
without negotiation, routing, adapters, monitors, or endpoint behavior. The
[Rocket Chip repository](https://github.com/chipsalliance/rocket-chip) is the
appropriate comparison point for that generator ecosystem.

See Chisel's official documentation for
[external modules](https://www.chisel-lang.org/docs/explanations/blackboxes),
[reset](https://www.chisel-lang.org/docs/explanations/reset),
[memories](https://www.chisel-lang.org/docs/explanations/memories), and
[probes](https://www.chisel-lang.org/docs/explanations/probes).

## Current RHDL caveats

Several implementation seams currently weaken the architectural guarantees
described above:

- ordinary Rhombus host control treats a hardware object as truthy instead of
  rejecting it, so `if signal` can silently select an elaboration branch;
- the documented read-only public IR contains mutable module collections, and
  verification does not yet re-establish every descriptor invariant;
- operation type rules use strings whose unknown verifier branch fails open;
- some ready-valid helpers compare interface display names instead of using
  nominal support relationships; and
- conditional effect capture has dedicated cases for assignments, memory
  writes, and assertions rather than an extensible guarded-effect protocol.

These are reasons to harden RHDL's existing model, not reasons to replace its
exact-driver, exact-width, typed-relation, or nominal-protocol foundations.
