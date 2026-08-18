<!-- Tracks how canonical RHDL core semantics, frontend features, and standard-library families appear in Golf. -->

# RHDL Golf coverage

This matrix records how the complete RHDL authoring stack appears under
`#lang rhdl/golf`. It does not redefine canonical features. The owning
inventories remain the [core semantic model](../core/README.md), the
[frontend layer catalog](../frontend/layers/README.md), and the
[standard-library module table](../README.md#standard-library-dependencies).

Golf has two independent coverage guarantees:

1. **Language coverage:** every binding exported by `#lang rhdl` is available
   with its canonical spelling under `#lang rhdl/golf`.
2. **Compression coverage:** selected repeated spellings have Golf-specific
   shorthand that expands to the canonical frontend.

A feature marked `identity` is therefore supported, not missing. It remains
canonical syntax because shortening it would save little, obscure hardware
meaning, or duplicate an API owned by another package.

## Status vocabulary

| Status | Meaning |
|---|---|
| `implemented` | Golf shorthand exists with focused expansion/equivalence coverage |
| `partial` | Some common canonical forms have shorthand, while supported cases still require canonical syntax |
| `planned` | The shorthand and canonical expansion are accepted in [`PLAN.md`](PLAN.md) but not implemented |
| `identity` | The canonical spelling is intentionally the Golf spelling |
| `candidate` | Compression may be useful, but no syntax is accepted yet |
| `not applicable` | The capability is not a source-language feature and must not acquire Golf syntax |

## Implemented evidence

| Golf surface | Canonical expansion | Executable evidence |
|---|---|---|
| `B(width)` | [`Bits(width)`](README.md#bwidth) | [`golf-test.rhm`](../../tests/frontend/golf-test.rhm) checks exact type equality |
| `sel(selector, default, choices...)` | Dense zero-based [`mux_lookup`](README.md#selselector-default-choices) | Golf [`alu.rhdl`](../../examples/golf/alu.rhdl) has exact frontend IR and backend CIRCT equivalence |
| Compact `c` | [`circuit`, ports, and explicit drives](README.md#compact-circuits) | Golf [`adder.rhdl`](../../examples/golf/adder.rhdl) and [`alu.rhdl`](../../examples/golf/alu.rhdl) plus frontend IR and [backend CIRCT](../../tests/backend/golf-equivalence-test.rhm) equivalence |
| `top circuit` | [`def design = elaborate(circuit)`](README.md#top) | The Golf adder and [`golf-test.rhm`](../../tests/frontend/golf-test.rhm) verify the resulting design |
| Complete standard profile | Identity re-export from `#lang rhdl` | [`golf-standard.rhdl`](../../tests/frontend/golf-standard.rhdl) checks unchanged canonical syntax |

## Foundation and language profile

| Canonical feature | Golf status | Golf spelling or policy |
|---|---|---|
| `Bits(width)` | `implemented` | `B(width)` is a transparent type and annotation alias |
| `Clock`, `Reset` | `identity` | Names remain explicit and already short |
| `circuit` plus data ports | `implemented` | `c` supports homogeneous and heterogeneous groups, empty sides, and single- or multiple-output expression bodies |
| Heterogeneous port groups | `implemented` | Comma-delimited names accumulate until an explicit type closes the group |
| Multiple outputs | `implemented` | Bracketed bodies positionally drive typed outputs with exact arity; explicit named drives remain available |
| Empty input or output side | `implemented` | The mandatory `->` may have no typed groups on either side |
| `sync_circuit` | `planned` | `sc` will reuse the complete compact port grammar and canonical ambient-domain policy |
| `input`, `output` | `identity` | Remain available inside canonical circuit declarations and where a compact header is not useful |
| `<==` connection | `identity` | The operator visibly identifies a hardware drive and is already minimal |
| `elaborate(circuit)` | `implemented` | `top circuit` defines `design` through one ordinary `elaborate` call |
| Named elaboration binding | `planned` | `top name = circuit` expands to `def name = elaborate(circuit)` |
| `elaborate_with_top` | `identity` | Top selection and inspection policy remain explicit |
| Host definitions, functions, loops, reducers, and imports | `identity` | Ordinary Rhombus host computation remains unchanged |

## Core semantic groups

Golf never imports or exposes the Builder to implement shorthand. These rows
track which frontend spellings reach each semantic group from the
[core operation catalog](../core/README.md#operation-model).

| Core capability | Golf status | Mapping policy |
|---|---|---|
| Module structure and ports | `implemented` | Compact `c` lowers data ports through canonical `circuit`, `input`, and `output`; interface boundaries remain canonical |
| Drives | `identity` | `<==` remains unchanged |
| Instances | `planned` | `x name(args...)` will be a direct alias for canonical `inst` |
| Internal wires | `planned` | `w name: T` will be a direct alias for canonical `wire` |
| Constants | `planned` | `b(value, width)` and `si(value, width)` will abbreviate typed literal constructors |
| Synthesis don't-care | `identity` | `dont_care(T)` remains explicit |
| Bitwise operations | `identity` | `!`, `&`, `|||`, and `^` are already compact and retain hardware/host distinctions |
| Modular arithmetic and shifts | `identity` | Existing operators remain unchanged; only type and literal names may shorten |
| Equality and ordering | `identity` | Existing typed operators and predicates remain unchanged |
| Mux and decode selection | `partial` | `sel` abbreviates dense zero-based `mux_lookup`; sparse, typed-key, Boolean, and one-hot selection remain canonical |
| Casts and width changes | `identity` | Explicit representation and width changes must remain visible |
| Records | `identity` | Bundle and record declarations, construction, and projection remain canonical |
| Vectors | `planned` | `V(length, T)` will alias `Vec(length, T)`; construction, indexing, and update remain canonical |
| Asynchronous memory resource | `planned` | `m name(depth, T)` will alias canonical `mem` without changing port or timing policy |
| Synchronous memory primitive | `identity` | Physical port shape, latency, and masks remain canonical and explicit |
| Registers | `planned` | `r name(args...)` will alias canonical `reg` and inherit its inference and reset rules |
| Assertions | `identity` | Clock, reset suppression, guards, and labels remain explicit |
| DPI simulation effects | `identity` | Procedure and result-register forms retain their canonical names |
| Core types, IR, Builder, verifier, and printer APIs | `not applicable` | These are implementation and inspection APIs, not Golf authoring syntax |

## Frontend layers

The row key is the owning module from the
[authoritative layer catalog](../frontend/layers/README.md#layer-catalog).

| Layer | Golf status | Golf-specific mapping |
|---|---|---|
| `cast.rhm` | `identity` | Cast, packing, and splitting forms remain explicit |
| `comb.rhm` | `partial` | `sel` implements dense lookup shorthand; `b` remains planned, while operators, sparse muxes, don't-cares, and width operations remain canonical |
| `signed.rhm` | `planned` | `S(width)` and `si(value, width)` shorten `SInt` and `sint`; signed operators and resizing remain unchanged |
| `expanding-arithmetic.rhm` | `identity` | `+&` and `*&` are already Golf-sized and semantically explicit |
| `bool.rhm` | `identity` | `Bool`, reductions, comparisons, membership, validity, encoders, and `mux` retain canonical spelling |
| `enum.rhm` | `identity` | Enum declarations and members retain their domain names |
| `one-hot.rhm` | `planned` | `OH(width)` shortens `OneHot(width)`; literals and selection remain canonical |
| `bundle.rhm` | `identity` | Bundle declarations, records, literals, and fields remain canonical |
| `vector.rhm` | `planned` | `V(length, T)` shortens `Vec(length, T)`; vector operations remain canonical |
| `wire.rhm` | `planned` | `w` directly aliases `wire` |
| `sequential.rhm` | `planned` | `r` directly aliases `reg`; next-state drives remain `<==` |
| `memory.rhm` | `planned` | `m` directly aliases `mem`; reads, writes, addresses, enables, and clocks remain explicit |
| `sync-memory.rhm` | `identity` | Fixed physical port kinds and masks remain canonical |
| `assertion.rhm` | `identity` | Assertions remain named, clocked verification effects |
| `dpi.rhm` | `identity` | DPI imports, calls, and result registers remain canonical |
| `conditional.rhm` | `identity` | Hardware `when`, `elsewhen`, and `switch` remain visibly distinct from host control |
| `hierarchy.rhm` | `planned` | `x` directly aliases `inst`; member access and instance arrays remain canonical |
| `sync.rhm` | `planned` | `sc` directly aliases `sync_circuit` after compact headers support its complete port grammar |
| `interface.rhm` | `identity` | Roles, refinements, endpoint shapes, handles, sinks, `<=>`, and `|>` remain canonical |

## Standard library

Golf imports and uses public `rhdl/std` modules directly. A protocol,
component, or helper is not copied into `rhdl/golf`, and Golf does not create
parallel flow, memory, decode, or interconnect dialects.

| Standard-library family | Golf status | Mapping policy |
|---|---|---|
| Host utilities: `bits`, `interconnect` | `identity` | Refinements, sets, alignment, and allocation helpers keep their public names |
| Small state components: `counter`, `scoreboard` | `identity` | Circuit generators and methods keep their public names |
| Decode: `decode/*`, `decode.rhdl` | `identity` | Patterns, tables, relations, and generators remain explicit library APIs |
| Protocols: `ready-valid`, `credited`, `read-write` | `identity` | Nominal protocol types, endpoint helpers, and monitors keep their public names |
| Memories: `simple-memory`, `simple-memory/ram`, `sync-ram` | `identity` | Protocol and physical timing distinctions remain explicit |
| Flow control: every `std/flow/*` module and `flow.rhdl` | `identity` | Stages, topology helpers, `|>`, and `<=>` keep their canonical spelling |
| Explicit std imports | `candidate` | A future short import form may compress `lib("rhdl/std/...")`, but each dependency must remain source-visible |

The [standard-library dependency table](../README.md#standard-library-dependencies)
is exhaustive. Every module in that table inherits `identity` coverage unless
this section names a narrower Golf policy.

## Deliberate non-mappings

Golf does not map:

- backend lowering, CIRCT, Verilog generation, or simulation harnesses;
- formal engines or proof APIs;
- RFPL or domain packages such as NoC, RISC-V, TileLink, CHI, or processor
  cores;
- core Builder or raw IR construction;
- implicit widths, unsized hardware literals, implicit conversions, inferred
  clocks/resets, inferred interfaces, or automatic state; or
- library-specific aliases and wrappers that would fork an owning public API.

Those capabilities may be consumed by a Golf-authored design through their
ordinary public boundaries, but they are not Golf syntax.

## Maintenance rule

When a core operation group, frontend layer, or public standard-library family
is added, this file must classify it as `identity`, `planned`, `candidate`, or
`not applicable` before Golf-specific syntax is proposed. Implemented shorthand
must link to a canonical expansion and focused equivalence coverage. Character
savings alone do not justify semantic inference.
