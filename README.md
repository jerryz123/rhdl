<!-- Defines RHDL's language-oriented architecture, user guide, semantic contract, and roadmap. -->

# RHDL

RHDL is an experimental Rhombus-hosted hardware description language. It uses
ordinary Rhombus computation to elaborate and verify a public hardware IR.
Optional consumers can inspect that IR or lower it through CIRCT to
SystemVerilog.

RHDL is primarily an exploration of language-oriented programming for hardware
design: a deliberately small semantic core supports progressively richer
languages and libraries. The same circuit can be written explicitly against
the IR, through a construction kernel, or with concise domain-specific syntax
without creating competing hardware semantics.

RHDL does not emit SystemVerilog itself. CIRCT owns RTL generation.

## Language-oriented architecture

### One semantic core, layered languages

RHDL separates hardware meaning from authoring convenience:

```text
ordinary Rhombus libraries and user extensions
                        |
                        v
              standard #lang rhdl
                        |
          +-------------+-------------+
          |                           |
          v                           v
   #lang rhdl/base           optional frontend modules
          |                           |
          +-------------+-------------+
                        |
                        v
               elaboration kernel
                        |
                        v
                 public core IR
                  /           \
                 v             v
       inspection tools   optional CIRCT backend
                               |
                               v
                         SystemVerilog
```

The layers have distinct responsibilities:

- The core defines hardware types, values, places, operations, modules,
  registers, instances, structural aggregates, verification, and inspection.
- The elaboration kernel makes core construction available inside a dynamic
  circuit context.
- `#lang rhdl/base` provides the circuit boundary, ports, connections, basic
  types, elaboration, and guarded host conditionals.
- Optional frontend modules add notation and abstractions without changing
  hardware semantics.
- `#lang rhdl` aggregates those frontend modules into the normal authoring
  language.
- Ordinary Rhombus libraries and user macros can add further layers without
  modifying the reader, core IR, verifier, or backend.

Macro expansion is not a second hardware IR. All frontend paths construct the
same public core graph.

### Core versus extension

A concept belongs in core when it introduces hardware semantics that the IR,
verifier, and backend must preserve. Current core concepts include:

- `HardwareType` and its data capabilities.
- Readable `Value` and driveable `Place` objects.
- Operations and operation schemas.
- Structural `RecordType` and fixed-length `VectorType` values and projections.
- Single-driver internal wires.
- Primitive registers.
- Modules, ports, and instances.
- Ownership, type, driver, and cycle verification.

A concept belongs in a frontend extension when it is notation, organization,
or policy over existing semantics. Current examples include:

- The extension-defined `Bool` type and Boolean syntax.
- Arithmetic, bitwise, literal, mux, and width-operation notation.
- Bundle declarations over `RecordType`.
- `Vec` and `vec(...)` notation over `VectorType` and vector construction.
- Role-based and recursively nested interfaces over record-typed ports.
- Binding-derived hardware names.
- Instance dot access and atomic bulk connection.

This division is intentional. `Bool` demonstrates that an additional scalar
type need not be hard-coded into core. Interfaces demonstrate that a rich,
bidirectional protocol abstraction can remain frontend metadata while lowering
to ordinary core records and ports.

### Language profiles

`#lang rhdl` is the curated standard profile used by normal designs.

`#lang rhdl/base` is the compositional profile. It contains only `circuit`,
`elaborate`, ports, `<==`, `Bits`, `Clock`, `Reset`, hardware selection and
`.into`, and guarded host `if`.
Programs explicitly import the additional language they want:

```rhombus
#lang rhdl/base

import:
  lib("rhdl/frontend/extensions/comb.rhm") open

circuit Adder(width):
  input(a, b): Bits(width)
  output sum: Bits(width)
  sum <== a + b

def design = elaborate(Adder(8))
```

The optional frontend modules are:

| Module | Contribution |
|---|---|
| `extensions/cast.rhm` | Functional `cast(value, T)` spelling for equal-width representation casts |
| `extensions/comb.rhm` | Literals, arithmetic, bitwise syntax, lookup muxes, and named width operations |
| `extensions/bool.rhm` | Nominal `Bool`, `===`, and binary `mux` |
| `extensions/bundle.rhm` | Bundle declarations, record construction, and field access |
| `extensions/interface.rhm` | Roles, directional flows, recursive interface composition, and `<=>` |
| `extensions/wire.rhm` | Binding-derived single-driver internal wires |
| `extensions/sequential.rhm` | Binding-derived registers |
| `extensions/hierarchy.rhm` | Binding-derived instances and child-member access |
| `extensions/vector.rhm` | Concise `Vec` types and inferred `vec(...)` construction |

