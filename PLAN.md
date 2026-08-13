<!-- Defines RHDL's agreed semantics, backend boundary, and staged implementation plan. -->

# RHDL Initial Architecture and Implementation Plan

## Current implementation status

The first manually constructed vertical slice is implemented. It currently
provides:

- `Design`, `Module`, `Operation`, `Value`, `Place`, `HardwareType`, `DataType`,
  `FlatDataType`, `BitwiseType`, `Bits`, `Clock`, `Reset`, `RecordType`,
  `RecordField`, `Location`, and `Origin` handles with stable IDs and explicit
  owning-object relationships.
- A static namespaced operation-schema table that records arity, required
  attributes, type rules, printing forms, and CIRCT lowering targets.
- Builder support for ports, constants, same-width bitwise logic, modular
  addition and subtraction, equality, canonical mux lookups, explicit width-changing
  operations, primitive registers, module instances, and single-driver
  relationships.
- Active-high synchronous register reset.
- Whole-design verification, including ownership, types, lookup keys, driver counts,
  register operands, instance interfaces, and combinational-cycle detection.
- Deterministic public IR printing and design walking.
- Deterministic lowering to textual CIRCT MLIR using the `hw`, `comb`, and
  `seq` dialects.
- Collision-free CIRCT SSA names derived from stable IR IDs, with validated
  user-facing module, port, register, and instance names.
- Rhombus unit and negative tests plus CIRCT verification, CIRCT-owned
  SystemVerilog export, and Verilator simulations for an adder, ALU,
  width-changing datapath, counter, and explicitly reused module definition.
- Embedded `#lang rhdl` standard and `#lang rhdl/base` compositional profiles
  that use the ordinary Rhombus reader, layer public frontend modules over an
  importable elaboration kernel, permit host-language abstraction, create
  fresh circuit definitions, and use the same CIRCT and Verilator backend path.
- Core structural records with construction, projection, canonical field-wise
  place assignment, generic mux/register support, nested `hw.struct` lowering,
  and focused simulation.
- Frontend bundle syntax and explicit-role two-way interfaces, including
  atomic bulk connection and metadata-based reconstruction at instances.

Native core `Clock` and `Reset` types, an extension-defined frontend `Bool`,
and the canonical N-way `rtl.mux_lookup` operation are implemented. Core and
the CIRCT backend depend on open type capabilities rather than on `Bool`.

The first-cut Builder-to-CIRCT vertical slice and IR contract are complete.
The complete initial scalar frontend, core-record, bundle, and two-role
interface surfaces are implemented and are the canonical path for examples
and positive integration fixtures. IR mutation and rewriting are explicitly
deferred.

## 1. Goal

RHDL is a Rhombus-hosted language for elaborating, verifying, inspecting, and
compiling digital hardware.

The initial implementation will establish one small, public hardware IR and a
complete path from Rhombus source to generated RTL. It will favor explicit
semantics and a working vertical slice over a broad catalog of types,
constructs, or dialects.

```text
Rhombus source
    |
    v
RHDL language forms
    |
    v
deterministic elaboration
    |
    v
public RHDL hardware IR
    |
    +--- read-only inspection
    |
    v
backend lowering
    |
    v
CIRCT hw/comb/seq MLIR
    |
    v
CIRCT lowering and ExportVerilog
    |
    v
SystemVerilog
```

## 2. Initial semantic charter

Elaboration is ordinary, deterministic Rhombus computation that constructs a
known-width hardware graph. Host values determine hardware structure but never
represent runtime hardware data.

Hardware values are readable, while hardware places are driveable. Every place
has exactly one effective driver. Hardware values cannot control host
conditionals or iteration. Registers are explicit state primitives. Module
generators accept host parameters and produce fresh module definitions.

The IR is a normal public programming interface. Users can inspect modules,
operations, types, and use-def relationships. A mutation API may be added
later, but it does not shape the immediate implementation sequence.

## 3. Syntax, elaboration, and IR

RHDL keeps four layers separate: ordinary Rhombus parsing and expansion, a
small embedded elaboration kernel, optional surface and library layers, and the
public hardware IR.

### 3.1 Syntax

Rhombus supplies parsing, hygienic macros, binding spaces, operators, dot
syntax, assignment syntax, static information, and source locations.

The initial standard layer supports conventional forms such as:

```text
circuit ALU(width):
    input(a, b): Bits(width)
    output y: Bits(width)
    y <== a + b
```

Both RHDL profiles use the ordinary Rhombus reader. `#lang rhdl/base` provides
the circuit boundary, basic public types, ports, connections, elaboration, and
the host-versus-hardware condition guard. Existing combinational, Boolean,
sequential, and hierarchy syntax is available through explicit frontend-module
imports. `#lang rhdl` aggregates those modules as the curated standard profile.
Neither profile implicitly exports the public core Builder or raw elaboration
kernel.

