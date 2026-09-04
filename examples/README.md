<!-- Presents the executable Rhodium and RFPL walkthroughs and canonical feature examples. -->

# Rhodium and RFPL examples

The examples demonstrate that progressively richer authoring layers construct
one public hardware IR. Language and component details live in the
[`rhodium/`](../rhodium/README.md) documentation; this guide owns the executable
walkthrough and example index.

Examples are grouped by the API or domain that owns their primary lesson:

| Directory | Contents |
|---|---|
| [`rtl/`](rtl/) | Built-in `#lang rhodium` syntax, elaboration, and hardware semantics |
| [`clocking/`](clocking/) | Frontend timing declarations and backend-independent temporal-provenance analysis over completed Rhodium IR |
| [`std/`](std/) | Reusable protocols and components imported from `rhodium/std` |
| [`noc/`](noc/) | Hardware examples owned by the graph-validated NoC domain library |
| [`riscv/`](riscv/) | RISC-V descriptor adapters and field extraction |
| [`chi/`](chi/) | AMBA CHI endpoints and finite components |
| [`cores/`](cores/) | Reusable processor datapaths and complete named cores |
| [`lop/`](lop/) | Equivalent designs expressed at different levels of abstraction |
| [`rfpl/`](rfpl/) | Logical designs paired with physical floorplans |
| [`formal/`](formal/) | Optional Rosette-backed behavioral proofs |
| [`rv5stage/`](rv5stage/) | RV5Stage core integration and inspection examples |

## One IR, layered languages

Start with four versions of the same 8-bit adder:

| Layer | Example | Contribution |
|---|---|---|
| Public core | [`lop/adder-core.rhm`](lop/adder-core.rhm) | Explicit `Design`, `Builder`, and verification APIs |
| Elaboration kernel | [`lop/adder-kernel.rhm`](lop/adder-kernel.rhm) | Active-context construction functions |
| Composed language | [`lop/adder-composed.rhdl`](lop/adder-composed.rhdl) | `#lang rhodium/base` plus an explicit combinational layer |
| Standard profile | [`lop/adder-standard.rhdl`](lop/adder-standard.rhdl) | Curated `#lang rhodium` syntax |

The sources become progressively shorter while constructing identical printed
Rhodium IR and CIRCT MLIR:

```sh
make lop-test
```

```text
direct Builder     elaboration kernel     base + comb     standard profile
       \                  |                    |                 /
        +-----------------+--------------------+----------------+
                                  |
                                  v
                          public Rhodium IR
                                  |
                                  v
                             CIRCT MLIR
```

The aggregate equivalence examples make the same boundary executable:

- [`lop/bundle-kernel.rhdl`](lop/bundle-kernel.rhdl) and
  [`lop/bundle-standard.rhdl`](lop/bundle-standard.rhdl) compare explicit
  record construction with bundle syntax.
- [`lop/interface-records.rhdl`](lop/interface-records.rhdl) and
  [`rtl/interface.rhdl`](rtl/interface.rhdl) compare directional records with
  role-based interfaces.
- [`lop/width-ops-kernel.rhm`](lop/width-ops-kernel.rhm) and
  [`rtl/width-ops.rhdl`](rtl/width-ops.rhdl) compare explicit kernel operations with
  concise indexing and width syntax.
- [`lop/counter-composed.rhdl`](lop/counter-composed.rhdl) and
  [`rtl/sync-counter.rhdl`](rtl/sync-counter.rhdl) show that explicitly selected
  sequential layers and the standard profile construct the same clocked IR.

The [frontend guide](../rhodium/frontend/README.md) explains the profiles, and
the [layer guide](../rhodium/frontend/layers/README.md) documents their features.

## Clocking-analysis examples

The examples under [`clocking/`](clocking/) use the clocking frontend layer or
import `rhodium/analysis/clocking.rhm` directly. Environment and report objects
remain outside core IR; explicit crossing evidence can now affect CDC
verification and backend register attributes.

- [`clocking/frontend-environment.rhdl`](clocking/frontend-environment.rhdl)
  uses `#lang rhodium/base` with the selectable clocking layer to declare local,
  asynchronous-clock, and asynchronous-pin input timing at the root circuit
  and obtain the resolved report as part of elaboration.
- [`clocking/sync-level.rhdl`](clocking/sync-level.rhdl) uses strict
  `elaborate_with_cdc`, instantiates the standard two-stage `SyncLevel`, checks
  its retained crossing lineage, and shows generated synchronizer attributes.
