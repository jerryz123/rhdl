<!-- Documents executable SoC harnesses, host models, and simulator bindings. -->

# Simulation harnesses

The executable simulation stack follows a Chipyard-like ownership boundary:

```text
TestDriver.v -> soc-harness.rhdl -> SimpleSoC or TiledSoC
                    |
                    +-> FESVR host model
```

`TestDriver.v` only generates clock and reset and observes the harness exit
status. `soc-harness.rhdl` specializes at elaboration time for one SoC,
instantiates the FESVR requester, and connects it to that SoC's common
`SoCHostInterface`. The SoCs contain no DPI calls or simulator dependencies.

The directory owns:

- `fesvr/`: the simulator-independent direct-memory FESVR transport and its
  Rhodium CHI requester.
- `verilator/`: the Verilator VPI/DPI binding.
- `tests/`: structural checks for both harness specializations.

Install the pinned FESVR dependency and build either reusable simulator with:

```sh
make -C sims setup
make -C sims simulator SOC=simple
make -C sims simulator SOC=tiled
```

`SOC` accepts `simple` or `tiled` and defaults to `simple`. Each specialization
has an independent artifact at `/tmp/rhodium-sims/<soc>/obj/VTestDriver`, so
switching configurations cannot reuse generated RTL for the other SoC. Set
`BUILD_ROOT` when a different artifact root is required. Building a simulator
does not require or embed a target program.

The Makefile passes `SOC` unchanged to the single `emit-soc-harness.rhm`
entrypoint. `soc-harness.rhdl` owns the `SimulationSoC` host enum, validates
the name, and elaborates only the selected SoC and its matching FESVR wiring.

Run any FESVR-compatible target binary through the already-built simulator
with:

```sh
make -C sims run SOC=simple BINARY=/absolute/path/to/program.elf
make -C sims run SOC=tiled BINARY=/absolute/path/to/program.elf
```

`HTIF_ARGS` places optional FESVR host arguments before the target binary, and
`TARGET_ARGS` places arguments after it. The simulator passes this process
argument vector through VPI to `DirectMemoryHtif`; FESVR owns ELF parsing,
segment loading, entry-point discovery, `tohost`/`fromhost` polling, and exit
status. The Makefile and RTL do not implement a separate binary loader.

Run the genuine execution smoke, focused structural checks, and tiled lowering
with:

```sh
make -C sims smoke SOC=simple
make -C sims smoke SOC=tiled
make -C sims dpi-compile-check \
  VERILATOR_ROOT="$(verilator -V | sed -n 's/^ *VERILATOR_ROOT *= *//p' | head -1)"
make -C sims elaboration-test
make -C sims tiled-lowering-test
```

The smoke starts with `tohost` cleared, executes RV64I instructions on RV5Stage,
stores the passing value into a dirty L1D line, and succeeds only after the
coherent FESVR requester observes that write. It uses the same `run` path as an
external target binary.

These simulators always use CIRCT-inferred memories. To validate a
design-and-technology SRAM mapping while reusing this harness, driver, FESVR
transport, and smoke payload, run `make -C vlsi/sim smoke`; see the
[`vlsi/sim` guide](../vlsi/sim/README.md). Keeping mapped simulation there
prevents technology policy from entering this package or the SoCs.

`DirectMemoryHtif` presents FESVR's abstract memory chunks as one-outstanding,
aligned 32-bit transactions. Target XLEN may be 32 or 64; addresses and entry
points remain 64-bit. `FesvrRequester` is a non-caching RN-F: it converts those
private ready-valid DPI signals into coherent CHI `ReadClean` and
`WriteUniquePtl` transactions and reports Invalid for every snoop. Consequently
ELF loading and `tohost`/`fromhost` polling observe dirty RV5Stage cache lines
without reserving a special mailbox address range.