Surface syntax expands to calls into the elaboration kernel and Builder; macro
expansion is not itself the hardware IR. Libraries may define new functions,
macros, and operators by importing a focused frontend module or the kernel,
without modifying either language reader. Both binary `mux` and N-way
`mux_lookup` surface forms lower to the canonical `rtl.mux_lookup` core
operation.

### 3.2 Package boundaries

Source layout enforces a one-way dependency graph:

```text
frontend/standard -> frontend/base + frontend/extensions/*
frontend/{base,extensions/*} -> frontend/kernel -> core
backend/circt -----------------------------------------------> core
language -> frontend/standard + kernel host-condition guard
base/language -> frontend/base + kernel host-condition guard
reader shims -> their language compositions
```

`core/` contains the public IR, schemas, Builder, verifier, and IR printer and
must not import the frontend or backend. The frontend cannot import the
backend, and the backend cannot import frontend syntax or elaboration.
`frontend/standard.rhm` is a feature-free aggregator, while the two language
modules compose the minimal and standard profiles. A test-time boundary audit
enforces these imports, prevents optional features from leaking into the base
frontend, reserves `.rhdl` for examples and frontend fixtures, and restricts
`.rkt` to reader shims.

### 3.3 Elaboration

Elaboration executes Rhombus code to decide what hardware exists.

```text
HOST                         HARDWARE

Int                          Bits(width)
Boolean                      host value only
Bool                         runtime Boolean hardware data
Clock                        clock control signal
Reset                        active-high reset control signal
if                           no initial hardware equivalent
for over a host collection   repeated generated structure
generator call               fresh module definition
```

Generator parameters may be any opaque host value, including hardware-type
descriptors, functions and closures, collections, and user-defined
configuration objects. Runtime hardware entities such as values, places,
registers, instances, and frontend hardware views are rejected at the circuit
boundary. This check is intentionally shallow: RHDL neither traverses host
containers nor inspects closure captures. Ordinary IR ownership checks remain
responsible for rejecting hardware handles captured from an incompatible
elaboration context.

Parameters are not serialized, compared, hashed, or embedded in module names.
Fresh module symbols use only the generator's declared name and elaboration
order. Active recursion is tracked by a private identity belonging to the
generator declaration, so unrelated generators with the same textual name do
not conflict.

A hardware value used as the test of host `if`, `when`, `unless`, `cond`, `&&`,
`||`, or host iteration must produce an error during expansion or elaboration;
it must never be accepted through Rhombus truthiness.

### 3.4 IR

Elaboration constructs one public RHDL hardware IR. The initial system will not
introduce a separate high-level RHDL IR and canonical RTL IR. A second IR level
will be added only when a concrete language feature requires it.

The module body is initially a single dataflow graph. General control-flow
blocks and regions are not part of the first implementation.

## 4. Core IR model

The initial public model consists of:

```text
IR.Design
IR.Module
IR.Operation
IR.Value
IR.Place
IR.Type
IR.Attribute
IR.Symbol
IR.Location
IR.Origin
```

An operation conceptually contains:

```text
Operation
    opcode
    operands       // readable IR.Values
    results        // readable IR.Values defined by this operation
    places         // driveable IR.Places owned by this operation
    attributes
    location
    origin
```

Operations use `rtl.*` namespaced opcodes and are described by schemas instead
of a closed hierarchy
such as `AddNode`, `MuxNode`, and `RegisterNode`. The first implementation may
use a static built-in schema registry. Runtime dialect loading and schema
versioning are deferred.

Each schema defines at least:

- Operand, result, and place arity.
- Type and width constraints.
- Required attributes.
- Verification behavior.
- Whether the operation is combinational, sequential, structural, or
  side-effecting.
- Printing behavior.

### 4.1 Values

An `IR.Value` is a readable hardware value with exactly one definition. It is
either an operation result or an input-like boundary value. Values expose:

```text
value.type
value.defining_op      // optional for boundary values
value.users()
value.location
value.origin
```

Operation order is used for stable printing but does not define hardware
execution order. The module is a graph, and register operations break temporal
cycles. Purely combinational cycles are invalid.

### 4.2 Places

An `IR.Place` is a destination that can be driven. Module outputs, instance
inputs, and register next-state inputs are places.

```text
place.type
place.owner
place.driver           // absent until driven
place.location
```

Every place must have exactly one driver by the end of elaboration. Driving a
place creates an explicit `rtl.drive` relationship in the IR.

A readable place yields the value supplied by its driver. In the initial
builder, a readable place must be driven before it is read. This keeps the
construction rules simple while allowing a module output to be reused after it
has been assigned.

