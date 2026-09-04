<!-- Describes reusable platform devices and their hardware and simulation contracts. -->

# Platform devices

This package contains reusable hardware devices that are independent of any
processor core or SoC address map, plus device-specific simulation models.

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

[`uart.rhdl`](uart.rhdl) provides reusable fixed-format 8-N-1 transmitter and
receiver engines. They consume a 16-times oversampling tick, expose byte-level
flow interfaces, and keep asynchronous receive synchronization inside the
receiver.

[`uart16550.rhdl`](uart16550.rhdl) wraps those engines in a one-outstanding CHI
SN-I endpoint with an eight-byte, byte-accessed 16550-style register window.
It implements RBR/THR and divisor-latch aliases, IER, IIR/FCR, LCR, MCR, LSR,
MSR, and SCR. The implemented serial format is deliberately limited to 8-N-1;
unsupported LCR formats raise a hardware assertion instead of silently
claiming compatibility. MCR is retained for software readback, while modem
status and modem-control pins are not implemented.

The UART supports FIFO depths from one through sixteen, divisor-driven
16-times oversampling, receive-data and transmitter-empty interrupts, FIFO
clears, overrun status, framing status, and stable CHI responses under
backpressure. `Uart16550Params` owns the SN-I capabilities and address window;
`Uart16550Identity` supplies occurrence-specific NodeID and base-address wires.
The synthesizable device exposes only `rx`, `tx`, and `interrupt`.

[`uart-dpi.rhdl`](uart-dpi.rhdl) provides a PTY-backed simulation model for
those serial pins. `UartDPI` uses the same 8-N-1 engines to deserialize
`uart_tx` and serialize bytes onto `uart_rx`, while
[`dpi/uart_dpi.cc`](dpi/uart_dpi.cc) creates one nonblocking raw
pseudo-terminal per model ID. It prints the slave path when the model is first
used; `rhodium_uart_pty_path` also returns that path so a simulator or test can
open it directly. A terminal program connected to the slave sees bytes sent by
the simulated UART and can write bytes that the model sends back over its
serial output.

The model buffers PTY input across hardware reset but suppresses serial
transfers while reset is active. A decoded byte with a framing error is still
written to the PTY because a PTY has no framing-error sideband; the C++ model
logs and counts the error for diagnostics. The elaboration-time oversample
divisor must match the divisor programmed into the connected UART.

No SoC harness instantiates `UartDPI` yet. A future harness can connect
`model.uart_tx` from the device's `tx` and the device's `rx` from
`model.uart_rx`.

Run the package host test with `make device-test`. The `aclint` and `uart16550`
CIRCT fixtures also simulate register, interrupt, and external-pin behavior
through Verilator. Run the standalone DPI serial model with
`FIXTURE=uart-dpi bash tests/backend/run-circt.sh --simulate-only`.
