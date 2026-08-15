<!-- Defines the RHDL implementation package graph and its enforced dependency contract. -->

# RHDL implementation architecture

RHDL has one backend-independent hardware model and multiple authoring layers.
Every frontend path elaborates into the same public core IR; frontend syntax is
not a second IR.

## Package graph

```text
#lang rhdl --------------------> frontend/standard
                                      |
                                      +----> frontend/foundation
                                      +----> frontend/layers/*

#lang rhdl/base ---------------> frontend/foundation
user base-profile imports -----> selected frontend/layers/*

std/* -------------------------> public #lang rhdl authoring surface
sim/* -------------------------> public #lang rhdl authoring surface
riscv/rhdl --------------------> public #lang rhdl authoring surface
user designs ------------------> optional std/* libraries

frontend/foundation -----------+
frontend/layers/* -------------+----> frontend/support/*
                               +----> frontend/kernel ----> core
frontend/{foundation,layers,support} ---------------------> approved core APIs

backend/circt ---------------------------------------------> core
```

`#lang rhdl` is the curated language. `#lang rhdl/base` is the composition
profile: it exposes the foundation and allows a program to import only the
language layers it wants. The word *base* names the public profile; the
internal module implementing its shared frontend forms is called the
*foundation*.

## Responsibilities

| Area | Responsibility | May depend directly on |
|---|---|---|
| [`core/`](core/README.md) | Types, IR, Builder, verification, and printing | Other core modules and Rhombus libraries |
| [`frontend/kernel.rhm`](frontend/kernel.rhm) | Context-sensitive elaboration and deferred frontend hardware values over the public core | Core |
| [`frontend/support/`](frontend/support/) | Shared cross-layer protocols, macros, and static-information machinery; not a language profile | Kernel, approved core APIs, other support modules |
| [`frontend/foundation.rhm`](frontend/foundation.rhm) | Circuits, ports, connections, elaboration, basic types, selection, and casts | Kernel, support, approved core type APIs |
| [`frontend/layers/`](frontend/layers/README.md) | Independently selectable notation and abstractions over existing semantics | Kernel, support, approved core APIs |
| [`frontend/standard.rhm`](frontend/standard.rhm) | Aggregation only; defines no feature behavior | Foundation and all standard layers |
| [`language.rhm`](language.rhm), [`base/language.rhm`](base/language.rhm) | Compose ordinary Rhombus host control with one public RHDL profile | Standard or foundation |
| [`std/`](std/README.md) | Optional host utilities, protocols, and circuit generators written in ordinary RHDL | Public `#lang rhdl` authoring surface only |
| [`backend/`](backend/README.md) | Consume verified public IR; currently lower it through CIRCT | Core only |
| [`../sim/`](../sim/fesvr/README.md) | Optional simulation adapters and external runtime support | Public `#lang rhdl` authoring surface only; external C++ libraries |
| [`../riscv/rhdl/`](../riscv/rhdl/README.md) | Converts RISC-V instruction encodings into generic typed decode patterns | Pure RISC-V model; public `#lang rhdl` libraries |

The import direction is one-way. Core never imports frontend or backend code;
frontend code never imports a backend; and a backend never imports frontend
syntax or elaboration. Layers do not import sibling layers. Shared machinery
needed by multiple layers belongs in `frontend/support/`. Standard-library
modules and simulation adapters use public RHDL forms rather than importing
implementation modules.

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

## Standard-library dependencies

Standard-library modules depend only on the public authoring surface. The
flow-control aggregate is separate from its implementations, so designs can
import one primitive without loading unrelated generators.

