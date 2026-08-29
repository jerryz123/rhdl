<!-- Describes reusable CHI platform devices and their integration contracts. -->

# Platform devices

This package contains reusable CHI hardware devices that are independent of
any processor core or SoC address map.

- [`aclint.rhdl`](aclint.rhdl) implements ACLINT MTIMER and MSWI for a
  parameterized number of harts. Its register layout uses offsets within a
  64-KiB CLINT-compatible service window; a containing SoC chooses the global
  base.

`Aclint` is a one-outstanding CHI SN-I endpoint. It accepts `ReadNoSnp`,
`WriteNoSnpFull`, and `WriteNoSnpPtl`, exposes a 64-bit
`time_counter`, and produces one software- and timer-interrupt level per hart.
`mtime`, `mtimecmp`, and `msip` honor byte masks, including RV32 accesses to
the high half of a timer register. The timer advances only when the explicit
`tick` input is asserted, which leaves clock-rate policy with the containing
platform.

`AclintParams` owns the SN-I endpoint capabilities and service window;
`AclintIdentity` supplies occurrence-specific NodeID and base-address wires.

Run the package host test with `make device-test`. The `aclint` CIRCT fixture
also simulates register and interrupt behavior through Verilator.
