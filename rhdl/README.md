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
| [`language.rhm`](language.rhm), [`base/language.rhm`](base/language.rhm) | Compose Rhombus with one public RHDL profile | Standard or foundation, plus the host-condition guard |
| [`std/`](std/README.md) | Optional host utilities, protocols, and circuit generators written in ordinary RHDL | Public `#lang rhdl` authoring surface only |
| [`backend/`](backend/README.md) | Consume verified public IR; currently lower it through CIRCT | Core only |
| [`../sim/`](../sim/fesvr/README.md) | Optional simulation adapters and external runtime support | Public `#lang rhdl` authoring surface only; external C++ libraries |

The import direction is one-way. Core never imports frontend or backend code;
frontend code never imports a backend; and a backend never imports frontend
syntax or elaboration. Layers do not import sibling layers. Shared machinery
needed by multiple layers belongs in `frontend/support/`. Standard-library
modules and simulation adapters use public RHDL forms rather than importing
implementation modules.

## Standard-library dependencies

Standard-library modules depend only on the public authoring surface. The
flow-control aggregate is separate from its implementations, so designs can
import one primitive without loading unrelated generators.

| Module | Provides | Direct RHDL dependencies |
|---|---|---|
| `std/counter.rhdl` | Enabled bounded `Counter` | None |
| `std/decode/pattern.rhdl` | Typed host-side `Pattern` cubes over hardware literals | None |
| `std/ready-valid.rhdl` | `Valid`, control and payload-bearing ready-valid protocols, `fire`, and payload introspection | None |
| `std/flow/pipe.rhdl` | Registered elastic `Pipe` and typed chaining helper | `std/ready-valid.rhdl` |
| `std/flow/queue.rhdl` | Configurable FIFO `Queue` and typed chaining helper | `std/ready-valid.rhdl`, `std/counter.rhdl` |
| `std/flow/arbiter.rhdl` | Fixed-priority `Arbiter` | `std/ready-valid.rhdl` |
| `std/flow/rr-arbiter.rhdl` | Round-robin `RRArbiter` | `std/ready-valid.rhdl` |
| `std/flow/demux.rhdl` | Selected one-to-many `Demux` | `std/ready-valid.rhdl` |
| `std/flow/join.rhdl` | Atomic homogeneous `Join` | `std/ready-valid.rhdl` |
| `std/flow/broadcast.rhdl` | Exactly-once buffered `Broadcast` | `std/ready-valid.rhdl` |
| `std/flow.rhdl` | Flow-control convenience aggregate | All `std/flow/` modules |

## Frontend layer dependencies

This table is the authoritative inventory of bundled frontend layers. Update
it when adding, removing, or changing a layer's direct dependencies.

| Layer | Provides | Direct RHDL dependencies |
|---|---|---|
| `cast.rhm` | Functional equal-width representation casts | core IR, kernel, field support |
| `comb.rhm` | Static packed literals, modular arithmetic, bitwise operations, muxes, and width operations | core types, kernel, field support, hardware-literal support, mux-lookup support |
| `expanding-arithmetic.rhm` | Lossless unsigned addition and multiplication with `+&` and `*&` sugar | core types, kernel, field support |
| `bool.rhm` | Nominal `Bool`, static host-Boolean literal shadows, equality, unsigned ordering, and binary `mux` | core IR, kernel, field support, hardware-literal support |
| `enum.rhm` | Nominal encoded hardware enums and member literals | core IR, kernel, field support, mux-lookup support |
| `one-hot.rhm` | Structurally sized one-hot types, literals, typed mux keys, and `mux_onehot` | core IR, kernel, field support, mux-lookup support |
| `bundle.rhm` | Bundle declarations, runtime records, recursive record literal shadows, and field access | core IR, kernel, field support, hardware-literal support |
| `vector.rhm` | `Vec` types, runtime vector construction, and recursive vector literal shadows | core types, kernel, field support, hardware-literal support |
| `memory.rhm` | Binding-derived memories, async reads, synchronous writes, and address-width helpers | core IR, kernel, clocking support, field support |
| `dpi.rhm` | Design-level DPI-C imports, result-less procedure calls, and explicit named DPI result registers | core IR, kernel, clocking support, field support |
| `interface.rhm` | Roles, directional interfaces, single-parent refinement, declared protocol support, refinement-delta routing, annotations, and compatible bulk connection | core IR, kernel, field support, instance-member support |
| `wire.rhm` | Binding-derived single-driver wires | kernel, field support |
| `sequential.rhm` | Binding-derived explicit and ambient registers | kernel, clocking support, field support |
| `conditional.rhm` | Hardware `when`, priority branches, conditional assignment, and conditional memory-write effects | kernel |
| `hierarchy.rhm` | Binding-derived instances, child-member access, and sync-child propagation | core IR, clocking support, instance-member support |
| `sync.rhm` | Sync circuits with ambient clock and synchronous reset | kernel, clocking support |

The support modules implement shared mechanisms without becoming selectable
language profiles:

- `hardware-literal.rhm` validates reusable packed host images, exposes their
  hardware type and packed width to ordinary libraries, and materializes them
  as a `Bits` constant followed by an explicit equal-width cast.
- `fields.rhm` owns exact hardware annotations plus readable and driveable
  field static information.
- `instance-members.rhm` lets layers contribute virtual instance members
  without creating sibling-layer dependencies.
- `clocking.rhm` expands frontend sync policy into explicit ports, register
  operands, instance inputs, and drives.
- `mux-lookup.rhm` lets independent layers contribute typed static keys and
  selector behavior to combinational mux syntax.

The kernel's deferred-value protocol retains authoring metadata until an
operation consumes it. Reusable host descriptions remain distinct from
objects already owned by an elaborated circuit. These protocols do not add
frontend types or operations to the public core IR.

## Enforcement

[`../tools/check-boundaries.sh`](../tools/check-boundaries.sh) enforces these
directions, prevents sibling-layer imports, keeps `standard.rhm` aggregation
only, and restricts reader shims and `.rhdl` files to their intended
locations. Run `make check-boundaries` after moving or adding modules.

The equivalence tests under [`../tests/frontend/`](../tests/frontend/) and
[`../tests/backend/`](../tests/backend/) check that direct core construction,
kernel construction, explicit layer composition, and the standard language
produce the same public IR and CIRCT representation.
