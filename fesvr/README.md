<!-- Documents the FESVR transport and ready-valid CHI requester channels. -->

# CHI-channel FESVR simulation support

`DirectMemoryHtif` derives from FESVR's `htif_t` and presents its abstract
memory chunks to RHDL as one-outstanding, aligned 32-bit transactions. It is
deliberately limited to an RV32 little-endian target. FESVR splits larger
accesses and performs read-modify-write for partial words.

Install the pinned optional dependency, then build and test the C++ transport:

```sh
make -C fesvr setup
make -C fesvr test
```

`direct_mem_htif_dpi.cc` provides the DPI-C entry point.
`direct-memory-htif.rhdl` preserves that flat ABI in `DirectMemoryHTIF`, while
`FesvrRequester` is its ready-valid CHI requester transaction engine:

```text
FesvrRequester
  port:  CHIRNIChannels node
  start: Irrevocable(Bits(32)) producer
  exit:  Bits(32)
```

The private ready-valid signals between `DirectMemoryHTIF` and
`FesvrRequester`
belong only to the DPI procedure call. They are not a hardware memory protocol
and are not exposed outside the requester. The requester owns these
one-outstanding CHI transaction flows but no physical link activation or credit
state. Its `CHIHomeMap` parameter selects the destination Home from each
accepted request address, and the requester retains that NodeID for the entire
transaction:

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
make -C fesvr dpi-compile-check \
  VERILATOR_ROOT="$(verilator -V | sed -n 's/^ *VERILATOR_ROOT *= *//p' | head -1)"
```

The transport is simulation support rather than synthesizable RHDL. It does
not introduce a dependency from the RHDL core, frontend, or CIRCT backend to
FESVR.

The concrete Ricket/CHI/RAM integration and its end-to-end simulation are owned
by [`socs/`](../socs/README.md). This directory owns only the reusable transport,
its direct unit test, and the external FESVR dependency setup.
