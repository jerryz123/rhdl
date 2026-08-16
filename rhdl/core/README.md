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
| `ArithmeticType` | Bitwise data supporting same-type modular arithmetic and width reconstruction |
| `SignedArithmeticType` | Arithmetic data supporting signed comparison, right shift, and extension |

Core supplies `Bits(width)`, `Clock`, `Reset`, `RecordType(fields)`, and
`VectorType(length, element_type)`. `Bits` implements `ArithmeticType`; `Clock`
and `Reset` are nominal control types rather than `DataType`s. Frontend-defined
types such as `Bool`, enums, and one-hot values implement the open capabilities
without core special cases.

Equal-width representations cross types only through explicit `rtl.cast`.
Clock selection is never an ordinary data mux.

### Records

`RecordType` is an ordered, nonempty structural `DataType` with unique field
names. Field names, order, and recursively equal field types participate in
`type_equal`. An optional preferred declaration name is non-semantic metadata:
it does not make structurally equal records distinct. A packable record has no
padding. Its first declared field occupies the most-significant bits,
recursively.

### Vectors

`VectorType` has a positive host-known length and one recursively equal element
`DataType`. A packable vector has no padding, and element zero occupies the
least-significant element-width bits. This convention applies recursively to
nested vectors and record elements.

### Width rules

- Every `Bits` width is a positive host `Int` known during elaboration.
- Constants specify a width and must fit it.
- A don't-care grants synthesis freedom for every bit; it is not a runtime X
  value and defines no four-state propagation semantics.
- There are no implicit conversions.
- Narrowing and extension use explicit operations.
- Fixed-width arithmetic is modular; signedness does not change its packed
  add, subtract, or multiply result.
- Logical and arithmetic shifts preserve value width. Overshifts produce zero
  for unsigned right shift and the sign fill for signed right shift.
- Expanding arithmetic is frontend composition over explicit extensions and
  modular core operations.

## Operation model

Operations use namespaced `rtl.*`, `verif.*`, and `sim.*` opcodes plus a static schema
registry instead of a closed node-class hierarchy. A schema defines arity,
required attributes, type constraints, semantic category, verification, and
printing. Backend lowering choices are not part of core schemas.

| Group | Core operations |
|---|---|
| Structure | input port, output port, drive, instance |
| Internal connection | wire |
| Sources | constant, synthesis don't-care |
| Bitwise | not, and, or, xor |
| Arithmetic | add, sub, multiply, logical left, unsigned-right, and signed-right shift |
| Comparison | equality, unsigned less-than, signed less-than |
| Selection | mux lookup, incompletely specified decode relation |
| Conversion | cast |
| Width-changing | concat, extract, zero extension, sign extension, truncation |
| Records | record create and field extraction |
| Vectors | vector create and host-static element extraction |
| Memories | resource allocation, asynchronous read, synchronous write, circuit-shaped synchronous memory |
| Sequential | register with optional synchronous reset |
| Verification | guarded, reset-suppressed clocked assertion |
| Simulation | clocked DPI procedure call and explicit DPI result registers |

Representative type rules are:

```text
not(T: BitwiseType)                         -> T
dont_care(Bits(w))                          -> Bits(w)
and/or/xor(T: BitwiseType, T)               -> T
add/sub/mul(T: ArithmeticType, T)           -> T
shl(T: ArithmeticType, Bits(a))             -> T
shru(Bits(w), Bits(a))                      -> Bits(w)
shrs(S: SignedArithmeticType, Bits(a))      -> S
eq/ult(Bits(w), Bits(w))                    -> Bits(1)
slt(S: SignedArithmeticType, S)             -> Bits(1)
mux_lookup(Bits(w), keys -> T, default: T)  -> T: DataType
decode(I: packable DataType,
       input cubes -> output cubes,
       default output cube)                 -> O: packable DataType
wire(T: HardwareType)                       -> (Value<T>, Place<T>) alias pair
record_create(fields matching R)            -> R: RecordType
record_get(R, field_name)                   -> R.field_type(field_name)
vector_create(elements matching V)          -> V: VectorType
vector_get(V, host_index)                    -> V.element_type
cast(A: packable, B: same packed width)     -> B
onehot_mux(Bits(n), n values of T)          -> T: packable DataType
concat(Bits(a), Bits(b), ...)               -> Bits(a + b + ...)
extract(Bits(w), high, low)                 -> Bits(high - low + 1)
sext(S: SignedArithmeticType, wider width)  -> S.with_bit_width(wider width)
memory(depth, T: DataType)                  -> Memory<T>
memory_read_async(Memory<T>, address)       -> T
memory_write(Memory<T>, address, T,
             Clock, one-bit enable)         -> void
sync_memory(depth, T: DataType, Clock,
            read?, write?, read_write?,
            mask_granularity?)              -> SyncMemory<T>
assert(one-bit condition, Clock, Reset,
       one-bit guard, optional label)        -> void
dpi_call(procedure, Clock, enable, args...) -> void
dpi_register(function, Clock, enable,
             args...)                       -> one or more flat result types
```

Mux keys are unique nonnegative host integers that fit the selector width and
are normalized into increasing order. Every lookup has a default and at least
one case. There is no `rtl.mux`: a binary Boolean mux is a frontend
specialization of `rtl.mux_lookup`.

