<!-- Documents RHDL's mirrored test organization and focused verification commands. -->

# RHDL tests

Tests mirror the implementation boundaries:

| Directory | Scope |
|---|---|
| [`core/`](core/) | Backend-independent types, IR construction, verification, and primitive semantics |
| [`frontend/`](frontend/) | Language profiles, layers, elaboration, examples, and invalid frontend uses |
| [`backend/`](backend/README.md) | CIRCT text, ExportVerilog goldens, and Verilator simulations |
| [`emacs/`](emacs/) | Project-aware `rhdl-mode` dispatch and Racket back-end configuration |
| [`fesvr/`](fesvr/) | Assertions and target programs for the FESVR simulation SoC |

Valid canonical authoring programs live under [`../examples/`](../examples/README.md).
Intentional language failures live under `frontend/invalid/` and are exercised
by `frontend/run-negative.sh`.

## Focused commands

Run the minimum target that covers a change:

```sh
make check-boundaries       # package, dependency, and file-type rules
make examples               # all canonical example modules
make lop-test               # equivalence across authoring layers
make riscv-test             # pure RISC-V model and instruction catalogs
make rv64i-core-test        # concrete integer ALU controls and simulation
make frontend-test          # core and frontend tests, including invalid uses
make backend-test           # textual CIRCT lowering without external tools
make unit-test              # frontend plus backend Rhombus tests
make emacs-test             # project-aware Emacs mode integration helpers
make noc-test               # pure host-side NoC model and its package boundary
make riscv-test             # pure RISC-V model, decode, and package boundaries
make host-test              # unit tests, examples, NoC, and RISC-V
make circt-test             # CIRCT verification and Verilator simulation
make verilog-golden-test    # exact example-owned SystemVerilog references
make test                   # complete host and CIRCT suite
```

The standalone FESVR transport has its own setup, native test, and DPI compile
checks in [`../sim/fesvr/`](../sim/fesvr/README.md). CI runs those checks as an
independent external-toolchain job.

Use `FIXTURE=name` with `tests/backend/run-circt.sh` to select one external
backend fixture. Update Verilog references only when backend output changes
intentionally.

Generated Racket, CIRCT, SystemVerilog, and Verilator build output remains out
of version control.

## What to test

- Test supported behavior and invalid uses of supported features.
- Prefer semantic structure, opcodes, and types over generated temporary names.
- Use language-layer equivalence tests when syntax should lower to existing
  kernel or core meaning.
- Run `make check-boundaries` after moving modules or changing dependencies.
- Reserve the complete suite for cross-layer, shared-infrastructure, or
  backend-pipeline changes.