`frontend/standard.rhm` only aggregates the base and optional modules. It does
not implement features itself. Neither language profile implicitly exports the
core Builder or raw elaboration kernel.

The shared base marks hardware bindings with frontend static information for
field access, host-range indexing, and `.into(TargetType)`. Consequently,
`value[i]`, `value[low..high]`, and `value.into(TargetType)` are common frontend
notation over the kernel's explicit `extract` and `cast` operations rather
than new core semantics.

### Executable equivalence ladder

The examples under [`examples/lop/`](examples/lop/) build the same adder at
four levels:

1. Direct public IR construction with `Design` and `Builder`.
2. Explicit construction through the elaboration kernel.
3. `#lang rhdl/base` plus an explicit combinational import.
4. Concise construction through the standard `#lang rhdl` profile.

The programs become progressively shorter while producing identical printed
RHDL IR and CIRCT MLIR. Focused equivalence tests also compare explicit record
ports with bundles and explicit directional record ports with interfaces.

```sh
make lop-test
```

This is the central architectural claim of the project: extensions improve the
language without fragmenting the hardware model.

## Quick start

### Requirements

- Racket 9.2 or a compatible current release.
- The Rhombus package.

The optional CIRCT integration tests additionally require:

- CIRCT; the repository pins `firtool-1.155.0`.
- Verilator for generated-hardware simulations.

On a Homebrew-based macOS setup:

```sh
brew install minimal-racket
raco pkg install --auto rhombus
```

On Apple Silicon macOS, install the pinned CIRCT release into the ignored
`.tools` directory:

```sh
make setup-circt
```

On other platforms, install CIRCT separately and set `CIRCT_OPT` to the path
of `circt-opt` when running backend integration tests.

### First circuit

```rhombus
#lang rhdl

circuit Adder(width):
  input(a, b): Bits(width)
  output sum: Bits(width)
  sum <== a + b

def design = elaborate(Adder(8))

export:
  Adder
  design
```

Run an example directly from the checkout:

```sh
racket -S "$(pwd)" examples/lop/adder-standard.rhdl
```

Run the canonical examples and tests:

```sh
make examples
make test
```

## Language guide

### Circuits, ports, and connections

A `circuit` declaration defines a Rhombus generator. Calling the generator
during `elaborate` creates a fresh module definition:

```rhombus
circuit Passthrough(T):
  input source: T
  output result: T
  result <== source

def design = elaborate(Passthrough(Bits(8)))
```

Inputs are readable and cannot be driven. Outputs are driveable places and may
be read after they have been driven. Outputs, instance inputs, and register
next-state places use `<==`. Every place must have exactly one effective
driver.

Grouped ports share one explicit type:

```rhombus
input(a, b): Bits(width)
output(sum, carry): Bits(width)
```

### Host parameters and generated structure

Circuit parameters may be any opaque host value that is not a runtime hardware
entity. Supported parameters include numbers, strings, symbols, collections,
user-defined configuration objects, hardware-type descriptors, functions, and
closures that return types or other configuration.

```rhombus
class Config(use_factory, labels)

fun type_factory(width):
  fun (): Bits(width)

circuit Configured(fallback_type, make_type, config):
  def T:
    if (config.use_factory) | make_type() | fallback_type
  input source: T
  output result: T
  result <== source
```

Runtime `Value`, `Place`, `Register`, `Instance`, and frontend hardware-view
objects are rejected as direct circuit parameters. This check is deliberately
shallow: RHDL does not recursively inspect host containers or closure captures.
Normal ownership verification catches hardware handles used in an incompatible
elaboration context.

Parameters are not serialized, compared, hashed, or embedded in module names.
Fresh definitions use the generator name and elaboration order, such as
`Adder`, `Adder_1`, and `Adder_2`. Active recursion is detected using a private
identity attached to the generator declaration.

Module bodies are ordinary Rhombus. Host functions, imports, collections,
conditionals, iteration, and recursion can determine generated structure. A
runtime hardware value cannot control host `if`, `when`, `unless`, `cond`,
`&&`, `||`, or host iteration.

See [`examples/host-parameters.rhdl`](examples/host-parameters.rhdl) and
[`examples/layered-adder.rhdl`](examples/layered-adder.rhdl).

### Literals and combinational expressions

