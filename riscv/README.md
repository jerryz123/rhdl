<!-- Defines the pure RISC-V host model, RV32I/RV64I catalogs, and RHDL adapter boundary. -->

# RISC-V instruction model

`riscv/` is a domain package for describing instruction encodings and decoded
field layouts. Those pure host packages remain separate from RHDL. The isolated
[`rhdl/`](rhdl/README.md) bridge converts the model to public RHDL patterns
without introducing a dependency in the opposite direction.

## Dependency boundary

Files under `model/` and `isa/` use only ordinary Rhombus and modules in those
pure packages:

```text
riscv/isa ---------> riscv/model --> Rhombus
       |
       v
riscv/rhdl --------> public RHDL standard libraries
```

Run the focused package checks from the repository root:

```sh
make riscv-test
```

## Host model

[`model/fields.rhm`](model/fields.rhm) defines named instruction `BitField`
values and fixed `FieldConstraint`s. [`model/encoding.rhm`](model/encoding.rhm)
combines constraints into an immutable 32-bit `InstructionEncoding` with
canonical `value` and `care` images. Construction rejects out-of-range and
conflicting constraints; encodings support host-side matching, overlap, and
subsumption relations.

[`model/formats.rhm`](model/formats.rhm) defines register operands, scattered
immediate layouts, and the R/I/S/B/U/J formats. Five-bit 32-bit-operation shift
amounts and six-bit 64-bit-operation shift amounts are distinct. A layout maps
named instruction fields into immediate result bits and explicitly records
implicit zero bits.

[`model/instruction.rhm`](model/instruction.rhm) binds an encoding to its
format. Every `InstructionSpec` proves that its fixed requirements and variable
format fields are disjoint and together cover all 32 instruction bits. An
`InstructionCatalog` requires unique names and pairwise-disjoint encodings.

## RHDL adapter

[`rhdl/instruction-pattern.rhdl`](rhdl/instruction-pattern.rhdl) converts
architectural value/care encodings to typed `Pattern` values.
[`rhdl/instruction-fields.rhdl`](rhdl/instruction-fields.rhdl) generates
hardware field and immediate extraction from the same pure descriptors.
Concrete hardware uses ordinary `DecodeCase` relations and generators from
`rhdl/std/decode`, which remains independent of RISC-V instruction
descriptions.

## Integer catalogs

[`isa/xlen.rhm`](isa/xlen.rhm) defines the closed host-side `XLen` configuration
with `XLen.X32` and `XLen.X64` members. Hardware generators accept this enum
when their behavior follows architectural XLEN and use `xlen_width` only when
constructing width-indexed RHDL types. Arbitrary implementation dimensions
such as address, cache, and generic comparator widths remain ordinary `Int`
values.

[`isa/rv32i.rhm`](isa/rv32i.rhm) enumerates the 40 architectural instructions
in RV32I version 2.1. [`isa/rv64i.rhm`](isa/rv64i.rhm) enumerates the 52
instructions in RV64I version 2.1 over that base. Each instruction exposes its
required encoding, register operands, immediate layout, and complete variable
field list:

```rhombus
def rv32_add = rv32i_instruction("ADD")
def add = rv64i_instruction("ADD")
add.encoding.value
add.encoding.care
add.operands
add.immediate
add.encoding_fields
```

[`isa/integer-common.rhm`](isa/integer-common.rhm) owns the 37 instruction
specifications whose encodings are identical at both XLENs. Both catalogs
reuse those same immutable objects. `SLLI`, `SRLI`, and `SRAI` remain distinct:
RV32I fixes instruction bit 25 and exposes a five-bit shift amount, while RV64I
uses that bit as the sixth shift-amount bit. RV64I then adds its wider loads,
store, and word-operation instructions. Consumers should import `rv32i.rhm` or
`rv64i.rhm` explicitly; the package deliberately has no ambiguous combined
namespace for architecture-specific instruction names.

The architecture-facing `encoding_fields` are instruction bits, not generated
control signals. Microarchitecture-specific operations, pipeline classes, and
similar policy belong in concrete typed decode relations rather than the
architectural catalog.

Assembler pseudoinstructions are deliberately excluded because they alias and
overlap architectural encodings. Specialized aliases such as `FENCE.TSO`,
`PAUSE`, and `SEXT.W` therefore do not create catalog entries.

The catalogs were checked against the RISC-V International
[RV32I specification](https://docs.riscv.org/reference/isa/unpriv/rv32.html),
[RV64I specification](https://docs.riscv.org/reference/isa/unpriv/rv64.html),
and canonical [`rv_i`](https://github.com/riscv/riscv-opcodes/blob/master/extensions/rv_i)
and [`rv64_i`](https://github.com/riscv/riscv-opcodes/blob/master/extensions/rv64_i)
opcode listings.
