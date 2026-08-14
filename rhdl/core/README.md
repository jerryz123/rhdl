<!-- Documents the backend-independent RHDL semantic model, public IR, and verification contract. -->

# RHDL core

The core is RHDL's backend-independent hardware model. It defines hardware
meaning, ownership, construction, verification, and inspection; it does not
import frontend syntax or a backend. The complete package dependency contract
is in [`../README.md`](../README.md).

## Elaboration result

Elaboration constructs one public SSA-style dataflow IR. There is no private
frontend IR or separate high-level and canonical pair. Host computation has
already finished by the time the core design is verified.

A module body is one dataflow graph. Operation order stabilizes printing but
does not define execution order. Primitive registers break temporal cycles;
purely combinational cycles are invalid.

## Values and places

A `Value` is readable hardware data with one definition. It is an operation
result or input-like boundary value and records its type, defining operation,
users, module, location, and origin.

A `Place` is a destination that must be driven. Internal wires, module outputs,
instance inputs, and register next-state inputs are places. Driving a place
creates an explicit `rtl.drive` relationship.

Every place must have exactly one effective driver. A readable place yields
its driver's value and must be driven before it is read. Values and places
belong to one design and one legal module scope.

Aggregate places expose recursively projected record fields and vector
elements during construction. Whole-value and element-wise drive modes are
mutually exclusive. A complete set of leaf drives canonicalizes to nested
aggregate construction and one whole-value drive.

At module and instance boundaries:

- A module input is a read-only `Value`.
- A module output is a `Place` that becomes readable after it is driven.
- A child input is a driveable instance-input `Place` in its parent.
- A child output is a readable instance-output `Value` in its parent.
- Communication across hierarchy occurs only through ports.

## Hardware types

The core type capabilities are open interfaces:

| Capability | Meaning |
|---|---|
| `HardwareType` | Any hardware type with well-formedness and equality behavior |
| `DataType` | Ordinary combinational, mux, port, and register data |
| `FlatDataType` | Data with a statically known physical bit width |
| `BitwiseType` | Flat data supporting same-type bitwise operations |

Core supplies `Bits(width)`, `Clock`, `Reset`, `RecordType(fields)`, and
`VectorType(length, element_type)`. `Bits` implements `BitwiseType`; `Clock`
and `Reset` are nominal control types rather than `DataType`s. Frontend-defined
types such as `Bool`, enums, and one-hot values implement the open capabilities
without core special cases.

Equal-width representations cross types only through explicit `rtl.cast`.
Clock selection is never an ordinary data mux.

### Records

`RecordType` is an ordered, nonempty structural `DataType` with unique field
names. Field names, order, and recursively equal field types participate in
`type_equal`. A packable record has no padding. Its first declared field
occupies the most-significant bits, recursively.

### Vectors

`VectorType` has a positive host-known length and one recursively equal element
`DataType`. A packable vector has no padding, and element zero occupies the
least-significant element-width bits. This convention applies recursively to
nested vectors and record elements.

### Width rules

- Every `Bits` width is a positive host `Int` known during elaboration.
- Constants specify a width and must fit it.
- There are no implicit conversions.
- Narrowing and extension use explicit operations.
- Arithmetic is unsigned and modular.
- Logical shifts preserve value width and produce zero for overshifts.
- Expanding arithmetic is frontend composition over explicit extensions and
  modular core operations.

## Operation model

Operations use namespaced `rtl.*` and `sim.*` opcodes plus a static schema
registry instead of a closed node-class hierarchy. A schema defines arity,
required attributes, type constraints, semantic category, verification, and
printing. Backend lowering choices are not part of core schemas.

| Group | Core operations |
|---|---|
| Structure | input port, output port, drive, instance |
| Internal connection | wire |
| Constants | constant |
| Bitwise | not, and, or, xor |
| Arithmetic | add, sub, multiply, logical left and unsigned-right shift |
| Comparison | equality, unsigned less-than |
| Selection | mux lookup |
| Conversion | cast |
| Width-changing | concat, extract, zero extension, truncation |
| Records | record create and field extraction |
| Vectors | vector create and host-static element extraction |
| Memories | allocation, asynchronous read, synchronous write |
| Sequential | register with optional synchronous reset |
| Simulation | clocked DPI procedure call and explicit DPI register |

Representative type rules are:

