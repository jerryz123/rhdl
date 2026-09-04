<!-- Defines ownership and composition boundaries for RV5Stage's independent decode relations. -->

# RV5Stage decode

RV5Stage decodes each instruction directly into the controls consumed by one
pipeline component. There is no intermediate instruction-kind enum. The final
`RV5StageControl` bundle is only the structural product of those independently
authored control columns.

| File | Owned result |
|---|---|
| [`alu-ctrl.rhdl`](alu-ctrl.rhdl) | Reusable ALU selection and modifiers, plus complete-domain address and unused-result cases |
| [`operand-ctrl.rhdl`](operand-ctrl.rhdl) | Register use, operand routing, and immediate format |
| [`branch-ctrl.rhdl`](branch-ctrl.rhdl) | Orthogonal branch-resolver controls and JALR target selection |
| [`mem-ctrl.rhdl`](mem-ctrl.rhdl) | Load/store operation and unsigned extension plus selection of the shared `MemoryWidth` |
| [`multiply-ctrl.rhdl`](multiply-ctrl.rhdl) | Zmmul signedness and high/word result selection |
| [`divide-ctrl.rhdl`](divide-ctrl.rhdl) | M signedness and quotient/remainder/word result selection |
| [`writeback-ctrl.rhdl`](writeback-ctrl.rhdl) | Architectural write enable and result source |
| [`system-ctrl.rhdl`](system-ctrl.rhdl) | Zicsr operations, ECALL/EBREAK, and MRET/SRET |
| [`fence-ctrl.rhdl`](fence-ctrl.rhdl) | FENCE, FENCE.I, and SFENCE.VMA serialization and translation-fence controls |
| [`fp-ctrl.rhdl`](fp-ctrl.rhdl) | Profile-selected F/D register-bank use and direct floating-point execution-unit controls |
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
those patterns into one `RV5StageControl` case. This is ordinary host code
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
word-result controls. `divide-ctrl.rhdl` decodes the four RV32 divide/remainder
instructions and four RV64 word variants into orthogonal signed, remainder,
and word-result controls. `system-ctrl.rhdl` adds the six Zicsr operations and
the initial privileged returns. `fence-ctrl.rhdl` owns architectural
serialization and translation fences. `core-ctrl.rhdl` composes these columns
with the base ISA columns into the same selected decode table.

`fp-ctrl.rhdl` is currently an independent decoder, deliberately
not a column of `RV5StageControl` yet. It derives integer/FPR source use and the
destination register bank from each `InstructionSpec` operand list instead of
duplicating that metadata. Its sparse execution relation selects memory, FMA,
add, multiply, divide/square-root, sign, min/max, comparison, conversion, move,
or classification controls. A D profile combines the F and D catalogs in host
code before constructing a single `ValidDecodeGen`; it does not instantiate
parallel F and D decoders.

`core-ctrl.rhdl` is a composition facade, not another source of controls. Its
selected `ValidDecodeGen` preserves every nested care mask and emits one
hardware decode operation. The focused decoder test checks every selected RV32
and RV64 RV5Stage row against its canonical instruction-pattern domain; the
catalog-derived coverage avoids a documentation count that drifts as supported
extensions grow.
