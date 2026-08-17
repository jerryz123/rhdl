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
