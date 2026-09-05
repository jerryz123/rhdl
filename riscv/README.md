<!-- Defines the pure RISC-V host model, ISA catalogs, and Rhodium adapter boundary. -->

# RISC-V instruction model

`riscv/` describes architectural instruction encodings, decoded fields, and
compact-to-canonical expansion as immutable host data. The pure [`model/`](model/)
and [`isa/`](isa/) packages do not depend on Rhodium. The isolated
[`rtl/`](rtl/README.md) adapter materializes those descriptions as hardware
without moving processor policy into the architectural model.

## Find what you need

| Task | Start here |
|---|---|
| Define a field, encoding, format, or instruction | [Pure model](#pure-model) |
| Select an integer, floating-point, compressed, or privileged catalog | [ISA catalog map](#isa-catalog-map) |
| Expand a 16-bit C instruction to its canonical 32-bit instruction | [Compressed-instruction expansion](#compressed-instruction-expansion) |
| Turn descriptions into hardware patterns or extracted fields | [RISC-V/Rhodium adapter](rtl/README.md) |
| Build CSR, PMA, Sv39, counter, trap, interrupt, or FP hardware | [Adapter component map](rtl/README.md#component-map) |
| Run the focused package checks | [Validation](#validation) |
| Initialize the architectural test sources | [Architectural tests](#architectural-tests) |

## Dependency boundary

Arrows show allowed import direction. Pure ISA and model code never imports the
adapter, Rhodium, HardFloat, a processor implementation, or backend tooling.

```mermaid
flowchart LR
  ISA["riscv/isa<br/>architectural catalogs"] --> Model["riscv/model<br/>pure descriptors"]
  Model --> Rhombus["ordinary Rhombus"]
  ISA --> Rhombus

  Adapter["riscv/rtl<br/>hardware adapter"] --> ISA
  Adapter --> Model
  Adapter --> Rhodium["public Rhodium libraries"]
  Adapter --> HardFloat["public HardFloat package"]
```

Concrete processors consume these packages but do not define their contracts;
core-specific decode, execution, fetch, pipeline, CSR policy, and retirement
belong under [`../cores/`](../cores/README.md).

## Pure model

[`model/main.rhm`](model/main.rhm) re-exports the complete pure model. Import a
narrow module when only one abstraction is needed:

| Module | Owns |
|---|---|
| [`model/fields.rhm`](model/fields.rhm) | Named `BitField` values, fixed `FieldConstraint`s, extraction, masks, and width checks |
| [`model/encoding.rhm`](model/encoding.rhm) | Width-aware `InstructionEncoding` value/care images and matching, overlap, and subsumption relations |
| [`model/formats.rhm`](model/formats.rhm) | Integer and floating-point register operands, instruction formats, and scattered immediate layouts |
| [`model/instruction.rhm`](model/instruction.rhm) | Validated 32-bit `InstructionSpec` values and disjoint `InstructionCatalog`s |
| [`model/expansion.rhm`](model/expansion.rhm) | Validated compact-source bindings, immediate resizing/scattering, legality constraints, and host expansion |

An `InstructionEncoding` defaults to 32 bits, while the C catalogs use the same
abstraction at 16 bits. Construction rejects fields outside the selected width,
out-of-range values, and conflicting constraints. Encodings are ordinary host
values and support `matches`, `overlaps`, and `subsumes` without elaborating
hardware.

An `InstructionSpec` binds one 32-bit encoding to its operand and immediate
format. Its fixed requirements and variable fields must be disjoint and must
cover all 32 instruction bits. An `InstructionCatalog` requires unique names
and pairwise-disjoint encodings. Architecture-facing `encoding_fields` remain
instruction bits, not generated controls; microarchitectural operations and
pipeline classes belong in a core-owned typed decode relation.

`ImmediateLayout` records each source fragment, destination position, signedness,
and implicit zero bit. In particular, five-bit RV32 shift amounts and six-bit
RV64 shift amounts remain distinct. `InstructionExpansion` requires exactly one
binding for every target operand and a correctly sized source or constant for
every target immediate. The same validated expansion can run as pure host code
or be materialized by the Rhodium adapter.

## ISA catalog map

### Base integer and architectural width

| Module | Public catalog or configuration | Coverage |
|---|---|---|
| [`isa/xlen.rhm`](isa/xlen.rhm) | `XLen.X32`, `XLen.X64` | Closed host-side architectural width selection |
| [`isa/integer-common.rhm`](isa/integer-common.rhm) | `RVIntegerCommonInstructions` | 37 immutable encodings shared by RV32I and RV64I |
| [`isa/rv32i.rhm`](isa/rv32i.rhm) | `RV32I` | 40 architectural instructions, RV32I 2.1 |
| [`isa/rv64i.rhm`](isa/rv64i.rhm) | `RV64I` | 52 architectural instructions, RV64I 2.1 over RV32I 2.1 |

Import `rv32i.rhm` or `rv64i.rhm` explicitly; there is no combined namespace
for architecture-specific names. `SLLI`, `SRLI`, and `SRAI` are distinct
objects because RV32 fixes bit 25 while RV64 uses it as the sixth shift bit.
RV64I additionally supplies wider loads, a wider store, and word operations.

Assembler pseudoinstructions and specialized aliases such as `FENCE.TSO`,
`PAUSE`, and `SEXT.W` are deliberately absent because they overlap architectural
encodings.

### Integer extensions

| Module | Public catalogs | Coverage |
|---|---|---|
| [`isa/zmmul.rhm`](isa/zmmul.rhm) | `RV32Zmmul`, `RV64Zmmul` | Multiply-only Zmmul 1.0; RV64 adds `MULW` |
| [`isa/m.rhm`](isa/m.rhm) | `RV32M`, `RV64M` | M 2.0, reusing Zmmul objects and adding divide/remainder operations |
| [`isa/a.rhm`](isa/a.rhm) | `RV32A`, `RV64A` | A 2.1 word and RV64 doubleword LR/SC and AMO encodings with variable `aq`/`rl` |
| [`isa/zba.rhm`](isa/zba.rhm) | `RV32Zba`, `RV64Zba` | Ratified Zba 1.0.0 address generation |
| [`isa/zbb.rhm`](isa/zbb.rhm) | `RV32Zbb`, `RV64Zbb` | Ratified Zbb 1.0.0 basic bit manipulation |
| [`isa/zbs.rhm`](isa/zbs.rhm) | `RV32Zbs`, `RV64Zbs` | Ratified Zbs 1.0.0 single-bit operations |
| [`isa/b.rhm`](isa/b.rhm) | `RV32B`, `RV64B` | Standard B 1.0.0 composition of Zba, Zbb, and Zbs; no Zbc or crypto subsets |
| [`isa/zicond.rhm`](isa/zicond.rhm) | `RV32Zicond`, `RV64Zicond` | Zicond 1.0.0 `CZERO.EQZ` and `CZERO.NEZ` |
| [`isa/zicsr.rhm`](isa/zicsr.rhm) | `Zicsr` | Six XLEN-independent Zicsr 2.0 encodings |
| [`isa/zifencei.rhm`](isa/zifencei.rhm) | `Zifencei` | XLEN-independent Zifencei 2.0 `FENCE.I` encoding |

These catalogs describe architectural dependencies and encodings only. Atomic
reservation and coherence policy, multiply/divide execution, conditional-mask
datapaths, CSR behavior, and instruction-cache serialization remain processor
responsibilities.

### Compressed instructions

| Module | Public catalogs | Coverage |
|---|---|---|
| [`isa/c.rhm`](isa/c.rhm) | `RV32CInteger`, `RV64CInteger` | C 2.0 integer instructions with XLEN-specific encodings and canonical targets |
| [`isa/c.rhm`](isa/c.rhm) | `RV32CFloat`, `RV32CDouble`, `RV64CDouble` | Profile-selectable compressed floating-point load/store catalogs |

See [Compressed-instruction expansion](#compressed-instruction-expansion) for
the pure descriptor and hardware materialization path.

### Floating point

| Module | Public catalog or configuration | Coverage |
|---|---|---|
| [`isa/fp-profile.rhm`](isa/fp-profile.rhm) | `FloatingPointProfile.None`, `.F`, `.D` | Host specialization; D implies F and selects a 64-bit FP register width |
| [`isa/f.rhm`](isa/f.rhm) | `RV32F`, `RV64F` | Standard F 2.2 instruction encodings |
| [`isa/d.rhm`](isa/d.rhm) | `RV32D`, `RV64D` | D-specific 2.2 instruction encodings, composed with F by a D-profile consumer |

The profile is host data so unsupported hardware specializes away rather than
becoming runtime control. `None` has no floating-point register width.

### Privileged and address-space descriptions

| Module | Owns |
|---|---|
| [`isa/csr.rhm`](isa/csr.rhm) | Closed `CsrId` namespace and canonical 12-bit addresses, including `fflags`/`frm`/`fcsr` aliases |
| [`isa/trap.rhm`](isa/trap.rhm) | Synchronous `ExceptionCause` members, architectural codes, and cause-set masks |
| [`isa/interrupt.rhm`](isa/interrupt.rhm) | Standard supervisor and machine interrupt causes and codes |
| [`isa/privileged.rhm`](isa/privileged.rhm) | Exact `MRET`, `SRET`, `WFI`, and `SFENCE.VMA` encodings |
| [`isa/sv39.rhm`](isa/sv39.rhm) | Pure Sv39 geometry and canonical-address helpers |

Sparse identifiers stay host-side until the [adapter](rtl/README.md) produces a
typed hardware value. Pending interrupt sources, delegation, privilege, CSR
WARL behavior, translation state, and exception selection remain integration
policy.

## Compressed-instruction expansion

[`isa/c.rhm`](isa/c.rhm) retains each 16-bit C encoding, legality constraints,
compressed fields, immediate layout, operand bindings, and canonical
`InstructionSpec` target as pure host data. A `CompressedInstructionCatalog`
checks unique names and nonoverlapping base encodings. Matching additionally
checks constraints such as nonzero registers and immediates, and host `expand`
rejects an illegal or nonmatching word.

```mermaid
flowchart LR
  CWord["16-bit compressed word"] --> Catalog["C catalog<br/>encoding + legality"]
  Catalog --> Expansion["InstructionExpansion<br/>operands + immediate"]
  Expansion --> Host["pure host expand"]
  Expansion --> RTL["RiscvCompressedExpander"]
  Host --> Canonical["canonical 32-bit instruction"]
  RTL --> Canonical
  Canonical --> Decoder["existing 32-bit decoder"]
```

[`rtl/compressed.rhdl`](rtl/compressed.rhdl) selects the correct integer and
floating-point descriptor lists from `XLen` and `FloatingPointProfile`, then
materializes the same expansion as combinational hardware. Reserved encodings
produce `valid = #false`; architectural hint encodings remain legal and expand
to the canonical no-effect instruction where the base ISA assigns that
behavior. See the [adapter contract](rtl/README.md#compressed-instruction-expansion)
for the exact profile matrix and output rules.

## Architectural tests

[`riscv-isa-tests/`](riscv-isa-tests/) pins the upstream
[`riscv-tests`](https://github.com/riscv-software-src/riscv-tests) repository.
Initialize it and its test-environment submodule after cloning Rhodium:

```sh
git submodule update --init --recursive riscv/riscv-isa-tests
```

The submodule supplies architectural sources and standard target environments.
Simulator-specific selection, building, and execution belong under
[`../sims/`](../sims/README.md); neither the pure model nor the adapter imports
the test repository.

## Validation

Run the focused model, catalog, adapter, expansion, and package-boundary checks
from the repository root:

```sh
make riscv-test
```

Executable pattern and field-extraction examples live in
[`../examples/riscv/`](../examples/riscv/).

## Architectural references

The base catalogs were checked against the RISC-V International
[RV32I specification](https://docs.riscv.org/reference/isa/unpriv/rv32.html),
[RV64I specification](https://docs.riscv.org/reference/isa/unpriv/rv64.html),
and canonical [`rv_i`](https://github.com/riscv/riscv-opcodes/blob/master/extensions/rv_i)
and [`rv64_i`](https://github.com/riscv/riscv-opcodes/blob/master/extensions/rv64_i)
opcode listings. Zmmul follows the ratified
[multiply-only extension](https://docs.riscv.org/reference/isa/unpriv/m-st-ext.html#_zmmul_extension_version_1_0),
A follows the ratified
[atomic extension](https://docs.riscv.org/reference/isa/unpriv/a-st-ext.html),
B follows the ratified
[bit-manipulation extension](https://docs.riscv.org/reference/isa/unpriv/b-st-ext.html),
Zicond follows the ratified
[integer conditional-operations extension](https://docs.riscv.org/reference/isa/unpriv/zicond.html),
and C follows the ratified
[compressed-instruction extension](https://docs.riscv.org/reference/isa/unpriv/c-st-ext.html).
