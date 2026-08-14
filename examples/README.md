<!-- Presents the examples as an executable language-oriented programming walkthrough. -->

# RHDL examples: one IR, layered languages

RHDL treats an HDL as a family of languages built over one public hardware IR.
The core owns hardware semantics. The elaboration kernel makes those semantics
available as ordinary Rhombus functions. Frontend layers then add notation,
binding conventions, types, and reusable abstractions without changing the IR.

Start with the four versions of the same 8-bit adder:

| Layer | Example | What the layer contributes |
|---|---|---|
| Public core | [`lop/adder-core.rhm`](lop/adder-core.rhm) | Ordinary Rhombus explicitly importing `Design`, `Builder`, verification, and related core APIs |
| Elaboration kernel | [`lop/adder-kernel.rhm`](lop/adder-kernel.rhm) | Ordinary Rhombus explicitly importing active-context construction functions |
| Composed language | [`lop/adder-composed.rhdl`](lop/adder-composed.rhdl) | `#lang rhdl/base` plus an explicit combinational-module import |
| Standard profile | [`lop/adder-standard.rhdl`](lop/adder-standard.rhdl) | The curated `#lang rhdl` composition |

The sources become progressively shorter, but all four construct identical
printed RHDL IR and identical CIRCT MLIR. The focused test makes that claim
executable:

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

The core version is intentionally verbose; it exposes the semantic substrate
used by verification and lowering. The kernel version is suitable for
libraries that want explicit construction without defining syntax. The
composed version makes language assembly visible, while the standard version
is the normal circuit-authoring style.

## Language profiles and frontend layers

`#lang rhdl/base` contains the shared circuit boundary: `Bits`, `Clock`,
`Reset`, binding-derived ports, `circuit`, `elaborate`, `<==`, and the guarded
host `if`. It intentionally does not expose the public core Builder or raw
elaboration kernel.

Existing frontend behavior is grouped into a foundation and independently
importable layers:

| Module | Existing behavior it contributes |
|---|---|
| [`foundation.rhm`](../rhdl/frontend/foundation.rhm) | Circuit generators, ports, connections, basic public types, indexing, and `.into` casts |
| [`layers/cast.rhm`](../rhdl/frontend/layers/cast.rhm) | Functional `cast(value, T)` spelling for equal-width representation casts |
| [`layers/comb.rhm`](../rhdl/frontend/layers/comb.rhm) | Literals, modular arithmetic, bitwise syntax, lookup muxes, and width operations |
| [`layers/expanding-arithmetic.rhm`](../rhdl/frontend/layers/expanding-arithmetic.rhm) | Lossless unsigned addition and multiplication, with `+&` and `*&` sugar |
| [`layers/bool.rhm`](../rhdl/frontend/layers/bool.rhm) | Nominal `Bool`, callable host-Boolean literals, `===`, unsigned ordering, and binary `mux` |
| [`layers/enum.rhm`](../rhdl/frontend/layers/enum.rhm) | Nominal hardware enums with automatic or explicit encodings |
| [`layers/one-hot.rhm`](../rhdl/frontend/layers/one-hot.rhm) | Structurally sized exact-one-hot values, literals, typed mux keys, and indexed `mux_onehot` selection |
| [`layers/bundle.rhm`](../rhdl/frontend/layers/bundle.rhm) | Bundle declarations, record construction, and field dot access |
| [`layers/interface.rhm`](../rhdl/frontend/layers/interface.rhm) | Explicit protocol roles, directional record ports, public endpoint annotations, host-sized endpoint arrays, bulk connection, and instance reconstruction |
| [`layers/wire.rhm`](../rhdl/frontend/layers/wire.rhm) | Binding-derived single-driver internal wires |
| [`layers/sequential.rhm`](../rhdl/frontend/layers/sequential.rhm) | Binding-derived registers |
| [`layers/hierarchy.rhm`](../rhdl/frontend/layers/hierarchy.rhm) | Binding-derived instances, deterministic names, and child-port dot access |
| [`layers/sync.rhm`](../rhdl/frontend/layers/sync.rhm) | Sync circuits, ambient registers, and marked-child clock/reset propagation |
| [`layers/vector.rhm`](../rhdl/frontend/layers/vector.rhm) | Concise fixed-length vector types and inferred construction |
| [`layers/memory.rhm`](../rhdl/frontend/layers/memory.rhm) | Binding-derived memories with async indexing and synchronous writes |
| [`layers/dpi.rhm`](../rhdl/frontend/layers/dpi.rhm) | Design-level DPI-C imports, result-less procedure calls, and explicit DPI registers |

