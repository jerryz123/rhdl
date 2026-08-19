<!-- Documents the FESVR transport and native CHI-backed simulation host. -->

# Native CHI FESVR simulation support

`DirectMemoryHtif` derives from FESVR's `htif_t` and presents its abstract
memory chunks to RHDL as one-outstanding, aligned 32-bit transactions. It is
deliberately limited to an RV32 little-endian target. FESVR splits larger
accesses and performs read-modify-write for partial words.

Install the pinned optional dependency, then build and test the C++ transport:

```sh
make -C sim/fesvr setup
make -C sim/fesvr test
```

`direct_mem_htif_dpi.cc` provides the DPI-C entry point.
`direct-memory-htif.rhdl` preserves that flat ABI in `DirectMemoryHTIF`, while
`FesvrHost` is a native CHI RN-I endpoint:

```text
FesvrHost
  memory: CHIRNILink node
  start:  Irrevocable(Bits(32)) producer
  exit:   Bits(32)
```

The private ready-valid signals between `DirectMemoryHTIF` and `FesvrHost`
belong only to the DPI procedure call. They are not a hardware memory protocol
and are not exposed outside the endpoint. `FesvrHost` directly implements CHI
link activation, credit handling, and these one-outstanding transaction flows:

| FESVR operation | Native CHI sequence |
|---|---|
| 32-bit read | `ReadNoSnp`, then `CompData` |
| 32-bit write | `WriteNoSnpFull`, `DBIDResp`, `NonCopyBackWriteData`, then `Comp` |

The default 128-bit CHI data flit carries the 32-bit word in the lane selected
by the low address bits. Writes generate the corresponding four-byte enable;
reads select the same lane from `CompData`.

The underlying DPI declaration remains:

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

The flat wrapper binds those ordered results with one parenthesized `dpi_reg`
declaration. The exact C signature is declared in `direct_mem_htif_dpi.h`.
Check it against the installed Verilator headers with:

```sh
make -C sim/fesvr dpi-compile-check \
  VERILATOR_ROOT="$(verilator -V | sed -n 's/^ *VERILATOR_ROOT *= *//p' | head -1)"
```

The transport is simulation support rather than synthesizable RHDL. It does
not introduce a dependency from the RHDL core, frontend, or CIRCT backend to
FESVR.

## Host-only CHI composition

`chi-top.rhdl` provides the first processor-free integration slice:

```text
TestDriver.sv
└── FesvrTop
    ├── FesvrHost (RN-I, NodeID 3)
    ├── CHIHNI (HN-I, NodeID 5)
    └── CHIRam (SN-I, NodeID 9)
```

The links are connected directly, without a compatibility adapter, shared-memory
owner queue, processor port, or crossbar.
The RAM covers `0x80000000` through `0x80001fff`, which includes both the ELF
entry point and the test program's HTIF mailbox.

Without a processor, the test ELF preinitializes `tohost` with the passing
value. FESVR completes ELF loading, hands off the entry point, then reads that
mailbox through CHI and reports its normal passing exit word. The driver checks
both the `0x80000000` handoff and exit value, while the CHI endpoint, Home, RAM,
and transaction monitors check the load writes and mailbox read.

Run the focused RTL checks with:

```sh
make -C sim/fesvr rtl-elaboration-test
make -C sim/fesvr chi-host-test
```

The second target additionally requires CIRCT, Verilator, and an RV32-capable
`riscv64-unknown-elf-gcc`. `FESVR_PREFIX` and `CIRCT_OPT` may point at existing
installations.

A later processor integration should add a native CHI Request Node and a CHI
fabric.
