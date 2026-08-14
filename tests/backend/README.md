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

Each public feature example exports a `verilog_reference` string beside its
canonical `design`. The backend lowers the design with the pinned CIRCT
toolchain, removes generated-version and temporary-location noise, and compares
the complete SystemVerilog output exactly:

```sh
make verilog-golden-test
```

Intentional output changes can be recorded with:

```sh
make update-verilog-goldens
```

Review the resulting example-file diff normally. `FIXTURE=name` limits both
commands to one fixture.

SystemVerilog testbenches remain under [`verilog/`](verilog/). They verify
behavior rather than textual output. A same-base-name `*_dpi.cpp` file is
linked automatically when a fixture exercises DPI-C.

## Additional MLIR fixtures

`emit-*.rhm` modules cover backend shapes that are not owned by one canonical
example, including nested and hierarchical aggregates and aggregate memories.
They are parsed and verified by CIRCT; fixtures with a matching testbench are
also simulated.
