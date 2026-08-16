<!-- Documents RHDL elaboration, public language profiles, and frontend extension boundaries. -->

# RHDL frontend

The frontend turns ordinary Rhombus computation and RHDL notation into the
single public core IR. Macro expansion is not a second hardware IR. The
package dependency contract is in [`../README.md`](../README.md); individual
features are documented in [`layers/README.md`](layers/README.md).

## One semantic core, layered languages

```text
#lang rhdl ------> standard ------> foundation + curated layers
#lang rhdl/base ------------------> foundation + selected layers
                                             |
                                             v
                                    elaboration kernel
                                             |
                                             v
                                       public core IR
```

The layers have separate responsibilities:

- [`kernel.rhm`](kernel.rhm) provides context-sensitive construction functions
  over the core.
- [`foundation.rhm`](foundation.rhm) defines circuits, ports, connections,
  elaboration, basic types, selection, and casts.
- [`support/`](support/) contains shared macro and static-information
  mechanisms, not selectable language profiles.
- [`layers/`](layers/README.md) contains independently selectable notation and
  abstractions over existing semantics.
- [`standard.rhm`](standard.rhm) only aggregates the foundation and curated
  layers for `#lang rhdl`.

A concept belongs in core when it introduces hardware semantics that the IR,
verifier, and backends must preserve. Notation, organization, reusable host
descriptions, and policy over existing operations belong in a frontend layer
or ordinary library.

## Language profiles

`#lang rhdl` is the normal curated profile. `#lang rhdl/base` exposes the
shared circuit boundary and lets a program select additional layers:

```rhombus
#lang rhdl/base

import:
  lib("rhdl/frontend/layers/comb.rhm") open

circuit Adder(width):
  input(a, b): Bits(width)
  output sum: Bits(width)
  sum <== a + b

def design = elaborate(Adder(8))
```

The base profile provides `circuit`, `elaborate`, ports, `<==`, `Bits`,
`Clock`, `Reset`, hardware selection, `.into`, and guarded host `if`. It does
not expose the public core Builder or raw kernel. The standard profile adds the
curated layers without changing the resulting IR.

Library code may use `hardware_value_type(value)` to recover the RHDL type of
caller-elaborated readable or driveable hardware without importing core IR
classes. Host values are rejected.

The four programs under [`../../examples/lop/`](../../examples/lop/) express
one adder through the public core, kernel, explicit base composition, and
standard profile. `make lop-test` checks that they produce identical public IR
and CIRCT representations.

## Circuits and elaboration

A circuit declaration defines a Rhombus generator. Calling it during
`elaborate` creates a fresh module definition:

```rhombus
circuit Passthrough(T):
  input source: T
  output result: T
  result <== source

def design = elaborate(Passthrough(Bits(8)))
```

Consumers that need a stable explicit top, such as RFPL physical annotation,
use `elaborate_with_top`:

```rhombus
def logical = elaborate_with_top(Passthrough(Bits(8)))
def design = logical.design
def top = logical.top
```

`elaborate` remains the concise compatibility form returning a bare `Design`.
`Module.find_instance(name)` provides stable direct-instance inspection; tools
must not infer the top or hierarchy from module-list positions.

Inputs are readable and cannot be driven. Outputs are driveable and become
readable after they are driven. Outputs, instance inputs, and register
next-state places use `<==`; every place has one effective driver.

Grouped ports share one explicit type:

```rhombus
input(a, b): Bits(width)
output(sum, carry): Bits(width)
```

Elaboration is deterministic host computation that constructs known-width
hardware. Host values determine which hardware exists but are not runtime
hardware data:

```text
HOST                         HARDWARE

Int                          Bits(width)
Boolean                      host value only
Bool                         runtime Boolean hardware data
if                           elaboration-time choice
when                         hardware conditional assignment
switch                       hardware exact-key conditional assignment
for over a host collection   repeated generated structure
generator call               fresh module definition
```

