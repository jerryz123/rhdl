<!-- Documents the Sky130 macro catalog and simulation-model ownership. -->

# Sky130 SRAM support

`macros.ini` is the Sky130 implementation of the generic SRAM catalog contract.
Each entry names its adapter interface, logical dimensions, write granularity,
physical size, power pins, functional model, and PDK-relative Verilog, LEF, GDS,
Liberty, and SPICE views.

The checked-in `models/*.functional.sv` files are deterministic zero-delay
models for mapper tests and cycle-level mapped simulation. They preserve the
adapter-visible synchronous behavior but are not timing, power, or signoff
models. Physical RTL lint may instead use the catalogued PDK Verilog view, and
physical implementation must use all catalogued collateral appropriate to the
tool stage.

The currently supported macro is
`sky130_sram_2kbyte_1rw1r_32x512_8`, a 512 x 32-bit OpenRAM-style macro with
byte writes, one read/write port, and one read-only port.
