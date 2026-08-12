# RHDL Initial Architecture and Implementation Plan

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

RHDL keeps three layers separate.

### 3.1 Syntax

Rhombus supplies parsing, hygienic macros, binding spaces, operators, dot
syntax, assignment syntax, static information, and source locations.

The initial surface language should support conventional forms such as:

```text
module ALU(width: Int):
    input:
        a: Bits(width)
        b: Bits(width)

    output:
        y: Bits(width)

    y := a + b
```

Surface syntax expands to calls into the elaboration and builder APIs. Macro
expansion is not itself the hardware IR.

### 3.2 Elaboration

Elaboration executes Rhombus code to decide what hardware exists.

```text
HOST                         HARDWARE

Int                          Bits(width)
Boolean                      Bits(1), when used as data
if                           no initial hardware equivalent
for over a host collection   repeated generated structure
generator call               fresh module definition
```

Generator parameters must be host values. A hardware value used as the test of
host `if`, `when`, `unless`, `cond`, `&&`, `||`, or host iteration must produce
an error during expansion or elaboration; it must never be accepted through
Rhombus truthiness.

### 3.3 IR

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

Operations are described by namespaced schemas instead of a closed hierarchy
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

## 5. Initial data type

The only initial hardware data type is:

```text
Bits(width)
```

Rules:

- `width` is an explicit positive host `Int`.
- All widths are known during elaboration.
- `Bits(1)` represents Boolean hardware data as well as ordinary one-bit data.
- There is no separate `Bool`, `UInt`, or `SInt` initially.
- There are no implicit width conversions.
- Narrowing and extension use explicit operations.
- Integer constants must specify a width and fit that width.
- Arithmetic is unsigned modular bit-vector arithmetic for now.

Initial width rules:

```text
not(Bits(w))                         -> Bits(w)
and/or/xor(Bits(w), Bits(w))         -> Bits(w)
add/sub(Bits(w), Bits(w))            -> Bits(w)
eq(Bits(w), Bits(w))                 -> Bits(1)
mux(Bits(1), Bits(w), Bits(w))       -> Bits(w)
concat(Bits(a), Bits(b), ...)        -> Bits(a + b + ...)
extract(Bits(w), high, low)          -> Bits(high - low + 1)
zext(Bits(a), target_width)          -> Bits(target_width)
trunc(Bits(a), target_width)         -> Bits(target_width)
```

`zext` requires a larger target width, `trunc` requires a smaller target width,
and `extract` indices are explicit host integers checked during elaboration.
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
mux
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
    clock         // Bits(1) Value
    reset         // optional Bits(1) Value
    reset_value   // required when reset is present
```

On the active edge of `clock`:

```text
if reset is present and reset == 1:
    current <- reset_value
else:
    current <- next
```

Only active-high synchronous reset is supported initially. The reset value must
have the register data width. Clock and reset operands use `Bits(1)` and are
validated by the register schema rather than represented by distinct types.

The next-state place must be driven exactly once. Holding state is explicit:

```text
r.next := r.current
```

Surface syntax may allow the register handle itself to be read as its current
value:

```text
r = Reg(Bits(8), clock = clk, reset = rst, reset_value = Bits(8)(0))
r.next := r + Bits(8)(1)
```

A register breaks a temporal feedback cycle. Cycles consisting only of
combinational operations remain illegal.

## 7. Modules, generators, and instances

A module declaration defines a Rhombus generator.

```text
module ALU(width: Int):
    ...
```

Calling the generator with host values produces a fresh module definition:

```text
ALU32 = ALU(32)
```

There is no automatic specialization deduplication initially. Calling
`ALU(32)` twice produces two distinct module definitions. A user can explicitly
reuse one definition for multiple instances:

```text
ALU32 = ALU(32)
u0 = instance(ALU32)
u1 = instance(ALU32)
```

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
builder.design(...)
builder.module(...)
builder.input(...)
builder.output(...)
builder.emit(...)
builder.drive(...)
builder.register(...)
builder.instance(...)
```

It maintains the active design, module, insertion point, source location, and
origin. It rejects locally impossible operations immediately, while whole-graph
checks run at verification boundaries.

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

The initial verifier enforces:

1. Every value and place belongs to exactly one design.
2. Values are used only where their module scope permits.
3. Input ports are never driven.
4. Every output, instance input, and register next-state place has exactly one
   driver.
5. A place and its driver have exactly the same `Bits(width)` type.
6. Operation operands and results satisfy their schema width rules.
7. Register clocks and resets are `Bits(1)`.
8. A reset value is present exactly when reset is present and matches the
   register width.
