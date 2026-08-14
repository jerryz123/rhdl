<!-- Defines the pure host-side RISC-V instruction model and RV64I catalog contract. -->

# RISC-V instruction model

`riscv/` is a domain package for describing instruction encodings, decoded
field layouts, and typed host-side instruction annotations. It is intentionally
separate from the RHDL implementation and standard library. The package
contains no RTL generation, RHDL `Pattern`, `DecodeGen`, core IR, or CIRCT
integration.

## Dependency boundary

Files under `model/`, `isa/`, and `annotations/` use only ordinary Rhombus and
modules in this package:

```text
riscv/isa ---------\
                    > riscv/model --> Rhombus
riscv/annotations -/
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

[`annotations/control.rhm`](annotations/control.rhm) attaches independently
defined, typed control metadata without modifying the architectural catalog.
Nominal callable `ControlKey` values validate their values and may provide
defaults. A `ControlLayer` materializes a complete value for every owned key and
instruction; `AnnotatedCatalog` composes layers only when their keys are
disjoint. This deliberately prevents implicit last-layer-wins overrides.

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
add.encoding_fields
```

The architecture-facing `encoding_fields` are instruction bits, not generated
control signals. Microarchitecture-specific operations, pipeline classes, and
similar policy belong in control layers. See the executable
[`riscv-control-annotations.rhm`](../examples/riscv-control-annotations.rhm)
example.

Assembler pseudoinstructions are deliberately excluded because they alias and
overlap architectural encodings. Specialized aliases such as `FENCE.TSO`,
`PAUSE`, and `SEXT.W` therefore do not create catalog entries.

The catalog was checked against the RISC-V International
[RV32I specification](https://docs.riscv.org/reference/isa/unpriv/rv32.html),
[RV64I specification](https://docs.riscv.org/reference/isa/unpriv/rv64.html),
and canonical [`rv_i`](https://github.com/riscv/riscv-opcodes/blob/master/extensions/rv_i)
and [`rv64_i`](https://github.com/riscv/riscv-opcodes/blob/master/extensions/rv64_i)
opcode listings.
