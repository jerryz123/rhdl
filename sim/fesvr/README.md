<!-- Documents the standalone C++ FESVR transport and its generated-RTL contract. -->

# Direct-memory FESVR transport

`DirectMemoryHtif` derives from FESVR's `htif_t` and converts its abstract
memory chunks into one-outstanding, aligned 32-bit ready/valid transactions.
It deliberately implements only an RV32 little-endian target. FESVR splits
larger accesses and performs read-modify-write for partial words.

The transport also turns `htif_t::reset()` into a startup transaction carrying
the ELF entry point. Generated simulation RTL should hold the core in reset
until that transaction is accepted. Once running, FESVR polls `tohost` through
the same memory interface and reports completion as `(exit_code << 1) | 1`.

Install the pinned optional dependency, then build and test the transport:

```sh
make -C sim/fesvr setup
make -C sim/fesvr test
```

`direct_mem_htif_dpi.cc` provides the intended DPI-C entry point.
`direct-memory-htif.rhdl` wraps it as a synchronous circuit whose ports can be
connected to a future core simulation top. Its DPI declaration is:

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

The wrapper binds those ordered results directly with one parenthesized
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
