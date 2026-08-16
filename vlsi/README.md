<!-- Documents the reproducible RHDL-to-GDS smoke flow for Double-Wide OpenFrame. -->

# RHDL Double-Wide OpenFrame prototype

This directory exercises the smallest useful physical-design path: GPIO 0 enters
an RHDL combinational leaf, the leaf inverts it, and GPIO 1 drives the result.
The other pads remain input-only. An inverter is used instead of a truly empty
module so synthesis and place-and-route must preserve a real RHDL-derived cell.

The pinned `double_wide_openframe` submodule owns the padframe, wrapper footprint,
1216-pin DEF template, LibreLane/Nix tool versions, and final Magic cell-swap
script. This directory owns only the RHDL leaf and its user-wrapper implementation.

```text
src/rhdl-top.rhdl
  -> RHDL CIRCT MLIR
  -> synthesizable SystemVerilog leaf
  -> double_wide_openframe_project_wrapper
  -> LibreLane wrapper GDS
  -> Magic cell-swap into the pinned padframe GDS
```

## Bring up and check RTL

Initialize the harness after cloning the parent repository:

```sh
git submodule update --init --recursive
make -C vlsi setup-circt
make -C vlsi rtl-check
```

The CIRCT setup is only needed when the repository-local tool is absent.
`CIRCT_OPT=/path/to/circt-opt` can instead select an existing installation.
The check regenerates the leaf RTL, verifies the wrapper header and pin-template
contract against the submodule, and lints the complete wrapper with Verilator.

## Produce and integrate GDS

The harness flake pins LibreLane 3.1.0.dev2 and its matching Sky130 PDK commit.
With Nix installed, prepare the PDK once and run the complete flow:

```sh
make -C vlsi enable-pdk
make -C vlsi gds
```

If `librelane`, `ciel`, and `magic` are already on `PATH`, the same targets use
them directly. Otherwise they automatically enter the harness's Nix shell.
For a standard multi-user Nix install, the Makefile also finds
`/nix/var/nix/profiles/default/bin/nix` when shell initialization has not added
Nix to `PATH`. The harness's FOSSi binary cache requires a trusted Nix user;
without that system setting, the first invocation builds the toolchain locally
and can take substantially longer, while later runs reuse the Nix store.
Generated artifacts stay under `vlsi/build/`; the final files are:

- `build/views/gds/double_wide_openframe_project_wrapper.gds`: hardened user area
- `build/integrated/double_wide_openframe.gds`: user area cell-swapped into the full padframe

This is an integration smoke test, not tapeout signoff. Like the upstream sparse
example, it skips tap/fill insertion, in-flow DRC/LVS, and IR-drop analysis to
keep a one-cell design tractable in the 32 mm2 footprint. A real design must
restore physical-verification and power-integrity checks and run the harness
precheck.
