<!-- Project overview, setup instructions, and first-cut usage for RHDL. -->

# RHDL

RHDL is an experimental Rhombus-hosted hardware description system. The first
cut implements a small public hardware IR with explicit readable values,
driveable places, fixed-width bit vectors, native control types, extensible
flat data types, structural records, primitive registers, module instances,
identity-based ownership, namespaced operation schemas, verification,
deterministic IR printing, CIRCT lowering, and an embedded `#lang rhdl`
frontend with bundles and role-based interfaces built as layers over ordinary
Rhombus.

RHDL does not emit SystemVerilog. It lowers its public IR to CIRCT MLIR using
the `hw`, `comb`, and `seq` dialects. CIRCT then lowers sequential operations
and owns SystemVerilog export.

The architecture and staged roadmap are described in [PLAN.md](PLAN.md).

## Source layout

The implementation enforces one-way package boundaries:

```text
rhdl/main.rkt                 # #lang reader shim
rhdl/language.rhm             # language composition
rhdl/base/                    # minimal compositional #lang rhdl/base profile
rhdl/core/                    # IR, Builder, verification, and IR printing
rhdl/frontend/                # base, kernel, optional extensions, and standard aggregation
rhdl/backend/                 # CIRCT lowering
```

`.rhdl` is reserved for RHDL-profile programs and frontend fixtures, `.rhm`
contains Rhombus implementation and library modules, and `.rkt` is restricted
to the reader shims required by Racket collection lookup. `make
check-boundaries` rejects imports that violate the layer graph or profile
composition rules.

## Requirements

- Racket 9.2 or a compatible current release.
- The Rhombus package.
- CIRCT; the repository pins `firtool-1.155.0` for backend tests.
- Verilator for generated-hardware simulations.

On a Homebrew-based macOS setup:

```sh
brew install minimal-racket
raco pkg install --auto rhombus
```

On Apple Silicon macOS, install the pinned CIRCT release into the ignored
`.tools` directory with:

```sh
make setup-circt
```

On another platform, install CIRCT separately and set `CIRCT_OPT` to the path
of `circt-opt` when running the tests.

## Run the tests

```sh
make test
```

This runs the Rhombus unit and negative-verification tests, emits and verifies
CIRCT MLIR, asks CIRCT to lower `seq` and export SystemVerilog, and runs seven
Verilator simulations:

- An 8-bit modular adder.
- A host-width-parameterized ALU covering bitwise logic, modular arithmetic,
  equality, and mux selection.
- A width-changing datapath covering concatenation, extraction, zero
  extension, and truncation.
- An 8-bit counter with active-high synchronous reset.
- Two instances that explicitly reuse one adder module definition.
- A record-valued mux and synchronous-reset register.
- Both directions of a ready-valid interface adapter.

Validate the canonical frontend examples with:

```sh
make examples
```

The checkout itself is added as a Racket collection path when the frontend
example and tests run. To invoke a `.rhdl` file directly from the checkout:

```sh
racket -S "$(pwd)" examples/lop/adder-standard.rhdl
```

All valid frontend programs used by the test suite live under `examples/`.
Feature examples export reusable circuit generators and a default elaborated
`design`, so tests can re-elaborate the same source with different host
parameters. The intentional `examples/lop/` equivalence ladder instead shows
the same adder through the core Builder, elaboration kernel, explicitly
composed base profile, and standard profile.
Intentionally invalid `.rhdl` fixtures live under `tests/frontend/invalid/`.
Tests mirror the implementation layers under `tests/core/`, `tests/frontend/`,
and `tests/backend/`. Outside the LOP ladder, Builder construction remains only
where the lower-level Builder or malformed public IR is itself under test.

## Language-oriented walkthrough

The examples are organized as an executable argument for language-oriented
hardware design. Start with [the examples guide](examples/README.md), which
places four equivalent adders side by side:

- Direct public IR construction through `Design` and `Builder`.
- Explicit construction through the context-based elaboration kernel.
- Explicit composition of `#lang rhdl/base` with combinational syntax.
- Concise construction through standard macros and operators.