Integer hardware literals always specify their width:

```rhombus
def zero = bits(0, ~width: width)
def one = bits(1, ~width: width)
```

The standard language provides `+`, `-`, `&`, `^`, `and`, `or`, `xor`, `not`,
and `===`, plus named construction functions. Arithmetic is currently unsigned
modular bit-vector arithmetic.

```rhombus
output result: Bits(width)
output equal: Bool

result <== (a & b) + bits(1, ~width: width)
equal <== a === b
```

The canonical selection operation is N-way `mux_lookup`:

```rhombus
result <== mux_lookup(op, ~default: not a):
  0: a & b
  1: a or b
  2: a ^ b
  3: a + b
  4: a - b
```

Binary `mux(sel, when_true, when_false)` is a frontend specialization for a
`Bool` selector. Both forms construct the core `rtl.mux_lookup` operation.

Width changes are explicit:

- Frontend `concat(a, b, ...)` accepts two or more packable data values and
  puts its first operand in the most-significant bits. Non-`Bits` data is
  packed to its canonical representation before one core concat operation.
- Host-generated operands can be supplied as one list, as in `concat(pieces)`.
- Explicit kernel `concat([a, b, ...])` remains Bits-only.
- `bits_value[index]` selects one bit and produces `Bits(1)`.
- `vector_value[index]` uses a host `Int` to select an element. A readable
  vector produces a value; a driveable vector produces an element place.
- `value[low..high]` selects a half-open host range; for example, `a[2..6]`
  is the concise form of `extract(a, 5, 2)`.
- `value[low..=high]` accepts the corresponding inclusive host range.
- Explicit `extract(value, high, low)` remains the kernel form and uses
  inclusive host-integer indices.
- `zext` adds zeroes on the most-significant side.
- `trunc` retains the least-significant bits.

Indices and range endpoints in bracket syntax are host `Int` values known
during elaboration.
Any bounded, nonempty host range is normalized to its selected low and high
bit; unbounded and empty ranges are rejected. Bit selection is read-only. A
selected `Bits(1)` remains `Bits(1)`—conversion to the frontend-defined `Bool`
is explicit with `value.into(Bool)`. The equivalent functional spelling is
`cast(value, Bool)`.

`value.into(TargetType)` changes only the hardware type, never the packed bit
pattern or width. It handles nominal flat types, `Clock`, `Reset`, and
recursively packed records and vectors. Width changes remain separate
operations. The member spelling is part of the base hardware-expression
surface;
`cast(value, TargetType)` remains the explicit functional frontend layer over
the same core `rtl.cast` operation.

### Registers

A register is a primitive with a readable current value and a driveable
next-state place:

```rhombus
def zero = bits(0, ~width: width)
def one = bits(1, ~width: width)

reg state(Bits(width), ~clock: clk, ~reset: reset, ~init: zero)
state.next <== state + one
```

The resetless form is:

```rhombus
reg state(Bits(width), ~clock: clk)
```

Only active-high synchronous reset is currently supported. `~init` is the
synchronous reset value, not a separate initialization mechanism. Register
state may use any `DataType`, and holding state is explicit:

```rhombus
state.next <== state
```

### Hierarchy

Every circuit call creates a fresh module definition. Reuse a definition
explicitly when several instances should refer to the same module:

```rhombus
def AdderModule = Adder(8)

inst u0(AdderModule)
inst u1(AdderModule)

u0.a <== a
u0.b <== b
sum0 <== u0.sum
```

A child input appears as a driveable place in its parent; a child output
appears as a readable value. All communication across hierarchy occurs through
ports.

### Records and bundles

`RecordType` is a structural core `DataType`. Records can be passed through
ports and instances and used as mux results or register state. The bundle
extension adds declaration and field syntax:

```rhombus
bundle Pair(T):
  left: T
  right: T

circuit Swap(T):
  input source: Pair(T)
  output result: Pair(T)

  result.left <== source.right
  result.right <== source.left
```

Complete field-wise drives canonicalize to nested `rtl.record_create`
operations followed by one whole-record drive. Partial assignment and mixing a
whole-record drive with field-wise drives are errors. Records may nest, and the
same rules apply recursively.

The explicit construction form is:

```rhombus
def pair = record(Pair(Bits(8))):
  left: a
  right: b
```

### Fixed-length vectors

`VectorType` is a structural core `DataType` for a positive host-known length
of one element type. The vector extension gives it the concise `Vec` and `vec`
spellings:

```rhombus
input carries: Vec(n + 1, Bool)
output words: Vec(3, Bits(8))
output reversed: Vec(3, Bits(8))

def initial = vec(a, b, c)
words <== initial
reversed[0] <== initial[2]
reversed[1] <== initial[1]
reversed[2] <== initial[0]
```

Unlike a host `List` of instances or hardware handles, which exists only while
elaborating generated structure, a `Vec` is one runtime hardware value.
Static bracket indexing is host computation and checks bounds during
elaboration. It works on readable vectors and on driveable vector places;
complete element-wise drives canonicalize to one `rtl.vector_create` followed
by one whole-vector drive. Partial and mixed whole/element-wise drives are
errors, as with records.

A hardware-selected read is deliberately distinct and requires a default:

```rhombus
chosen <== initial.lookup(selector, ~default: fallback)
```

This is frontend sugar for statically projecting every element and building a
core `rtl.mux_lookup`; there is no dynamic vector-index operation in core.
Vectors may contain any `DataType`, including records and other vectors. A
packable vector has no padding and places element zero in the least-significant
packed bits, matching ordinary hardware indexing. Equal-width explicit casts
therefore support `Vec` to `Bits` and back without changing the bit pattern.

See [`examples/vector.rhdl`](examples/vector.rhdl).

### Wires

A wire is an internal driveable `Place` that becomes readable after it has one
complete effective driver:

```rhombus
wire sum: Vec(n, Bool)

for (i in 0..n):
  sum[i] <== left[i] ^ right[i]

result <== sum
```

The wire type may be any `HardwareType`. Aggregate wires reuse record and
vector projection: all leaves must be driven before the wire is read or
elaboration finishes. A whole-value drive cannot be mixed with field-wise or
element-wise drives. Scalar and aggregate wires require exactly one effective
driver; there is no last-connect, conditional-connect, or priority behavior.

`rtl.wire` records the internal connection point in the public IR. Because its
read value is exactly its driver, CIRCT lowering erases the declaration and
uses the driver expression directly. It does not force a SystemVerilog wire to
be emitted.

See [`examples/wire.rhdl`](examples/wire.rhdl).

### Interfaces

Interfaces are frontend protocol descriptors over directional record-typed
ports. An interface is not itself a core `DataType`.

```rhombus
interface ReadyValid(T):
  role producer
  role consumer

  producer -> consumer:
    valid: Bool
    bits: T

  consumer -> producer:
    ready: Bool

circuit Adapter(T):
  interface ingress(ReadyValid(T), ~role: consumer)
  interface egress(ReadyValid(T), ~role: producer)
  egress <=> ingress
```

Each root flow becomes one record-typed core port. For a producer endpoint,
`{valid, bits}` is an output record and `{ready}` is an input record; a
consumer sees the complementary directions. There is no generic `Flipped`
operation. Protocol roles are named explicitly.

`<=>` atomically connects every flow when interface definitions and effective
directions are compatible. Individual fields remain available for protocol
logic. Frontend metadata reconstructs logical endpoints through instances;
reconstruction never guesses from generated port names.

### Nested interfaces

An interface member may itself be another interface:

```rhombus
interface ControlPlane(T):
  role manager
  role device

  manager -> device:
    command: ReadyValid(T)
    enable: Bool

  device -> manager:
    response: ReadyValid(T)
    status: T
```

The containing flow orients the nested interface. Its first declared role maps
to the containing flow's source role, and its second role maps to the
destination role. In this example, `command` maps `producer` to `manager` and
`consumer` to `device`; `response`, declared in the reverse flow, maps
`producer` to `device` and `consumer` to `manager`.

Composition is recursive. Nested field access, nested `<=>`, and instance
reconstruction work at arbitrary depth:

```rhombus
bus.command.valid <== valid
accepted <== bus.command.ready
left.command <=> right.command
source.bus.command.bits
```

Each root direction remains one core record port. Nested directions become
nested `RecordType` fields and lower naturally to nested CIRCT `hw.struct`
types. Core IR and the backend have no interface-specific cases.

See [`examples/nested-interface.rhdl`](examples/nested-interface.rhdl).

### Extending the language with ordinary libraries

A reusable construction abstraction can be an ordinary Rhombus function:

```rhombus
#lang rhombus

import:
  lib("rhdl/frontend/extensions/comb.rhm") open

fun add_pair(left, right):
  left + right
```

Importing that library from a `.rhdl` program requires no reader, IR, verifier,
or backend change. New macros and operators can follow the same pattern when a
function is not enough.

