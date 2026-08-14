<!-- Presents RHDL's executable language-oriented walkthrough and canonical feature examples. -->

# RHDL examples

The examples demonstrate that progressively richer authoring layers construct
one public hardware IR. Language and component details live in the
[`rhdl/`](../rhdl/README.md) documentation; this guide owns the executable
walkthrough and example index.

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
  [`interface.rhdl`](interface.rhdl) compare directional records with
  role-based interfaces.
- [`lop/width-ops-kernel.rhm`](lop/width-ops-kernel.rhm) and
  [`width-ops.rhdl`](width-ops.rhdl) compare explicit kernel operations with
  concise indexing and width syntax.

The [frontend guide](../rhdl/frontend/README.md) explains the profiles, and
the [layer guide](../rhdl/frontend/layers/README.md) documents their features.

## Feature showcases

| Example | Primary lesson |
|---|---|
| [`full-adder.rhdl`](full-adder.rhdl) | Nominal Boolean ports and carry logic |
| [`adder4.rhdl`](adder4.rhdl) | Ripple-carry hierarchy and pack-aware concatenation |
| [`generated-adder.rhdl`](generated-adder.rhdl) | Host `InstanceArray` generation plus runtime vector wiring |
| [`alu.rhdl`](alu.rhdl) | Boolean, bitwise, arithmetic, equality, and N-way selection |
| [`unsigned-comparisons.rhdl`](unsigned-comparisons.rhdl) | Unsigned ordering derived from one core comparison |
| [`enum-state.rhdl`](enum-state.rhdl) | Nominal enums, explicit encodings, state, and invalid recovery |
| [`one-hot.rhdl`](one-hot.rhdl) | One-hot literals, selection, equality, and representation casts |
| [`shifts.rhdl`](shifts.rhdl) | Logical shifts with independent amount widths |
| [`expanding-arithmetic.rhdl`](expanding-arithmetic.rhdl) | Lossless arithmetic over unequal-width operands |
| [`counter.rhdl`](counter.rhdl) | Host helper functions accepting and returning hardware |
| [`standard-counter.rhdl`](standard-counter.rhdl) | Reusable bounded counter with wrap indication |
| [`sync-counter.rhdl`](sync-counter.rhdl) | Ambient clock/reset policy and explicit override |
| [`enable-shift-register.rhdl`](enable-shift-register.rhdl) | Hardware conditionals, register hold, and synchronous reset |
| [`reset-shift-register.rhdl`](reset-shift-register.rhdl) | Inferred reset-initialized registers |
| [`hierarchy.rhdl`](hierarchy.rhdl) | Reused module definitions and child-port access |
| [`nested-circuit.rhdl`](nested-circuit.rhdl) | Lexically private child generators with explicit hardware boundaries |
| [`layered-adder.rhdl`](layered-adder.rhdl) | Ordinary imported library plus generated structure |
| [`fresh-generators.rhdl`](fresh-generators.rhdl) | Fresh definitions without automatic deduplication |
| [`host-parameters.rhdl`](host-parameters.rhdl) | Opaque host parameters and type-producing closures |
| [`riscv-control-annotations.rhm`](riscv-control-annotations.rhm) | Independent typed host control layers over an immutable architectural catalog |
| [`tiny-simd.rhdl`](tiny-simd.rhdl) | Integrated host-specialized SIMD, bundles, enums, memory, vectors, and state |
| [`stack.rhdl`](stack.rhdl) | Memory, guarded writes, nested hardware control, and bounds checks |
| [`async-read-memory.rhdl`](async-read-memory.rhdl) | Asynchronous reads and synchronous writes |
| [`sync-memory.rhdl`](sync-memory.rhdl) | Circuit-shaped synchronous memory with explicit read and write ports |
| [`sync-memory-1rw.rhdl`](sync-memory-1rw.rhdl) | One shared synchronous read-write physical port |
| [`sync-memory-masked.rhdl`](sync-memory-masked.rhdl) | Byte-masked writes through a shared synchronous memory port |
| [`simple-memory.rhdl`](simple-memory.rhdl) | Parameterized aligned byte-masked `SimpleMemory` protocol |
| [`simple-memory-flow.rhdl`](simple-memory-flow.rhdl) | `SimpleMemory` request and response channels composed with standard flow control |
| [`simple-memory-ram.rhdl`](simple-memory-ram.rhdl) | Finite byte-masked synchronous RAM serving a `SimpleMemory` interface |
| [`multi-write-memory.rhdl`](multi-write-memory.rhdl) | Independent same-clock physical write ports |
| [`clocked-dpi.rhdl`](clocked-dpi.rhdl) | DPI procedure effects plus single- and multi-result DPI register state |
| [`assertions.rhdl`](assertions.rhdl) | Reset-suppressed assertions with branch-derived activation guards |
| [`width-ops.rhdl`](width-ops.rhdl) | Concatenation, slicing, and explicit width changes |
| [`dont-care.rhdl`](dont-care.rhdl) | Typed synthesis freedom and Pattern-selected fixed bits |
| [`decode.rhdl`](decode.rhdl) | Callable typed decode relation with named aggregate fields and semantic enum values |
| [`bundle.rhdl`](bundle.rhdl) | Structural records, recursive literal shadows, muxes, casts, and state |
| [`vector.rhdl`](vector.rhdl) | Fixed vectors, selection, packing, aggregate drives, and state |
| [`vector-update.rhdl`](vector-update.rhdl) | Functional hardware-selected replacement |
| [`table.rhdl`](table.rhdl) | Host-generated combinational vector table |
| [`vec-search.rhdl`](vec-search.rhdl) | Registered traversal of a host-defined vector pattern |
| [`vec-shift-register.rhdl`](vec-shift-register.rhdl) | Priority aggregate load and shift updates |
| [`vec-shift-register-param.rhdl`](vec-shift-register-param.rhdl) | Host-parameterized vector pipeline |
| [`predicate-filter.rhdl`](predicate-filter.rhdl) | Host predicate closures specialized through a `Valid` interface |
| [`wire.rhdl`](wire.rhdl) | Internal aggregate wire assembled by element |
| [`interface.rhdl`](interface.rhdl) | Ready-valid fields, bulk connection, and instance reconstruction |
| [`ready-valid-compatibility.rhdl`](ready-valid-compatibility.rhdl) | Safe protocol weakening and refinement merge/split |
| [`interface-array.rhdl`](interface-array.rhdl) | Host-sized endpoint arrays and flattened ports |
| [`nested-interface.rhdl`](nested-interface.rhdl) | Recursive interface composition and orientation |
| [`flow-control.rhdl`](flow-control.rhdl) | Pipe, queue, fixed-priority arbiter, and typed endpoint chaining |
| [`flow-topology.rhdl`](flow-topology.rhdl) | Round-robin arbitration, demux, atomic join, and exactly-once broadcast |
| [`ctrl-flow.rhdl`](ctrl-flow.rhdl) | Payloadless token-flow versions of pipe, queue, arbitration, routing, join, and broadcast |

[`add-pair.rhm`](add-pair.rhm) is intentionally an ordinary Rhombus library,
showing that useful RHDL composition need not modify a reader or define a
macro. [`inspect-ir.rhm`](inspect-ir.rhm) is an intentionally non-CIRCT
consumer that walks the public IR.

Run every example with:

```sh
make examples
```

## Generated Verilog

Canonical feature examples colocate exact `verilog_reference` strings with
their exported designs. The comparison, update, and Verilator workflows are
documented in [`../tests/backend/README.md`](../tests/backend/README.md).