```text
not(T: BitwiseType)                         -> T
and/or/xor(T: BitwiseType, T)               -> T
add/sub/mul(Bits(w), Bits(w))               -> Bits(w)
shl/shru(Bits(w), Bits(a))                  -> Bits(w)
eq/ult(Bits(w), Bits(w))                    -> Bits(1)
mux_lookup(Bits(w), keys -> T, default: T)  -> T: DataType
wire(T: HardwareType)                       -> Place<T>
record_create(fields matching R)            -> R: RecordType
record_get(R, field_name)                   -> R.field_type(field_name)
vector_create(elements matching V)          -> V: VectorType
vector_get(V, host_index)                    -> V.element_type
cast(A: packable, B: same packed width)     -> B
concat(Bits(a), Bits(b), ...)               -> Bits(a + b + ...)
extract(Bits(w), high, low)                 -> Bits(high - low + 1)
memory(depth, T: DataType)                  -> Memory<T>
memory_read_async(Memory<T>, address)       -> T
memory_write(Memory<T>, address, T,
             Clock, one-bit enable)         -> void
dpi_call(procedure, Clock, enable, args...) -> void
dpi_register(function, Clock, enable,
             args...)                       -> result type
```

Mux keys are unique nonnegative host integers that fit the selector width and
are normalized into increasing order. Every lookup has a default and at least
one case. There is no `rtl.mux`: a binary Boolean mux is a frontend
specialization of `rtl.mux_lookup`.

There is also no conditional-connect operation or general control-flow
region. Frontend hardware conditionals canonicalize to mux lookups and one
final drive.

## Stateful resources

### Registers

A primitive register contains a readable current value, driveable next-state
place, `Clock`, optional `Reset`, and a reset value exactly when reset is
present. On the active edge, asserted reset loads the reset value; otherwise
the register loads next state. Reset is active-high and synchronous.

### Memories

A `Memory` has stable identity, an owning module, positive host-known depth,
element `DataType`, and allocation operation. It is a resource rather than a
`Value` or `Place`.

`rtl.memory_read_async` produces an ordinary combinational value.
`rtl.memory_write` is a sequential effect carrying address, data, clock, and
enable. Multiple writes represent independent physical ports and must share
one clock. Address dependencies through asynchronous reads participate in
combinational-cycle checking.

### DPI simulation operations

DPI imports belong to a design and have flat signatures. A result-less
`sim.dpi_call` represents a clocked procedure effect. A result-bearing
`sim.dpi_register` represents visible state that holds while disabled. Both
carry an explicit clock and one-bit hardware enable. They are deliberately
unsynthesizable core semantics rather than frontend-only annotations.

## Public API

The public object model includes:

```text
Design        DpiImport      Module       Operation
Value         Place          Port         Register
Memory        Instance       HardwareType Location      Origin
```

An operation owns operands, results, places, attributes, a location, and an
origin. The IR is a read-only inspection API: callers can walk designs,
modules, and operations; follow value definitions and users; and print
deterministic text with `dump_ir`.

IR identity is separate from user-facing names. Hardware names are ASCII
identifiers beginning with a letter or underscore; `__rhdl_` is reserved for
generated names. User-authored mutation and rewriting remain deferred until a
concrete transformation motivates coherent transaction and handle-validity
semantics.

### Builder

`Builder` is the low-level construction API:

```text
design = Design()
builder = Builder(design)
module_def = builder.module("Adder")

a = builder.input(module_def, "a", Bits(8))
b = builder.input(module_def, "b", Bits(8))
sum = builder.output(module_def, "sum", Bits(8))
result = builder.add(module_def, a, b, "result")
builder.drive(sum, result)
builder.finish(module_def)

verify_design(design)
dump_ir(design)
```

The Builder owns one design and edits an explicit module. It rejects locally
impossible construction immediately; whole-graph checks run at verification
boundaries. `Builder.instance` uses an exact name, while
`Builder.suggested_instance` deterministically allocates a collision-free name.

The core API is exported by [`main.rhm`](main.rhm). CIRCT is imported
separately from [`../backend/circt.rhm`](../backend/circt.rhm).

## Verification contract

The Builder and whole-design verifier enforce:

1. Every value and place belongs to exactly one design.
2. Values are used only in legal module scopes.
3. Input ports are never driven.
4. Every output, instance input, and register next-state place has exactly one
   effective driver.
5. A place and its driver have exactly the same hardware type.
6. Operation operands, results, places, and attributes satisfy their schema.
7. Record fields and vector elements match their aggregate type completely;
   whole and element-wise drive modes remain consistent.
8. Mux selectors, keys, cases, and defaults are well typed and valid.
9. Register clocks are `Clock`; reset operands are `Reset`.
10. Reset presence and reset-value presence match, and reset value equals the
    state type.
11. DPI operations reference a same-design import and exact signature, with a
    clock and one-bit enable.
12. Instances reference completed same-design definitions and have unique
    final names within their parent.
13. Purely combinational cycles are rejected.

The frontend separately rejects active recursive generator elaboration,
runtime hardware circuit parameters, and hardware-controlled host
computation. Compilation verifies every completed design before lowering.
