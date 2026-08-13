<!-- Presents the examples as an executable language-oriented programming walkthrough. -->

# RHDL examples: one IR, layered languages

RHDL treats an HDL as a family of languages built over one public hardware IR.
The core owns hardware semantics. The elaboration kernel makes those semantics
available as ordinary Rhombus functions. Frontend extensions then add notation,
binding conventions, types, and reusable abstractions without changing the IR.

Start with the three versions of the same 8-bit adder:

| Layer | Example | What the layer contributes |
|---|---|---|
| Public core | [`lop/adder-core.rhdl`](lop/adder-core.rhdl) | Explicit `Design`, `Builder`, module, port, operation, drive, and verification calls |
| Elaboration kernel | [`lop/adder-kernel.rhdl`](lop/adder-kernel.rhdl) | Implicit active design/module context and reusable generator functions |
| Standard extensions | [`lop/adder-standard.rhdl`](lop/adder-standard.rhdl) | `circuit`, binding-derived ports, `+`, `<==`, and `elaborate` |

The sources become progressively shorter, but all three construct identical
printed RHDL IR and identical CIRCT MLIR. The focused test makes that claim
executable:

```sh
make lop-test
```

```text
direct Builder       elaboration kernel       standard extensions
       \                    |                       /
        +-------------------+----------------------+
                            |
                            v
                    public RHDL IR
                            |
                            v
                       CIRCT MLIR
```

The core version is intentionally verbose; it exposes the semantic substrate
used by verification and transformation. The kernel version is suitable for
libraries that want explicit construction without defining syntax. The
standard version is the normal circuit-authoring style.

## What the standard language adds

The standard frontend is implemented in
[`rhdl/frontend/standard.rhm`](../rhdl/frontend/standard.rhm). Its forms layer
over [`rhdl/frontend/kernel.rhm`](../rhdl/frontend/kernel.rhm):

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

[`rhdl/frontend/bool.rhm`](../rhdl/frontend/bool.rhm) is a separate type
extension. It defines nominal `Bool`, Boolean equality, and binary mux behavior
outside core:

| Boolean form | Core representation |
|---|---|
| `a === b` | `rtl.eq` producing `Bits(1)`, then `rtl.reinterpret` to `Bool` |
| `mux(sel, a, b)` | Reinterpret `Bool` to `Bits(1)`, then one-case `rtl.mux_lookup` |

This division is the central language-oriented design rule: add a core concept
only when it introduces new hardware semantics. Add notation and abstractions
in a language or library layer when existing semantics are sufficient.

## Feature showcases

After the adder ladder, each remaining example has one primary lesson:

| Example | Primary lesson |
|---|---|
| [`alu.rhdl`](alu.rhdl) | Extension-defined `Bool`, `===`, word-form bitwise operators, and canonical N-way selection |
| [`counter.rhdl`](counter.rhdl) | Explicit-width literal and binding-derived register extensions over primitive registers |
| [`hierarchy.rhdl`](hierarchy.rhdl) | Binding-derived instances and dot-based access to elaborated child ports |
| [`layered-adder.rhdl`](layered-adder.rhdl) | An ordinary imported Rhombus hardware library plus recursive host-generated structure |
| [`fresh-generators.rhdl`](fresh-generators.rhdl) | Host iteration creates fresh hardware definitions without automatic deduplication |
| [`width-ops.rhdl`](width-ops.rhdl) | Explicit width-changing operations whose semantics remain in the kernel/core |

[`add-pair.rhm`](add-pair.rhm) is intentionally an ordinary Rhombus module. It
shows that a useful RHDL extension need not be a macro or require a language
reader change.

Run every example with:

```sh
make examples
```
