<!-- Defines ownership and composition boundaries for Ricket's independent decode relations. -->

# Ricket decode

Ricket decodes each instruction directly into the controls consumed by one
pipeline component. There is no intermediate instruction-kind enum. The final
`RicketControl` bundle is only the structural product of those independently
authored control columns.

| File | Owned result |
|---|---|
| [`alu-ctrl.rhdl`](alu-ctrl.rhdl) | Reusable ALU selection and modifiers, plus complete-domain address and unused-result cases |
| [`operand-ctrl.rhdl`](operand-ctrl.rhdl) | Register use, operand routing, and immediate format |
| [`branch-ctrl.rhdl`](branch-ctrl.rhdl) | Orthogonal branch-resolver controls and JALR target selection |
| [`mem-ctrl.rhdl`](mem-ctrl.rhdl) | Load/store operation and unsigned extension plus selection of the shared `MemoryWidth` |
| [`multiply-ctrl.rhdl`](multiply-ctrl.rhdl) | Zmmul signedness and high/word result selection |
| [`writeback-ctrl.rhdl`](writeback-ctrl.rhdl) | Architectural write enable and result source |
| [`system-ctrl.rhdl`](system-ctrl.rhdl) | Zicsr operations, ECALL/EBREAK, and MRET/SRET |
| [`decode-support.rhdl`](decode-support.rhdl) | Instruction-pattern adaptation, relation composition, and instruction-family helpers |
| [`core-ctrl.rhdl`](core-ctrl.rhdl) | Host-side column composition and the XLEN-selected integrated decoder circuit |

Each component file owns its decoder-facing control bundle and instruction
families. XLEN-independent controls are authored against the exact shared
`InstructionSpec` objects from `integer-common.rhm`. The ALU and operand
relations accept each catalog's own `SLLI`, `SRLI`, and `SRAI` specs, whose
encodings genuinely differ, and append explicit RV64-only operation groups.
No catalog is treated as the source of another, and no instruction is rebound
by name. Both complete relations get their own `ValidDecodeGen`; this creates
one selected table in a core specialization, not parallel decoders. Component
files do not import one another. Memory decode uses the `MemoryWidth` owned by the reusable
[`LoadGen`/`StoreGen`](../../load-store.rhdl) datapath contract instead of
defining a decoder-local duplicate. `core-ctrl.rhdl` iterates over the canonical
selected catalog, looks up one output pattern from every relation, and nests
those patterns into one `RicketControl` case. This is ordinary host code
over `Pattern` and `DecodeCase`, not another decode-library primitive.

Relations express architectural requirements rather than defensive defaults.
For example, a store constrains its memory operation and width but not load
extension; a non-writing instruction constrains write enable but not its result
source; and an instruction that does not consume the ALU result leaves the
whole ALU control unconstrained. `DecodeGen` preserves those omitted fields as
synthesis don't-cares, including all result fields for unmatched instructions.
Component tables use `decode_groups` directly. Its `group inputs:` form accepts
the named host instruction-family lists, avoiding component-specific wrappers
whose only job would be to construct and distribute one output pattern.

`multiply-ctrl.rhdl` decodes the four RV32 Zmmul instructions and RV64 `MULW`
into a nested reusable `MultiplierMode` plus orthogonal high-result and
word-result controls. `system-ctrl.rhdl` adds the six Zicsr operations and the
initial privileged returns. `core-ctrl.rhdl` composes both columns with the
base ISA columns into the same selected decode table.

`core-ctrl.rhdl` is a composition facade, not another source of controls. Its
selected `ValidDecodeGen` preserves every nested care mask and emits one
hardware decode operation. The focused decoder test checks all 52 RV32 and 65
RV64 Ricket rows against their canonical instruction-pattern domains.