- [`clocking/reconvergence.rhdl`](clocking/reconvergence.rhdl) shows that two
  individually legal `SyncLevel` results remain accepted while their later
  convergence is retained as a structured diagnostic and report entry.
- [`clocking/missing-crossings.rhdl`](clocking/missing-crossings.rhdl) reports
  every missing crossing across a reused child hierarchy, then elaborates a
  corrected version whose transfers use standard `SyncLevel` instances.
- [`clocking/single-clock.rhm`](clocking/single-clock.rhm) applies one set of
  top-level synchronous input contracts to an existing `sync_circuit` shift
  register and shows that its certified subtree samples those inputs on the
  same clock. Reset timing remains explicitly unknown until the planned RDC
  environment work.
- [`clocking/relationships.rhm`](clocking/relationships.rhm) compares exact,
  declared-identical, derived, asynchronous, and unknown clock relationships.
- [`clocking/hierarchy.rhm`](clocking/hierarchy.rhm) reuses one child module at
  two clock bindings and obtains a separate classification for each instance.
- [`clocking/report.rhm`](clocking/report.rhm) classifies a sync-counter
  hierarchy and prints its hierarchy-aware temporal-provenance report.

Run only these clocking examples with:

```sh
make examples-clocking
```

## Structural floorplanning

[`rfpl/circuit-pair.rhdl`](rfpl/circuit-pair.rhdl) defines an ordinary Rhodium
hierarchy. [`rfpl/circuit-pair.rfpl`](rfpl/circuit-pair.rfpl) annotates its
logic-bearing `Adder` as a hard macro and its wiring-only `AdderShell` and
`AdderPair` circuits as composite floorplans. Every physical view has an exact
rectangle and every direct composite child has a contained coordinate. The
colocated `verilog_reference` confirms that annotation adds no modules, ports,
instances, or logic to the generated RTL.

## Rhodium language examples

