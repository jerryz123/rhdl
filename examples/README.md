<!-- Presents the executable RHDL and RFPL walkthroughs and canonical feature examples. -->

# RHDL and RFPL examples

The examples demonstrate that progressively richer authoring layers construct
one public hardware IR. Language and component details live in the
[`rhdl/`](../rhdl/README.md) documentation; this guide owns the executable
walkthrough and example index.

Examples are grouped by the API or domain that owns their primary lesson:

| Directory | Contents |
|---|---|
| [`rhdl/`](rhdl/) | Built-in `#lang rhdl` syntax, elaboration, and hardware semantics |
| [`clocking/`](clocking/) | Frontend timing declarations and backend-independent temporal-provenance analysis over completed RHDL IR |
| [`std/`](std/) | Reusable protocols and components imported from `rhdl/std` |
| [`noc/`](noc/) | Hardware examples owned by the graph-validated NoC domain library |
| [`ridx/`](ridx/) | Ridx-driven structural hardware generation |
| [`riscv/`](riscv/) | RISC-V descriptor adapters and field extraction |
| [`chi/`](chi/) | AMBA CHI endpoints and finite components |
| [`cores/`](cores/) | Reusable processor datapaths and complete named cores |
| [`lop/`](lop/) | Equivalent designs expressed at different levels of abstraction |
| [`rfpl/`](rfpl/) | Logical designs paired with physical floorplans |
| [`formal/`](formal/) | Optional Rosette-backed behavioral proofs |

## One IR, layered languages

Start with four versions of the same 8-bit adder:

| Layer | Example | Contribution |
|---|---|---|
| Public core | [`lop/adder-core.rhm`](lop/adder-core.rhm) | Explicit `Design`, `Builder`, and verification APIs |
| Elaboration kernel | [`lop/adder-kernel.rhm`](lop/adder-kernel.rhm) | Active-context construction functions |
| Composed language | [`lop/adder-composed.rhdl`](lop/adder-composed.rhdl) | `#lang rhdl/base` plus an explicit combinational layer |
| Standard profile | [`lop/adder-standard.rhdl`](lop/adder-standard.rhdl) | Curated `#lang rhdl` syntax |

The sources become progressively shorter while constructing identical printed
RHDL IR and CIRCT MLIR:

```sh
make lop-test
```

```text
direct Builder     elaboration kernel     base + comb     standard profile
       \                  |                    |                 /
        +-----------------+--------------------+----------------+
                                  |
                                  v
                          public RHDL IR
                                  |
                                  v
                             CIRCT MLIR
```

The aggregate equivalence examples make the same boundary executable:

- [`lop/bundle-kernel.rhdl`](lop/bundle-kernel.rhdl) and
  [`lop/bundle-standard.rhdl`](lop/bundle-standard.rhdl) compare explicit
  record construction with bundle syntax.
- [`lop/interface-records.rhdl`](lop/interface-records.rhdl) and
  [`rhdl/interface.rhdl`](rhdl/interface.rhdl) compare directional records with
  role-based interfaces.
- [`lop/width-ops-kernel.rhm`](lop/width-ops-kernel.rhm) and
  [`rhdl/width-ops.rhdl`](rhdl/width-ops.rhdl) compare explicit kernel operations with
  concise indexing and width syntax.
- [`lop/counter-composed.rhdl`](lop/counter-composed.rhdl) and
  [`rhdl/sync-counter.rhdl`](rhdl/sync-counter.rhdl) show that explicitly selected
  sequential layers and the standard profile construct the same clocked IR.

The [frontend guide](../rhdl/frontend/README.md) explains the profiles, and
the [layer guide](../rhdl/frontend/layers/README.md) documents their features.

## Clocking-analysis examples

The examples under [`clocking/`](clocking/) use the clocking frontend layer or
import `rhdl/analysis/clocking.rhm` directly. Environment and report objects
remain outside core IR; explicit crossing evidence can now affect CDC
verification and backend register attributes.

- [`clocking/frontend-environment.rhdl`](clocking/frontend-environment.rhdl)
  uses `#lang rhdl/base` with the selectable clocking layer to declare local,
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

