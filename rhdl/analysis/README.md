<!-- Documents optional backend-independent analyses over RHDL core IR. -->

# RHDL analysis

Analysis packages inspect verified public core IR without changing hardware,
authoring syntax, or backend output. They may depend on `rhdl/core/`; core does
not depend on analysis. Frontends and downstream tools may opt into an
analysis when they need its policy or reports.

## Clocking analysis

[`clocking.rhm`](clocking.rhm) is the public entry point for clock-use
certification and temporal provenance analysis. Its implementation is split
under [`clocking/`](clocking/):

- `types.rhm` defines clock-use summaries, provenance, environments,
  relationships, and report objects.
- `module.rhm` inventories explicit clock/reset operands and builds reusable,
  hierarchy-aware module summaries.
- `environment.rhm` resolves one module summary against validated top-level
  input timing and clock-relationship declarations.

`summarize_module_clocking` returns `Combinational`, `SingleClock`, or
`MultiClock` and inventories reset use separately as `NoReset`,
`AmbientReset`, or `LocalReset`. `verify_single_clock` is used by frontend
`sync_circuit` support to certify its ambient-clock policy. Clock identity
follows transparent `rtl.wire` aliases only; a cast to `Clock` is not identity
evidence.

`summarize_module_temporal` computes a report-only, leaf-sensitive temporal
summary for a completed module hierarchy. Origins remain static, symbolic
module inputs, or state tied to a concrete instance path and clock/reset.
Symbolic child inputs are substituted at each instance, so one definition can
be reused under different clocks without specialization or flattening.

`summarize_design_temporal` starts from an explicit `DesignElaboration` top.
A `TemporalEnvironment` binds top data-input aggregate subtrees to unknown,
synchronous-to-clock, or asynchronous timing and may declare top clocks
identical, derived, asynchronous, or exclusive. Exact signal identity remains
distinct from declared equivalence. Malformed, overlapping, duplicate, and
contradictory declarations are rejected.

Both temporal analyzers expose inspectable objects and deterministic reports.
Their current classifications are findings only: they do not approve a
crossing, reject CDCs, mutate core IR, or affect backend lowering. Future
crossing operations that change hardware meaning must remain explicit core IR;
optional authoring notation belongs in a frontend layer. The selectable
[`../frontend/layers/clocking.rhm`](../frontend/layers/clocking.rhm) layer now
collects root-owned environment declarations and invokes this analysis without
changing the design.