`make lop-test` verifies that the four adder programs produce identical
printed RHDL IR and identical CIRCT MLIR. It also checks equivalence pairs for
an explicit record circuit versus concise bundles, and explicit directional
record ports versus role-based interfaces. The remaining examples each focus
on one extension boundary.

## Frontend

RHDL provides two language profiles. `#lang rhdl` is the curated standard
profile used by normal designs. `#lang rhdl/base` provides only circuit and
port declarations, connections, elaboration, `Bits`, `Clock`, `Reset`, and the
guarded host `if`; programs add existing syntax through explicit imports:

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

The importable optional modules are `extensions/comb.rhm`,
`extensions/bool.rhm`, `extensions/bundle.rhm`, `extensions/interface.rhm`,
`extensions/sequential.rhm`, and `extensions/hierarchy.rhm`.
`frontend/standard.rhm` aggregates them with `frontend/base.rhm`. The public
core Builder and raw elaboration kernel are deliberately not in either
language profile; lower-level code imports `rhdl/core/main.rhm` or
`rhdl/frontend/kernel.rhm` explicitly.

```rhombus
#lang rhdl

circuit Adder(width):
  input(a, b): Bits(width)
  output sum: Bits(width)
  sum <== a + b

def design = elaborate(Adder(8))

export:
  design
```

Every circuit call creates a fresh module definition. Circuit parameters are
host `Int` values, while ports and hardware values use explicit hardware
types. `input a: Bits(width)` and `output y: Bits(width)` derive hardware names
from their bindings; parentheses group same-typed ports, as in
`input(a, b): Bits(width)`. Outputs, instance inputs, and register next state
are connected with `<==`. Standard-layer registers derive their hardware names
from bindings:

```rhombus
reg state(Bits(width), ~clock: clk, ~reset: reset, ~init: zero)
```

The resetless form is `reg state(Bits(width), ~clock: clk)`. Here `~init`
means the active synchronous-reset value; it does not introduce a separate IR
initialization mechanism. The underlying kernel form remains
`reg("state", Bits(width), clk, reset, reset_value)`, where `clk` is `Clock`
and `reset` is `Reset`. Standard-layer instances similarly derive their name
from the binding and expose child ports through dot access:

```rhombus
inst u0(child_definition)
u0.a <== a
sum <== u0.sum
```

This expands to the kernel's `inst("u0", child_definition)`,
`u0.input("a")`, and `u0.output("sum")` operations. Port direction and type
checking still use the elaborated child-module interface.

Core records are structural `DataType` values and therefore work with ports,
instances, muxes, and registers. The bundle extension supplies concise type
declarations, construction, and field access:

```rhombus
bundle Pair(T):
  left: T
  right: T

input source: Pair(Bits(width))
output result: Pair(Bits(width))
result.left <== source.right
result.right <== source.left
```

Complete field-wise drives canonicalize to `rtl.record_create` followed by one
whole-record drive. Partial field assignment and mixing whole-record with
field-wise assignment are errors. The generic `record(T): ...` form constructs
a record value explicitly.

Interfaces remain a frontend protocol abstraction over directional
record-typed ports. Roles and flows are explicit; there is no `Flipped` type
operation:

```rhombus
interface ReadyValid(T):
  role producer
  role consumer
  producer -> consumer:
    valid: Bool
    bits: T
  consumer -> producer:
    ready: Bool

interface tx(ReadyValid(Bits(width)), ~role: producer)
```

`left <=> right` atomically connects every flow when the interface types and
the two endpoint views have compatible directions. Interface metadata is
retained by the frontend so `instance.endpoint.field` reconstructs the same
logical protocol without inferring it from flattened names.

The embedded surface includes `+`, `-`, `&`, `^`, `and`, `or`, `xor`, `not`,
and `===`, plus the named functions `bits`, `bit_not`, `bit_and`, `bit_or`,
`bit_xor`, `hw_add`, `hw_sub`, `hw_eq`, `mux`, `mux_lookup`, `concat`,
`extract`, `zext`, and `trunc`. `bits(value, ~width: width)` is the concise
standard-layer spelling of the kernel's `literal(Bits(width), value)`.
`mux_lookup(selector, ~default: value)` constructs a canonical N-way lookup
from unique host-`Int` keys. Binary `mux` requires a `Bool`
selector and becomes a one-case `rtl.mux_lookup`; there is no binary mux IR
operation. `Bool` is supplied by the standard frontend as a nominal,
one-bit `BitwiseType`; it is not hard-coded into core. Kernel-level constants
remain available as `literal(Bits(width), integer)`. Explicit function forms
accept an optional IR name, while operator-produced temporary values receive
deterministic generated names.