Places and values belong to one design and one module scope. Cross-design and
illegal cross-hierarchy references are verifier errors.

A place whose type is `RecordType` exposes recursively projected field places
during construction. Driving the whole place and driving projected fields are
mutually exclusive. Before module completion, the Builder canonicalizes a
complete set of leaf drives into nested `rtl.record_create` operations and one
whole-record drive. Partial or mixed driving is invalid. This rule applies
uniformly to module outputs, instance inputs, and register next-state places.

## 5. Hardware types and selection

Core supplies these concrete hardware types:

```text
Bits(width)
Clock
Reset
RecordType(fields)
```

The open core protocol is `HardwareType`, with progressively stronger
capabilities: `DataType` marks ordinary combinational and register data,
`FlatDataType` supplies a physical `bit_width`, and `BitwiseType` opts a flat
type into same-type bitwise operations. `Bits` implements `BitwiseType`.
Future types may implement these capabilities outside core; core
well-formedness and nominal structural equality remain centralized in
`type_well_formed` and `type_equal`.

The Boolean frontend module supplies `Bool` as an extension-defined nominal
`BitwiseType` with width one. It is distinct from `Bits(1)`, and neither core
nor the CIRCT backend imports or special-cases it. Equal-width flat types may
cross explicitly through representation-transparent `reinterpret` operations.
`Clock` and `Reset` are nominal core control types rather than `DataType`s;
their explicit conversions pass through `Bits(1)`. `Reset` initially means an
active-high reset signal, while the consuming register operation determines
that its behavior is synchronous. Clock selection requires a dedicated clock
operation and is never an ordinary data mux.

`RecordType` is a structural `DataType` containing an ordered, nonempty set of
uniquely named `DataType` fields. Field names participate in type equality;
two records are equal only when they have the same fields in the same order
and each corresponding field type is equal. Records may nest. They are not
implicitly packed into `Bits`, and no bit layout or `reinterpret` between a
record and a flat type is defined. `RecordType` therefore does not implement
`FlatDataType` or `BitwiseType`.

Rules:

- `width` is an explicit positive host `Int`.
- All widths are known during elaboration.
- There are no implicit conversions among nominal flat or control types.
- Narrowing and extension use explicit operations.
- Integer bit-vector constants must specify a width and fit that width.
- Arithmetic is unsigned modular bit-vector arithmetic for now.
- `UInt` and `SInt` remain deferred.

Initial operation type rules:

```text
not(T: BitwiseType)                       -> T
and/or/xor(T: BitwiseType, T)             -> T
add/sub(Bits(w), Bits(w))                 -> Bits(w)
eq(Bits(w), Bits(w))                      -> Bits(1)
mux_lookup(Bits(w), cases: Key -> T,
           default:T)                    -> T
record_create(field values matching R)   -> R: RecordType
record_get(R, field_name)                 -> R.field_type(field_name)
reinterpret(A: FlatDataType,
            B: FlatDataType of same width) -> B
concat(Bits(a), Bits(b), ...)             -> Bits(a + b + ...)
extract(Bits(w), high, low)               -> Bits(high - low + 1)
zext(Bits(a), target_width)               -> Bits(target_width)
trunc(Bits(a), target_width)              -> Bits(target_width)
```

For `mux_lookup`, the selector is `Bits(w)`, and `T` is any `DataType` whose
case and default values satisfy `type_equal`. IR keys are normalized host
integers that must be nonnegative and fit `w`. Keys are unique and stored in
increasing order, making lookup semantics independent of source order. Every
lookup has an explicit default and at least one case. Duplicate keys are
errors rather than priority semantics; a separate priority-mux abstraction can
be layered later if needed.

The canonical operation shape is:

```text
rtl.mux_lookup(selector, default, case_values...) {keys = [key, ...]} -> T
```

A binary Boolean mux is exactly the one-case specialization:

```text
mux(sel: Bool, when_true: T, when_false: T)
  == mux_lookup(as_bits(sel), default: when_false) {1: when_true}
```

There is no separate `rtl.mux` operation. The `Bool` extension retains `mux`
as ergonomic syntax, reinterprets the selector as `Bits(1)`, and constructs
`rtl.mux_lookup`. It similarly layers Boolean `===` over core equality by
reinterpreting the `Bits(1)` result as `Bool`. The backend erases these
representation-transparent conversions, lowers a one-bit one-case lookup
directly to `comb.mux`, and lowers larger lookups to comparisons plus a mux
tree. Dense lookup optimizations can be introduced without changing source or
core IR semantics.

`zext` requires a larger target width, `trunc` requires a smaller target width,
and `extract` indices are inclusive explicit host integers checked during
elaboration. `concat` requires at least two operands and places its first
operand in the most-significant bits. Zero extension adds zeroes on the
most-significant side, and truncation retains the least-significant bits.
Multiplication and shifts can be added after their width rules are specified.