| Example | Primary lesson |
|---|---|
| [`rtl/full-adder.rhdl`](rtl/full-adder.rhdl) | Nominal Boolean ports and carry logic |
| [`rtl/adder4.rhdl`](rtl/adder4.rhdl) | Ripple-carry hierarchy and pack-aware concatenation |
| [`rtl/generated-adder.rhdl`](rtl/generated-adder.rhdl) | Host `InstanceArray` generation plus runtime vector wiring |
| [`rtl/alu.rhdl`](rtl/alu.rhdl) | Boolean, bitwise, arithmetic, equality, and N-way selection |
| [`rtl/unsigned-comparisons.rhdl`](rtl/unsigned-comparisons.rhdl) | Unsigned ordering derived from one core comparison |
| [`rtl/signed-integers.rhdl`](rtl/signed-integers.rhdl) | Explicit-width signed arithmetic, ordering, shifts, and resizing |
| [`rtl/enum-state.rhdl`](rtl/enum-state.rhdl) | Equivalent enum mux/switch forms, explicit encodings, and invalid recovery |
| [`rtl/tagged-union.rhdl`](rtl/tagged-union.rhdl) | Nullary and payload variants with `.tag`, `.is(...)`, and `.view(...)` inspection |
| [`rtl/nested-tagged-union.rhdl`](rtl/nested-tagged-union.rhdl) | Nested tagged-union literals, chained payload views, and runtime reconstruction |
| [`rtl/one-hot.rhdl`](rtl/one-hot.rhdl) | One-hot literals, selector-owned selection, equality, and representation casts |
| [`rtl/one-hot-enum.rhdl`](rtl/one-hot-enum.rhdl) | Nominal one-hot enums selecting named datapath result families |
| [`rtl/masks.rhdl`](rtl/masks.rhdl) | Non-numeric lane sets, bitwise set operations, and explicit selector widening |
| [`rtl/shifts.rhdl`](rtl/shifts.rhdl) | Logical shifts with host constants and independent hardware amount widths |
| [`rtl/multiply.rhdl`](rtl/multiply.rhdl) | Modular same-width unsigned multiplication |
| [`rtl/expanding-arithmetic.rhdl`](rtl/expanding-arithmetic.rhdl) | Lossless unsigned addition plus signed and unsigned multiplication |
| [`rtl/fir-filter.rhdl`](rtl/fir-filter.rhdl) | Signed direct-form FIR filtering with generated taps, explicit widths, and balanced summation |
| [`rtl/counter.rhdl`](rtl/counter.rhdl) | Host helper functions accepting and returning hardware |
| [`rtl/sync-counter.rhdl`](rtl/sync-counter.rhdl) | Ambient clock/reset policy and explicit override |
| [`rtl/enable-shift-register.rhdl`](rtl/enable-shift-register.rhdl) | Hardware conditionals, register hold, and synchronous reset |
| [`rtl/reset-shift-register.rhdl`](rtl/reset-shift-register.rhdl) | Generic enabled shift register with ambient synchronous reset |
| [`rtl/hierarchy.rhdl`](rtl/hierarchy.rhdl) | Reused module definitions and child-port access |
| [`rtl/nested-circuit.rhdl`](rtl/nested-circuit.rhdl) | Lexically private child generators with explicit hardware boundaries |
| [`rtl/layered-adder.rhdl`](rtl/layered-adder.rhdl) | Ordinary imported library plus generated structure |
| [`rtl/fresh-generators.rhdl`](rtl/fresh-generators.rhdl) | Automatic reuse of equivalent module specializations |
| [`rtl/host-parameters.rhdl`](rtl/host-parameters.rhdl) | `StableCircuitParam` reuse and hardware-type parameters |
| [`rtl/generator-parameters.rhdl`](rtl/generator-parameters.rhdl) | Positional, keyword, typed, defaulted, and synchronous generator parameters |
| [`rtl/register-forms.rhdl`](rtl/register-forms.rhdl) | Inferred register types, immediate next values, reset values, and direct drives |
| [`rtl/tiny-simd.rhdl`](rtl/tiny-simd.rhdl) | Integrated host-specialized SIMD, bundles, enums, memory, vectors, and state |
| [`rtl/stack.rhdl`](rtl/stack.rhdl) | Memory, guarded writes, nested hardware control, and bounds checks |
| [`rtl/async-read-memory.rhdl`](rtl/async-read-memory.rhdl) | Asynchronous reads and synchronous writes |
| [`rtl/sync-memory.rhdl`](rtl/sync-memory.rhdl) | Circuit-shaped synchronous memory with explicit read and write ports |
| [`rtl/sync-memory-1rw.rhdl`](rtl/sync-memory-1rw.rhdl) | One shared synchronous read-write physical port |
| [`rtl/sync-memory-masked.rhdl`](rtl/sync-memory-masked.rhdl) | Byte-masked writes through a shared synchronous memory port |
| [`rtl/multi-write-memory.rhdl`](rtl/multi-write-memory.rhdl) | Independent same-clock physical write ports |
| [`rtl/clocked-dpi.rhdl`](rtl/clocked-dpi.rhdl) | DPI procedure effects plus single- and multi-result DPI register state |
| [`rtl/assertions.rhdl`](rtl/assertions.rhdl) | Reset-suppressed assertions with branch-derived activation guards |
| [`rtl/width-ops.rhdl`](rtl/width-ops.rhdl) | Concatenation, slicing, and explicit width changes |
| [`rtl/bundle.rhdl`](rtl/bundle.rhdl) | Type-named fixed and elaboration-conditional bundles, recursive literal shadows, muxes, casts, and state |
| [`rtl/vector.rhdl`](rtl/vector.rhdl) | Fixed vectors, elaboration-time mapping, selection, `.as_bits()`/`.as_vec(...)` representation changes, aggregate drives, and state |
| [`rtl/vector-update.rhdl`](rtl/vector-update.rhdl) | Functional replacement and dynamic vector-register writes |
| [`rtl/table.rhdl`](rtl/table.rhdl) | Host-generated combinational vector table |
| [`rtl/vec-search.rhdl`](rtl/vec-search.rhdl) | Registered traversal of a host-defined vector pattern |
| [`rtl/vec-shift-register.rhdl`](rtl/vec-shift-register.rhdl) | Priority aggregate load and shift updates |
| [`rtl/vec-shift-register-param.rhdl`](rtl/vec-shift-register-param.rhdl) | Host-parameterized vector pipeline |
| [`rtl/predicate-filter.rhdl`](rtl/predicate-filter.rhdl) | Stable predicate policies elaborated inline through a `Valid` interface |
| [`rtl/wire.rhdl`](rtl/wire.rhdl) | Forward-readable aggregate wire driven later by element |
| [`rtl/interface.rhdl`](rtl/interface.rhdl) | Ready-valid fields, bulk connection, and instance reconstruction |
| [`rtl/interface-specialization.rhdl`](rtl/interface-specialization.rhdl) | Directional parameter compatibility, nested rules, operand reversal, and explicit width adaptation |
| [`rtl/interface-array.rhdl`](rtl/interface-array.rhdl) | Endpoint arrays, positional sequences, generic interface links, handles, and terminated sinks |
| [`rtl/nested-interface.rhdl`](rtl/nested-interface.rhdl) | Recursive interface composition and orientation |
| [`rtl/interface-monitor.rhdl`](rtl/interface-monitor.rhdl) | Read-only endpoint observations and explicit protocol assertions |
| [`rtl/interface-transform.rhdl`](rtl/interface-transform.rhdl) | Typed custom interface transforms, fanout, and detached terminals |
| [`rtl/priority-encoder.rhdl`](rtl/priority-encoder.rhdl) | Lower-index-first binary and native `MaybeOneHot` selection over packed and aggregate inputs |
| [`rtl/bit-utilities.rhdl`](rtl/bit-utilities.rhdl) | Negation, reductions, membership predicates, and enum validity |