[`standard.rhm`](../rhdl/frontend/standard.rhm) contains no feature
implementation. It aggregates the foundation and the curated layers, including
enum, one-hot, and sync. `#lang rhdl` exposes that curated standard profile. The lower-level
[`kernel.rhm`](../rhdl/frontend/kernel.rhm) and [`core/main.rhm`](../rhdl/core/main.rhm)
remain explicit library imports.

The package rules and exact direct dependencies of these layers are documented
in [`ARCHITECTURE.md`](../ARCHITECTURE.md).

Reusable protocol declarations live separately under [`rhdl/std`](../rhdl/std)
because they use the public language without extending it. The initial
[`ready-valid.rhdl`](../rhdl/std/ready-valid.rhdl) module provides `Valid`,
`DecoupledControl`, `IrrevocableControl`, `Decoupled`, and `Irrevocable` as
opt-in nominal interface types, plus the common `fire` helper. The
[`flow/`](../rhdl/std/flow) directory contains separate elastic pipe, FIFO
queue, and fixed-priority arbiter modules; [`flow.rhdl`](../rhdl/std/flow.rhdl)
re-exports all three for convenience. [`counter.rhdl`](../rhdl/std/counter.rhdl)
provides an enabled bounded counter with value and wrap outputs.

## What the standard language adds

The standard frontend aggregates the foundation and layers above. Their forms
layer over [`rhdl/frontend/kernel.rhm`](../rhdl/frontend/kernel.rhm):

| Standard form | Kernel meaning |
|---|---|
| `circuit Adder(width): ...` | A function calling `build_circuit(...)` |
| `input(a, b): T` | Two `input(name, T)` calls |
| `output sum: T` | `output("sum", T)` |
| `sum <== value` | `connect(sum, value)` |
| `a + b` | `hw_add(a, b)` |
| `a * b` | `hw_mul(a, b)` |
| `a +& b` | `add_expanding(a, b)` |
| `a *& b` | `mul_expanding(a, b)` |
| `add_expanding(a, b)` | Zero-extend to `max(width(a), width(b)) + 1`, then `hw_add` |
| `mul_expanding(a, b)` | Zero-extend to `width(a) + width(b)`, then `hw_mul` |
| `bits(1, w)` | `literal(Bits(w), 1)` |
| `reg state(T, ...)` | `reg("state", T, ...)` |
| `inst u(Child)` | A suggested-name instance using `"u"` as its deterministic base |
| `u.port` | Lookup in the elaborated child interface |
| `bundle Pair(T): ...` | A function constructing a core `RecordType` |
| `record(Pair(T)): ...` | `rtl.record_create` |
| `value.field` | `rtl.record_get` or construction-time place projection |
| `bits_value[index]` | `rtl.extract(value, index, index)` |
| `value[low..high]` | `rtl.extract(value, high - 1, low)` |
| `value.into(T)` | `rtl.cast` preserving canonical packed width and bit order |
| `OneHot(n)` and `OneHot(n)(index)` | A distinct flat encoding and a power-of-two constant followed by `rtl.cast` |
| `mux_onehot(selector, ~default: fallback): ...` | Indexed choices lowered to one power-of-two-keyed `rtl.mux_lookup` |
| `concat(a, b, ...)` or `concat(parts)` | Canonical packing as needed, then one Bits-only `rtl.concat` |
| `Vec(n, T)` | Core `VectorType(n, T)` |
| `vec(a, b, ...)` or `vec(elements)` | `rtl.vector_create` with inferred uniform element type |
| `vector[index]` | Static `rtl.vector_get` or construction-time element-place projection |
| `state.next[index] <== value` | Element-wise drive of an aggregate register's next-state place |
| `vector.lookup(selector, ~default: value)` | Static projections plus one core `rtl.mux_lookup` |
| `vector.updated(selector, replacement)` | Static projections, per-element muxes, and one reconstructed vector value |
| `wire temporary: T` | One core `rtl.wire` place, readable after a complete single drive |
| `mem storage(depth, T)` | One core `Memory` resource and `rtl.memory` allocation |
| `storage[address]` | `rtl.memory_read_async(storage, address)` |
| `storage.write(address, data, ...)` | One clocked `rtl.memory_write` port |
| `dpi_import procedure p(a: T)` | One result-less design-level DPI import |
| `p.call(a, ~clock: clock, ~enable: enable)` | One result-less, mandatory-clock `sim.dpi_call` |
| `dpi_import function f(a: T) -> result: R` | One result-bearing design-level DPI import |
| `dpi_reg r = f(a, ~clock: clock, ~enable: enable)` | One visible, mandatory-clock `sim.dpi_register` state value |
| `interface tx(..., ~role: producer)` | Directional record-typed core ports plus frontend protocol metadata |
| `interface tx[n](..., ~role: producer)` | A host `Array` of `n` scalar endpoints flattened as `tx_0_in`, `tx_0_out`, and so on |
| `endpoint :: Endpoint.of(protocol)` | A function boundary that retains exact interface type and field static information |
| `interface Child(T) refines Parent(): ...` | A nominal subtype with inherited roles and flattened inherited members |
| `endpoint :: Endpoint.supports(protocol)` | A function boundary accepting an exact protocol or any nominal refinement |
| `left <=> right` | Atomic connection of every compatible interface flow |