Because `RecordType` is a `DataType`, the existing generic register and
`mux_lookup` rules accept record values without record-specific variants.
Record construction and projection are the only new combinational operations.
Record places support field projection as a core construction operation: a
record place may be driven exactly once as a whole, or all of its leaf places
may be driven exactly once, but whole-record and field-wise driving may not be
mixed. The Builder canonicalizes complete field-wise drives to ordinary record
construction plus a whole-place drive. The verifier rejects any incomplete or
noncanonical aggregate drive state that reaches a verification boundary.

## 6. Initial operations

### 6.1 Structure

```text
design
module
instance
input_port
output_port
drive
```

### 6.2 Combinational values

```text
constant
not
and
or
xor
add
sub
eq
mux_lookup
reinterpret
as_bits
as_clock
as_reset
concat
extract
zext
trunc
record_create
record_get
```

These form the canonical combinational representation. There is no initial
`wire`, `connect`, or conditional `when` operation.

### 6.3 Sequential state

A register is a primitive with:

```text
Register
    current       // readable Value
    next          // driveable Place
    clock         // Clock Value
    reset         // optional Reset Value
    reset_value   // required when reset is present
```

On the active edge of `clock`:

```text
if reset is present and asserted:
    current <- reset_value
else:
    current <- next
```

Only active-high synchronous reset is supported initially. Register state can
have any `DataType`, and the reset value must have exactly the same type as
that state. Clock and reset operands use the nominal `Clock` and `Reset` types.

The next-state place must be driven exactly once. Holding state is explicit:

```text
r.next <== r
```

Surface syntax may allow the register handle itself to be read as its current
value:

```text
def zero = bits(0, ~width: 8)
reg r(Bits(8), ~clock: clk, ~reset: rst, ~init: zero)
r.next <== r + bits(1, ~width: 8)
```

A register breaks a temporal feedback cycle. Cycles consisting only of
combinational operations remain illegal.

## 7. Modules, generators, and instances

A circuit declaration defines a Rhombus generator.

```text
circuit ALU(width):
    ...
```

Calling the generator with host values produces a fresh module definition:

```text
def ALU32 = ALU(32)
```

There is no automatic specialization deduplication initially. Calling
`ALU(32)` twice produces two distinct module definitions. A user can explicitly
reuse one definition for multiple instances:

```text
def ALU32 = ALU(32)
inst u0(ALU32)
inst u1(ALU32)
```

The standard frontend derives each instance's hardware name from its binding
and resolves `u0.port` through the elaborated child interface. This dot access
is frontend static information over the existing core `Instance.input` and
`Instance.output` relationships, not a distinct IR concept.

Fresh definitions and instances receive deterministic symbols based on their
generator name and elaboration order. Generator arguments never participate in
symbol construction. Recursion in the active declaration-identity stack is
diagnosed as an elaboration error.

### 7.1 Port capabilities

Within a module definition:

- An input is a read-only `Value`.
- An output is a driveable `Place` that may also be read after it is driven.
- Driving an input is an error.
- Every output must be driven exactly once.

At an instance in its parent module:

- The child module's input appears as a driveable instance-input `Place`.
- The child module's output appears as a readable instance-output `Value`.
- Every instance input must be driven exactly once.

There are no implicit hierarchical references. Communication across a module
boundary occurs only through ports.

## 8. Public construction, inspection, and compilation APIs

### 8.1 Builder

The builder is the only normal mechanism for constructing structural IR:

```text
builder.module(...)
builder.input(module, ...)
builder.output(module, ...)
builder.constant(module, ...)
builder.add(module, ...)
builder.drive(...)
builder.read(...)
builder.register(module, ...)
builder.instance(module, ...)
builder.finish(module)
```

The initial Builder owns one design, while the module being edited is passed
explicitly to construction methods. Operations accept source locations and
origins. The Builder rejects locally impossible operations immediately, while
whole-graph checks run at verification boundaries. An insertion-point API is
deferred until regions require one.

### 8.2 Elaboration, inspection, and compilation

The IR boundary remains explicit:

```text
design = elaborate(Top(...))

design.verify()
design.dump_ir()

for op in design.walk():
    ...

compile(design)
```

Inspection is read-only. Compilation verifies the completed design before
lowering. User-authored mutation passes and rewrite transactions are future
work rather than an acceptance criterion for the aggregate/type-system work.

## 9. Verification invariants

The target IR Builder and verifier enforce:

1. Every value and place belongs to exactly one design.
2. Values are used only where their module scope permits.
3. Input ports are never driven.
4. Every output, instance input, and register next-state place has exactly one
   driver.
