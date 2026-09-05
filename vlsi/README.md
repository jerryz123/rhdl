<!-- Documents the reproducible Rhodium-to-GDS smoke flow for Double-Wide OpenFrame. -->

# Rhodium Double-Wide OpenFrame prototype

This directory exercises the smallest useful physical-design path: GPIO 0 enters
an Rhodium combinational leaf, the leaf inverts it, and GPIO 1 drives the result.
The other pads remain input-only. An inverter is used instead of a truly empty
module so synthesis and place-and-route must preserve a real Rhodium-derived cell.

The pinned `double_wide_openframe` submodule owns the padframe, wrapper footprint,
1216-pin DEF template, LibreLane/Nix tool versions, and final Magic cell-swap
script. This directory owns only the Rhodium leaf and its user-wrapper implementation.

```text
src/rhodium-top.rhdl
  -> Rhodium CIRCT MLIR
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

## Prototype SRAM mapping at the CIRCT boundary

The MiniSoC experiment keeps physical-memory knowledge outside Rhodium and the
SoC. Reusable occurrence selection, contract validation, tiling, and wrapper
generation live in the top-level [`sram/`](../sram/README.md) package. Sky130
macro data and models live in `sram/sky130/`, while this physical-design layer
owns the MiniSoC/Sky130 site policy at
`designs/mini-soc/sky130/sram-map.yaml`.

The policy maps the 4096 by 128-bit shared CHI RAM and both 256 by 64-bit RV64
L1 data arrays onto 36 installed 512 by 32-bit Sky130 SRAMs. The shared RAM
uses 32 instances at full capacity. Each 2 KiB direct-mapped cache uses two
width slices at half depth because the installed macro is only 32 bits wide,
so the design uses 68 KiB of the available 72 KiB macro capacity. The four
shallow tag and coherence-state arrays intentionally continue through CIRCT's
inferred-memory lowering. A JSON manifest records all seven decisions and
carries selected macro instances and physical collateral into later
floorplanning, PDN, and LVS work.

```sh
make -C sram test
make -C vlsi mini-soc-memory-map
make -C vlsi mini-soc-macro-rtl-check
make -C vlsi mini-soc-slang-check
make -C vlsi mini-soc-synth
```

The first target proves scoped and direct elaboration tops produce identical
policy-relative wrapper identities, checks unknown-site rejection, functionally
tests banking, width slicing and byte masking, and rejects unsupported port
contracts. The MiniSoC inventory also requires both L1 data arrays to remain
256 by 64-bit RV64-word memories and rejects the former line-wide shape. The
remaining targets lint the mixed
macro/inferred RTL against the generated wrapper and installed PDK SRAM model,
prove LibreLane can elaborate it through Slang, then run full Sky130 synthesis.
Both LibreLane targets require all 36 SRAM instances to survive. The fast check
uses LibreLane's elaborate-only synthesis mode and also rejects packed structs
in its emitted Yosys netlist; the full target checks the technology-mapped
netlist. The configuration also registers the macro's LEF, GDS, liberty,
Verilog, and SPICE views so later floorplanning and physical-verification work
can use the same definition.

Slang is the synthesis boundary rather than an RTL rewrite: CIRCT's packed
structs remain in `build/mini-soc/mini-soc.sv`, and LibreLane lowers them
directly while reading the generated RTL. The focused target stops after
`Yosys.Synthesis`; macro placement, power-grid hookup, routing, and signoff are
still separate work. Mapping the two cache data arrays avoids synthesizing
their bulk storage as standard-cell flops and muxes. The four remaining
metadata arrays are deliberately inferred because the only installed macro
would use at most 5.2 percent of its bits for any one of them. Use
`mini-soc-slang-check` for the quick frontend regression and `mini-soc-synth`
when a complete mapped netlist is needed.

Cycle-level validation of the same policy is owned by [`sim/`](sim/README.md):

```sh
make -C vlsi/sim smoke
```

That target reuses the technology-independent `sims/` SoCHarness and FESVR
stack, scopes the policy through the harness's `soc` instance, and runs the
existing MiniSoC smoke payload against the checked-in Sky130 functional SRAM
model.

## Run the focused LVS proof

The full OpenFrame wrapper contains roughly 32 mm2 of standard-cell rows. Filling
that area around a one-cell design would create millions of physical-only cells,
so the fast integration profile intentionally leaves tap, filler, and LVS steps
disabled. A separate 100 um by 100 um fixture hardens the same Rhodium-generated
inverter with normal SKY130 well taps and fillers, then requires Netgen LVS to
match:

```sh
make -C vlsi lvs-smoke
```

The target fails unless LibreLane runs LVS and Netgen reports a matching final
result. Its exported GDS is written to `build/lvs-views/gds/rhodium_lvs_smoke.gds`.
This gives the Rhodium-to-standard-cell flow a cheap physical-connectivity
regression without pretending that the sparse full-size wrapper is signoff
ready.

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
enable tap/endcap and filler insertion, enable wrapper LVS, cut standard-cell
rows around SRAMs and other macros, provide each macro's LVS model or matching
black-box declaration, restore the remaining physical-verification and
power-integrity checks, and run the harness precheck. The focused fixture proves
the tool path and well-tap fix, but it does not replace wrapper, padframe, or
post-integration LVS for the populated design.
