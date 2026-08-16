<!-- Documents CIRCT fixtures, Verilator simulations, and example-owned Verilog goldens. -->

# Backend tests

Backend unit tests exercise RHDL-to-CIRCT lowering without invoking external
tools. [`run-circt.sh`](run-circt.sh) owns the external pipeline:

```text
example design
    -> RHDL CIRCT MLIR
    -> circt-opt verification and lowering
    -> ExportVerilog
    -> exact golden comparison
    -> optional Verilator testbench
```

Run every external fixture with `make circt-test`, or select one:

```sh
FIXTURE=bundle bash tests/backend/run-circt.sh
```

The fixture manifest in `run-circt.sh` is authoritative; this document does
not duplicate its evolving list.

## Verilog references

Each concrete example design exports a colocated Verilog string. The canonical
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

Exact references belong to the CIRCT version pinned by
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
They are parsed and verified by CIRCT; fixtures with a matching testbench are
also simulated.