5. A place and its driver have exactly the same hardware type.
6. Operation operands and results satisfy their schema type rules.
7. Record types have unique ordered fields, record construction and projection
   match those fields, and every record place uses one complete drive mode.
8. Lookup selectors and keys are valid, lookup keys are unique, and every case
   and default has the result `DataType`.
9. Register clocks are `Clock`, and synchronous reset operands are `Reset`.
10. A reset value is present exactly when reset is present and matches the
   register state type.
11. Module instances reference a completed module definition.
12. Purely combinational cycles are rejected.

The frontend additionally rejects recursive generator elaboration and prevents
hardware values from controlling host conditionals. Those checks do not belong
to the manual IR verifier because the host computation is no longer present
once IR exists.

Complete source-location and multi-location diagnostic reporting is useful but
is not a gate for the aggregate/type-system work. It is deferred to hardening.

## 10. Provenance and naming

Every operation, value, and place carries or can recover:

```text
location       immediate user source span when captured, otherwise unknown
origin         immutable link to the construct that produced it
name_hint      optional semantic name for diagnostics and generated RTL
```

Macro-introduced operations retain the user's call-site location plus an origin
record for the expansion. When several frontend constructs contribute to one
operation, its origin may reference multiple parent origins.

IR identity and user-facing names are separate. Names may be changed or made
unique without changing value, operation, or module identity.

Initial user-facing hardware names are ASCII identifiers beginning with a
letter or underscore and continuing with letters, digits, or underscores. The
`__rhdl_` prefix is reserved for compiler-generated names. CIRCT SSA values use
stable numeric IR IDs where a semantic port or register name is not required,
so no lossy name legalization step can create collisions.

## 11. Backend boundary

The public RHDL IR remains independent of backend representation:

```text
RHDL hardware IR
    |
    v
CIRCT hw/comb/seq MLIR
    |
    v
CIRCT lowering passes
    |
    v
CIRCT ExportVerilog
    |
    v
SystemVerilog
```

The initial backend lowers directly to CIRCT's `hw`, `comb`, and `seq`
dialects. Every `FlatDataType` becomes a signless integer of its declared bit
width, without requiring the backend to know its concrete type; this includes
core `Bits` and the frontend's extension-defined `Bool`. `RecordType` lowers
recursively to `hw.struct`, preserving field names and order. `Reset` lowers
to a one-bit value, and `Clock` lowers through the backend's clock
representation. Modules and instances become `hw` operations, combinational
values become `comb` or `hw` operations, and primitive registers become `seq`
operations.
Active-high synchronous reset is preserved explicitly with `seq.firreg` and
`reset sync`.

RHDL does not contain a direct SystemVerilog emitter. CIRCT owns lowering from
its IR to SystemVerilog, including any required `seq`-to-`sv` conversion and
`ExportVerilog`. Backend tests must first parse and verify the emitted CIRCT IR,
then use CIRCT to generate the RTL supplied to Verilator.

Backend-specific IR must not leak into the frontend value and place APIs.

The planned combinational mappings are:

```text
RHDL                    CIRCT

rtl.constant            hw.constant
rtl.not                 comb.xor with an all-ones constant
rtl.and/or/xor          comb.and/or/xor
rtl.add/sub             comb.add/sub
rtl.eq                  comb.icmp eq producing Bits(1)
rtl.mux_lookup          comb.icmp plus comb.mux tree
rtl.reinterpret         erased equal-width flat-data cast
rtl.as_*                erased one-bit data/control cast
rtl.concat              comb.concat
rtl.extract             comb.extract
rtl.zext                comb.concat with a zero high part
rtl.trunc               comb.extract from bit zero
rtl.record_create       hw.struct_create
rtl.record_get          hw.struct_extract
```

These mappings are part of the backend contract. RHDL should not introduce
same-named pseudo-CIRCT operations when CIRCT expresses the canonical form as a
composition.

## 12. Remaining non-goals

The current record-and-interface sequence deliberately excludes:

- `when` and conditional-connect semantics.
- General wires or multiple/priority connects.
- Automatic module-specialization deduplication.
- `UInt` and `SInt` as distinct types.
- Implicit widths or general width inference.
- Arrays and memories.
- Asynchronous or active-low resets.
- Multiple clock/reset-domain analysis.
- General IR regions and control-flow blocks.
- Runtime-loaded dialects.
- Multiplication and shifts until their width semantics are chosen.

These can be added only with explicit semantics and tests.

## 13. Implementation sequence

### Phase 0: executable semantic examples and toolchain — complete

- Pin compatible Racket/Rhombus and CIRCT versions.
- Establish a repeatable development environment.
- Write expected IR for an adder, a synchronous-reset counter, and a module
  instance.