`rtl.onehot_mux` is a separate partial selection primitive. Its selector width
must equal its number of same-typed choices. Exactly one selector bit being set
is a caller precondition; zero-hot and multi-hot selectors have an unspecified
result. This permits direct selector-bit gating and reduction without validity
logic or a default value.

There is also no conditional-connect operation or general control-flow
region. Frontend hardware conditionals canonicalize to mux lookups and one
final drive.

`rtl.dont_care` is deliberately narrower than an unknown-value model. It is a
zero-operand `Bits` source whose bits may be chosen independently by synthesis.
Verification and inspection preserve that optimization freedom, while each
backend selects its own carrier representation. It does not alter assignment
completeness, register hold behavior, comparisons, muxes, or simulation into
four-state operations.

`rtl.decode` preserves an unordered, non-overlapping relation between packed
input cubes and partially specified output cubes. Every cube stores canonical
`value & care` and `care` images. Cared output bits constrain the result;
uncared bits grant the same per-bit synthesis freedom as `rtl.dont_care`.
Input and output may have different packable `DataType` types, including
records and vectors. Backends may choose any implementation satisfying the
relation, so core does not expand a decode into a particular mux or gate
network.

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

A `SyncMemory` is a distinct circuit-shaped primitive, not an indexed
`Memory`. It owns one clock and typed collections of read, write, and shared
read-write ports. The current Builder admits 1R, 1W, 1R1W, and 1RW shapes; the
collections preserve the physical port kinds without yet exposing general
multi-port construction.

A read port has driveable `address` and one-bit `enable` fields plus readable
`data`. A write port has driveable `address`, `data`, and one-bit `enable`. A
shared read-write port has driveable `address`, `enable`, one-bit `write`, and
`write_data` fields plus readable `read_data`. With an enabled shared port,
`write = 0` selects a read and `write = 1` selects a write. Addresses are
exactly `Bits(index_width(depth))`.

A memory may optionally declare a positive host-known mask granularity that
evenly divides the packed element width. Each write port then gains a required
mask field of type `Bits(packed_width(element_type) / mask_granularity)`; the
shared port names it `write_mask`. Mask bit zero controls the least-significant
packed granule. A one writes that granule and a zero preserves its stored bits.
The layout belongs to the memory and will be shared by every future
write-capable port. Masking requires a statically packable element type.

An enabled read presents its data one rising edge after its address is
sampled. Read output while its enable is false, or after a shared-port write,
is unspecified. An all-zero mask preserves every stored bit but remains a
write-mode cycle on a shared port. Initial contents, out-of-range addresses,
and collisions between separate ports are unspecified. The primitive has no
reset, initialization, inferred ports, or direct indexing.

### DPI simulation operations

DPI imports belong to a design and have flat signatures. A function has zero
or more ordered `out` results followed by exactly one `return` result. A
result-less `sim.dpi_call` represents a clocked procedure effect. A
result-bearing `sim.dpi_register` produces one visible state value per result;
all hold while disabled. Both operations carry an explicit clock and one-bit
hardware enable. They are deliberately unsynthesizable core semantics rather
than frontend-only annotations.

### Clocked assertions

`verif.assert` checks a readable one-bit condition on each rising clock edge
while its one-bit guard is asserted. It is disabled while its active-high reset
operand is asserted. Frontends use the guard to record lexical activation from
hardware conditionals; it is not a user-facing assertion enable. The optional
label is an ASCII identifier used to identify the check after backend lowering.
Assertions have no results, places, or hidden state; they remain verification
collateral in every containing module and therefore apply independently to
every instance.

The core operation is deliberately limited to a current-cycle condition. It
does not define temporal sequences, formatted messages, assumptions, coverage,
or immediate combinational checks.

## Public API

The public object model includes:

```text
Design        DesignElaboration  DpiImport   DpiResult   Module       Operation
Value         Place              Port        Register    Memory       SyncMemory
Instance      HardwareType       Location    Origin
```

An operation owns operands, results, places, attributes, a location, and an
origin. The IR is a read-only inspection API: callers can walk designs,
modules, and operations; follow value definitions and users; and print
deterministic text with `dump_ir`.

`DesignElaboration` pairs a verified design with its explicit top module for
downstream consumers. `Module.find_instance(name)` returns the stable direct
`rtl.instance` operation rather than relying on operation or module order.

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
4. Every output, instance input, register next-state place, and synchronous
   memory input field has exactly one effective driver.
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
12. Assertions have a one-bit condition and guard, a `Clock`, a `Reset`, and an
    optional identifier label.
13. Instances reference completed same-design definitions and have unique
    final names within their parent.
14. Purely combinational cycles are rejected, including cycles that cross
    instance boundaries. Dependency summaries preserve record-field and
    vector-element paths through structural operations and hierarchy, so an
    independent aggregate leaf does not create a false cycle. Operations that
    reinterpret a packed representation, including `rtl.cast`, conservatively
    depend on every source leaf.

The frontend separately rejects active recursive generator elaboration,
runtime hardware circuit parameters, and hardware-controlled host
computation. Compilation verifies every completed design before lowering.