[`rfpl/circuit-pair.rhdl`](rfpl/circuit-pair.rhdl) defines an ordinary RHDL
hierarchy. [`rfpl/circuit-pair.rfpl`](rfpl/circuit-pair.rfpl) annotates its
logic-bearing `Adder` as a hard macro and its wiring-only `AdderShell` and
`AdderPair` circuits as composite floorplans. Every physical view has an exact
rectangle and every direct composite child has a contained coordinate. The
colocated `verilog_reference` confirms that annotation adds no modules, ports,
instances, or logic to the generated RTL.

## RHDL language examples

| Example | Primary lesson |
|---|---|
| [`rhdl/full-adder.rhdl`](rhdl/full-adder.rhdl) | Nominal Boolean ports and carry logic |
| [`rhdl/adder4.rhdl`](rhdl/adder4.rhdl) | Ripple-carry hierarchy and pack-aware concatenation |
| [`rhdl/generated-adder.rhdl`](rhdl/generated-adder.rhdl) | Host `InstanceArray` generation plus runtime vector wiring |
| [`rhdl/alu.rhdl`](rhdl/alu.rhdl) | Boolean, bitwise, arithmetic, equality, and N-way selection |
| [`rhdl/unsigned-comparisons.rhdl`](rhdl/unsigned-comparisons.rhdl) | Unsigned ordering derived from one core comparison |
| [`rhdl/signed-integers.rhdl`](rhdl/signed-integers.rhdl) | Explicit-width signed arithmetic, ordering, shifts, and resizing |
| [`rhdl/enum-state.rhdl`](rhdl/enum-state.rhdl) | Equivalent enum mux/switch forms, explicit encodings, and invalid recovery |
| [`rhdl/one-hot.rhdl`](rhdl/one-hot.rhdl) | One-hot literals, selection, equality, and representation casts |
| [`rhdl/one-hot-enum.rhdl`](rhdl/one-hot-enum.rhdl) | Nominal one-hot enums selecting named datapath result families |
| [`rhdl/shifts.rhdl`](rhdl/shifts.rhdl) | Logical shifts with host constants and independent hardware amount widths |
| [`rhdl/multiply.rhdl`](rhdl/multiply.rhdl) | Modular same-width unsigned multiplication |
| [`rhdl/expanding-arithmetic.rhdl`](rhdl/expanding-arithmetic.rhdl) | Lossless arithmetic over unequal-width operands |
| [`rhdl/counter.rhdl`](rhdl/counter.rhdl) | Host helper functions accepting and returning hardware |
| [`rhdl/sync-counter.rhdl`](rhdl/sync-counter.rhdl) | Ambient clock/reset policy and explicit override |
| [`rhdl/enable-shift-register.rhdl`](rhdl/enable-shift-register.rhdl) | Hardware conditionals, register hold, and synchronous reset |
| [`rhdl/reset-shift-register.rhdl`](rhdl/reset-shift-register.rhdl) | Inferred reset-initialized registers |
| [`rhdl/hierarchy.rhdl`](rhdl/hierarchy.rhdl) | Reused module definitions and child-port access |
| [`rhdl/nested-circuit.rhdl`](rhdl/nested-circuit.rhdl) | Lexically private child generators with explicit hardware boundaries |
| [`rhdl/layered-adder.rhdl`](rhdl/layered-adder.rhdl) | Ordinary imported library plus generated structure |
| [`rhdl/fresh-generators.rhdl`](rhdl/fresh-generators.rhdl) | Fresh definitions without automatic deduplication |
| [`rhdl/host-parameters.rhdl`](rhdl/host-parameters.rhdl) | Opaque host parameters and type-producing closures |
| [`rhdl/generator-parameters.rhdl`](rhdl/generator-parameters.rhdl) | Positional, keyword, typed, defaulted, and synchronous generator parameters |
| [`rhdl/register-forms.rhdl`](rhdl/register-forms.rhdl) | Inferred register types, immediate next values, reset values, and direct drives |
| [`rhdl/tiny-simd.rhdl`](rhdl/tiny-simd.rhdl) | Integrated host-specialized SIMD, bundles, enums, memory, vectors, and state |
| [`rhdl/stack.rhdl`](rhdl/stack.rhdl) | Memory, guarded writes, nested hardware control, and bounds checks |
| [`rhdl/async-read-memory.rhdl`](rhdl/async-read-memory.rhdl) | Asynchronous reads and synchronous writes |
| [`rhdl/sync-memory.rhdl`](rhdl/sync-memory.rhdl) | Circuit-shaped synchronous memory with explicit read and write ports |
| [`rhdl/sync-memory-1rw.rhdl`](rhdl/sync-memory-1rw.rhdl) | One shared synchronous read-write physical port |
| [`rhdl/sync-memory-masked.rhdl`](rhdl/sync-memory-masked.rhdl) | Byte-masked writes through a shared synchronous memory port |
| [`rhdl/multi-write-memory.rhdl`](rhdl/multi-write-memory.rhdl) | Independent same-clock physical write ports |
| [`rhdl/clocked-dpi.rhdl`](rhdl/clocked-dpi.rhdl) | DPI procedure effects plus single- and multi-result DPI register state |
| [`rhdl/assertions.rhdl`](rhdl/assertions.rhdl) | Reset-suppressed assertions with branch-derived activation guards |
| [`rhdl/width-ops.rhdl`](rhdl/width-ops.rhdl) | Concatenation, slicing, and explicit width changes |
| [`rhdl/bundle.rhdl`](rhdl/bundle.rhdl) | Type-named fixed and elaboration-conditional bundles, recursive literal shadows, muxes, casts, and state |
| [`rhdl/vector.rhdl`](rhdl/vector.rhdl) | Fixed vectors, selection, `as_bits`/`as_vec` representation changes, aggregate drives, and state |
| [`rhdl/vector-update.rhdl`](rhdl/vector-update.rhdl) | Functional replacement and dynamic vector-register writes |
| [`rhdl/table.rhdl`](rhdl/table.rhdl) | Host-generated combinational vector table |
| [`rhdl/vec-search.rhdl`](rhdl/vec-search.rhdl) | Registered traversal of a host-defined vector pattern |
| [`rhdl/vec-shift-register.rhdl`](rhdl/vec-shift-register.rhdl) | Priority aggregate load and shift updates |
| [`rhdl/vec-shift-register-param.rhdl`](rhdl/vec-shift-register-param.rhdl) | Host-parameterized vector pipeline |
| [`rhdl/predicate-filter.rhdl`](rhdl/predicate-filter.rhdl) | Host predicate closures specialized through a `Valid` interface |
| [`rhdl/wire.rhdl`](rhdl/wire.rhdl) | Forward-readable aggregate wire driven later by element |
| [`rhdl/interface.rhdl`](rhdl/interface.rhdl) | Ready-valid fields, bulk connection, and instance reconstruction |
| [`rhdl/interface-specialization.rhdl`](rhdl/interface-specialization.rhdl) | Directional parameter compatibility, nested rules, operand reversal, and explicit width adaptation |
| [`rhdl/interface-array.rhdl`](rhdl/interface-array.rhdl) | Endpoint arrays, positional sequences, generic interface links, handles, and terminated sinks |
| [`rhdl/nested-interface.rhdl`](rhdl/nested-interface.rhdl) | Recursive interface composition and orientation |
| [`rhdl/interface-monitor.rhdl`](rhdl/interface-monitor.rhdl) | Read-only endpoint observations and explicit protocol assertions |
| [`rhdl/interface-transform.rhdl`](rhdl/interface-transform.rhdl) | Typed custom interface transforms, fanout, and detached terminals |
| [`rhdl/priority-encoder.rhdl`](rhdl/priority-encoder.rhdl) | Lower-index-first priority selection over packed and aggregate inputs |
| [`rhdl/bit-utilities.rhdl`](rhdl/bit-utilities.rhdl) | Negation, reductions, membership predicates, and enum validity |

