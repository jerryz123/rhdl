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

`summarize_module_temporal` computes a leaf-sensitive temporal summary for a
completed module hierarchy. Origins remain static, symbolic module inputs,
state tied to a concrete instance path and clock/reset, or a crossed origin
that retains its `cdc.sync_level` identity, source lineage, and destination
clock.
Symbolic child inputs are substituted at each instance, so one definition can
be reused under different clocks without specialization or flattening.

Both module and closed-design summaries expose structured
`CrossingReconvergence` findings when two or more distinct crossing identities
reach one clocked sink. Each finding retains the sink, input-leaf paths,
crossing hierarchy paths, and original source lineage. Reconvergence is a
diagnostic rather than a blanket CDC error because independently synchronized
controls can legitimately meet; repeated fanout from one crossing identity is
not reported.

`summarize_design_temporal` starts from an explicit `DesignElaboration` top.
A `TemporalEnvironment` binds top data-input aggregate subtrees to unknown,
synchronous-to-clock, or asynchronous timing and may declare top clocks
identical, derived, asynchronous, or exclusive. Exact signal identity remains
distinct from declared equivalence. Malformed, overlapping, duplicate, and
contradictory declarations are rejected.

Both temporal analyzers expose inspectable objects and deterministic reports.
Every closed-design summary contains structured `CdcViolation` findings for
all unsafe sink leaves, including their hierarchy paths, classifications,
origins, and reasons. `verify_design_cdc` applies the same conservative policy
and rejects once with the complete deterministic list: raw incompatible,
unknown, or asynchronous sampling is unsafe; verified `cdc.sync_level`
evidence approves one declared timing source at its first destination stage;
multi-clock fan-in and unknown external timing remain errors. Synchronous reset
inputs are still reported but excluded from CDC enforcement until RDC
semantics are defined. Strict verification returns the same reconvergence
findings without rejecting otherwise verified crossings.

The [`../frontend/layers/clocking.rhm`](../frontend/layers/clocking.rhm) layer
collects root-owned environment declarations, exposes report-only
`elaborate_with_clocking`, and exposes strict `elaborate_with_cdc`. The CIRCT
backend derives `async_reg` attributes only from core-verified evidence.
