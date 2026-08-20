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
verifier, and backends must preserve. Optional derived facts and diagnostic
reports belong in `rhdl/analysis/`. Notation, organization, reusable host
descriptions, and authoring policy over existing operations belong in a
frontend layer or ordinary library.

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

A circuit declaration defines a parameterized module family. Calling it during
`elaborate` creates the selected specialization once and reuses that definition
for later calls with the same stable parameters:

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

The [`layers/clocking.rhm`](layers/clocking.rhm) layer builds on that explicit-
top seam and is included in the standard profile. Its
`elaborate_with_clocking` wrapper collects temporal environment declarations
from the root circuit, validates them after ordinary elaboration, and returns
the unchanged design together with its resolved clocking report.
`elaborate_with_cdc` additionally rejects unsafe clock-domain sampling unless
the first destination register carries structurally verified crossing
evidence.

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
generator call               cached module specialization
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

Circuit parameters are stable immutable host values. RHDL directly accepts
integers, Booleans, strings, symbols, recursively stable immutable lists, and
hardware-type descriptors. A user-defined immutable configuration implements
`CircuitParam`. Its default specialization equality is ordinary Rhombus `==`:
transparent immutable classes compare structurally, while opaque compiled
artifacts remain nominal:

```rhombus
class EngineConfig(lanes :: PosInt, width :: PosInt):
  implements CircuitParam
```

Override `same_circuit_param` only when a type needs semantic equality that
differs from `==`. An overridden comparison must be symmetric, deterministic,
and independent of mutable elaboration state. Mutable collections, ordinary
functions and closures, elaborated modules, circuit-bound hardware, and other
opaque values that do not implement `CircuitParam` are rejected.

Generator declarations accept positional and keyword bindings with ordinary
Rhombus annotations and default expressions. Ordinary and sync circuits share
the same parameter forms and host-value validation.

Annotate a generic hardware-type parameter as `T :: DataType`; annotate a
hardware value separately with the most specific hardware annotation its
operation accepts. This keeps elaboration-time type descriptors distinct from
runtime circuit values.

The elaboration-local specialization cache compares the circuit declaration
identity and its normalized positional and keyword argument values. Equivalent
calls share one definition; distinct parameter values receive deterministic
suffixes such as `Adder` and `Adder_1`. Parameters are not embedded into module
names, and the cache is not persisted across compiler runs. Active recursion
is rejected by generator identity.

Circuit bodies and parameter defaults must depend only on their parameters,
stable immutable captures, and local elaboration state. Local mutation used to
collect generated structure is valid; observing or modifying external mutable
state is not, because a cache hit does not execute the body again. A physical
or implementation variant that needs a distinct definition should carry an
explicit stable parameter naming that variant.

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
`Hardware.of(type)` directly. Use `Hardware.bits` only when a function accepts
`Bits` of any width, and `Hardware.packable` only when it accepts any packable
hardware `DataType`. Bare `Hardware` is reserved for operations that genuinely
accept arbitrary readable or driveable hardware entities without a data-type
constraint.

See [`../../examples/rhdl/host-parameters.rhdl`](../../examples/rhdl/host-parameters.rhdl)
and [`../../examples/rhdl/layered-adder.rhdl`](../../examples/rhdl/layered-adder.rhdl).

## Nested circuits and hierarchy

A circuit body may declare a private child generator that captures stable host
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
children; ordinary children never inherit a domain by port name or type. The
physical `clock` and `reset` ports are not source bindings in a `sync_circuit`
body. Use `reset_when(condition)` for a nested reset scope or an instance's
`~reset_when: condition` option to derive a child reset from the ambient one.
Explicit `~clock` and `~reset` controls remain available only outside an active
sync domain.

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
