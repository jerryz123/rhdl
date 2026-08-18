<!-- Documents RHDL's mirrored test organization and focused verification commands. -->

# RHDL tests

Tests mirror the implementation boundaries:

| Directory | Scope |
|---|---|
| [`core/`](core/) | Backend-independent types, IR construction, verification, and primitive semantics |
| [`analysis/`](analysis/) | Optional backend-independent analyses over completed core IR |
| [`frontend/`](frontend/) | Language profiles, layers, elaboration, examples, and invalid frontend uses |
| [`backend/`](backend/README.md) | CIRCT text, ExportVerilog goldens, and Verilator simulations |
| [`formal/`](formal/) | Optional Rosette semantics, equivalence queries, counterexamples, and unsupported cases |
| [`emacs/`](emacs/) | Project-aware `rhdl-mode` dispatch and Racket back-end configuration |
| [`fesvr/`](fesvr/) | Assertions and target programs for the FESVR simulation SoC |

Domain-library tests live with their owning packages, including
[`../tilelink/tests/`](../tilelink/tests/) and [`../chi/tests/`](../chi/tests/).

Valid canonical authoring programs live under [`../examples/`](../examples/README.md).
Intentional language failures live under `frontend/invalid/` and are exercised
by `frontend/run-negative.sh`.

Successful programs remain under `frontend/` only when their small, test-shaped
form isolates a profile boundary, diagnostic, or exact IR property that a
canonical example does not. Frontend tests should import an example directly
when it already demonstrates the supported behavior under test.

## Focused commands

Run the minimum target that covers a change:

```sh
make check-boundaries       # package, dependency, and file-type rules
make analysis-test          # optional analyses over completed core IR
make examples               # all canonical example modules
make examples-rhdl          # built-in language examples only
make examples-std           # standard-library examples only
make examples-noc           # NoC hardware examples only
make examples-lop           # abstraction-level comparisons only
make examples-golf          # compact Golf examples only
make examples-rfpl          # logical and physical RFPL examples only
make examples-tilelink      # TileLink domain examples only
make lop-test               # equivalence across authoring layers
make golf-test              # compact Golf syntax, diagnostics, and profile equivalence
make riscv-test             # pure RISC-V model and instruction catalogs
make ridx-test              # finite structural index-space model
make tilelink-test          # TileLink boundaries, monitored links, RAM, and invalid uses
make chi-test               # CHI boundaries, flits, links, and invalid connections
make ricket-host-test       # Ricket core and reusable ALU host checks
make ricket-test            # host checks plus external ALU simulation
make frontend-test          # core and frontend tests, including invalid uses
make backend-test           # textual CIRCT lowering; decode tests require Espresso
make formal-test            # Rosette combinational equivalence and counterexample checks
make rfpl-test              # structural RFPL semantics and invalid uses
make rfpl-circt-test        # RFPL CIRCT and example-owned Verilog golden
make unit-test              # frontend plus backend Rhombus tests
make emacs-test             # project-aware Emacs mode integration helpers
make noc-test               # pure host-side NoC model and its package boundary
make riscv-test             # pure RISC-V model, decode, and package boundaries
make host-checks            # host and model checks without the explicit example sweep
make host-test              # unit tests, examples, models, protocols, and cores
make circt-test             # curated CIRCT, golden, and Verilator integration spine
make circt-verify-test      # curated CIRCT lowering without simulation
make verilator-test         # curated behavioral SystemVerilog simulations
make verilog-golden-test    # every exact example-owned SystemVerilog reference
make circt-full-test        # comprehensive goldens and available simulations
make test                   # complete host and CIRCT suite
```

The standalone FESVR transport has its own setup, native test, and DPI compile
checks in [`../sim/fesvr/`](../sim/fesvr/README.md). CI also elaborates and
simulates its generated stub SoC in an independent external-toolchain job.

Pull-request CI classifies changed paths into parallel host, example, and CIRCT
matrices. Unknown executable paths fail closed by selecting every job; only
documentation and the explicitly non-CI Emacs and VLSI trees select no job. A
manual workflow dispatch selects every matrix shard, including comprehensive
CIRCT fixture groups instead of only the curated local integration spine.

Use `FIXTURE=name` with `tests/backend/run-circt.sh` to select one external
backend fixture, or space-separated `FIXTURES` to batch several. Update
Verilog references only when backend output changes intentionally.

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