## Semantic model

### Elaboration

Elaboration is deterministic Rhombus computation that constructs a known-width
hardware graph. Host values determine which hardware exists but do not
represent runtime hardware data.

```text
HOST                         HARDWARE

Int                          Bits(width)
Boolean                      host value only
Bool                         runtime Boolean hardware data
Clock                        clock control signal
Reset                        active-high reset control signal
if                           no implicit hardware equivalent
for over a host collection   repeated generated structure
generator call               fresh module definition
```

Elaboration constructs one public RHDL IR. There is no private frontend IR or
separate high-level/canonical pair. A second IR level should be introduced only
when a concrete feature requires it.

The current module body is a single dataflow graph. Operation order stabilizes
printing but does not define execution order. Registers break temporal cycles;
purely combinational cycles are invalid.

### Values and places

A `Value` is readable hardware data with one definition. It is an operation
result or an input-like boundary value and records its type, defining
operation, users, module, location, and origin.

A `Place` is a destination that must be driven. Internal wires, module outputs,
instance inputs, and register next-state inputs are places. Driving a place
creates an explicit `rtl.drive` relationship.

Every place must have exactly one effective driver by the end of elaboration.
A readable place yields its driver's value and must currently be driven before
it is read. Values and places belong to one design and one legal module scope.

Aggregate places expose recursively projected record fields and vector
elements during construction. Whole-value and element-wise drive modes are
mutually exclusive. A complete set of leaf drives canonicalizes to nested
aggregate construction and one whole-value drive.

### Hardware types

The core type capabilities are open interfaces:

| Capability | Meaning |
|---|---|
| `HardwareType` | Any hardware type with well-formedness and equality behavior |
| `DataType` | Ordinary combinational, mux, port, and register data |
| `FlatDataType` | Data with a physical bit width |
| `BitwiseType` | Flat data supporting same-type bitwise operations |

Core supplies:

```text
Bits(width)
Clock
Reset
RecordType(fields)
VectorType(length, element_type)
```

`Bits` implements `BitwiseType`. `Clock` and `Reset` are nominal control types,
not `DataType`s. The frontend-defined `Bool` is a nominal one-bit
`BitwiseType`; it is distinct from `Bits(1)`. Core and the backend depend on
the open capabilities rather than importing `Bool`.

Types with equal canonical packed widths may cross only through an explicit
`cast`. This includes nominal flat types, `Clock`, `Reset`, and packable
records. Clock selection is never an ordinary data mux.

`RecordType` is an ordered, nonempty structural `DataType` with uniquely named
`DataType` fields. Field names, order, and recursively equal field types all
participate in `type_equal`. A packable record has the sum of its field widths,
without padding. Fields are packed in declaration order with the first field
occupying the most-significant bits; nested records apply the rule recursively.
This layout is used only by explicit casts and is part of the record's binary
interface contract.

`VectorType` is a positive-length structural `DataType` whose elements all
have the same `DataType`. Length and recursively equal element type participate
in `type_equal`. Its packed width is length times element width, without
padding, and element zero occupies the least-significant element-width bits.
This convention applies recursively to nested vectors and record elements.

Current width rules are explicit:

- Every `Bits` width is a positive host `Int` known during elaboration.
- There are no implicit conversions between nominal flat or control types.
- Constants specify a width and must fit it.
- Narrowing and extension use explicit operations.
- Arithmetic is unsigned and modular.

### Operation type rules

```text
not(T: BitwiseType)                         -> T
and/or/xor(T: BitwiseType, T)               -> T
add/sub(Bits(w), Bits(w))                   -> Bits(w)
eq(Bits(w), Bits(w))                        -> Bits(1)
mux_lookup(Bits(w), cases: Key -> T,
           default: T)                      -> T: DataType
wire(T: HardwareType)                       -> driveable/readable Place<T>
record_create(fields matching R)            -> R: RecordType
record_get(R, field_name)                   -> R.field_type(field_name)
vector_create(elements matching V)          -> V: VectorType
vector_get(V, host_index)                    -> V.element_type
cast(A: packable, B: same packed width)     -> B
concat(Bits(a), Bits(b), ...)               -> Bits(a + b + ...)
extract(Bits(w), high, low)                 -> Bits(high - low + 1)
zext(Bits(a), target_width)                 -> Bits(target_width)
trunc(Bits(a), target_width)                -> Bits(target_width)
```

