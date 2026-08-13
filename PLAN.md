<!-- Defines RHDL's agreed semantics, backend boundary, and staged implementation plan. -->

# RHDL Initial Architecture and Implementation Plan

## Current implementation status

The first manually constructed vertical slice is implemented. It currently
provides:

- `Design`, `Module`, `Operation`, `Value`, `Place`, `HardwareType`, `DataType`,
  `FlatDataType`, `BitwiseType`, `Bits`, `Clock`, `Reset`, `Location`, and
  `Origin` handles with stable IDs and explicit owning-object relationships.
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

Native core `Clock` and `Reset` types, an extension-defined frontend `Bool`,
and the canonical N-way `rtl.mux_lookup` operation are implemented. Core and
the CIRCT backend depend on open type capabilities rather than on `Bool`.

The first-cut Builder-to-CIRCT vertical slice and IR contract are complete.
The complete initial frontend surface is implemented and is the canonical path
for examples and positive integration fixtures. User rewrite transactions
remain future work.

## 1. Goal

RHDL is a Rhombus-hosted language for elaborating, inspecting, transforming,
and compiling digital hardware.

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
    |             ^
    |             |
    +--- inspection and user rewrites
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

The IR is a normal public programming interface. Users can inspect it, walk
use-def relationships, and transform it through controlled rewriting APIs.

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

Generator parameters must be host values. A hardware value used as the test of
host `if`, `when`, `unless`, `cond`, `&&`, `||`, or host iteration must produce
an error during expansion or elaboration; it must never be accepted through
Rhombus truthiness.

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

## 5. Hardware types and selection

Core supplies these concrete hardware types:

```text
Bits(width)
Clock
Reset
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
generator name and elaboration order. Recursion in the active generator stack
is diagnosed as an elaboration error.

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

## 8. Public construction and transformation APIs

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
deferred until regions or rewriting require one.

### 8.2 Rewriter

Existing IR is structurally mutable only through a rewriter:

```text
rewriter.replace(...)
rewriter.erase(...)
rewriter.insert_before(...)
rewriter.insert_after(...)
```

A rewrite transaction may temporarily contain incomplete relationships, but it
must verify before completion. Erased operations and values invalidate their
handles. Iteration and `users()` return documented snapshots so mutation does
not silently corrupt traversal.

### 8.3 Elaboration and compilation

The IR boundary remains explicit:

```text
design = elaborate(Top(...))

design.verify()
design.dump_ir()

for op in design.walk():
    ...

compile(design, passes = [...])
```

Compilation verifies after elaboration and after every user transformation
stage.

## 9. Verification invariants

The target IR Builder and verifier enforce:

1. Every value and place belongs to exactly one design.
2. Values are used only where their module scope permits.
3. Input ports are never driven.
4. Every output, instance input, and register next-state place has exactly one
   driver.
5. A place and its driver have exactly the same hardware type.
6. Operation operands and results satisfy their schema type rules.
7. Lookup selectors and keys are valid, lookup keys are unique, and every case
   and default has the result `DataType`.
8. Register clocks are `Clock`, and synchronous reset operands are `Reset`.
9. A reset value is present exactly when reset is present and matches the
   register state type.
10. Module instances reference a completed module definition.
11. Purely combinational cycles are rejected.

The frontend additionally rejects recursive generator elaboration and prevents
hardware values from controlling host conditionals. Those checks do not belong
to the manual IR verifier because the host computation is no longer present
once IR exists.

Complete source-location and multi-location diagnostic reporting is useful but
is not a gate for the initial language or rewriting work. It is deferred to
hardening.

## 10. Provenance and naming

Every operation, value, and place carries or can recover:

```text
location       immediate user source span when captured, otherwise unknown
origin         immutable link to the construct that produced it
name_hint      optional semantic name for diagnostics and generated RTL
```

Macro-introduced operations retain the user's call-site location plus an origin
record for the expansion. Rewrites preserve the replaced operation's origin by
default. When several operations are combined, the new origin may reference
multiple parent origins.

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
core `Bits` and the frontend's extension-defined `Bool`. `Reset` lowers to a
one-bit value, and `Clock` lowers through the backend's clock representation.
Modules and instances become `hw` operations, combinational values become
`comb` operations, and primitive registers become `seq` operations.
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
```

These mappings are part of the backend contract. RHDL should not introduce
same-named pseudo-CIRCT operations when CIRCT expresses the canonical form as a
composition.

## 12. Remaining non-goals

The native-type and canonical-selection refactor still deliberately excludes:

- `when` and conditional-connect semantics.
- General wires or multiple/priority connects.
- Automatic module-specialization deduplication.
- `UInt` and `SInt` as distinct types.
- Implicit widths or general width inference.
- Arrays, structs, and memories.
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
- Host-`Int`-parameterized circuit generators with deterministic fresh module
  symbols and active-generator recursion checks.
- Explicit `input` and `output` construction with `Bits(width)` types.
- Explicit-width literals, the full initial combinational operation surface,
  primitive registers, synchronous reset, reusable definitions, instances,
  and instance port access.
- Ordinary Rhombus definitions, functions, imports, host conditionals, and
  iteration within and around circuit generators.
- A separately imported user combinator test proving that new construction
  abstractions do not require reader, IR, verifier, or backend changes.
- Explicit embedded-frontend origins on constructed operations.
- Diagnostics for non-host parameters, recursive elaboration, generator calls
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

### Phase 3.6: frontend aggregate and interface prototype

