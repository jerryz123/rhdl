<!-- Defines the semantic and implementation plan for the RFPL structural floorplanning language. -->

# RFPL language plan

## Status

This document records the accepted direction and concrete initial cut for
RFPL. The first structural vertical slice is implemented: `#lang rfpl`
defines floorplans, admits nested floorplans and RHDL circuit instances,
requires an exact rectangular physical outline for every floorplan definition,
requires coordinates for contained floorplan instances, enforces
structural-only module bodies, and emits the shared design through the existing
CIRCT backend. Strap-pin specialization is the next semantic milestone.

The first cut is intentionally much narrower than a physical-design database
or geometry language. It establishes a structural floorplan hierarchy that
can contain RHDL circuits, gives every floorplan a rectangular macro width and
height, preserves ordinary typed wiring, rejects logic in floorplan bodies,
and emits the complete hierarchy as CIRCT modules.

Placement coordinates, nonrectangular geometry, technology grids, constraints,
and physical-design tool integration build on this foundation later. They
must not be designed into the rectangular-outline feature speculatively.

## Decision

RFPL is a separate Rhombus-based language above RHDL. Its initial and only
domain object is `floorplan`.

A floorplan behaves similarly to an RHDL circuit:

- It is a parameterized host-language generator.
- It declares typed input and output ports.
- It declares one exact rectangular physical size.
- Its child floorplans have explicit lower-left coordinates within it.
- Its body may use ordinary Rhombus host computation to generate structure.
- Calling it elaborates a module definition.
- The resulting object may be instantiated hierarchically.
- Every driveable port or wire has exactly one effective driver.

Unlike a circuit, a floorplan body may contain only:

- One `size(width: ..., height: ...)` declaration.
- Placed instances of other floorplans.
- Instances of RHDL circuits.
- Exact-type wiring among its own ports, child ports, and optional internal
  alias wires.

A floorplan body may not implement logic. It cannot create constants,
operators, registers, memories, hardware conditionals, assertions, DPI calls,
or other behavioral hardware.

Each floorplan lowers to an ordinary CIRCT `hw.module`. Floorplan instances
and circuit instances both lower to `hw.instance`. Wiring lowers through the
same alias and `hw.output` conventions as RHDL. RFPL does not introduce a new
CIRCT operation or dialect in the initial cut.

## Dependency direction

The dependency direction is one-way:

```text
RHDL circuit generators --------+
                                |
RFPL floorplan generators ------+--> shared RHDL core Design
                                           |
                                           v
                                  existing CIRCT backend
                                           |
                                           v
                                  hw.module / hw.instance
```

RFPL may depend on the narrow RHDL construction APIs needed for types, ports,
instances, connections, core verification, and CIRCT emission. RHDL core,
frontend, and backend must not import RFPL.

An RFPL floorplan may instantiate an RHDL circuit. An RHDL circuit may not
instantiate an RFPL floorplan. This direction preserves RFPL as the structural
layer above logic implementation.

The initial implementation uses RHDL's internal `CircuitDefinition` protocol
to reuse its established instance construction without copying it.
`FloorplanDefinition` remains a distinct public wrapper, and RFPL performs a
whole-elaboration hierarchy check that rejects any non-floorplan module which
targets a floorplan module. This enforces the one-way boundary semantically;
it does not rely on an import convention.

## Initial authoring surface

`#lang rfpl` initially exports only the surface necessary to declare and wire
structural modules:

- `floorplan`
- `input`
- `output`
- `size`
- `Length`, `RectOutline`, `nm`, and `um`
- `Coordinate` and `FloorplanPlacement` for inspecting elaborated placement
  metadata
- `wire`, if the implementation retains explicit alias wires
- `inst`
- `<==`
- `elaborate`
- RHDL hardware type descriptors and annotations needed to type ports
- Ordinary Rhombus definitions, functions, conditionals, loops, collections,
  and other host computation

It does not export:

- `circuit` or `sync_circuit`
- Hardware literals or constants
- Arithmetic, Boolean, comparison, mux, decode, concat, extract, cast, or
  indexing operations
