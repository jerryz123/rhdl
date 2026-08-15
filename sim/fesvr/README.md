<!-- Documents the FESVR transport, typed RTL adapter, and minimal simulation harness. -->

# Direct-memory FESVR simulation support

`DirectMemoryHtif` derives from FESVR's `htif_t` and converts its abstract
memory chunks into one-outstanding, aligned 32-bit ready/valid transactions.
It deliberately implements only an RV32 little-endian target. FESVR splits
larger accesses and performs read-modify-write for partial words.

The transport also turns `htif_t::reset()` into a startup transaction carrying
the ELF entry point. The processor must remain idle until that transaction is
accepted. Once running, FESVR polls `tohost` through the same memory interface
and reports completion as `(exit_code << 1) | 1`.

Install the pinned optional dependency, then build and test the transport:

```sh
make -C sim/fesvr setup
make -C sim/fesvr test
```

`direct_mem_htif_dpi.cc` provides the intended DPI-C entry point.
`direct-memory-htif.rhdl` keeps that flat ABI in `DirectMemoryHTIF` and exposes
the normal RHDL-facing `FesvrHost` adapter:

```text
FesvrHost
  memory: SimpleMemory(32, 4) requester
  start:  Irrevocable(Bits(32)) producer
  exit:   Bits(32)
```

The full-byte request mask matches the C++ transport: FESVR itself performs
read-modify-write for sub-word ELF chunks. The underlying DPI declaration is:

```rhombus
dpi_import function rhdl_htif_tick(
  reset: Bool,
  request_ready: Bool,
  response_valid: Bool,
  response_data: Bits(32),
  start_ready: Bool
) -> (
  out request_valid: Bool,
  out request_write: Bool,
  out request_address: Bits(32),
  out request_data: Bits(32),
  out response_ready: Bool,
  out start_valid: Bool,
  out start_entry: Bits(32),
  return exit: Bits(32)
)
```

The flat wrapper binds those ordered results directly with one parenthesized
`dpi_reg` declaration. The exact C signature is declared in
`direct_mem_htif_dpi.h`. Check the adapter against the installed Verilator
headers with:

```sh
make -C sim/fesvr dpi-compile-check \
  VERILATOR_ROOT="$(verilator -V | sed -n 's/^ *VERILATOR_ROOT *= *//p' | head -1)"
```

The transport is simulation support rather than synthesizable RHDL. It does
not introduce a dependency from the RHDL core, frontend, or CIRCT backend to
FESVR.

## Simple simulation SoC

`shared-memory.rhdl` fairly arbitrates FESVR and processor requests directly
into one `SimpleMemoryRam`. It exposes complete `SimpleMemory` endpoints for
both requesters; the request and response directions remain independent
generic interface-handle chains internally. It stores one owner token per
accepted request, couples it with the corresponding ordered response, and
payload-demultiplexes that response back to its requester.

`simple-soc-top.rhdl` owns the reusable simulation-only composition. Its
processor is a host generator parameter with two required interfaces:
`SimpleMemory(32, 4)` requester `memory` and
`Irrevocable(Bits(32))` consumer `start`.

```text
TestDriver.sv
└── SimpleSoCTop
    ├── processor
    ├── FesvrSharedMemory
    │   └── SimpleMemoryRam
    └── FesvrHost
        └── DirectMemoryHTIF
```

`TestDriver.sv` is the only handwritten SystemVerilog layer. It supplies
clock and reset, monitors the FESVR exit word, and enforces a timeout. The
generated `SimpleSoCTop` owns all typed hardware composition and the DPI call.

The runnable smoke configuration is also under `sim/fesvr/`:

```text
FesvrHost ---------\
                    FesvrSharedMemory
FesvrStubCore -----/
       ^
       +------------ start entry
```

`stub-soc.rhdl` supplies `FesvrStubCore` to `SimpleSoCTop`. The stub executes no
instructions. After accepting the ELF entry point, it writes `1` to `tohost`.
The integration test under `tests/fesvr/` proves that FESVR loads the ELF
through generated RTL, start delivery completes, processor and host traffic
share the same RAM, and FESVR observes the passing exit. Test-owned files are
limited to assertions, the transport unit test, and target programs.

Install FESVR and CIRCT, then run the focused RTL checks:

```sh
make -C sim/fesvr rtl-elaboration-test
make -C sim/fesvr stub-soc-test
```

The second target additionally requires Verilator and an RV32-capable
`riscv64-unknown-elf-gcc`. `FESVR_PREFIX` and `CIRCT_OPT` may point at existing
installations.

A future processor implementation is expected to live under the repository's
top-level `core/`, not under this simulator package. A concrete simulation
configuration can supply that processor to `SimpleSoCTop` while retaining the
FESVR host, shared memory, SV driver, and DPI support defined here.
