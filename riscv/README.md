<!-- Defines the pure RISC-V host model, ISA catalogs, and Rhodium adapter boundary. -->

# RISC-V instruction model

`riscv/` is a domain package for describing instruction encodings and decoded
field layouts. Those pure host packages remain separate from Rhodium. The isolated
[`rtl/`](rtl/README.md) bridge converts the model to public Rhodium patterns
without introducing a dependency in the opposite direction.

## Dependency boundary

Files under `model/` and `isa/` use only ordinary Rhombus and modules in those
pure packages:

```text
riscv/isa ---------> riscv/model --> Rhombus
       |
       v
riscv/rtl --------> public Rhodium and HardFloat libraries
```

Run the focused package checks from the repository root:

```sh
make riscv-test
```

## Architectural tests

[`riscv-isa-tests/`](riscv-isa-tests/) pins the upstream
[`riscv-tests`](https://github.com/riscv-software-src/riscv-tests) repository.
Initialize it and its test-environment submodule after cloning Rhodium with:

```sh
git submodule update --init --recursive riscv/riscv-isa-tests
```

The submodule supplies architectural test sources and their standard target
environments. Simulator-specific selection, building, and execution belong
under `sims/`; the pure instruction model does not import this test repository.

## Host model

[`model/fields.rhm`](model/fields.rhm) defines named instruction `BitField`
values and fixed `FieldConstraint`s. [`model/encoding.rhm`](model/encoding.rhm)
combines constraints into an immutable 32-bit `InstructionEncoding` with
canonical `value` and `care` images. Construction rejects out-of-range and
conflicting constraints; encodings support host-side matching, overlap, and
subsumption relations.

[`model/formats.rhm`](model/formats.rhm) defines typed integer and floating-point
register operands, scattered immediate layouts, and the standard integer and
floating-point instruction formats. Five-bit 32-bit-operation shift
amounts and six-bit 64-bit-operation shift amounts are distinct. A layout maps
named instruction fields into immediate result bits and explicitly records
implicit zero bits.

[`model/instruction.rhm`](model/instruction.rhm) binds an encoding to its
format. Every `InstructionSpec` proves that its fixed requirements and variable
format fields are disjoint and together cover all 32 instruction bits. An
`InstructionCatalog` requires unique names and pairwise-disjoint encodings.

## Rhodium adapter

[`rtl/instruction-pattern.rhdl`](rtl/instruction-pattern.rhdl) converts
architectural value/care encodings to typed `Pattern` values.
[`rtl/instruction-fields.rhdl`](rtl/instruction-fields.rhdl) generates
hardware field and immediate extraction from the same pure descriptors.
Concrete hardware uses ordinary `DecodeCase` relations and generators from
`rhodium/std/decode`, which remains independent of RISC-V instruction
descriptions.

## Integer catalogs

[`isa/xlen.rhm`](isa/xlen.rhm) defines the closed host-side `XLen` configuration
with `XLen.X32` and `XLen.X64` members. Hardware generators accept this value
when their behavior follows architectural XLEN and use `xlen.width` only when
constructing width-indexed Rhodium types. Arbitrary implementation dimensions
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

[`isa/zmmul.rhm`](isa/zmmul.rhm) separately describes the multiply-only Zmmul
extension. Its RV32 catalog contains `MUL`, `MULH`, `MULHSU`, and `MULHU`; its
RV64 catalog adds `MULW`. Keeping the extension separate preserves the exact
base-ISA catalogs and allows cores to adopt multiplication without claiming
the divide and remainder operations from the full M extension.

[`isa/m.rhm`](isa/m.rhm) builds complete RV32M and RV64M catalogs by retaining
the Zmmul instruction objects and adding signed and unsigned divide and
remainder operations. RV64M additionally contributes the four 32-bit word
variants. Keeping both catalogs public lets a core select Zmmul alone or claim
the complete M extension without duplicating multiply encodings.

[`isa/a.rhm`](isa/a.rhm) defines the RV32A word and RV64A word/doubleword
load-reserved, store-conditional, and atomic memory-operation encodings. Its
dedicated formats keep `aq` and `rl` as variable architectural fields while
fixing `rs2` to zero for LR. The catalog describes ISA encodings only;
reservation granules, coherence ownership, and read-modify-write execution
remain core policy.

[`isa/zba.rhm`](isa/zba.rhm), [`isa/zbb.rhm`](isa/zbb.rhm), and
[`isa/zbs.rhm`](isa/zbs.rhm) describe the ratified address-generation, basic
bit-manipulation, and single-bit instruction encodings. [`isa/b.rhm`](isa/b.rhm)
combines those three independent subsets into the standard RV32B and RV64B
catalogs without including Zbc or cryptography-oriented subsets. Fixed-operand
unary encodings use `UnaryFormat`, so their architectural operand list contains
only `rd` and `rs1` even when fixed instruction bits occupy the `rs2` field.

[`isa/zicond.rhm`](isa/zicond.rhm) defines the XLEN-independent
`CZERO.EQZ` and `CZERO.NEZ` register encodings as the ratified Zicond 1.0.0
extension. The catalog describes the architectural dependency on both source
registers; its conditional-mask implementation remains a core datapath choice.

[`isa/zicsr.rhm`](isa/zicsr.rhm) describes the six register and immediate CSR
read/modify/write encodings independently of any core's CSR implementation.
[`isa/zifencei.rhm`](isa/zifencei.rhm) describes the XLEN-independent
`FENCE.I` encoding as the separate ratified Zifencei extension; microarchitectural
cache invalidation and pipeline serialization remain core policy.
[`isa/csr.rhm`](isa/csr.rhm) owns the closed `CsrId` host enum and its canonical
12-bit architectural address mapping. Hardware must cross through
[`rtl/csr.rhdl`](rtl/csr.rhdl) when it needs a typed instruction-field value,
so sparse architectural identifiers do not become a core-specific hardware
enum or a collection of numeric literals.
[`rtl/counters.rhdl`](rtl/counters.rhdl) implements the reusable 64-bit
`mcycle` and `minstret` state behind Zicntr's read-only counter views. Concrete
cores supply their precise retirement event and retain privilege and
`counteren` policy in their CSR integration; platform real time remains an
external `mtime`-equivalent source.
[`isa/trap.rhm`](isa/trap.rhm) similarly owns synchronous `ExceptionCause`
members, cause codes, and masks assembled from cause sets.
[`isa/interrupt.rhm`](isa/interrupt.rhm) owns the six standard supervisor and
machine interrupt causes and their architectural cause codes; concrete cores
remain responsible for pending-source wiring, enable and delegation policy,
and priority.
[`isa/privileged.rhm`](isa/privileged.rhm) currently contributes the exact
`MRET`, `SRET`, `WFI`, and `SFENCE.VMA` encodings used by RV5Stage's privileged control
plane. [`isa/sv39.rhm`](isa/sv39.rhm) owns pure Sv39 geometry and canonical
address helpers, while [`rtl/sv39.rhdl`](rtl/sv39.rhdl) provides typed PTE,
permission, superpage, and physical-address combinational operations.
Keeping these catalogs separate lets a core select the mechanisms it actually
implements without adding them to the RV32I or RV64I base catalogs.

## Floating-point catalogs

[`isa/fp-profile.rhm`](isa/fp-profile.rhm) defines the closed host-side
`FloatingPointProfile` specialization. `None` is the default, `F` selects
single precision, and `D` implies both single- and double-precision support.
This configuration is deliberately a host value so absent FP hardware can be
specialized away rather than represented by run-time control.

[`isa/f.rhm`](isa/f.rhm) and [`isa/d.rhm`](isa/d.rhm) define the standard F and
D instruction encodings for RV32 and RV64. D catalogs contain the D-specific
instructions; a D-profile core composes them with the corresponding F catalog.
The shared formats distinguish integer and floating-point register banks and
model `rs3`, `fmt`, and `rm` as ordinary architectural fields.

[`rtl/floating-point.rhdl`](rtl/floating-point.rhdl) owns reusable RISC-V policy
around HardFloat values: NaN boxing, canonical NaNs, architectural rounding
mode and exception-flag mapping, raw moves, classification, sign injection,
and the specified floating min/max NaN and signed-zero behavior. HardFloat
continues to own arithmetic implementation; concrete cores own register files,
CSR state, decode, scheduling, and retirement.

The catalogs were checked against the RISC-V International
[RV32I specification](https://docs.riscv.org/reference/isa/unpriv/rv32.html),
[RV64I specification](https://docs.riscv.org/reference/isa/unpriv/rv64.html),
and canonical [`rv_i`](https://github.com/riscv/riscv-opcodes/blob/master/extensions/rv_i)
and [`rv64_i`](https://github.com/riscv/riscv-opcodes/blob/master/extensions/rv64_i)
opcode listings. Zmmul follows the ratified
[multiply-only extension](https://docs.riscv.org/reference/isa/unpriv/m-st-ext.html#_zmmul_extension_version_1_0),
and A follows the ratified
[atomic extension](https://docs.riscv.org/reference/isa/unpriv/a-st-ext.html).
B follows the ratified
[bit-manipulation extension](https://docs.riscv.org/reference/isa/unpriv/b-st-ext.html).
Zicond follows the ratified
[integer conditional-operations extension](https://docs.riscv.org/reference/isa/unpriv/zicond.html).