- Record and test the direct `hw`/`comb`/`seq` lowering and CIRCT invocation
  contract.

### Phase 1: IR kernel — core first-cut subset complete

Implement:

```text
Design
Module
Operation
Value
Place
Bits(width)
Location
Origin
schema registry
Builder
Verifier
deterministic printer
```

Ownership, actual repository membership, use-def tracking, single-driver
behavior, type checks, cycle detection, schema attributes, cross-design ID
collisions, and emitted-name safety are unit tested. Handle invalidation is
deferred with rewriting.

Dedicated `Attribute` and `Symbol` object models are deferred. The first cut
uses immutable host values for attributes and validated strings for symbols;
they should become distinct objects only when parameterized attributes,
renaming, or symbol references require them.

### Phase 2: manually built vertical slice — complete

- Implement constants, bitwise logic, modular addition and subtraction,
  equality, and muxes.
- Implement modules, ports, drives, instances, and registers.
- Construct the adder, host-width-parameterized ALU, and counter directly
  through the builder API.
- Lower them to CIRCT MLIR.
- Have CIRCT generate SystemVerilog and simulate it with Verilator.

This phase produces working hardware before frontend syntax work expands. The
width-changing group—`concat`, `extract`, `zext`, and `trunc`—is implemented
with schema verification, deterministic printing, canonical CIRCT lowering,
and Verilator simulation.

### Phase 3: Rhombus frontend — complete

The frontend implements:

- Thin `#lang rhdl` and `#lang rhdl/base` bridges using the ordinary Rhombus
  reader instead of a closed line-oriented parser.
- An importable context-based elaboration kernel, a minimal base frontend,
  focused combinational, Boolean, sequential, and hierarchy modules, and a
  feature-free standard aggregator.
- A curated standard profile that does not implicitly expose the public core
  Builder or raw elaboration-kernel entry points.
- Opaque host-value-parameterized circuit generators with deterministic fresh
  module symbols and declaration-identity recursion checks. Hardware types,
  closures, collections, and user-defined configuration objects are supported;
  runtime hardware entities are rejected.
- Explicit `input` and `output` construction with `Bits(width)` types.
- Explicit-width literals, the full initial combinational operation surface,
  primitive registers, synchronous reset, reusable definitions, instances,
  and instance port access.
- Ordinary Rhombus definitions, functions, imports, host conditionals, and
  iteration within and around circuit generators.
- A separately imported user combinator test proving that new construction
  abstractions do not require reader, IR, verifier, or backend changes.
- Explicit embedded-frontend origins on constructed operations.
- Diagnostics for hardware parameters, recursive elaboration, generator calls
  outside elaboration, driving inputs, width mismatch, and hardware-controlled
  host conditions.
- CIRCT lowering and Verilator simulation of frontend-authored adder, ALU,
  width-changing, counter, and hierarchy designs.
- One canonical source for each feature showcase under `examples/`. Examples
  export reusable generators and a default design, so positive IR, printer,
  CIRCT, and simulation tests import or re-elaborate them instead of maintaining
  separate fixtures. Intentionally invalid programs live under
  `tests/frontend/invalid/`.
- An explicit language-oriented equivalence ladder under `examples/lop/` that
  builds one adder through the public Builder, elaboration kernel,
  `#lang rhdl/base` plus an explicit combinational import, and the concise
  standard profile. Focused tests prove that all four presentations create
  identical printed RHDL IR and identical CIRCT MLIR while retaining
  layer-appropriate provenance.
- Concise standard-layer syntax throughout the feature showcases. Builder
  construction remains elsewhere only for lower-layer API, verifier,
  malformed-IR, and backend-name tests.

The kernel remains lower-level than every public surface module, while the
standard module only aggregates those surfaces. Grouped `IO`, `RegInit`,
protocol interfaces, pipelines, and similar Chisel-like conveniences should be
libraries over the kernel whenever they do not require new hardware semantics.
Static-information-based ergonomics can be added while retaining runtime
checks where static information is unavailable.

### Phase 3.5: extensible scalar types and canonical selection — complete

- Add nominal core `Clock` and `Reset` implementations of `HardwareType`, plus
  open `DataType`, `FlatDataType`, and `BitwiseType` capabilities for types
  defined outside core.
- Define `Bool` in the standard frontend as a nominal, one-bit `BitwiseType`.
  Keep core equality's result and mux lookup's selector in `Bits`, then layer
  Boolean equality and binary selection over explicit equal-width
  reinterpretation. Require `Clock` and `Reset` at register boundaries.
- Replace `rtl.mux` with variable-arity `rtl.mux_lookup`, including normalized
  unique keys, an explicit default, selector-key validation, and equal
  `DataType` results.