- Registers or memories
- `when`, `switch`, or other runtime hardware control
- Assertions, simulation effects, or DPI operations
- RHDL implementation Builders or raw operation constructors

An imported RHDL module may export a circuit generator. Calling that generator
inside a floorplan is legal because its logic is elaborated inside the child
circuit module, not the active floorplan module.

## Initial example

The intended shape is:

```rhombus
#lang rfpl

import:
  "blocks.rhdl" open

floorplan Pair(width):
  size(width: um(100), height: um(50))
  input(a, b): Bits(width)
  output(sum0, sum1): Bits(width)

  def adder = Adder(width)
  inst left(adder)
  inst right(adder)

  left.a <== a
  left.b <== b
  right.a <== b
  right.b <== a
  sum0 <== left.sum
  sum1 <== right.sum

def design = elaborate(Pair(8))
```

`Adder` is an RHDL circuit generator. `Pair` contains no addition operation;
it instantiates the already elaborated `Adder` circuit module twice and wires
its ports.

Reusing the same `adder` object stamps the same child module definition twice.
Calling `Adder(width)` separately for each instance retains RHDL's existing
fresh-definition behavior. RFPL does not change circuit specialization or
deduplication semantics.

The floorplan portion of the emitted CIRCT should have the following essential
shape:

```mlir
hw.module @Pair(in %a : i8, in %b : i8,
                out sum0 : i8, out sum1 : i8) {
  %left.sum = hw.instance "left" @Adder(
    a: %a: i8, b: %b: i8) -> (sum: i8)
  %right.sum = hw.instance "right" @Adder(
    a: %b: i8, b: %a: i8) -> (sum: i8)
  hw.output %left.sum, %right.sum : i8, i8
}
```

Exact textual formatting and generated SSA names remain backend details. The
semantic requirement is that the floorplan module contain hierarchy and
wiring only. The separately emitted `Adder` module may contain `comb`, `seq`,
or other RHDL-supported logic operations.

## Floorplan definition object

Calling a floorplan generator returns a `FloorplanDefinition` containing at
least:

- Its ordinary RHDL core `Module`.
- Its floorplan declaration identity and source name.
- Its host generator arguments for diagnostics only; they are not hashed or
  compared in the initial cut.
- Its required `RectOutline` with exact physical width and height.
- Its source location.

`FloorplanDefinition` is not itself a second module IR. Its core module is the
single representation used for ownership verification, inspection, and CIRCT
emission.

The wrapper exists to:

- Distinguish a floorplan from a circuit at the RFPL authoring boundary.
- Let RFPL's `inst` admit both floorplans and circuits.
- Prevent RHDL's `inst` from admitting floorplans.
- Select floorplan modules for structural-only verification.
- Retain rectangular physical metadata and later strap specialization without
  placing either in the RHDL hardware IR prematurely.

The complete RFPL elaboration result contains the shared RHDL `Design`, the
explicit top `FloorplanDefinition`, and the set of all floorplan definitions
created during elaboration. It also retains every `FloorplanPlacement`, tying
an instance operation to its parent module, child definition, and coordinate.
Child circuit modules remain ordinary modules in the same design.

## Elaboration behavior

`floorplan` follows RHDL circuit staging where that behavior is structural:

- Generator arguments are host values, not live hardware values.
- Each generator call creates a fresh floorplan definition in the initial cut.
- A floorplan definition can be stored and instantiated more than once.
- Every generated definition declares `size` exactly once; every stamp of that
  definition shares the same outline.
- Only the selected top may be generated outside a floorplan body. Every other
  floorplan generator call occurs while a parent floorplan body is active.
- Active recursion by declaration identity is rejected.
- Nested floorplan declarations may capture host values but not parent
  hardware ports or child-instance handles.
- Hardware crosses hierarchy only through ports.
- Host `if` and `for` generate instances and connections; they do not inspect
  runtime hardware.

