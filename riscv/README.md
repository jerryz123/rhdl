<!-- Defines the pure host-side RISC-V instruction model and RV64I catalog contract. -->

# RISC-V instruction model

`riscv/` is a domain package for describing instruction encodings and decoded
field layouts. It is intentionally separate from the RHDL implementation and
standard library. The initial package contains no RTL generation, RHDL
`Pattern`, `DecodeGen`, core IR, or CIRCT integration.

## Dependency boundary

Files under `model/` and `isa/` use only ordinary Rhombus and modules in this
package:

```text
riscv/isa --> riscv/model --> Rhombus
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
immediate layouts, and the R/I/S/B/U/J formats. RV64-specific six-bit and
five-bit shift-amount formats are distinct. A layout maps named instruction
fields into immediate result bits and explicitly records implicit zero bits.

[`model/instruction.rhm`](model/instruction.rhm) binds an encoding to its
format. Every `InstructionSpec` proves that its fixed requirements and variable
format fields are disjoint and together cover all 32 instruction bits. An
`InstructionCatalog` requires unique names and pairwise-disjoint encodings.

## RV64I catalog

[`isa/rv64i.rhm`](isa/rv64i.rhm) enumerates the 52 architectural instructions
in RV64I version 2.1 over RV32I version 2.1. Each instruction exposes its
required encoding, register operands, immediate layout, and complete variable
field list:

```rhombus
def add = rv64i_instruction("ADD")
add.encoding.value
add.encoding.care
add.operands
add.immediate
add.fields
```

Assembler pseudoinstructions are deliberately excluded because they alias and
overlap architectural encodings. Specialized aliases such as `FENCE.TSO`,
`PAUSE`, and `SEXT.W` therefore do not create catalog entries.

The catalog was checked against the RISC-V International
[RV32I specification](https://docs.riscv.org/reference/isa/unpriv/rv32.html),
[RV64I specification](https://docs.riscv.org/reference/isa/unpriv/rv64.html),
and canonical [`rv_i`](https://github.com/riscv/riscv-opcodes/blob/master/extensions/rv_i)
and [`rv64_i`](https://github.com/riscv/riscv-opcodes/blob/master/extensions/rv64_i)
opcode listings.