Host control retains ordinary Rhombus truthiness. A hardware value is a host
object and is therefore truthy, so using one wherever Rhombus asks for a truth
value—including `if`, `unless`, `cond`, host Boolean operators, and iteration
guards—tests the presence of that object; it never observes the value carried
by hardware at runtime. Use the hardware-only `when` and `switch` forms supplied
by the conditional layer for runtime control. `when` conditions must be one-bit
hardware values; `switch` selectors must be hardware values with supported
exact keys. Host values are rejected by both forms.

## Host parameters and helpers

Circuit parameters may be opaque host values such as numbers, strings,
symbols, collections, configuration objects, hardware-type descriptors,
functions, and closures. Circuit-bound `Value`, `Place`, `Register`,
`Instance`, and frontend hardware views are rejected as direct parameters.
The check is deliberately shallow; ordinary ownership verification catches
incompatible handles hidden in host containers or closures.

Generator declarations accept positional and keyword bindings with ordinary
Rhombus annotations and default expressions. Ordinary and sync circuits share
the same parameter forms and host-value validation.

Parameters are not serialized, hashed, compared, or embedded into module
names. Calling a generator creates a fresh definition, with deterministic
suffixes such as `Adder`, `Adder_1`, and `Adder_2`. Active recursion is
rejected by generator identity.

Ordinary host functions may accept hardware objects while elaborating,
inspect type descriptors, construct hardware, and return hardware to the
enclosing circuit. This is different from passing runtime hardware as a
circuit generator parameter:

```rhombus
fun low_word(value, width) :: Bits(width):
  value[0..width]
```

Exact hardware annotations retain field, indexing, casting, and lookup static
information. `Bits`, `SInt`, `Clock`, `Reset`, `Bool`, `Vec`, bundles, and
hardware enums provide concise annotation forms. Extension-produced types can use
`Hardware.of(type)` directly.

See [`../../examples/rhdl/host-parameters.rhdl`](../../examples/rhdl/host-parameters.rhdl)
and [`../../examples/rhdl/layered-adder.rhdl`](../../examples/rhdl/layered-adder.rhdl).

## Nested circuits and hierarchy

A circuit body may declare a private child generator that captures host
values, including parameters of the enclosing generator:

```rhombus
circuit Incrementer(width):
  input value_in: Bits(width)
  output value_out: Bits(width)

  circuit Increment():
    input value_in: Bits(width)
    output value_out: Bits(width)
    value_out <== value_in + bits(1, width)

  inst increment(Increment())
  increment.value_in <== value_in
  value_out <== increment.value_out
```

Calling the nested generator still materializes a separate module. Only host
values may be captured; parent hardware crosses the child boundary through
ports. An unused nested declaration emits no module.

A nested `sync_circuit` follows the same domain rules as any other synchronous
child. A sync parent propagates its ambient clock and reset only to marked sync
children; ordinary children never inherit a domain by port name or type.

See [`../../examples/rhdl/nested-circuit.rhdl`](../../examples/rhdl/nested-circuit.rhdl)
and the integrated host-specialization example
[`../../examples/rhdl/tiny-simd.rhdl`](../../examples/rhdl/tiny-simd.rhdl).

## Deferred host descriptions

The kernel supports deferred frontend values so layers can retain authoring
metadata until a hardware operation consumes it. Static literal shadows,
enum members, and other reusable host descriptions do not allocate IR merely
by being declared or passed as circuit parameters. Once consumed, they lower
to ordinary core values and operations.

Every `HardwareLiteral` reports its hardware type, packed width, and packed
host value. Ordinary public-surface libraries can therefore build typed static
abstractions—such as [`../std/decode/pattern.rhdl`](../std/decode/pattern.rhdl)—
without importing core or frontend implementation modules.

The static subtype distinguishes reusable descriptions from objects already
owned by an elaborated circuit. This is how extensions add types, literal
forms, mux keys, field access, and annotations without adding frontend-only
operations to the core IR.

## Extending RHDL

A useful construction abstraction can be an ordinary Rhombus function:

```rhombus
#lang rhombus

import:
  lib("rhdl/frontend/layers/comb.rhm") open

fun add_pair(left, right):
  left + right
```

Importing this function from a `.rhdl` program requires no reader, IR,
verifier, or backend change. Add a frontend layer when reusable syntax or
static information is required; add a core concept only when new hardware
semantics must survive elaboration.
