<!-- Introduces RHDL, provides a first circuit, and routes readers to component-owned documentation. -->

# RHDL

RHDL is an experimental Rhombus-hosted hardware description language. Ordinary
Rhombus computation elaborates and verifies a public hardware IR. Optional
consumers can inspect that IR or lower it through CIRCT to SystemVerilog.

The project explores language-oriented programming for hardware design: a
small semantic core supports progressively richer languages and libraries.
The same circuit can be written explicitly against the IR, through a
construction kernel, through selected language layers, or with concise
standard syntax without creating competing hardware semantics.

RHDL does not emit SystemVerilog itself. CIRCT owns RTL generation.

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

On Apple Silicon macOS, install the pinned CIRCT release into the ignored
`.tools` directory:

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
| Package graph and dependency rules | [`rhdl/README.md`](rhdl/README.md) |
| Core semantics, IR, Builder, and verification | [`rhdl/core/README.md`](rhdl/core/README.md) |
| Elaboration, profiles, and extension boundaries | [`rhdl/frontend/README.md`](rhdl/frontend/README.md) |
| Frontend feature and syntax guide | [`rhdl/frontend/layers/README.md`](rhdl/frontend/layers/README.md) |
| Host utilities, protocols, and reusable circuit generators | [`rhdl/std/README.md`](rhdl/std/README.md) |
| CIRCT lowering and SystemVerilog generation | [`rhdl/backend/README.md`](rhdl/backend/README.md) |
| Language-oriented walkthrough and examples | [`examples/README.md`](examples/README.md) |
| Test organization and focused commands | [`tests/README.md`](tests/README.md) |
| CIRCT fixtures, simulation, and Verilog goldens | [`tests/backend/README.md`](tests/backend/README.md) |
| Direct-memory FESVR transport | [`sim/fesvr/README.md`](sim/fesvr/README.md) |

## Language-oriented equivalence

The programs under [`examples/lop/`](examples/lop/) construct the same adder
at four levels:

1. Direct public IR construction with `Design` and `Builder`.
2. Explicit construction through the elaboration kernel.
3. `#lang rhdl/base` plus an explicit combinational import.
4. Concise construction through standard `#lang rhdl`.

The sources become progressively shorter while producing identical printed
RHDL IR and CIRCT MLIR:

```sh
make lop-test
```

This executable equivalence is the central architectural claim: layers improve
the authoring language without fragmenting the hardware model.

## Repository conventions

```text
rhdl/             implementation and component-owned documentation
examples/         canonical valid authoring programs
tests/core/       backend-independent semantic tests
tests/frontend/   frontend behavior and invalid-language fixtures
tests/backend/    CIRCT lowering, goldens, and Verilator simulations
sim/              optional simulation support
tools/            repository and toolchain scripts
```

`.rhdl` is reserved for RHDL-profile programs, simulation adapters, and
frontend fixtures. `.rhm` contains Rhombus implementation and library modules.
`.rkt` is restricted to reader shims and Racket interoperability where
collection lookup requires it.

Generated Racket, CIRCT, SystemVerilog, and Verilator output stays out of
version control.

## Current status

The current vertical slice includes:

- A public, inspectable, backend-independent IR with values, places,
  operations, modules, instances, primitive registers, memories, and DPI
  simulation operations.
- Explicit-width bit vectors, open hardware-type capabilities, structural
  records and vectors, single-driver verification, and combinational-cycle
  detection.
- Standard and compositional Rhombus language profiles with host-only generator
  parameters and deterministic fresh module construction.
- Frontend-defined Boolean, enum, and one-hot types; combinational and
  width-changing expressions; bundles, vectors, wires, memories, hierarchy,
  ambient synchronous domains, and hardware conditional assignment.
- Typed host-side patterns over scalar, extension-defined, and recursively
  aggregate hardware literals.
- Directional interfaces with nesting, refinement, supported contracts, bulk
  connection, and a reusable ready-valid flow library.
- Deterministic CIRCT lowering, example-owned SystemVerilog references, and
  Verilator simulations.

This section is the sole completion ledger; component documents explain the
implemented contracts without maintaining separate milestone lists.

## Deferred work

- General last-connect and unordered multiple-driver semantics
- Automatic module-specialization deduplication
- Distinct `UInt` and `SInt`, implicit widths, and general width inference
- Memory initialization, masks, synchronous reads, and defined collisions
- Asynchronous or active-low reset and multi-domain analysis
- General IR regions and control-flow blocks
- Runtime-loaded operation dialects
- Arithmetic right shift before signed types exist
- Multi-role protocols, optional interface fields, and generated protocol
  assertions
- User-authored IR mutation and rewriting before a concrete transformation
  defines transaction and handle-validity requirements

Hardening work remains focused on diagnostics, deterministic goldens,
property-based and differential testing, and a future public IR compatibility
policy.

## Design commitments

- Keep one public hardware IR until a concrete feature requires another.
- Keep frontend conveniences out of core when existing hardware semantics are
  sufficient.
- Keep backends independent of frontend syntax and metadata.
- Use CIRCT rather than an RHDL-owned SystemVerilog emitter.
- Keep widths explicit and elaboration deterministic.
- Keep generator parameters in the host language and runtime data in hardware.
- Specify and test implicit conversion, connection, priority, or reset behavior
  before adding it.