| Module | Provides | Direct RHDL dependencies |
|---|---|---|
| `std/counter.rhdl` | Enabled bounded `Counter` | None |
| `std/bits.rhdl` | Host power-of-two testing plus alignment width, checking, and downward alignment for `Bits` | None |
| `std/interconnect.rhdl` | Protocol-neutral host-side ID ranges, masked address sets, and transfer-size sets | `std/bits.rhdl` |
| `std/decode/pattern.rhdl` | Typed host-side `Pattern` cubes, exact-literal normalization, partial records, and recursive aggregate construction | None |
| `std/decode/pattern-value.rhdl` | Partially specified hardware values from `Pattern` cubes | `std/decode/pattern.rhdl` |
| `std/decode/table.rhdl` | Validated unordered typed decode relations, grouped sparse record cases, input lifting, and row-aligned output products | `std/decode/pattern.rhdl` |
| `std/decode/generator.rhdl` | Callable `DecodeGen` and valid-tagged partial mappings lowering to one core decode | `std/decode/pattern.rhdl`, `std/decode/table.rhdl` |
| `std/decode.rhdl` | Public decode facade | `std/decode/pattern.rhdl`, `std/decode/table.rhdl`, `std/decode/generator.rhdl` |
| `std/ready-valid.rhdl` | `Valid`, `DecoupledCtrl`, `IrrevocableCtrl`, payload-bearing protocols, `fire`, and endpoint introspection | None |
| `std/tilelink/params.rhdl` | Host-side TileLink wire widths, operation capabilities, and endpoint descriptions | `std/bits.rhdl`, `std/interconnect.rhdl` |
| `std/tilelink/bundles.rhdl` | Exact TileLink A-E opcode and payload bundle types | `std/tilelink/params.rhdl` |
| `std/tilelink/link.rhdl` | Directional `TLUncached` and `TLCached` ready-valid interfaces | `std/ready-valid.rhdl`, `std/tilelink/params.rhdl`, `std/tilelink/bundles.rhdl` |
| `std/tilelink.rhdl` | Public TileLink facade | All `std/tilelink/` modules |
| `std/simple-memory.rhdl` | Ordered multi-outstanding aligned byte-addressed and byte-masked `SimpleMemory` protocol | `std/bits.rhdl`, `std/ready-valid.rhdl` |
| `std/simple-memory/ram.rhdl` | Pipelined finite masked synchronous-RAM implementation of `SimpleMemory` | `std/simple-memory.rhdl`, `std/ready-valid.rhdl`, `std/flow/queue.rhdl`, `std/flow/pipe.rhdl` |
| `std/flow/stage.rhdl` | Valid-only and ready-valid protocol and payload inference plus generic-handle application helpers | `std/ready-valid.rhdl` |
| `std/flow/pipe.rhdl` | Registered fixed-latency `ValidPipe`, elastic `Pipe`/`CtrlPipe`, and their endpoint/handle chaining | `std/ready-valid.rhdl`, `std/flow/stage.rhdl` |
| `std/flow/queue.rhdl` | Configurable FIFO `Queue`/`CtrlQueue` and typed handle construction | `std/ready-valid.rhdl`, `std/counter.rhdl`, `std/flow/stage.rhdl` |
| `std/flow/arbiter.rhdl` | Fixed-priority `Arbiter`/`CtrlArbiter` | `std/ready-valid.rhdl` |
| `std/flow/rr-arbiter.rhdl` | Round-robin `RRArbiter`/`CtrlRRArbiter` plus Array-shaped handle construction | `std/ready-valid.rhdl`, `std/flow/stage.rhdl` |
| `std/flow/demux.rhdl` | Selected one-to-many `Demux`/`CtrlDemux` plus payload-selected handle construction | `std/ready-valid.rhdl`, `std/flow/stage.rhdl` |
| `std/flow/join.rhdl` | Atomic homogeneous `Join`/`CtrlJoin` | `std/ready-valid.rhdl` |
| `std/flow/zip.rhdl` | Inline binary heterogeneous atomic `zip_flow` handles | `std/ready-valid.rhdl` |
| `std/flow/broadcast.rhdl` | Exactly-once buffered `Broadcast`/`CtrlBroadcast` | `std/ready-valid.rhdl` |
| `std/flow/atomic-fork.rhdl` | Combinational all-or-none `AtomicFork`/`CtrlAtomicFork` and array-shaped handles | `std/ready-valid.rhdl`, `std/flow/stage.rhdl` |
| `std/flow/map.rhdl` | Protocol-preserving inline payload-substitution handles | `std/ready-valid.rhdl`, `std/flow/stage.rhdl` |
| `std/flow/parallel.rhdl` | Parallel generic handle and terminated-sink composition | None |
| `std/flow.rhdl` | Valid-only and ready-valid protocols plus the flow-control convenience aggregate | `std/ready-valid.rhdl` and all `std/flow/` modules |

## Frontend layer dependencies

This table is the authoritative inventory of bundled frontend layers. Update
it when adding, removing, or changing a layer's direct dependencies.

