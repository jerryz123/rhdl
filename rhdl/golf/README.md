<!-- Documents the implemented #lang rhdl/golf syntax-compression profile and its current limits. -->

# RHDL Golf

`#lang rhdl/golf` is an experimental syntax-compression profile over the
complete standard RHDL language. It shortens source without introducing a
second hardware model: every Golf form expands to ordinary RHDL and reaches the
same elaboration kernel, public IR, verifier, and CIRCT backend.

Canonical RHDL remains available in a Golf module. Authors can mix compact and
standard forms and use ordinary Rhombus host computation unchanged.

## Quick start

```rhombus
#lang rhdl/golf

c Add(w)[a,b->sum:B(w)]=a+b

top Add(8)

export:
  design
```

A complete executable version with its generated-Verilog reference is in
[`examples/golf/adder.rhdl`](../../examples/golf/adder.rhdl).

This is equivalent to:

```rhombus
#lang rhdl

circuit Add(w):
  input a: Bits(w)
  input b: Bits(w)
  output sum: Bits(w)
  sum <== a + b

def design = elaborate(Add(8))

export:
  design
```

The current implementation verifies that the two forms produce identical
public IR and CIRCT MLIR.

## Current surface

### `B(width)`

`B(width)` is a transparent alias for `Bits(width)`. It works both as a type
value and as an exact hardware annotation:

```rhombus
def Byte = B(8)

c Pass()[value: Byte -> result: B(8)] = value
```

It creates no wrapper type and retains the normal `Bits` operators, casts,
selection behavior, and static information.

### `sel(selector, default, choices...)`

`sel` abbreviates a dense zero-based `mux_lookup`. Choice position supplies
the canonical key while the out-of-range result stays explicit:

```rhombus
sel(op,!a,a&b,a|||b,a^b,a+b,a-b)
```

This expands to keys `0` through `4` with `!a` as the default. It introduces
no new selection operation and retains ordinary `mux_lookup` type checking.

### Compact circuits

`c` abbreviates a standard combinational `circuit`. When every port has one
type, the preferred homogeneous form writes that type once:

```text
c Name(parameters...)[input,...->output:PortType]=expression
```

```rhombus
c A(w)[a,b->s:B(w)]=a+b
```

The final type applies to every input and the output. Width and type remain
explicit; only their repeated spelling is removed.

Typed groups are separated by commas. Each annotation closes the immediately
preceding names that do not yet have a type:

```text
c Name(parameters...)[input,...:Type,input,...:Type->output,...:Type,output,...:Type]=[expressions...]
```

```rhombus
c ALU(w)[a,b:B(w),op:B(3)->result:B(w),equal:Bool]=[sel(op,!a,a&b,a|||b),a===b]
```

The arrow appears exactly once. Either side may be empty. A bracketed body
positionally drives multiple outputs in their declared order and must contain
exactly one expression per output. An ordinary body remains available when
named drives communicate the structure better.

The ordinary-body form preserves explicit drives:

```rhombus
c Add(width)[a,b->sum:B(width)]:
  sum <== a + b
```

When the circuit has one output, an expression body drives that output
directly:

```rhombus
c Invert(width)[value->result:B(width)]=!value
```

The expression is parsed inside the generated circuit, so its input bindings
have the same scope and static information as canonical port declarations.
Generator parameters retain the complete standard `circuit` parameter grammar.

Compact synchronous circuits and compact interfaces are planned rather than
implemented.

### `top`

`top expression` abbreviates one ordinary elaboration binding:

```rhombus
top Add(8)
```

expands to:

```rhombus
def design = elaborate(Add(8))
```

`top` evaluates the circuit expression once. It does not infer a top from
source order, export the binding, invoke a backend, or generate Verilog.
Modules that expose the design use an ordinary explicit `export` declaration.

## Standard RHDL and libraries

Every binding exported by `#lang rhdl` is also exported by
`#lang rhdl/golf`. Changing only the language line of a standard RHDL module
must preserve its meaning.

Optional standard-library modules remain explicit imports:

```rhombus
#lang rhdl/golf

import:
  lib("rhdl/std/flow.rhdl") open
```

Golf does not copy or privately wrap standard-library components. Imported
types and helpers compose with canonical and compact forms through their normal
public RHDL interfaces.

## Semantic contract

Golf compresses spelling, not hardware rules:

- Types and boundary widths remain explicit.
- Host control remains distinct from hardware `when` and `switch`.
- State, clock/reset domains, hierarchy, and connection destinations remain
  explicit.
- Every place retains standard RHDL's one-driver rule.
- Golf adds no core operations, verifier rules, backend lowering, or implicit
  conversions.
- A hardware capability must exist in canonical RHDL before Golf may
  abbreviate it.

The full architecture, admission criteria, milestones, and deferred syntax are
defined in [`PLAN.md`](PLAN.md). [`COVERAGE.md`](COVERAGE.md) classifies every
core semantic group, frontend layer, and standard-library family by its Golf
mapping policy.

## Validation

Run the focused profile checks with a fresh `PLTCOMPILEDROOTS` as required by
the repository test policy:

```sh
make golf-test
```

The target checks package boundaries, standard-profile compatibility, verified
IR equivalence, exact CIRCT equivalence, and supported invalid Golf syntax.
