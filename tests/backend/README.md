<!-- Documents CIRCT fixtures, Verilator simulations, and example-owned Verilog goldens. -->

# Backend tests

Backend unit tests exercise Rhodium-to-CIRCT lowering, including native sparse
CaseZ decode relations. [`run-circt.sh`](run-circt.sh) owns the external pipeline:

```text
example design
    -> Rhodium CIRCT MLIR
    -> circt-opt verification and lowering
    -> ExportVerilog
    -> exact golden comparison
    -> optional Verilator testbench
```

`make circt-test` runs a curated semantic spine across the external pipeline.
It covers each distinct lowering family without rebuilding every documented
frontend variation. Select one fixture explicitly with:

```sh
FIXTURE=bundle bash tests/backend/run-circt.sh
```

Use space-separated `FIXTURES` when one focused batch needs several fixtures;
they share one Rhombus materialization process.

The fixture manifest and curated integration set in `run-circt.sh` are
authoritative; this document does not duplicate their evolving lists.

The external stages are independently selectable:

```sh
make circt-verify-test     # curated CIRCT lowering without simulation
make verilator-test       # curated fixtures that own behavioral testbenches
make verilog-golden-test  # every example-owned exact Verilog reference
make circt-full-test      # comprehensive goldens and available simulations
```

## Verilog references

Each concrete example design still exports a colocated Verilog string. The canonical
`design` pairs with `verilog_reference`; another `*_design` pairs with the same
prefix followed by `*_verilog_reference`. `make examples` enforces references,
exports, and manifest coverage. The backend lowers each design with the pinned
CIRCT toolchain, removes generated-version and temporary-location noise, and
compares the complete SystemVerilog output exactly:

```sh
make verilog-golden-test
```

Intentional output changes can be recorded with:

```sh
make update-verilog-goldens
```

Review the resulting example-file diff normally. `FIXTURE=name` limits both
commands to one fixture.

The complete golden sweep is intentionally separate from the normal curated
integration path. Exact references belong to the CIRCT version pinned by
[`tools/install-circt.sh`](../../tools/install-circt.sh). When `make circt-test`
is run against another CIRCT version, such as tip of tree, the runner still
verifies lowering and executes every available Verilator testbench but skips
the version-specific text comparison. `make verilog-golden-test` requires the
pinned version so it cannot silently pass without checking the references.

SystemVerilog testbenches remain under [`verilog/`](verilog/). They verify
behavior rather than textual output. A same-base-name `*_dpi.cpp` file is
linked automatically when a fixture exercises DPI-C.

Verilator runs with assertion evaluation enabled. The assertion fixture also
runs a dedicated testbench that must fail and report its expected label, so
the suite checks reset suppression, branch suppression, and active failure.

## Additional MLIR fixtures

`emit-*.rhm` modules cover backend shapes that are not owned by one canonical
example, including nested and hierarchical aggregates and aggregate memories.
The curated integration set retains the distinct aggregate, assertion,
protocol, and processor shapes. `make circt-full-test` parses and lowers every
additional fixture; fixtures with a matching testbench are also simulated.
