<!-- Defines the dependency boundary and public API of the RISC-V-to-RHDL adapter. -->

# RISC-V/RHDL adapter

This package is the only bridge from the pure host-side RISC-V model to RHDL.
It may import `riscv/model`, `riscv/isa`, and public `#lang rhdl` libraries. It
must not depend on RHDL implementation modules, concrete processors, CIRCT, or
tests.

[`instruction-pattern.rhdl`](instruction-pattern.rhdl) converts
`InstructionEncoding` and `InstructionSpec` values into typed RHDL `Pattern`
values. Generic case grouping, output patterns, valid-tagged partial mappings,
and hardware decode generation remain in `rhdl/std/decode`. The adapter is
catalog-independent: RV32I and RV64I instructions pass through the same
conversion while retaining their exact architectural care masks.

[`instruction-fields.rhdl`](instruction-fields.rhdl) converts the pure model's
`BitField` and `ImmediateLayout` descriptors into hardware slices,
concatenations, and signed or unsigned extension. Architectural bit placement
therefore remains defined once in `riscv/model`; concrete cores only select
which described layout their datapath consumes.

[`csr.rhdl`](csr.rhdl) converts a pure `CsrId` enum member to the corresponding
typed `Bits(12)` instruction field. Its `csr_bank` form defines each
implemented CSR once and derives recognition, read selection, and one exact-key
write dispatch. `storage` entries provide direct state, `read` entries provide
constants or write-ignored views, and `csr` entries provide custom read and
write behavior for aliases and WARL masks. The architectural identifier and
numeric address remain owned by `riscv/isa`; hardware receives a value only at
this adapter boundary.

[`trap.rhdl`](trap.rhdl) converts an architectural `ExceptionCause` into a
width-specialized hardware value. Core-specific trap selection stays in the
processor while the cause-number namespace remains shared.

[`interrupt.rhdl`](interrupt.rhdl) converts an architectural `InterruptCause`
into a width-specialized `xcause` value with the interrupt bit set. Pending
sources, interrupt selection, and privilege transitions remain core policy.
