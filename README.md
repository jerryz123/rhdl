<!-- Project overview, setup instructions, and first-cut usage for RHDL. -->

# RHDL

RHDL is an experimental Rhombus-hosted hardware description system. The first
cut implements a small public hardware IR with explicit readable values,
driveable places, fixed-width bit vectors, primitive registers, module
instances, identity-based ownership, namespaced operation schemas,
verification, deterministic IR printing, and CIRCT lowering.

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
CIRCT MLIR, asks CIRCT to lower `seq` and export SystemVerilog, builds five
Verilator testbenches, and simulates:

- An 8-bit modular adder.
- A host-width-parameterized ALU covering bitwise logic, modular arithmetic,
  equality, and mux selection.
- A width-changing datapath covering concatenation, extraction, zero
  extension, and truncation.
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
SystemVerilog emitter; generated RTL is always produced by CIRCT. The frontend
language and rewriting API remain later milestones.