- Lower the binary `mux` surface form to a reinterpretation plus one-case
  `Bits(1)` lookup, and lower the existing `mux_lookup` surface form directly
  to the same IR operation.
- Update deterministic printing, verification, CIRCT lowering, examples, and
  focused negative tests. Preserve direct `comb.mux` lowering for the one-bit
  one-case form, without teaching the backend about `Bool`.

### Phase 3.6: core records and frontend aggregates — complete

Add aggregates as a complete vertical slice rather than as a flattened
frontend experiment. A record is a real core hardware value: it can cross a
module boundary, be constructed and projected, drive a record place, and be
selected or stored wherever an operation accepts any `DataType`.

Implement the slice in this order:

1. Add structural `RecordType` to core with ordered named fields, nesting,
   recursive well-formedness, deterministic printing, and structural
   `type_equal` support.
2. Add `rtl.record_create` and `rtl.record_get`, plus readable field projection
   on record values.
3. Add projected record places and complete driver accounting. Support either
   one whole-record drive or complete field-wise drives for module outputs,
   instance inputs, and register next-state places; reject partial and mixed
   driving, and canonicalize complete field drives to `rtl.record_create` plus
   one whole-record drive before module completion.
4. Confirm that the existing generic `mux_lookup` and register operations
   accept `RecordType` without introducing `record_mux` or `record_reg`
   operations.
5. Lower record types, construction, projection, aggregate ports, aggregate
   muxes, and aggregate registers through CIRCT's `hw` and `seq` dialects.
6. Add the frontend `bundle` extension as concise syntax for defining a
   `RecordType` plus its constructor and field accessors. Bundle ports remain
   single record-typed core ports; they are not flattened into unrelated
   scalar ports.
7. Add aggregate literals/construction, nested dot access, whole-bundle bulk
   connection, and field-wise assignment. All connection checks happen before
   emitting a partial set of drives.
8. Add focused core, frontend, backend, and Verilator tests covering nested
   records, ports, instances, construction/projection, bulk and field-wise
   connection, muxes, registers, resets, and invalid driver/type cases.

The intended bundle surface is:

```text
bundle Pair(T):
  left: T
  right: T

circuit Swap(width):
  input source: Pair(Bits(width))
  output result: Pair(Bits(width))

  result.left <== source.right
  result.right <== source.left
```

The frontend syntax is an extension over core record semantics, not a parallel
aggregate model. A lower-level `#lang rhdl/base` example must build the same
record circuit using `RecordType`, record construction/projection, and ordinary
core connections, and equivalence tests must compare both RHDL IR and CIRCT
MLIR.

### Phase 3.7: role-based interfaces — complete

Build interfaces as a complete frontend abstraction after records work end to
end. An interface is not itself a `DataType`: it is a typed group of record
ports whose directions depend on an explicitly selected protocol role.

```text
interface ReadyValid(T):
  role producer
  role consumer

  producer -> consumer:
    valid: Bool
    bits: T

  consumer -> producer:
    ready: Bool

circuit Example(width):
  interface tx(ReadyValid(Bits(width)), ~role: producer)
  interface rx(ReadyValid(Bits(width)), ~role: consumer)

  tx <=> rx
```

Each declared flow becomes one record-typed core port. For a `producer`
endpoint above, `{valid, bits}` is an output record and `{ready}` is an input
record; the `consumer` role receives the opposite directions. Named roles are
part of the interface definition and there is no generic `Flipped` or
`flipped(...)` type operation.

The interface extension owns its protocol descriptor and attaches it to the
frontend circuit definition alongside the elaborated core module. Instance dot
access uses that descriptor to reconstruct the logical interface; it never
infers structure from generated port names. Core and the backend see only
ordinary typed ports and do not interpret roles or bulk-connection policy.

This phase includes:

1. Parameterized two-role interface definitions with ordered, nested
   `DataType` fields and explicit field flows.
2. Endpoint declaration, field access, and reconstruction across module
   instances.
3. Atomic `<=>` connection that requires the same interface definition,
   compatible parameters, and complementary effective directions, then
   connects both flows. Two module-boundary endpoints normally use
   complementary roles; a module boundary and an inverted instance view
   normally use the same declared role.
4. Explicit one-way access for adapters and protocol logic; bulk connection is
   convenience, not the only way to use an endpoint.
5. Diagnostics for duplicate roles or fields, unknown roles, same-role bulk
   connection, incompatible interface parameters, mismatched field types, and
   incomplete underlying connections.
6. A manually expressed pair-of-record-ports example and a role-interface
   example that produce equivalent core IR and CIRCT MLIR, followed by CIRCT
   verification and Verilator simulation.

Multi-role protocols, optional fields, arrays, and protocol behavior such as
arbitration remain separate extensions. They are not required to make the
two-role interface feature internally complete.