## Standard-library examples

| Example | Primary lesson |
|---|---|
| [`std/standard-counter.rhdl`](std/standard-counter.rhdl) | Reusable bounded counter with wrap indication |
| [`std/sync-ram.rhdl`](std/sync-ram.rhdl) | One generic lane-masked `Valid` request flow over a fixed-latency shared 1RW RAM |
| [`std/dont-care.rhdl`](std/dont-care.rhdl) | Typed synthesis freedom and Pattern-selected fixed bits |
| [`std/decode.rhdl`](std/decode.rhdl) | Callable typed decode relation with named aggregate fields and semantic enum values |
| [`std/decode-composition.rhdl`](std/decode-composition.rhdl) | PatternSet input algebra plus independent decode expansion across rows, output fields, and input fields |
| [`std/ready-valid-compatibility.rhdl`](std/ready-valid-compatibility.rhdl) | Safe protocol weakening and refinement merge/split |
| [`std/flow-control.rhdl`](std/flow-control.rhdl) | Pipe, queue, fixed-priority arbiter, and typed endpoint chaining |
| [`std/valid-pipe.rhdl`](std/valid-pipe.rhdl) | Fixed-latency Valid-only pipelining without a readiness channel |
| [`std/flow-topology.rhdl`](std/flow-topology.rhdl) | Endpoint-first and precomposed flow topology over map, filter, gate, zip, parallel, arbitration, buffering, fork, and payload routing |
| [`std/ctrl-flow.rhdl`](std/ctrl-flow.rhdl) | Payloadless token-flow versions of pipe, queue, arbitration, routing, join, and broadcast |
| [`std/valid-flow.rhdl`](std/valid-flow.rhdl) | Valid-only map, filter, fanout, and conversion from accepted flow |
| [`std/completion-queue.rhdl`](std/completion-queue.rhdl) | Response-capacity reservation before nonstallable issue |
| [`std/credited-transport.rhdl`](std/credited-transport.rhdl) | Monitored sender/buffer composition with explicit credit return |
| [`std/flit-formats.rhdl`](std/flit-formats.rhdl) | Transfer-counted framing for fixed-length ready-valid packets |
| [`std/scoreboard.rhdl`](std/scoreboard.rhdl) | Set/clear occupancy tracking with range and state assertions |

## Domain-library examples

| Example | Primary lesson |
|---|---|
| [`noc/noc-route-computer.rhdl`](noc/noc-route-computer.rhdl) | Validated NoC route rows lowered into an exhaustively checked combinational decoder |
| [`noc/noc-router.rhdl`](noc/noc-router.rhdl) | Validated one-beat NoC routing with per-origin buffers, one-to-one allocation, ejection, and backpressure |
| [`noc/noc-network.rhdl`](noc/noc-network.rhdl) | Three user-owned router subsystems assembled hierarchically from pure router and VC wiring plans |
| [`noc/noc-crossbar.rhdl`](noc/noc-crossbar.rhdl) | Linkless one-router NoC elaborated as a three-ingress, three-ejection generalized crossbar |
| [`riscv/instruction-pattern.rhdl`](riscv/instruction-pattern.rhdl) | RV32I and RV64I descriptors materialized as typed patterns |
| [`riscv/instruction-fields.rhdl`](riscv/instruction-fields.rhdl) | Descriptor-generated instruction fields and sign-extended immediates |
| [`chi/ram.rhdl`](chi/ram.rhdl) | Finite initial-profile non-coherent CHI backing RAM |
| [`chi/home.rhdl`](chi/home.rhdl) | Decoupled HN-I transaction translation between requester and subordinate flows |
| [`cores/decoded-alu.rhdl`](cores/decoded-alu.rhdl) | RV64I decode connected directly to the reusable integer ALU |
| [`cores/rv5stage.rhdl`](cores/rv5stage.rhdl) | Complete RV64 RV5Stage core with private instruction and data caches |
| [`noc/wormhole-router-diagram.rhdl`](noc/wormhole-router-diagram.rhdl) | Flow-aware diagram of a packet-retaining phased-XY router with five inputs and five targets |
| [`rv5stage/core-diagram.rhdl`](rv5stage/core-diagram.rhdl) | Flow-aware logical diagram extraction for the flow-oriented RV5Stage core |