The `concat` rule above is the core operation. The combinational frontend
accepts any packable `DataType`, inserts canonical equal-width casts for
non-`Bits` operands, and then constructs one core `rtl.concat`. Control types
such as `Clock` and `Reset` are not data and are rejected by this sugar.

For `mux_lookup`, keys are nonnegative host integers that fit the selector
width. They are unique and normalized into increasing order, so lookup meaning
does not depend on source order. Every lookup has an explicit default and at
least one case. All cases and the default satisfy `type_equal` for the result
`DataType`.

The canonical operation shape is:

```text
rtl.mux_lookup(selector, default, case_values...) {keys = [key, ...]} -> T
```

A binary Boolean mux is its one-case specialization:

```text
mux(sel: Bool, when_true: T, when_false: T)
  == mux_lookup(cast(sel, Bits(1)), default: when_false) {1: when_true}
```

There is no `rtl.mux` operation.

### Registers

A register contains:

```text
Register
    current       readable Value
    next          driveable Place
    clock         Clock Value
    reset         optional Reset Value
    reset_value   required when reset is present
```

On the active clock edge, an asserted reset loads `reset_value`; otherwise the
register loads `next`. State and reset value must have exactly equal
`DataType`s.

### Modules and instances

Within a module:

- An input is a read-only `Value`.
- An output is a `Place` that becomes readable after it is driven.
- Every output must be driven exactly once.

At an instance in its parent:

- A child input is a driveable instance-input `Place`.
- A child output is a readable instance-output `Value`.
- Every instance input must be driven exactly once.

There are no implicit hierarchical references.

## Public IR and APIs

### Object model

The public model consists of:

```text
Design
Module
Operation
Value
Place
Port
Register
Instance
HardwareType
Location
Origin
```

An operation conceptually contains:

```text
Operation
    opcode
    operands       readable Values
    results        readable Values defined by the operation
    places         driveable Places owned by the operation
    attributes
    location
    origin
```

Operations use namespaced `rtl.*` opcodes and a static schema registry rather
than a closed class hierarchy such as `AddNode` or `MuxNode`. Each schema
defines arity, required attributes, type constraints, verification behavior,
semantic category, and printing form. Backend lowering choices are not part of
the core schema.

### Operation catalog

| Group | Core operations |
|---|---|
| Structure | input port, output port, drive, instance |
| Internal connection | wire |
| Constants | constant |
| Bitwise | not, and, or, xor |
| Arithmetic | add, sub |
| Comparison | equality |
| Selection | mux lookup |
| Conversion | cast |
| Width-changing | concat, extract, zext, trunc |
| Records | record create, record get |
| Vectors | vector create, vector get with a host-static index |
| Sequential | register, synchronous-reset register |

There is no conditional-connect operation or general control-flow region.

### Builder

The Builder is the normal low-level mechanism for constructing structural IR:

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
emit_circt(design)
```

The Builder owns one design; the module being edited is explicit. It rejects
locally impossible construction immediately, while whole-graph checks run at
verification boundaries. Construction methods accept locations and origins.

The core API is exported by `rhdl/core/main.rhm`. The optional CIRCT backend is
imported separately from `rhdl/backend/circt.rhm`; core construction,
verification, printing, and inspection do not import it.

### Inspection, provenance, and naming

The IR is a public read-only inspection API. Designs, modules, and operations
can be walked; values expose definitions and users; deterministic printing is
available through `dump_ir`.

Operations carry a source `Location` and immutable `Origin`. Generated values
and places can recover their producing operation and ownership. Comprehensive
source-located multi-error diagnostics are not currently a priority.

IR identity is separate from user-facing names. Hardware names are ASCII
identifiers beginning with a letter or underscore; `__rhdl_` is reserved for
compiler-generated names. CIRCT SSA temporaries use stable numeric IR IDs so
name legalization cannot create collisions.

User-authored mutation and rewriting are deferred. Rewrite transactions,
insertion points, handle invalidation, and mutation-safe traversal should be
designed together when a concrete transformation requires them.

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
   aggregate construction, projection, and whole/element-wise drive modes are
   consistent.
8. Mux selectors and keys are valid, keys are unique, and every case/default
   has the result `DataType`.
9. Register clocks are `Clock`; synchronous reset operands are `Reset`.
10. Reset value presence matches reset presence and its type equals the state
    type.
11. Instances reference completed definitions in the same design.
12. Purely combinational cycles are rejected.

The frontend additionally rejects active recursive generator elaboration,
runtime hardware circuit parameters, and hardware-controlled host computation.
Those checks do not belong in the core verifier because host computation is no
longer present after elaboration.

Compilation verifies the completed design before lowering.

## Optional CIRCT backend

The backend is an explicit consumer of the public core IR:

```text
RHDL hardware IR
    |
    v
