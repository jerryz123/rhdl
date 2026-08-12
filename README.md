<!-- Project overview, setup instructions, and first-cut usage for RHDL. -->

# RHDL

RHDL is an experimental Rhombus-hosted hardware description system. The first
cut implements a small public hardware IR with explicit readable values,
driveable places, fixed-width bit vectors, primitive registers, module
instances, verification, deterministic IR printing, and a validation-oriented
SystemVerilog emitter.

The architecture and staged roadmap are described in [PLAN.md](PLAN.md).

## Requirements

- Racket 9.2 or a compatible current release.
- The Rhombus package.
- Verilator for generated-hardware simulations.

On a Homebrew-based macOS setup:

```sh
brew install minimal-racket
raco pkg install --auto rhombus
```

## Run the tests

```sh
make test
```

This runs the Rhombus unit and negative-verification tests, emits
SystemVerilog, builds three Verilator testbenches, and simulates:

- An 8-bit modular adder.
- An 8-bit counter with active-high synchronous reset.
- Two instances that explicitly reuse one adder module definition.

Run the readable examples with:

```sh
make examples
```

## First-cut API

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
emit_systemverilog(design)
```

The direct SystemVerilog emitter is validation scaffolding for this first cut,
not the final backend decision. The frontend language, richer operations,
rewriting API, and CIRCT lowering remain later milestones.
