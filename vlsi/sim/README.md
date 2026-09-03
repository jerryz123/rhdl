<!-- Documents cycle-level simulation after design- and technology-specific SRAM mapping. -->

# Mapped VLSI simulation

This directory builds the repository's normal FESVR `SoCHarness` after applying
the same SRAM site policy used by physical implementation. It is intentionally
mapped-only: the technology-independent inferred-memory simulator remains in
[`../../sims/`](../../sims/README.md).

```text
socs/simple-soc.rhdl
  -> sims/soc-harness.rhdl and the existing FESVR requester
  -> CIRCT flattening under SoCHarness
  -> SimpleSoC-relative policy, scoped through instance `soc`
  -> mixed mapped/inferred RTL
  -> generated SRAM adapters plus Sky130 functional model
  -> existing sims/TestDriver.v and FESVR Verilator bridge
```

The flow reuses the SoC harness, test driver, host transport, Verilator bridge,
and smoke payload from `sims/`; it does not copy simulator logic into the VLSI
layer. The SimpleSoC/Sky130 policy lives at
`../designs/simple-soc/sky130/sram-map.yaml`, because site selection belongs to
that design-and-technology pairing. Generic mapping mechanics live in
`../../sram/`, and Sky130 catalog/model data live in `../../sram/sky130/`.

Install the shared FESVR dependency once, then build or exercise the mapped
simulator:

```sh
make -C vlsi/sim setup
make -C vlsi/sim mapping
make -C vlsi/sim simulator
make -C vlsi/sim smoke
make -C vlsi/sim run BINARY=/absolute/path/to/program.elf
```

`SOC=simple` and `TECH=sky130` are the only supported pair today; other values
fail explicitly. Generated MLIR, RTL, manifests, and Verilator objects live
under `vlsi/build/sim/simple/sky130/`. The mapped simulation uses checked-in
zero-delay functional SRAM models. Those models establish logical cycle
behavior only and are not substitutes for PDK timing or signoff views.
