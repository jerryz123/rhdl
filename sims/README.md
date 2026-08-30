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
  RHDL CHI requester.
- `verilator/`: the Verilator VPI/DPI binding.
- `programs/`: target payloads used by executable simulation checks.
- `tests/`: structural checks for both harness specializations.

Run the focused workflows with:

```sh
make -C sims setup
make -C sims fesvr-test
make -C sims dpi-compile-check \
  VERILATOR_ROOT="$(verilator -V | sed -n 's/^ *VERILATOR_ROOT *= *//p' | head -1)"
make -C sims elaboration-test
make -C sims verilator-test
make -C sims tiled-lowering-test
```

`DirectMemoryHtif` presents FESVR's abstract memory chunks as one-outstanding,
aligned 32-bit transactions. Target XLEN may be 32 or 64; addresses and entry
points remain 64-bit. `FesvrRequester` is a non-caching RN-F: it converts those
private ready-valid DPI signals into coherent CHI `ReadClean` and
`WriteUniquePtl` transactions and reports Invalid for every snoop. Consequently
ELF loading and `tohost`/`fromhost` polling observe dirty Ricket cache lines
without reserving a special mailbox address range.