## Formal example

[`formal/equivalence.rhm`](formal/equivalence.rhm) asks the optional Rosette
engine to prove that standard-profile and explicitly composed adders are
behaviorally equivalent. It is excluded from the default example suite so
ordinary Rhodium use does not require Rosette:

```sh
make examples-formal
```

## Interface topology composition

[`rtl/interface-array.rhdl`](rtl/interface-array.rhdl) separates the generic interface
model from ready-valid flow control. It demonstrates direct endpoint bulk
connection with `<=>`, serial composition of two `interface_link` handles, and
parallel composition into array-shaped handle or sink ends. Handles and sinks
work for any directional interface, including the bidirectional `ByteExchange`
protocol.

[`rtl/interface-specialization.rhdl`](rtl/interface-specialization.rhdl) demonstrates
declaration-owned compatibility between specializations of one nominal
interface. A provider with greater semantic capacity can satisfy a smaller
requirement in either `<=>` operand order, including through a nested interface
member. Its width-adapter circuit separately shows that semantic compatibility
does not waive exact physical wire shape: width conversion remains explicit.

[`std/flow-topology.rhdl`](std/flow-topology.rhdl) then layers ready-valid operations on
that generic mechanism. Its three integrated circuits show the complete
composition vocabulary:

- `EndpointFirstTopology` starts from concrete endpoints and applies an
  arbiter and pipe immediately.
- `FanInProjectTopology` builds a handle before attaching endpoints, combining
  per-lane maps, round-robin fan-in, stateful buffering, atomic fanout, and
  independent projections.
- `ZipRouteTopology` atomically joins heterogeneous inputs, buffers the joined
  payload, routes by a payload field, and maps both outputs in parallel.

The operator boundary is deliberate: `|>` applies or composes handles,
terminates scalar chains into endpoints, and returns any still-open end, while
`<=>` bulk-connects endpoint arrays and expresses symmetric refinement
merge/split wiring. Piping a handle into an endpoint closes one branch and
returns a sink, allowing `parallel` to terminate heterogeneous branches inside
one chain. Compact `payload => expression` binders keep maps, zips, and payload
routing directly inside pipelines; their colon-bodied forms remain available
for multiline transformations. Pure maps and zips elaborate as local wiring;
pipes, queues, arbiters, and forks remain explicit circuit instances where
they represent state or a meaningful structural boundary.

[`rtl/add-pair.rhm`](rtl/add-pair.rhm) is intentionally an ordinary Rhombus library,
showing that useful Rhodium composition need not modify a reader or define a
macro. [`lop/inspect-ir.rhm`](lop/inspect-ir.rhm) is an intentionally non-CIRCT
consumer that walks the public IR.

Run every example with:

```sh
make examples
```

The directory-specific targets `examples-rhodium`, `examples-clocking`,
`examples-std`, `examples-noc`, `examples-lop`,
`examples-rfpl`, `examples-riscv`, `examples-chi`, and
`examples-cores` run one ownership group. CI selects only groups affected by
the changed implementation layer: core and frontend changes reach every group,
standard-library changes reach every group that imports `rhodium/std`, and domain
changes remain local to their group.

## Generated Verilog

Every concrete example design colocates its complete generated Verilog. The
canonical `design` uses `verilog_reference`; additional names such as
`register_design` use the matching `register_verilog_reference`. Generic
circuit generators need a concrete `*_design` elaboration before they have one
specific Verilog form.

`make examples` checks that every concrete design owns and exports a nonempty
reference and appears in the backend golden manifest. The comparison, update,
and Verilator workflows are documented in
[`../tests/backend/README.md`](../tests/backend/README.md).