### Phase 4: hardening

- Expand negative diagnostic coverage and improve source-location and
  multi-location diagnostic quality when prioritized.
- Add deterministic golden RHDL IR and CIRCT MLIR tests.
- Test CIRCT-exported SystemVerilog through simulation rather than maintaining
  a second RHDL-owned RTL printer.
- Add randomized or property-based bit-vector tests.
- Differentially simulate generated modules against an elaboration-time
  reference model where practical.
- Document the public IR compatibility policy.

### Deferred: IR mutation and rewriting

Read-only inspection remains supported, but user-authored IR mutation is not
an immediate project goal. Rewrite transactions, insertion points, handle
invalidation, mutation-safe traversal, optimization passes, and provenance
rules for replacement operations should be designed together only when a
concrete transformation use case justifies them. Aggregate implementation and
hardening do not depend on that work.

## 14. Acceptance milestones

### Milestone A: Builder and backend slice — complete

RHDL can:

1. Construct a host-width-parameterized adder through the Builder.
2. Construct a counter with a primitive register and active-high synchronous
   reset.
3. Instantiate one explicitly reused module definition twice.
4. Read an already-driven module output within its defining module.
5. Dump and walk the public IR.
6. Generate valid CIRCT MLIR, have CIRCT export SystemVerilog, and pass
   Verilator simulation.
7. Reject width mismatch, undriven and multiply-driven places, reads before a
   drive, illegal cross-module or cross-design use, forged ownership, and
   combinational cycles through Builder or verifier diagnostics.

### Milestone B: complete manual IR surface — complete

RHDL constructs, verifies, lowers, and simulates the full initial manual
combinational surface. A host-width-parameterized ALU covers `not`, `and`,
`or`, `xor`, `add`, `sub`, `eq`, and `mux`; a width-changing datapath covers
`concat`, `extract`, `zext`, and `trunc` through CIRCT and Verilator.

### Milestone C: frontend foundation — complete

RHDL can:

1. Elaborate parameterized circuits from arbitrary opaque host values,
   including a host `Int` width, a hardware type, a closure, and a
   configuration object.
2. Create fresh definitions for repeated generator calls without automatic
   deduplication and reject active recursive elaboration.
3. Preserve origins through the public IR and elaborate an imported user
   hardware combinator without changing the language reader.
4. Reject driving an input, a width mismatch, a runtime hardware parameter, a
   generator call outside elaboration, and a hardware-controlled host
   condition.
5. Lower the frontend-produced design through CIRCT and pass the existing
   adder Verilator testbench.

### Milestone D: complete initial frontend surface — complete

RHDL can:

1. Elaborate a parameterized ALU whose width parameter is a host `Int`, while
   allowing the same circuit mechanism to accept other opaque host values.
2. Elaborate a counter with a primitive register and active-high synchronous
   reset.
3. Instantiate and access ports of an explicitly reused module definition.
4. Reject malformed surface forms, invalid local hardware operations,
   recursive generators, and hardware values used as host conditions through
   the frontend, Builder, or verifier boundary as appropriate.

The design surface and canonical examples are complete. Comprehensive
source-location coverage for whole-graph verifier diagnostics is deferred to
Phase 4 and does not block aggregate types or interfaces.

### Milestone E: extensible scalar types and canonical selection — complete

RHDL can:

1. Define a nominal `Bool` outside core and distinguish it from `Clock`,
   `Reset`, and `Bits(1)` through `type_equal`.
2. Require extension `Bool` for the binary selection surface, core `Bits` for
   canonical lookup selection, `Clock` for register clocks, and `Reset` for
   synchronous register resets.
3. Represent binary and N-way selection with only `rtl.mux_lookup` in the
   public IR.
4. Reject duplicate or out-of-range lookup keys and mismatched case/default
   data types.
5. Lower extension-defined flat types without backend special cases, lower
   one-bit binary lookup to `comb.mux`, lower wider lookup through CIRCT, and
   pass focused simulation tests.

### Milestone F: records and bundles

RHDL can construct, project, connect, select, register, reset, pass through
module ports, lower, and simulate nested structural records. The standard
frontend can express the same semantics through bundles, including nested dot
access and atomic whole or field-wise connections.

### Milestone G: role-based interfaces

RHDL can define a parameterized two-role interface, expose either role on a
module, reconstruct it through an instance, connect direction-compatible
endpoints atomically in both directions, and lower the result as ordinary
record-typed core ports. Equivalent explicit-record and interface-authored
examples produce the same core IR and CIRCT MLIR and pass simulation.

These milestones keep core type/value semantics, frontend language
extensions, and backend lowering independently testable. IR mutation is not a
milestone for the current implementation sequence.
