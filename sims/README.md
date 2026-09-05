<!-- Documents executable SoC harnesses, host models, and simulator bindings. -->

# Simulation harnesses

The executable simulation stack follows a Chipyard-like ownership boundary:

```text
TestDriver.v -> <soc>-soc-harness.rhdl -> one SoC variant
                         |
                         +-> FESVR host model
```

`TestDriver.v` only generates clock and reset and observes the harness exit
status. Each SoC has a separate parameterless harness that instantiates the
FESVR requester and connects it to that SoC's common `SoCHostInterface`. The
SoCs contain no DPI calls or simulator dependencies.

The directory owns:

- `fesvr/`: the simulator-independent direct-memory FESVR transport and its
  Rhodium CHI requester.
- `verilator/`: the Verilator VPI/DPI binding.
- `tests/`: independent structural checks for FESVR and each SoC harness.

Install the pinned FESVR dependency and build a reusable simulator with:

```sh
make -C sims setup
make -C sims simulator SOC=simple
make -C sims simulator SOC=mini
make -C sims simulator SOC=tiled
```

`SOC` accepts `simple`, `mini`, or `tiled` and defaults to `simple`. The
SimpleSoC harness attaches `CHIDPIMemory` to the SoC's exposed ready-valid SN-F
channels as a simulation-only external memory model. MiniSoC instead contains
its own synthesizable `CHIRam`. Each harness has an independent artifact at
`/tmp/rhodium-sims/<soc>/obj/VTestDriver`, so
switching configurations cannot reuse generated RTL for the other SoC. Set
`BUILD_ROOT` when a different artifact root is required. Building a simulator
does not require or embed a target program.

The SimpleSoC harness uses that SoC's default RV64D specialization. The MiniSoC
harness retains its fabric's integer-only default; TiledSoC also defaults to
integer-only operation and can select an FP profile explicitly.

The Makefile maps `SOC` to its harness module. A shared emitter dynamically
loads only that module's exported `design`, so unrelated SoCs are not imported
or elaborated. Every harness emits the same `SoCHarness` Verilog top contract,
so `TestDriver.v` remains shared; there is no Rhodium variant enum or conditional
harness circuit.

Run any FESVR-compatible target binary through the already-built simulator
with:

```sh
make -C sims run SOC=simple BINARY=/absolute/path/to/program.elf
make -C sims run SOC=mini BINARY=/absolute/path/to/program.elf
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
make -C sims smoke SOC=mini
make -C sims smoke SOC=tiled
make -C sims dpi-compile-check \
  VERILATOR_ROOT="$(verilator -V | sed -n 's/^ *VERILATOR_ROOT *= *//p' | head -1)"
make -C sims chi-dpi-memory-test \
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

The `chi-dpi-memory-test` convenience target independently compiles and
exercises the CHI-owned DPI model documented in the
[`chi/` package](../chi/README.md). The SimpleSoC harness instantiates that same
model behind the SoC's external memory boundary.
