<!-- Project overview, setup instructions, and first-cut usage for RHDL. -->

# RHDL

RHDL is an experimental Rhombus-hosted hardware description system. The first
cut implements a small public hardware IR with explicit readable values,
driveable places, fixed-width bit vectors, primitive registers, module
instances, identity-based ownership, namespaced operation schemas,
verification, deterministic IR printing, CIRCT lowering, and a narrow
`#lang rhdl` frontend covering the initial combinational, sequential, and
hierarchical design surface.

RHDL does not emit SystemVerilog. It lowers its public IR to CIRCT MLIR using
the `hw`, `comb`, and `seq` dialects. CIRCT then lowers sequential operations
and owns SystemVerilog export.

The architecture and staged roadmap are described in [PLAN.md](PLAN.md).

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
CIRCT MLIR, asks CIRCT to lower `seq` and export SystemVerilog, and runs five
Verilator simulations:

- An 8-bit modular adder.
- A host-width-parameterized ALU covering bitwise logic, modular arithmetic,
  equality, and mux selection.
- A width-changing datapath covering concatenation, extraction, zero
  extension, and truncation.
- An 8-bit counter with active-high synchronous reset.
- Two instances that explicitly reuse one adder module definition.

Validate the canonical frontend examples with:

```sh
make examples
```

The checkout itself is added as a Racket collection path when the frontend
example and tests run. To invoke a `.rhdl` file directly from the checkout:

```sh
racket -S "$(pwd)" examples/adder.rhdl
```

All canonical examples are `.rhdl` programs. Builder construction remains in
the tests only where the lower-level Builder or malformed public IR is itself
under test.

## Frontend

```rhombus
#lang rhdl

module Adder(width: Int):
  input:
    a: Bits(width)
    b: Bits(width)

  output:
    sum: Bits(width)

  result = a + b
  sum := result

elaborate(Adder(8))
```

The module exports the elaborated `design`, which can be inspected, printed,
or passed to `emit_circt`. Every generator call creates a fresh module
definition. The frontend accepts host-`Int` generator parameters, explicit
`Bits(width)` ports, named hardware expressions, output and instance-input
drives with `:=`, primitive registers through `reg`, module definitions and
instances, and instance/register field access. Frontend operations retain their
original path and line in `Location` and carry frontend-specific `Origin`
records.

The initial expression surface includes explicit-width constants, `not`,
`&`, `|`, `^`, `+`, `-`, `==`, `mux`, `concat`, `extract`, `zext`, and `trunc`.
Registers use `state = reg(Bits(width), clk, reset, reset_value)` and drive
next state through `state.next := value`. A reusable definition and instance
look like `Adder8 = Adder(8)` and `u0 = instance(Adder8)`; instance inputs and
outputs use fields such as `u0.a` and `u0.sum`.

General host forms remain deferred. Host conditionals are rejected in this
restricted frontend, with a specific diagnostic preventing hardware data from
controlling host elaboration.

## Builder API

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
`bit_xor`, `add`, `sub`, `eq`, `mux`, `concat`, `extract`, `zext`, and `trunc`.
All operands have explicit `Bits(width)` types. `eq` returns `Bits(1)`;
same-width logic and arithmetic preserve their data width; and width-changing
operations compute or require their result width explicitly.

`concat(module, [a, b, ...])` places the first operand in the most-significant
bits. `extract(module, value, high, low)` uses inclusive host-`Int` indices.
`zext` adds zeroes on the most-significant side, while `trunc` retains the
least-significant bits. Extension must be strictly wider and truncation must be
strictly narrower.

`emit_circt` is the backend boundary. The RHDL library has no direct
SystemVerilog emitter; generated RTL is always produced by CIRCT. Frontend
diagnostic hardening and the rewriting API remain later milestones.