9. Module instances reference a completed module definition.
10. Recursive generator elaboration is rejected.
11. Purely combinational cycles are rejected.
12. Hardware values never control host computation.

Diagnostics should identify both the invalid operation and the relevant
declaration or driver when two locations are involved.

## 10. Provenance and naming

Every operation, value, and place carries or can recover:

```text
location       immediate user source span
origin         immutable link to the construct that produced it
name_hint      optional semantic name for diagnostics and generated RTL
```

Macro-introduced operations retain the user's call-site location plus an origin
record for the expansion. Rewrites preserve the replaced operation's origin by
default. When several operations are combined, the new origin may reference
multiple parent origins.

IR identity and user-facing names are separate. Names may be changed or made
unique without changing value, operation, or module identity.

## 11. Backend boundary

The public RHDL IR remains independent of backend representation:

```text
RHDL hardware IR
    |
    +-- FIRRTL/CIRCT lowering
    |
    +-- or CIRCT hw/comb/seq lowering
    |
    v
SystemVerilog
```

The first backend is selected through a small spike that implements the same
combinational module, synchronous-reset register, and module instance through
both plausible CIRCT routes. The comparison should evaluate:

- Lowering complexity.
- Preservation of source locations and names.
- Diagnostic quality.
- Tool installation and version pinning.
- Generated SystemVerilog quality.
- Compatibility with Verilator.

Backend-specific IR must not leak into the frontend value and place APIs.

## 12. Initial non-goals

The first implementation deliberately excludes:

- `when` and conditional-connect semantics.
- General wires or multiple/priority connects.
- Automatic module-specialization deduplication.
- `Bool`, `UInt`, and `SInt` as distinct types.
- Implicit widths or general width inference.
- Arrays, structs, and memories.
- Asynchronous or active-low resets.
- Multiple clock/reset-domain analysis.
- General IR regions and control-flow blocks.
- Runtime-loaded dialects.
- Multiplication and shifts until their width semantics are chosen.

These can be added only with explicit semantics and tests.

## 13. Implementation sequence

### Phase 0: executable semantic examples and toolchain

- Pin compatible Racket/Rhombus and CIRCT versions.
- Establish a repeatable development environment.
- Write expected IR for an ALU, a synchronous-reset counter, and a module
  instance.
- Complete the FIRRTL-versus-CIRCT-direct backend spike.
- Record the backend decision and invocation contract.

### Phase 1: IR kernel

Implement:

```text
Design
Module
Operation
Value
Place
Bits(width)
Attribute
Symbol
Location
Origin
schema registry
Builder
Verifier
deterministic printer
```

Unit-test ownership, use-def tracking, single-driver behavior, type checks,
cycle detection, and invalid handle behavior.

### Phase 2: manually built vertical slice

- Implement the initial combinational operations.
- Implement modules, ports, drives, instances, and registers.
- Construct the ALU and counter directly through the builder API.
- Lower them through the selected backend.
- Generate SystemVerilog and simulate it with Verilator.

This phase must produce working hardware before frontend syntax work expands.

### Phase 3: Rhombus frontend

Implement:

```text
#lang rhdl
module
input/output declarations
Bits(width)
Reg
instance
:=
initial operators
field and port access
elaborate(...)
```

Add static-information-based ergonomics, but retain runtime elaboration checks
where Rhombus static information may be unavailable. Explicitly guard every
host conditional path against hardware values.

### Phase 4: inspection and rewriting

- Stabilize `walk`, `users`, `defining_op`, and IR printing.
- Implement rewrite transactions and handle invalidation.
- Add a user pass that replaces `x + 0` with `x`.
- Verify automatically after every user pass.
- Check that provenance survives replacement.

### Phase 5: hardening

- Add negative diagnostic tests.
- Add deterministic golden IR and SystemVerilog tests.
- Add randomized or property-based bit-vector tests.
- Differentially simulate generated modules against an elaboration-time
  reference model where practical.
- Document the public IR compatibility policy.

## 14. First acceptance milestone

The first milestone is complete when RHDL can:

1. Elaborate a parameterized ALU whose width parameter is a host `Int`.
2. Elaborate a counter with a primitive register and active-high synchronous
   reset.
3. Instantiate one explicitly reused module definition twice.
4. Read an already-driven module output within its defining module.
5. Dump and walk the public IR.
6. Apply a user-authored `x + 0 -> x` rewrite and reverify the design.
7. Generate SystemVerilog and pass Verilator simulation.
8. Produce source-located errors for width mismatch, driving an input,
   undriven and multiply-driven places, reading an output before driving it,
   illegal cross-module use, a combinational cycle, and a hardware value used
   as a host condition.

That milestone establishes the defining RHDL architecture without committing
to the deferred language features.
