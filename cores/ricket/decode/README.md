<!-- Defines ownership and composition boundaries for Ricket's independent decode relations. -->

# Ricket decode

Ricket decodes each instruction directly into the controls consumed by one
pipeline component. There is no intermediate instruction-kind enum. The final
`RV64IControl` bundle is only the structural product of those independently
authored control columns.

| File | Owned result |
|---|---|
| [`alu-ctrl.rhdl`](alu-ctrl.rhdl) | Reusable ALU selection and modifiers, plus complete-domain address and unused-result cases |
| [`operand-ctrl.rhdl`](operand-ctrl.rhdl) | Register use, operand routing, and immediate format |
| [`branch-ctrl.rhdl`](branch-ctrl.rhdl) | Orthogonal branch-resolver controls and JALR target selection |
| [`mem-ctrl.rhdl`](mem-ctrl.rhdl) | Load/store operation and unsigned extension plus selection of the shared `MemoryWidth` |
| [`writeback-ctrl.rhdl`](writeback-ctrl.rhdl) | Architectural write enable and result source |
| [`trap-ctrl.rhdl`](trap-ctrl.rhdl) | Synchronous trap indication |
| [`decode-support.rhdl`](decode-support.rhdl) | Canonical instruction-pattern adaptation and instruction-family exclusion helpers |
| [`core-ctrl.rhdl`](core-ctrl.rhdl) | Host-side column composition and the integrated decoder circuit |

Each component file owns its decoder-facing control bundle,
instruction-family lists, complete 52-row relation, and standalone
`ValidDecodeGen`. Component files do not import one another. Memory decode uses
the `MemoryWidth` owned by the reusable
[`LoadGen`/`StoreGen`](../../load-store.rhdl) datapath contract instead of
defining a decoder-local duplicate. `core-ctrl.rhdl` iterates over the canonical
`RV64IInstructions` list, looks up one output pattern from every relation, and
nests those patterns into one `RV64IControl` case. This is ordinary host code
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

`core-ctrl.rhdl` is a composition facade, not another source of controls. Its
single `ValidDecodeGen` preserves every nested care mask and emits one hardware
decode operation. The focused decoder test separately rejects missing, extra,
or duplicate component rows against the canonical instruction-pattern domain.