[`rhdl/frontend/layers/bool.rhm`](../rhdl/frontend/layers/bool.rhm) is
a separate type layer. It defines nominal `Bool`, Boolean equality, and
binary mux behavior outside core:

| Boolean form | Core representation |
|---|---|
| `Bool(#true)` | `rtl.constant 1 : Bits(1)`, then `rtl.cast` to `Bool` |
| `a === b` | `rtl.eq` producing `Bits(1)`, then `rtl.cast` to `Bool` |
| `a < b` | `rtl.ult` producing `Bits(1)`, then `rtl.cast` to `Bool` |
| `a > b` | `rtl.ult(b, a)`, then `rtl.cast` to `Bool` |
| `a <= b` / `a >= b` | Opposite `rtl.ult`, `rtl.not`, then `rtl.cast` to `Bool` |
| `mux(sel, a, b)` | Cast `Bool` to `Bits(1)`, then one-case `rtl.mux_lookup` |

This division is the central language-oriented design rule: add a core concept
only when it introduces new hardware semantics. Add notation and abstractions
in a language or library layer when existing semantics are sufficient.

The aggregate examples make that boundary executable. The explicit
[`lop/bundle-kernel.rhdl`](lop/bundle-kernel.rhdl) and concise
[`lop/bundle-standard.rhdl`](lop/bundle-standard.rhdl) programs produce the
same record IR and CIRCT MLIR. Likewise,
[`lop/interface-records.rhdl`](lop/interface-records.rhdl) expresses a
ready-valid adapter as raw directional record ports, while
[`interface.rhdl`](interface.rhdl) expresses it using roles and `<=>`; their
outputs are identical. The explicit
[`lop/width-ops-kernel.rhm`](lop/width-ops-kernel.rhm) and concise
[`width-ops.rhdl`](width-ops.rhdl) pair similarly demonstrates that host-range
indexing is only frontend notation for the existing kernel `extract` operation.

## Feature showcases

After the adder ladder, each remaining example has one primary lesson:

| Example | Primary lesson |
|---|---|
| [`full-adder.rhdl`](full-adder.rhdl) | Nominal Boolean ports, named intermediate logic, and an unparenthesized chained carry reduction |
| [`adder4.rhdl`](adder4.rhdl) | Four reused full-adder instances, bit selection, carry chaining, and pack-aware concatenation |
| [`generated-adder.rhdl`](generated-adder.rhdl) | An `InstanceArray` host collection wired through runtime `Vec` carry and sum wires |
| [`alu.rhdl`](alu.rhdl) | Layer-defined `Bool`, `===`, word-form bitwise operators, and canonical N-way selection |
| [`unsigned-comparisons.rhdl`](unsigned-comparisons.rhdl) | Four unsigned ordering forms derived from the single core `rtl.ult` primitive |
| [`enum-state.rhdl`](enum-state.rhdl) | Nominal enums as typed mux selectors and values, explicit encodings, registers, and invalid-state recovery |
| [`one-hot.rhdl`](one-hot.rhdl) | Structurally sized one-hot literals, indexed `mux_onehot`, equality, and explicit representation casts |
| [`shifts.rhdl`](shifts.rhdl) | Fixed-width logical shifts with narrower and wider hardware shift amounts |
| [`expanding-arithmetic.rhdl`](expanding-arithmetic.rhdl) | Lossless unsigned addition and multiplication over unequal-width operands |
| [`counter.rhdl`](counter.rhdl) | Host helper functions that accept hardware values, allocate an ambient register, and return hardware |
| [`standard-counter.rhdl`](standard-counter.rhdl) | Standard-library enabled ten-state counter with explicit wrap indication |
| [`sync-counter.rhdl`](sync-counter.rhdl) | Opt-in implicit clock/reset ports, ambient register syntax, propagation, and explicit domain override |
| [`enable-shift-register.rhdl`](enable-shift-register.rhdl) | Hardware `when` lowered to enable muxes with implicit register hold and synchronous reset |
| [`reset-shift-register.rhdl`](reset-shift-register.rhdl) | Chisel-style reset-initialized registers using inferred types and an ambient sync domain |
| [`hierarchy.rhdl`](hierarchy.rhdl) | Binding-derived instances and dot-based access to elaborated child ports |
| [`nested-circuit.rhdl`](nested-circuit.rhdl) | A lexically private child generator capturing its parent's host width while communicating only through ports |
| [`layered-adder.rhdl`](layered-adder.rhdl) | An ordinary imported Rhombus hardware library plus recursive host-generated structure |
| [`fresh-generators.rhdl`](fresh-generators.rhdl) | Host iteration creates fresh hardware definitions without automatic deduplication |
| [`host-parameters.rhdl`](host-parameters.rhdl) | Hardware types, type-producing closures, lists, and custom host configuration as opaque circuit parameters |
| [`tiny-simd.rhdl`](tiny-simd.rhdl) | Host-specialized SIMD microengine combining comprehension-generated lanes, typed instructions, expanding arithmetic with low-bit slicing, power-of-two program memory, and ambient state |
| [`stack.rhdl`](stack.rhdl) | Host-sized stack combining async-read memory, guarded writes, nested hardware conditionals, unsigned bounds checks, and registered output |
| [`multi-write-memory.rhdl`](multi-write-memory.rhdl) | Two independently enabled same-clock physical write ports on one asynchronous-read memory |
| [`clocked-dpi.rhdl`](clocked-dpi.rhdl) | Result-less procedure effects and explicit DPI register state using ambient and explicit clocks |
| [`width-ops.rhdl`](width-ops.rhdl) | Variadic concatenation, host-range selection, and other width-changing operations over kernel/core semantics |
| [`bundle.rhdl`](bundle.rhdl) | Structural records, canonical record packing, aggregate mux/register state, and record-typed instances |
| [`vector.rhdl`](vector.rhdl) | Fixed vectors, static and hardware selection, packing casts, aggregate drives, muxes, and registers |
| [`vector-update.rhdl`](vector-update.rhdl) | Functional dynamic replacement with unchanged out-of-range behavior |
| [`table.rhdl`](table.rhdl) | Host-generated 256-byte vector contents with exhaustive eight-bit hardware lookup |
| [`vec-search.rhdl`](vec-search.rhdl) | Host-defined pattern materialized as a hardware vector and selected by a wrapping register |
| [`vec-shift-register.rhdl`](vec-shift-register.rhdl) | Priority load and shift updates assembled into one aggregate vector register |
| [`vec-shift-register-param.rhdl`](vec-shift-register-param.rhdl) | Host-selected depth and width with generated reset contents and next-state wiring |
| [`predicate-filter.rhdl`](predicate-filter.rhdl) | Standard-library `Valid` interfaces and host-closure-specialized filter hierarchy |
| [`wire.rhdl`](wire.rhdl) | A vector wire assembled element by element and then read as one value |
| [`interface.rhdl`](interface.rhdl) | Standard-library `Decoupled`, field access, bidirectional bulk connection, and instance reconstruction |
| [`interface-array.rhdl`](interface-array.rhdl) | Host-sized `Decoupled` endpoint arrays, deterministic flattened ports, whole-array connection, and hierarchy reconstruction |
| [`nested-interface.rhdl`](nested-interface.rhdl) | Recursive interface composition, orientation, nested field access, bulk connection, and hierarchy reconstruction |
| [`flow-control.rhdl`](flow-control.rhdl) | Standard-library flow primitives plus a typed `ingress |> queue(_, ...) |> pipe(_, ...)` endpoint chain |

[`add-pair.rhm`](add-pair.rhm) is intentionally an ordinary Rhombus module. It
shows that a useful RHDL construction abstraction need not be a macro or
require a language reader change.

[`inspect-ir.rhm`](inspect-ir.rhm) is an intentionally non-CIRCT consumer. It
uses only the public core API to walk an elaborated design and report module,
operation, and addition counts. It demonstrates that compilation is one use
of the public IR rather than the IR's defining purpose.

Run every example with:

```sh
make examples
```

## Verilog references

Each public feature example exports a `verilog_reference` string beside its
canonical `design`. Backend tests lower that design with the pinned CIRCT
toolchain, discard generated version and temporary-file location comments, and
compare the complete Verilog output exactly:

```sh
make verilog-golden-test
```

Set `FIXTURE=adder` to check one named fixture. Intentional backend-output
changes can be recorded with `make update-verilog-goldens`, followed by normal
review of the example-file diff. The Verilog testbenches remain separate under
`tests/backend/verilog/`; they verify behavior rather than textual output.