## Standard-library examples

| Example | Primary lesson |
|---|---|
| [`std/standard-counter.rhdl`](std/standard-counter.rhdl) | Reusable bounded counter with wrap indication |
| [`std/sync-ram.rhdl`](std/sync-ram.rhdl) | One generic lane-masked `Valid` request flow over a fixed-latency shared 1RW RAM |
| [`std/simple-memory.rhdl`](std/simple-memory.rhdl) | Parameterized byte-masked `SimpleMemory` protocol plus generic alignment operations |
| [`std/simple-memory-flow.rhdl`](std/simple-memory-flow.rhdl) | `SimpleMemory` request and response channels composed with standard flow control |
| [`std/simple-memory-ram.rhdl`](std/simple-memory-ram.rhdl) | Finite byte-masked synchronous RAM serving a `SimpleMemory` interface |
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
| [`std/scoreboard.rhdl`](std/scoreboard.rhdl) | Set/clear occupancy tracking with range and state assertions |

## Domain-library examples

| Example | Primary lesson |
|---|---|
| [`noc/noc-route-computer.rhdl`](noc/noc-route-computer.rhdl) | Validated NoC route rows lowered into an exhaustively checked combinational decoder |
| [`noc/noc-router.rhdl`](noc/noc-router.rhdl) | Validated one-beat NoC routing with per-origin buffers, one-to-one allocation, ejection, and backpressure |
| [`noc/noc-network.rhdl`](noc/noc-network.rhdl) | Three user-owned router subsystems assembled hierarchically from pure router and VC wiring plans |
| [`noc/noc-crossbar.rhdl`](noc/noc-crossbar.rhdl) | Linkless one-router NoC elaborated as a three-ingress, three-ejection generalized crossbar |
| [`ridx/grid.rhdl`](ridx/grid.rhdl) | Ridx views, relations, and mappings generating a finite RHDL grid |
| [`riscv/instruction-pattern.rhdl`](riscv/instruction-pattern.rhdl) | RV32I and RV64I descriptors materialized as typed patterns |
| [`riscv/instruction-fields.rhdl`](riscv/instruction-fields.rhdl) | Descriptor-generated instruction fields and sign-extended immediates |
| [`chi/ram.rhdl`](chi/ram.rhdl) | Finite initial-profile non-coherent CHI backing RAM |
| [`chi/home.rhdl`](chi/home.rhdl) | Bounded HN-I between one requester and one subordinate port |
| [`cores/decoded-alu.rhdl`](cores/decoded-alu.rhdl) | RV64I decode connected directly to the reusable integer ALU |
| [`cores/ricket.rhdl`](cores/ricket.rhdl) | Complete RV64 Ricket core with private instruction and data caches |