CIRCT hw/comb/seq MLIR
    |
    v
CIRCT lowering passes and ExportVerilog
    |
    v
SystemVerilog
```

Every `FlatDataType` lowers to a signless integer of its declared bit width;
the backend does not need to know the concrete scalar type. `RecordType`
lowers recursively to packed `hw.struct`, preserving field order and names.
`VectorType` lowers recursively to `hw.array`. Modules and instances use `hw`,
combinational values use `comb` or `hw`, and primitive registers use `seq`.
Active-high synchronous reset remains explicit as `seq.firreg` with
`reset sync`.

All opcode dispatch, representation-transparent alias elimination, CIRCT SSA
naming, and type lowering live in the backend. Core operation schemas contain
only RHDL semantics. A core operation can therefore exist independently of
CIRCT; `emit_circt` reports a backend error when a verified design contains a
type or operation it cannot represent.

| RHDL | CIRCT |
|---|---|
| `rtl.constant` | `hw.constant` |
| `rtl.not` | `comb.xor` with an all-ones constant |
| `rtl.and/or/xor` | `comb.and/or/xor` |
| `rtl.add/sub` | `comb.add/sub` |
| `rtl.eq` | `comb.icmp eq` |
| `rtl.mux_lookup` | `comb.icmp` plus a `comb.mux` tree |
| `rtl.cast` | Erased for identical lowered types; otherwise `hw.bitcast` |
| `rtl.concat` | `comb.concat` |
| `rtl.extract` | `comb.extract` |
| `rtl.zext` | Zero constant plus `comb.concat` |
| `rtl.trunc` | `comb.extract` from bit zero |
| `rtl.record_create` | `hw.struct_create` |
| `rtl.record_get` | `hw.struct_extract` |
| `rtl.vector_create` | `hw.array_create` |
| `rtl.vector_get` | `hw.array_get` with a host-constant index |
| `rtl.wire` | Erased; references resolve to the wire's driver |

RHDL does not introduce pseudo-CIRCT operations when CIRCT's canonical form is
a composition. Backend tests first parse and verify emitted MLIR, then use
CIRCT to generate the SystemVerilog supplied to Verilator. Backend-specific IR
does not leak into frontend value and place APIs.

## Repository and development

### Source layout

```text
rhdl/main.rkt                 # #lang rhdl reader shim
rhdl/language.rhm             # standard language composition
rhdl/base/                    # minimal #lang rhdl/base composition and reader
rhdl/core/                    # IR, types, Builder, verifier, and printer
rhdl/frontend/kernel.rhm      # context-based elaboration kernel
rhdl/frontend/base.rhm        # minimal frontend surface
rhdl/frontend/extensions/     # independently composable language features
rhdl/frontend/standard.rhm    # feature-free standard aggregator
rhdl/backend/                 # optional backend extensions, currently CIRCT
examples/                     # canonical valid frontend programs
tests/                        # mirrored core, frontend, and backend tests
```

The dependency direction is enforced:

```text
frontend/standard -> frontend/base + frontend/extensions/*
frontend/{base,extensions/*} -> frontend/kernel -> core
backend/circt -----------------------------------------------> core
language -> frontend/standard + kernel host-condition guard
base/language -> frontend/base + kernel host-condition guard
reader shims -> their language compositions
```

Core must not import the frontend or backend. The frontend and its tests must
not import the backend. The backend must not import frontend syntax or
elaboration.

`.rhdl` is reserved for RHDL-profile programs and frontend fixtures, `.rhm`
contains Rhombus implementation and library modules, and `.rkt` is restricted
to reader shims needed by Racket collection lookup.

### Examples

The [examples guide](examples/README.md) presents the LOP equivalence ladder
and feature showcases. Canonical valid frontend programs live under
`examples/`; intentional failures live under `tests/frontend/invalid/`.

Important examples include:

| Example | Focus |
|---|---|
| `examples/lop/` | Same hardware expressed at four language layers |
| `examples/alu.rhdl` | Boolean, bitwise, arithmetic, equality, and N-way selection |
| `examples/adder4.rhdl` | Ripple-carry hierarchy built from a reusable Boolean full adder |
| `examples/counter.rhdl` | Primitive registers and synchronous reset |
| `examples/hierarchy.rhdl` | Explicit module reuse and instance access |
| `examples/layered-adder.rhdl` | Ordinary imported library plus host-generated structure |
| `examples/host-parameters.rhdl` | Opaque host parameters and type-producing closures |
| `examples/bundle.rhdl` | Records, nested bundles, aggregate muxes and registers |
| `examples/vector.rhdl` | Fixed vectors, static and hardware selection, packing, and state |
| `examples/wire.rhdl` | Internal vector wire assembled through element assignments |
| `examples/interface.rhdl` | Named roles, flows, bulk connection, and hierarchy |
| `examples/nested-interface.rhdl` | Recursive interface composition and orientation |
| `examples/inspect-ir.rhm` | Backend-independent operation and module inspection |

### Test commands

Run the minimum target that covers a change:

```sh
make check-boundaries  # package and file-type boundaries
make examples          # all canonical frontend programs
make lop-test          # language-layer equivalence
make base-test          # core and frontend tests without any backend import
make backend-test       # textual CIRCT lowering tests without external tools
make unit-test          # base plus backend Rhombus tests
make circt-test        # CIRCT verification and Verilator simulation
make test              # complete unit plus CIRCT suite
```

`make circt-test` currently runs twelve simulations:

- An 8-bit modular adder.
- A four-bit ripple-carry adder.
- A host-width-parameterized ALU.
- A width-changing datapath.
- A fixed-vector datapath.
- An element-wise assembled vector wire.
- An 8-bit synchronous-reset counter.
- Two instances sharing one child definition.
- A record-valued mux and register.
- Equal-width record/bit representation casts.
- A ready-valid interface adapter.
- A recursively nested interface adapter.

Generated Racket, CIRCT, SystemVerilog, and Verilator build output stays out of
version control.

## Current status

The initial vertical slice is complete:

- Public, inspectable IR with stable identity and ownership.
- Static operation schemas and deterministic printing.
- Explicit values, places, drivers, modules, instances, and registers.
- Open hardware-type capabilities with core `Bits`, `Clock`, `Reset`, records,
  and fixed-length vectors.
- Extension-defined `Bool` without core or backend special cases.
- Canonical lookup muxes, arithmetic, bitwise, comparison, conversion, and
  explicit width-changing operations.
- Whole-design verification including combinational-cycle detection.
- Standard and compositional Rhombus language profiles.
- Arbitrary non-hardware host parameters and generated structure.
- Bundles over core records.
- Concise fixed-length vectors with static indexing, hardware lookup, aggregate
  connections, explicit packing casts, muxes, and registers.
- Readable, single-driver internal wires with aggregate element assignment.
- Named-role interfaces, recursive interface composition, nested field access,
  bulk connection, and reconstruction through instances.
- Deterministic lowering through CIRCT and simulation of generated RTL.

This status list is the sole completion ledger. Historical implementation
phases and duplicated acceptance milestones are intentionally not maintained.

## Roadmap

### Hardening

- Expand negative diagnostic coverage where gaps appear.
- Improve source and multi-location diagnostics when prioritized.
- Add more deterministic golden RHDL IR and CIRCT MLIR tests.
- Add randomized or property-based bit-vector tests.
- Differentially simulate generated circuits against host reference models
  where practical.
- Define a public IR compatibility policy.

### Deferred features

- `when` and conditional-connect semantics.
- Multiple, conditional, or priority connects.
- Automatic module-specialization deduplication.
- `UInt` and `SInt` as distinct types.
- Implicit widths and general width inference.
- Dynamically sized arrays and memories.
- Asynchronous and active-low resets.
- Multiple clock/reset-domain analysis.
- General IR regions and control-flow blocks.
- Runtime-loaded operation dialects.
- Multiplication and shifts until their width rules are specified.
- Multi-role protocols, optional interface fields, and protocol behavior such
  as arbitration.
- IR mutation and rewriting until a concrete transformation use case requires
  a coherent transaction and handle-validity model.

## Design commitments

- Keep one public hardware IR until a concrete feature requires another.
- Keep frontend conveniences out of core when existing hardware semantics are
  sufficient.
- Keep backends independent of frontend syntax and metadata.
- Use CIRCT, not an RHDL-owned SystemVerilog emitter.
- Keep widths explicit and elaboration deterministic.
- Keep generator parameters in the host language and runtime data in hardware.
- Do not add implicit conversion, connection, priority, or reset behavior
  without first specifying and testing its semantics.