RFPL `elaborate` requires the selected top object to be a floorplan. A bare
RHDL circuit is not a valid RFPL top, although circuits may appear anywhere
beneath the top floorplan.

The elaboration result must retain its explicit top instead of returning a
bare `Design` whose top is inferred from module order.

## Physical rectangle

Every generated floorplan definition declares exactly one rectangular macro
outline:

```rhombus
floorplan Macro(bit_width):
  size(width: um(bit_width * 5), height: um(20))
  // ports, instances, and wiring
```

`Length` is an exact nonnegative physical distance. The initial closed unit
surface is `nm(nonnegative_int)` and `um(nonnegative_int)`, both canonicalized
to an integer number of picometers so equality and later specialization keys
never depend on floating-point behavior. `size` additionally requires both
dimensions to be positive. Bare numbers and negative lengths are rejected;
zero is reserved for coordinate components.

The outline belongs to `FloorplanDefinition`, not an instance occurrence.
Stamping one definition repeatedly preserves one physical macro shape. A
different size requires a separately generated definition or, after strap
support exists, a distinct specialization. Per-instance size overrides are
not allowed.

The rectangle is implicitly anchored at `(0, 0)` and extends to
`(width, height)`. Bare RHDL circuits have no RFPL outline; wrap a circuit in a
floorplan to assign its physical macro boundary.

## Floorplan containment and coordinates

Every instance whose child is a `FloorplanDefinition` requires an explicit
lower-left coordinate relative to its parent floorplan:

```rhombus
def child = ChildFloorplan()
inst placed(child, at: (um(10), um(5)))
```

Coordinate components are nonnegative `Length` values, so `um(0)` and `nm(0)`
represent the parent origin while negative or unitless components are invalid.
The placed child rectangle must fit completely within the parent's rectangle.
Overlap between siblings, orientation, halos, and placement grids remain
deferred.

The top floorplan is the sole root exception. A second root-level floorplan is
invalid, as is generating a floorplan while an RHDL circuit body is active.
The whole-elaboration verifier independently rejects floorplan instances under
circuit modules and floorplan instances that bypass RFPL's coordinate-aware
`inst` form.

RHDL circuit instances inside a floorplan do not accept `at:`. They are logical
implementation children rather than independently placed RFPL macros; wrap a
circuit in a floorplan when it needs a physical rectangle and coordinate.

## Ports and wiring

The initial cut reuses RHDL hardware types and its `Value` versus `Place`
directionality:

- A floorplan input is a readable `Value`.
- A floorplan output is a driveable `Place`.
- A child input is a driveable instance-input `Place`.
- A child output is a readable instance-output `Value`.
- `<==` drives one place from one readable value.

Every connection requires exact hardware-type equality. There are no implicit
casts, extensions, truncations, packing conversions, or literal coercions.
Fanout is legal because one value may drive several distinct places. Every
place still has exactly one driver.

The narrowest initial implementation supports whole-value connections only.
Records, vectors, and frontend-defined port types may cross a floorplan as
whole values when their types are exactly equal, but field selection,
element selection, reconstruction, and partial aggregate driving are deferred
because they introduce non-alias IR operations or canonicalization machinery.

Clock and reset values are ordinary typed ports for RFPL. A floorplan may pass
them into a circuit instance explicitly. A floorplan does not establish an
ambient sequential domain and cannot contain registers.

An explicit `wire` is only an aliasing convenience. If included, its ultimate
source must be a floorplan input or child output, and it must disappear during
CIRCT lowering just as RHDL `rtl.wire` does. Direct port-to-port wiring is
sufficient for the first end-to-end example, so `wire` can be deferred if it
adds implementation surface without proving a need.

## Structural-only verification

The language surface is intentionally incapable of spelling logic, but that
is not the authority. Imported helpers or low-level implementation mistakes
must not be able to sneak logic into a floorplan module.

After each floorplan body is elaborated and before the definition is returned,
RFPL verifies that the module contains only this core operation subset:

- `rtl.input_port`
- `rtl.output_port`
- `rtl.instance`
- `rtl.drive`
- `rtl.wire`, if explicit wires are supported

All other opcodes are illegal in a floorplan module. In particular, reject:

- Sources such as `rtl.constant` and `rtl.dont_care`
- Arithmetic, bitwise, comparison, selection, decode, conversion, and
  aggregate construction or projection
- Registers and memories
- Verification and simulation effects
- Unknown or dynamically registered operations

The verifier checks only the floorplan module body. It does not recursively
reject logic inside an instantiated circuit module. It does verify that every
instance target is either:

- A floorplan definition registered in the current RFPL elaboration, or
- An RHDL circuit definition/module produced in the current shared design.

Ordinary RHDL `verify_design` remains authoritative for ownership, complete
driving, type legality, hierarchy cycles, and combinational cycles. RFPL's
structural verifier adds the no-logic and allowed-child-kind rules; it does not
duplicate the core verifier.

Structural verification errors use the rejected operation's source location
and explain that logic belongs in an RHDL child circuit. For example:

```text
Pair.rfpl:12: floorplan Pair cannot contain rtl.add;
define the operation in an RHDL circuit and instantiate that circuit
```

## CIRCT emission contract

The initial cut uses the existing RHDL CIRCT backend. Because a floorplan is
represented by an ordinary verified core module:

- Floorplan ports lower as `hw.module` ports.
- Floorplan and circuit children lower as `hw.instance`.
- Drives and alias wires do not emit standalone CIRCT operations.
- Floorplan outputs lower through `hw.output`.
- Circuit modules lower exactly as they do under RHDL today.

The emitted CIRCT module for a floorplan must contain no `comb`, `seq`,
`verif`, `sim`, memory, or behavioral `sv` operations. This property is checked
on the RFPL/core module before lowering and may also be asserted against the
emitted MLIR in integration tests.

No floorplan marker is required in CIRCT for the initial cut. The RFPL
elaboration result retains which modules are floorplans for source-level
inspection, including each definition's rectangle. Physical dimensions do not
become ports, constants, or logic, and placement coordinates remain in the
RFPL elaboration result, so neither changes CIRCT or Verilog output. Add a
CIRCT attribute, sidecar, or physical dialect only when a concrete downstream
consumer defines the contract.

## RHDL construction boundary

RFPL should reuse, not copy, the following RHDL semantics:

- Hardware types and exact type equality.
- Port and instance construction.
- `Value` and `Place` ownership.
- Exactly-one-driver verification.
- Hierarchy-cycle and combinational-cycle verification.
- Deterministic CIRCT module and instance emission.

RFPL must not import the curated RHDL language wholesale because that would
make logic forms available. Its implementation should depend on the smallest
structural construction surface possible.

The current frontend kernel already has the underlying circuit-definition,
port, instance, and connection machinery. During implementation, either:

1. Expose a small supported structural-construction module from the RHDL
   frontend, or
2. Let RFPL's implementation use a tightly enumerated set of kernel bindings
   and enforce that dependency in the boundary checker.

Prefer the first if it is a small extraction with a clear RHDL-independent
contract. Do not create a generic plugin or operation-policy framework merely
to implement RFPL.

RHDL's public `emit_circt(design)` may be reused without teaching the backend
about `FloorplanDefinition`. RFPL passes the shared verified core `Design`, not
its frontend wrappers, to the backend.

## Strap pins after the initial cut

The previously accepted meaning remains: a strap pin is a static RFPL input
that de-uniquifies an otherwise stamped/reused sub-floorplan. It is not a
power-grid strap and not a runtime CIRCT port.

Strap pins are deliberately the next language feature, not part of the first
vertical slice. The initial cut must nevertheless avoid closing off their
semantics:

- A floorplan object can already be instantiated more than once, producing
  multiple `hw.instance` operations targeting one `hw.module`.
- A future floorplan declaration may expose typed static `strap` ports.
- Strap values are bound at RFPL `inst` sites, not through `<==`.
- A binding selects a physical/module specialization before the instance is
  built.
