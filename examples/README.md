<!-- Presents the examples as an executable language-oriented programming walkthrough. -->

# RHDL examples: one IR, layered languages

RHDL treats an HDL as a family of languages built over one public hardware IR.
The core owns hardware semantics. The elaboration kernel makes those semantics
available as ordinary Rhombus functions. Frontend extensions then add notation,
binding conventions, types, and reusable abstractions without changing the IR.

Start with the four versions of the same 8-bit adder:

| Layer | Example | What the layer contributes |
|---|---|---|
| Public core | [`lop/adder-core.rhm`](lop/adder-core.rhm) | Ordinary Rhombus explicitly importing `Design`, `Builder`, verification, and related core APIs |
| Elaboration kernel | [`lop/adder-kernel.rhm`](lop/adder-kernel.rhm) | Ordinary Rhombus explicitly importing active-context construction functions |
| Composed language | [`lop/adder-composed.rhdl`](lop/adder-composed.rhdl) | `#lang rhdl/base` plus an explicit combinational-module import |
| Standard extensions | [`lop/adder-standard.rhdl`](lop/adder-standard.rhdl) | `circuit`, binding-derived ports, `+`, `<==`, and `elaborate` |

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

## Language profiles and frontend modules

`#lang rhdl/base` contains the shared circuit boundary: `Bits`, `Clock`,
`Reset`, binding-derived ports, `circuit`, `elaborate`, `<==`, and the guarded
host `if`. It intentionally does not expose the public core Builder or raw
elaboration kernel.

Existing frontend behavior is grouped into independently importable modules:

| Module | Existing behavior it contributes |
|---|---|
| [`base.rhm`](../rhdl/frontend/base.rhm) | Circuit generators, ports, connections, basic public types, indexing, and `.into` casts |
| [`extensions/cast.rhm`](../rhdl/frontend/extensions/cast.rhm) | Functional `cast(value, T)` spelling for equal-width representation casts |
| [`extensions/comb.rhm`](../rhdl/frontend/extensions/comb.rhm) | Literals, arithmetic, bitwise syntax, lookup muxes, and width operations |
| [`extensions/bool.rhm`](../rhdl/frontend/extensions/bool.rhm) | Nominal `Bool`, `===`, and binary `mux` |
| [`extensions/bundle.rhm`](../rhdl/frontend/extensions/bundle.rhm) | Bundle declarations, record construction, and field dot access |
| [`extensions/interface.rhm`](../rhdl/frontend/extensions/interface.rhm) | Explicit protocol roles, directional record ports, bulk connection, and instance reconstruction |
| [`extensions/sequential.rhm`](../rhdl/frontend/extensions/sequential.rhm) | Binding-derived registers |
| [`extensions/hierarchy.rhm`](../rhdl/frontend/extensions/hierarchy.rhm) | Binding-derived instances and child-port dot access |
| [`extensions/vector.rhm`](../rhdl/frontend/extensions/vector.rhm) | Concise fixed-length vector types and inferred construction |

[`standard.rhm`](../rhdl/frontend/standard.rhm) contains no feature
implementation. It aggregates those modules, and `#lang rhdl` exposes that
curated standard profile. The lower-level
[`kernel.rhm`](../rhdl/frontend/kernel.rhm) and [`core/main.rhm`](../rhdl/core/main.rhm)
remain explicit library imports.

## What the standard language adds

The standard frontend aggregates the modules above. Their forms layer over
[`rhdl/frontend/kernel.rhm`](../rhdl/frontend/kernel.rhm):

| Standard form | Kernel meaning |
|---|---|
| `circuit Adder(width): ...` | A function calling `build_circuit(...)` |
| `input(a, b): T` | Two `input(name, T)` calls |
| `output sum: T` | `output("sum", T)` |
| `sum <== value` | `connect(sum, value)` |
| `a + b` | `hw_add(a, b)` |
| `bits(1, ~width: w)` | `literal(Bits(w), 1)` |
| `reg state(T, ...)` | `reg("state", T, ...)` |
| `inst u(Child)` | `inst("u", Child)` with instance static information |
| `u.port` | Lookup in the elaborated child interface |
| `bundle Pair(T): ...` | A function constructing a core `RecordType` |
| `record(Pair(T)): ...` | `rtl.record_create` |
| `value.field` | `rtl.record_get` or construction-time place projection |
| `bits_value[index]` | `rtl.extract(value, index, index)` |
| `value[low..high]` | `rtl.extract(value, high - 1, low)` |
| `value.into(T)` | `rtl.cast` preserving canonical packed width and bit order |
| `concat(a, b, ...)` or `concat(parts)` | Canonical packing as needed, then one Bits-only `rtl.concat` |
| `Vec(n, T)` | Core `VectorType(n, T)` |
| `vec(a, b, ...)` or `vec(elements)` | `rtl.vector_create` with inferred uniform element type |
| `vector[index]` | Static `rtl.vector_get` or construction-time element-place projection |
| `vector.lookup(selector, ~default: value)` | Static projections plus one core `rtl.mux_lookup` |
| `interface tx(..., ~role: producer)` | Directional record-typed core ports plus frontend protocol metadata |
| `left <=> right` | Atomic connection of every compatible interface flow |

[`rhdl/frontend/extensions/bool.rhm`](../rhdl/frontend/extensions/bool.rhm) is
a separate type extension. It defines nominal `Bool`, Boolean equality, and
binary mux behavior outside core:

| Boolean form | Core representation |
|---|---|
| `a === b` | `rtl.eq` producing `Bits(1)`, then `rtl.cast` to `Bool` |
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
| [`alu.rhdl`](alu.rhdl) | Extension-defined `Bool`, `===`, word-form bitwise operators, and canonical N-way selection |
| [`counter.rhdl`](counter.rhdl) | Explicit-width literal and binding-derived register extensions over primitive registers |
| [`hierarchy.rhdl`](hierarchy.rhdl) | Binding-derived instances and dot-based access to elaborated child ports |
| [`layered-adder.rhdl`](layered-adder.rhdl) | An ordinary imported Rhombus hardware library plus recursive host-generated structure |
| [`fresh-generators.rhdl`](fresh-generators.rhdl) | Host iteration creates fresh hardware definitions without automatic deduplication |
| [`host-parameters.rhdl`](host-parameters.rhdl) | Hardware types, type-producing closures, lists, and custom host configuration as opaque circuit parameters |
| [`width-ops.rhdl`](width-ops.rhdl) | Variadic concatenation, host-range selection, and other width-changing operations over kernel/core semantics |
| [`bundle.rhdl`](bundle.rhdl) | Structural records, canonical record packing, aggregate mux/register state, and record-typed instances |
| [`vector.rhdl`](vector.rhdl) | Fixed vectors, static and hardware selection, packing casts, aggregate drives, muxes, and registers |
| [`interface.rhdl`](interface.rhdl) | Two-role ready-valid interfaces, field access, bidirectional bulk connection, and instance reconstruction |
| [`nested-interface.rhdl`](nested-interface.rhdl) | Recursive interface composition, orientation, nested field access, bulk connection, and hierarchy reconstruction |

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