```rhombus
result <== mux_lookup(op, ~default: not a):
  0: a and b
  1: a or b
  2: a xor b
  3: a + b
  4: a - b
```

Module bodies are ordinary Rhombus. Host functions, imports, collections,
`if`, and iteration can decide generated structure; a hardware value used as
an `if` condition is rejected. The `circuit`, `elaborate`, and operator forms
are macros or bindings layered over an importable elaboration kernel—not cases
in a private source parser.

An ordinary Rhombus library can define reusable hardware construction:

```rhombus
#lang rhombus

import:
  lib("rhdl/frontend/extensions/comb.rhm") open

fun add_pair(left, right):
  left + right
```

The complete library-and-circuit example is
`examples/add-pair.rhm` plus `examples/layered-adder.rhdl`. Importing that
library from a `.rhdl` program requires no changes to the RHDL reader, IR,
verifier, or backend. The circuit uses host recursion and a host `stages`
parameter to generate repeated hardware while a `Bool` `bypass` input
selects runtime hardware behavior. Higher-level conveniences such as grouped
`IO`, `RegInit`, and pipeline generators should follow this same layering
rule. Bundles and interfaces are concrete examples: records provide the core
semantics, while declaration syntax, roles, bulk connection, and instance
reconstruction live in frontend extensions.

The four adder presentations make their dependencies explicit. The core and
kernel versions are ordinary Rhombus modules with direct imports, the composed
version uses `#lang rhdl/base` plus `frontend/extensions/comb.rhm`, and the
standard version uses `#lang rhdl`. They lower to the same public IR.

## Builder API

The core API is exported by `rhdl/core/main.rhm`; CIRCT emission is a separate
backend API exported by `rhdl/backend/circt.rhm`.

```text
design = Design()
builder = Builder(design)
module_def = builder.module("Adder8")

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

The initial combinational Builder methods are `bit_not`, `bit_and`, `bit_or`,
`bit_xor`, `add`, `sub`, `eq`, `mux_lookup`, `record_create`, `record_get`,
`reinterpret`, `concat`, `extract`, `zext`, and `trunc`. Core equality compares same-width `Bits` operands and
returns `Bits(1)`. Same-type bitwise operations accept any `BitwiseType` and
preserve that type; arithmetic remains specific to `Bits`. Width-changing
operations compute or require their result width explicitly. Mux lookup values
and register state may use any `DataType` when their types satisfy
`type_equal`; core mux selectors are `Bits` values. Register clocks use
`Clock`, and synchronous resets use `Reset`.

The Boolean frontend module defines `Bool` outside core and layers Boolean
equality and binary `mux` over those primitives: `===` explicitly reinterprets the
one-bit equality result as `Bool`, while binary `mux` reinterprets its `Bool`
selector as `Bits(1)` before constructing `rtl.mux_lookup`. `reinterpret`
permits an explicit representation-transparent crossing between equal-width
`FlatDataType` implementations. The CIRCT backend lowers any `FlatDataType`
through its declared bit width, so extension-defined scalar types such as
`Bool` require no backend case. Core `RecordType` lowers recursively to
CIRCT `hw.struct`; construction and projection lower to `hw.struct_create`
and `hw.struct_extract`.

`concat(module, [a, b, ...])` places the first operand in the most-significant
bits. `extract(module, value, high, low)` uses inclusive host-`Int` indices.
`zext` adds zeroes on the most-significant side, while `trunc` retains the
least-significant bits. Extension must be strictly wider and truncation must be
strictly narrower.

`emit_circt` is the backend boundary. The RHDL library has no direct
SystemVerilog emitter; generated RTL is always produced by CIRCT. Frontend
diagnostic hardening remains the next phase; an IR rewriting API is deferred
until a concrete transformation use case justifies it.