- Different canonical strap bindings select different emitted `hw.module`
  definitions.
- Equal bindings for the same base floorplan object may share one
  specialization.
- Strap values never become CIRCT module ports and never enter RHDL logic.

The specialization key will be based on the base floorplan definition identity
and canonical strap bindings. A specialization may have its own rectangular
outline; two differently sized variants cannot remain instances of one
physical definition. The exact strap object model, allowed static types,
forwarding rules, and naming are specified when strap support begins. Do not
add a general physical IR as a prerequisite.

Use unambiguous names for later power distribution concepts:

- `strap` or `strap_pin`: static RFPL specialization input.
- `power_stripe` or `pdn_strap`: conductive power-grid geometry.
- `promoted_supply_pin`: terminal geometry derived from a power grid.

## Initial repository shape

The first implementation should remain small:

```text
rfpl/
  PLAN.md
  main.rkt                  #lang reader shim
  language.rhm              language composition
  frontend/
    foundation.rhm          floorplan, ports, inst, wiring, elaborate
    verify.rhm              structural-only module verification
  tests/
    structural-test.rhm
    run-negative.sh
    run-circt.sh
    invalid/
    support/
examples/
  rfpl/
    circuit-pair.rfpl
```

Add a separate RFPL core only when RFPL owns semantic objects that are not
thin wrappers around the RHDL core module. The initial implementation does not
need `rfpl/core/`, `rfpl/backend/`, a layer system, or a standard library.

Update the repository boundary checker when RFPL source exists. It should
enforce:

- RHDL does not import RFPL.
- RFPL does not import RHDL combinational, sequential, memory, verification,
  or simulation language layers.
- `.rfpl` is used for RFPL programs and fixtures.
- The reader shim is the only required `.rkt` file.

## Initial implementation sequence

### Milestone 1: one structural floorplan module — implemented

- Add `#lang rfpl` and the `floorplan` form.
- Reuse RHDL `Bits`, `Clock`, `Reset`, `input`, `output`, and exact `<==`
  semantics.
- Return a `FloorplanDefinition` around one core module.
- Require an RFPL floorplan as the explicit elaboration top.
- Emit a pass-through floorplan as one CIRCT `hw.module`.

### Milestone 2: circuit instances — implemented

- Add RFPL's `inst` form.
- Instantiate an imported RHDL circuit beneath a floorplan.
- Wire floorplan ports to child ports.
- Emit both modules through the existing CIRCT backend.
- Verify that logic appears only in the circuit module.

### Milestone 3: nested floorplans and stamping — implemented

- Allow a floorplan to instantiate another floorplan.
- Reuse one floorplan definition in multiple instance occurrences.
- Retain an explicit top and all floorplan-definition wrappers.
- Reject recursive hierarchy and foreign-design children through existing
  ownership verification.

### Milestone 4: hard no-logic boundary — implemented

- Add the structural operation whitelist.
- Add a representative imported-logic negative fixture; the closed whitelist
  rejects every other unrecognized operation by the same path.
- Confirm that an imported helper attempting to build logic in the active
  floorplan is rejected even when the operator is not exported by RFPL.
- Add dependency-boundary checks.

### Milestone 5: rectangular macro dimensions — implemented

- Require one `size(width: ..., height: ...)` declaration per floorplan.
- Represent dimensions as positive, exact, explicitly unit-bearing `Length`
  values.
- Retain one `RectOutline` on each `FloorplanDefinition`.
- Keep physical dimensions out of the logical RHDL IR and CIRCT output.
- Reject missing, duplicate, zero, negative, and unitless dimensions.

### Milestone 6: contained floorplan coordinates — implemented

- Permit only one top floorplan outside an active floorplan body.
- Require `inst child(definition, at: (x, y))` for floorplan children.
- Retain typed placement records in the RFPL elaboration result.
- Require nonnegative coordinates and complete containment in the parent
  rectangle.
- Reject floorplans under circuits and coordinate-less low-level instances in
  whole-elaboration verification.