| Layer | Provides | Direct RHDL dependencies |
|---|---|---|
| `cast.rhm` | Functional equal-width representation casts | core IR, kernel, field support |
| `comb.rhm` | Static packed literals, typed synthesis don't-cares, decode relations, modular arithmetic, bitwise operations, muxes, bit-vector zero extension, and width operations | core types, kernel, field support, hardware-literal support, mux-lookup support |
| `signed.rhm` | Explicit-width `SInt`, two's-complement literals, sign extension, signed truncation, and signed operator participation | core types and IR, kernel, field support, hardware-literal support |
| `expanding-arithmetic.rhm` | Lossless unsigned addition and multiplication with `+&` and `*&` sugar | core types, kernel, field support |
| `bool.rhm` | Nominal `Bool`, static host-Boolean literal shadows, equality and inequality, signed and unsigned ordering, and binary `mux` | core types and IR, kernel, field support, hardware-literal support |
| `enum.rhm` | Nominal sequential, explicit, and one-hot encoded hardware enums plus member literals | core IR, kernel, field support, mux-lookup support |
| `one-hot.rhm` | One-hot selector types, literals, typed mux keys, and partial `mux_onehot` selection | core IR, kernel, field support, mux-lookup support |
| `bundle.rhm` | Bundle declarations, type-named construction, generic runtime records, recursive literal shadows, and field access | core IR, kernel, field support, hardware-literal support |
| `vector.rhm` | `Vec` types, runtime vector construction, and recursive vector literal shadows | core types, kernel, field support, hardware-literal support |
| `memory.rhm` | Binding-derived memories, async reads, synchronous writes, and address-width helpers | core IR, kernel, clocking support, field support |
| `sync-memory.rhm` | Circuit-shaped synchronous memories with fixed read, write, and shared read-write ports plus optional packed-lane write masks | core IR, kernel, clocking support, field support |
| `assertion.rhm` | Reset-suppressed clocked assertions with branch-derived guards and optional labels | kernel, clocking support |
| `dpi.rhm` | Design-level DPI-C imports, result-less procedure calls, and explicit named DPI result registers | core IR, kernel, clocking support, field support |
| `interface.rhm` | Roles, directional interfaces, refinement, endpoint shapes, local links, linear callable handles and sinks, annotations, and compatible bulk connection | core IR, kernel, field support, instance-member support |
| `wire.rhm` | Binding-derived forward-readable single-driver connections | kernel, field support |
| `sequential.rhm` | Binding-derived explicit and ambient registers | kernel, clocking support, field support |
| `conditional.rhm` | Hardware `when` priority chains and exact-key `switch`, including assignment, memory-write, and assertion effects | core IR, kernel, mux-lookup support |
| `hierarchy.rhm` | Binding-derived instances, child-member access, and sync-child propagation | core IR, clocking support, instance-member support |
| `sync.rhm` | Sync circuits with ambient clock and synchronous reset | kernel, clocking support, generator-parameter support |

The support modules implement shared mechanisms without becoming selectable
language profiles:

- `hardware-literal.rhm` validates reusable packed host images, exposes their
  hardware type and packed width to ordinary libraries, and materializes them
  as a `Bits` constant followed by an explicit equal-width cast.
- `fields.rhm` owns exact hardware annotations, public hardware-value type
  discovery for libraries, and readable and driveable field static information.
- `instance-members.rhm` lets layers contribute virtual instance members
  without creating sibling-layer dependencies.
- `clocking.rhm` expands frontend sync policy into explicit ports, register
  operands, instance inputs, and drives.
- `generator-parameters.rhm` extracts runtime bindings from the ordinary
  Rhombus parameter forms shared by circuit generators.
- `mux-lookup.rhm` lets independent layers contribute typed static keys,
  lookup selector behavior, and one-hot selector types without importing one
  another.

Domain adapters such as `riscv/rhdl` consume the public language and standard
libraries. They do not become frontend layers and cannot import RHDL
implementation packages.

The kernel's deferred-value protocol retains authoring metadata until an
operation consumes it. Reusable host descriptions remain distinct from
objects already owned by an elaborated circuit. These protocols do not add
frontend types or operations to the public core IR.

## Enforcement

[`../tools/check-boundaries.sh`](../tools/check-boundaries.sh) enforces these
directions, prevents sibling-layer imports, keeps `standard.rhm` aggregation
only, and restricts reader shims and `.rhdl` files to their intended
locations. Run `make check-boundaries` after moving or adding modules.

`.rhdl` is reserved for RHDL-profile programs, public adapters, concrete core
designs, simulation adapters, and frontend or FESVR fixtures. `.rhm` contains
Rhombus implementation and library modules.
`.rkt` is restricted to reader shims and Racket interoperability where
collection lookup requires it.

The equivalence tests under [`../tests/frontend/`](../tests/frontend/) and
[`../tests/backend/`](../tests/backend/) check that direct core construction,
kernel construction, explicit layer composition, and the standard language
produce the same public IR and CIRCT representation.