Prototype aggregates as a language extension before adding aggregate values
to the core IR. The extension flattens each aggregate port into deterministic
scalar `HardwareType` ports, retains its logical shape in frontend metadata,
and reconstructs the same view at instance boundaries. It must not pack an
aggregate into one `Bits` value merely to fit the current core.

Keep two distinct abstractions:

- A **bundle** is a named value shape whose fields all inherit the enclosing
  port direction. It provides nesting, field projection, and structural bulk
  connection over scalar leaves.
- An **interface** describes communication between two explicitly named roles.
  Each field declares which role drives it. An interface is a group of related
  ports, not initially a `DataType` and not a value accepted by registers,
  muxes, equality, or other core operations.

The intended source model is:

```text
bundle Pair(T):
  left: T
  right: T

interface ReadyValid(T):
  role producer
  role consumer

  producer -> consumer:
    valid: Bool
    bits: T

  consumer -> producer:
    ready: Bool

circuit Example(width):
  input source: Pair(Bits(width))
  output result: Pair(Bits(width))
  interface tx: ReadyValid(Bits(width)) as producer
  interface rx: ReadyValid(Bits(width)) as consumer

  result <== source
  tx <=> rx
```

Named roles replace a generic direction-reversing type wrapper. The local
direction of every interface leaf follows from the selected role and the
field's declared flow. At an instance boundary, ordinary input/output
inversion still follows from core instance semantics; the interface role
itself remains stable and visible. Bulk interface connection requires
compatible interface definitions and complementary roles. This makes role
meaning explicit in APIs and leaves room for protocols with names such as
`requester`/`responder`, `controller`/`peripheral`, or
`producer`/`consumer`.

Implement this prototype in the following order:

1. Add a frontend-only shape protocol and aggregate view over ordered scalar
   leaves. Scalar `HardwareType` remains the base case.
2. Add bundles, deterministic flattening, nested field projection, and atomic
   bulk connection. Flattened names use a reserved separator and are checked
   for collisions.
3. Preserve logical port-group metadata on elaborated modules and use it to
   reconstruct bundle views through concise instance dot access. Do not infer
   aggregate structure from flattened names.
4. Add precise structural diagnostics for missing fields, unexpected fields,
   leaf type mismatches, illegal directions, recursive shapes, and name
   collisions.
5. Add two-role interfaces with named roles, per-field flow declarations, and
   complementary-role bulk connection. Do not add a generic `Flipped` or
   `flipped(...)` operation.
6. Prove the extension boundary with paired examples and focused tests showing
   that manually flattened, bundled, and interface-authored circuits produce
   equivalent core IR and CIRCT MLIR.

This phase intentionally excludes aggregate-valued literals and operations,
aggregate registers and muxes, core grouping metadata, and general multi-role
protocols. Fieldwise frontend helpers may be explored without claiming that
an aggregate is a core hardware value.

After the prototype settles field access, role syntax, bulk connection, and
diagnostics, promote a structural `RecordType`, record construction, and
record projection into core when aggregates need value semantics such as
storage or selection. Interface roles and bulk connection remain frontend
policy. Add neutral core grouping metadata only if inspection, rewriting, or
module APIs must preserve source-level grouping after elaboration.

### Phase 4: inspection and rewriting

- Stabilize inspection first: make `walk` return documented snapshots, expose
  `Value.defining_op` as an operation handle, make `Value.users()` return
  operation handles instead of internal IDs, and expose a place's owning
  operation without leaking its internal ID.
- Update the verifier, CIRCT lowering, and tests to use the public inspection
  contract where appropriate.
- Implement rewrite transactions and handle invalidation.
- Add a user pass that replaces `x + 0` with `x`.
- Verify automatically after every user pass.
- Check that provenance survives replacement.

### Phase 5: hardening

- Expand negative diagnostic coverage and improve source-location and
  multi-location diagnostic quality when prioritized.
- Add deterministic golden RHDL IR and CIRCT MLIR tests.
- Test CIRCT-exported SystemVerilog through simulation rather than maintaining
  a second RHDL-owned RTL printer.
- Add randomized or property-based bit-vector tests.
- Differentially simulate generated modules against an elaboration-time
  reference model where practical.
- Document the public IR compatibility policy.

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

1. Elaborate a parameterized adder whose width parameter is a host `Int`.
2. Create fresh definitions for repeated generator calls without automatic
   deduplication and reject active recursive elaboration.
3. Preserve origins through the public IR and elaborate an imported user
   hardware combinator without changing the language reader.
4. Reject driving an input, a width mismatch, a non-`Int` parameter, a
   generator call outside elaboration, and a hardware-controlled host
   condition.
5. Lower the frontend-produced design through CIRCT and pass the existing
   adder Verilator testbench.

### Milestone D: complete initial frontend surface — complete

RHDL can:

1. Elaborate a parameterized ALU whose width parameter is a host `Int`.
2. Elaborate a counter with a primitive register and active-high synchronous
   reset.
3. Instantiate and access ports of an explicitly reused module definition.
4. Reject malformed surface forms, invalid local hardware operations,
   recursive generators, and hardware values used as host conditions through
   the frontend, Builder, or verifier boundary as appropriate.

The design surface and canonical examples are complete. Comprehensive
source-location coverage for whole-graph verifier diagnostics is deferred to
Phase 5 and does not block inspection or rewriting.

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

### Milestone F: inspection and rewriting

RHDL can apply a user-authored `x + 0 -> x` rewrite, preserve provenance,
invalidate replaced handles, and automatically reverify the design.

These milestones keep the manual IR/backend contract, surface language, and
mutation model independently testable.