### Milestone 7: strap-pin specialization

- Specify closed strap types and canonical equality.
- Bind straps at floorplan instance sites.
- Clone/specialize a stamped floorplan only when bindings require it.
- Emit distinct `hw.module` symbols for distinct specializations.
- Retain deterministic provenance explaining each de-uniquification.

Automatic placement and geometry beyond rectangular containment begin only
after Milestone 7 has a real example that requires them.

## Focused verification plan

The first six milestones require these checks:

- A pass-through floorplan emits one `hw.module` and direct `hw.output`.
- A floorplan containing one circuit emits one floorplan module, one circuit
  module, and one `hw.instance` in the floorplan.
- Reusing one child definition twice emits two instances targeting the same
  module symbol.
- A nested floorplan may itself contain circuit instances.
- Every floorplan retains one positive exact rectangular outline.
- Reused instances of one definition share that definition's rectangle.
- Host generator parameters may determine dimensions.
- Missing, duplicate, zero, negative, and unitless sizes fail.
- Every floorplan child instance has a nonnegative coordinate and fits within
  its parent rectangle.
- A second root floorplan, a floorplan generated or instantiated by a circuit,
  and a coordinate-less floorplan instance fail.
- Circuit instances reject RFPL coordinates.
- Floorplan inputs and child outputs are readable but not driveable.
- Floorplan outputs and child inputs are driveable and have exactly one
  driver.
- Missing, duplicate, cross-design, and wrong-type connections fail.
- A floorplan hierarchy cycle fails.
- Constants, arithmetic, muxes, casts, aggregate projection/construction,
  registers, memories, assertions, and simulation effects fail in a
  floorplan body.
- The same operations remain legal inside an instantiated RHDL circuit.
- A circuit cannot instantiate a `FloorplanDefinition`.
- Host `if` and `for` may generate structural instances and connections.
- A hardware value used as host control is rejected consistently with RHDL's
  staging rules.
- Repeated emission is deterministic.
- The CIRCT text for every floorplan module contains only `hw.instance` and
  `hw.output` operations after its signature.

Run the focused RFPL host tests and CIRCT fixture rather than the full RHDL
suite. Run RHDL frontend/backend tests only if shared construction or emission
code changes.

## Initial non-goals

The first cut does not include:

- Strap pins or module specialization.
- Nonrectangular outlines, shapes, layers, tracks, sites, technology grids, or
  unit conversion beyond exact `nm` and `um`.
- Automatic macro placement, sibling-overlap resolution, orientation, or
  standard-cell placement.
- Regions, blockages, halos, or pin placement constraints.
- Power domains or power distribution.
- DEF, LEF, OpenDB, or OpenROAD emission.
- A custom RFPL IR or CIRCT dialect.
- Timing, routing, clock-tree synthesis, or automatic pipelining.
- Logic construction or mutation.
- RHDL circuit deduplication.
- General physical/logical regrouping or flattening.

These are deferred capabilities, not implicit escape hatches. Raw backend text
must not be accepted as a substitute for missing RFPL semantics.

## Initial acceptance criteria

The initial cut is complete when one checked-in `.rfpl` example can:

- Define a top floorplan with typed ports.
- Declare one exact rectangular macro size for every floorplan definition.
- Instantiate at least one imported RHDL circuit.
- Instantiate a nested floorplan.
- Place every nested floorplan at an explicit contained coordinate.
- Stamp one child definition more than once.
- Wire all boundaries using exact-type connections.
- Elaborate to one shared verified RHDL core `Design` with an explicit RFPL
  top.
- Emit valid CIRCT in which every floorplan is an `hw.module` containing only
  `hw.instance` and `hw.output`, while circuit modules retain their logic.
- Fail with a source-located diagnostic when logic is attempted directly in a
  floorplan body.

If this requires a second hardware IR, backend-specific escape text, changes
to RHDL logic semantics, or a generic extension framework, the initial cut has
expanded beyond its intended boundary and should be simplified.
