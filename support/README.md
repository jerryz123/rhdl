<!-- Documents shared fixtures used by repository-level executable simulations. -->

# Simulation support

This directory contains shared testbench artifacts that do not belong to a
protocol implementation or a particular SoC definition.

- `TestDriver.sv` clocks the FESVR-backed `SimpleSoC` and checks its entry
  handoff and HTIF exit.
- `direct_mem_htif_pass.S` and `direct_mem_htif_pass.ld` provide the inert RV64
  ELF used by both the direct FESVR transport test and the SimpleSoC end-to-end
  smoke.

The owning test workflows remain in [`fesvr/`](../fesvr/README.md) for the
transport unit test and [`socs/`](../socs/README.md) for system integration.
