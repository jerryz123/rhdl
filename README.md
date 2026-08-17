<!-- Introduces RHDL, provides a first circuit, and routes readers to component-owned documentation. -->

# RHDL

> Yes, all the code here was written by a LLM. The only text not produced by a LLM is this disclaimer. I worked with a coding agent to implement everything here to my personal preferences.

RHDL is an experimental Rhombus-hosted hardware description language. Ordinary
Rhombus computation elaborates and verifies a public hardware IR. Optional
consumers can inspect that IR or lower it through CIRCT to SystemVerilog.

The project explores language-oriented programming for hardware design: a
small semantic core supports progressively richer languages and libraries.
The same circuit can be written explicitly against the IR, through a
construction kernel, through selected language layers, or with concise
standard syntax without creating competing hardware semantics.

RHDL does not emit SystemVerilog itself. CIRCT owns RTL generation.

Dependency-neutral host refinements shared by the pure model and hardware
packages live under [`host/`](host/README.md).

RFPL is the physical-annotation language above RHDL. It classifies existing
RHDL circuits as opaque hard macros or wiring-only composite floorplans, adds
exact rectangular dimensions and child-instance coordinates, and leaves the
logical IR and generated RTL unchanged. See the
[RFPL plan](rfpl/PLAN.md).

## Architecture

```text
#lang rhdl ------> standard ------> foundation + curated layers
#lang rhdl/base ------------------> foundation + selected layers
                                             |
                                             v
                                    elaboration kernel
                                             |
                                             v
                                       public core IR
                                        /           \
                                       v             v
                             inspection tools   optional CIRCT backend
                                                     |
                                                     v
                                               SystemVerilog
```

Macro expansion is not a second hardware IR. A concept belongs in core only
when it introduces hardware meaning that verification and backends must
preserve. Notation, organization, and policy over existing semantics belong in
frontend layers or ordinary libraries.

The authoritative package graph and dependency contract are in
[`rhdl/README.md`](rhdl/README.md).

> **Design perspectives:** the
> [RHDL comparison guide](docs/comparisons/README.md) contrasts RHDL with
> construction languages, rule-based and functional HDLs, timing-typed
> research languages, compiler IRs, multi-level modeling systems, and
> SystemVerilog. It focuses on core semantics, abstraction expressivity,
> syntactic clarity, and compositionality.

## Quick start

### Requirements

- Racket 9.2 or a compatible current release
- The Rhombus package
- CIRCT and Verilator only for external backend integration tests

On a Homebrew-based macOS setup:

```sh
brew install minimal-racket
raco pkg install --auto rhombus
```

On x86-64 Linux or Apple Silicon macOS, install the pinned CIRCT release into
the ignored `.tools` directory:

```sh
make setup-circt
```

On other platforms, install CIRCT separately and set `CIRCT_OPT` to the path
of `circt-opt` when running backend integration tests.

### First circuit

```rhombus
#lang rhdl

circuit Adder(width):
  input(a, b): Bits(width)
  output sum: Bits(width)
  sum <== a + b

def design = elaborate(Adder(8))

export:
  Adder
  design
```

Run the standard adder from the checkout:

```sh
racket -S "$(pwd)" examples/lop/adder-standard.rhdl
```

Run all canonical examples or the complete test suite:

```sh
make examples
make test
```

Use the focused commands in [`tests/README.md`](tests/README.md) while
developing.

## Documentation

Detailed documentation lives with the component that owns it:

| Topic | Document |
|---|---|
| Shared dependency-neutral host refinements | [`host/README.md`](host/README.md) |
| Package graph and dependency rules | [`rhdl/README.md`](rhdl/README.md) |
| RFPL structural language and roadmap | [`rfpl/PLAN.md`](rfpl/PLAN.md) |
| Language and compiler design comparisons | [`docs/comparisons/README.md`](docs/comparisons/README.md) |
| Core semantics, IR, Builder, and verification | [`rhdl/core/README.md`](rhdl/core/README.md) |
| Elaboration, profiles, and extension boundaries | [`rhdl/frontend/README.md`](rhdl/frontend/README.md) |
| Frontend feature and syntax guide | [`rhdl/frontend/layers/README.md`](rhdl/frontend/layers/README.md) |
| Host utilities, protocols, and reusable circuit generators | [`rhdl/std/README.md`](rhdl/std/README.md) |
| TileLink parameters, monitored interfaces, legality checks, and RAM manager | [`tilelink/README.md`](tilelink/README.md) |
| AMBA CHI parameters, exact flits, credited node links, and link-local monitors | [`chi/README.md`](chi/README.md) |
| CIRCT lowering and SystemVerilog generation | [`rhdl/backend/README.md`](rhdl/backend/README.md) |
| Language-oriented walkthrough and examples | [`examples/README.md`](examples/README.md) |
| Test organization and focused commands | [`tests/README.md`](tests/README.md) |
| Project-aware Emacs integration | [`tools/emacs/README.md`](tools/emacs/README.md) |
| CIRCT fixtures, simulation, and Verilog goldens | [`tests/backend/README.md`](tests/backend/README.md) |
| Direct-memory FESVR transport | [`sim/fesvr/README.md`](sim/fesvr/README.md) |
| RISC-V instruction model, RV32I/RV64I catalogs, and RHDL adapter | [`riscv/README.md`](riscv/README.md) |
| Reusable processor components and named cores | [`cores/README.md`](cores/README.md) |

## Current status

The current vertical slice includes:

- An RFPL physical-annotation language whose hard macros may contain arbitrary
  RHDL logic and whose composite floorplans classify existing wiring-only
  circuits, with exact dimensions and contained child-instance coordinates.
- A public, inspectable, backend-independent IR with explicit-width types,
  structural aggregates, primitive state and memories, clocked assertions, DPI
  simulation operations, single-driver verification, and combinational-cycle
  detection.
- Standard and compositional Rhombus profiles with host-only generation,
  frontend-defined types including explicit-width signed integers, typed
  literals and patterns, relational decode generation, combinational and
  sequential constructs, hierarchy, directional interfaces, and reusable
  protocol libraries.
- Deterministic CIRCT lowering with example-owned SystemVerilog references and
  Verilator simulations.
- Ricket, a standalone five-stage RV32I/RV64I integer core with direct component-oriented
  structured decode, separate instruction and data memory ports, forwarding,
  load-use stalls, redirect flushing, and fault-stop behavior. Its typed,
  shared integer ALU remains independently reusable.

## Deferred work

- General last-connect and unordered multiple-driver semantics
- Automatic module-specialization deduplication
- A dedicated `UInt` distinct from raw `Bits`, implicit widths, and general
  width inference
- Memory initialization, masks on asynchronous-read memories, general
  multi-port synchronous memories, and defined inter-port collisions
- Asynchronous reset, reset-polarity metadata, and multi-domain analysis
- General IR regions and control-flow blocks
- Runtime-loaded operation dialects
- Multi-role protocols, optional interface fields, and generated protocol
  assertions
- User-authored IR mutation and rewriting before a concrete transformation
  defines transaction and handle-validity requirements

Hardening work remains focused on diagnostics, deterministic goldens,
property-based and differential testing, and a future public IR compatibility
policy.