## Formal example

[`formal/equivalence.rhm`](formal/equivalence.rhm) asks the optional Rosette
engine to prove that standard-profile and explicitly composed adders are
behaviorally equivalent. It is excluded from the default example suite so
ordinary RHDL use does not require Rosette:

```sh
make examples-formal
```

## Interface topology composition

[`rhdl/interface-array.rhdl`](rhdl/interface-array.rhdl) separates the generic interface
model from ready-valid flow control. It demonstrates direct endpoint bulk
connection with `<=>`, serial composition of two `interface_link` handles, and
parallel composition into array-shaped handle or sink ends. Handles and sinks
work for any directional interface, including the bidirectional `ByteExchange`
protocol.

[`rhdl/interface-specialization.rhdl`](rhdl/interface-specialization.rhdl) demonstrates
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

[`rhdl/add-pair.rhm`](rhdl/add-pair.rhm) is intentionally an ordinary Rhombus library,
showing that useful RHDL composition need not modify a reader or define a
macro. [`lop/inspect-ir.rhm`](lop/inspect-ir.rhm) is an intentionally non-CIRCT
consumer that walks the public IR.

Run every example with:

```sh
make examples
```

The directory-specific targets `examples-rhdl`, `examples-clocking`,
`examples-std`, `examples-noc`, `examples-lop`,
`examples-rfpl`, `examples-ridx`, `examples-riscv`, `examples-chi`, and
`examples-cores` run one ownership group. CI selects only groups affected by
the changed implementation layer: core and frontend changes reach every group,
standard-library changes reach every group that imports `rhdl/std`, and domain
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
