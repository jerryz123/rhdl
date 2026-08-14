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

`direct_mem_htif_dpi.cc` provides the intended DPI-C entry point. It follows
the conventional SystemVerilog ABI for output arguments and therefore needs
RHDL DPI declarations with multiple outputs before it can be instantiated by
an RHDL simulation top. The exact function signature is declared in
`direct_mem_htif_dpi.h`. Check that adapter against the installed Verilator
headers with:

```sh
make -C sim/fesvr dpi-compile-check \
  VERILATOR_ROOT="$(verilator -V | sed -n 's/^ *VERILATOR_ROOT *= *//p' | head -1)"
```

The transport is simulation support rather than synthesizable RHDL. It does
not introduce a dependency from the RHDL core, frontend, or CIRCT backend to
FESVR.
