<!-- Defines RHDL's package responsibilities and mechanically enforced dependency directions. -->

# RHDL architecture

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

frontend/foundation -----------+
frontend/layers/* -------------+----> frontend/support/*
                               +----> frontend/kernel ----> core
frontend/{foundation,layers,support} ---------------------> approved core APIs

backend/circt ---------------------------------------------> core
```

`#lang rhdl` is the ordinary curated language. `#lang rhdl/base` is the
composition profile: it exposes the foundation and allows a program to import
only the language layers it wants. The word *base* names this public profile;
the internal module implementing its shared frontend forms is called the
*foundation* to avoid overloading that name.

## Responsibilities

| Area | Responsibility | May depend directly on |
|---|---|---|
| `core/` | Types, IR, Builder, verification, and printing | Other core modules and Rhombus libraries |
| `frontend/kernel.rhm` | Context-sensitive elaboration and deferred frontend hardware values over the public core | Core |
| `frontend/support/` | Shared cross-layer protocols, macros, and static-information machinery; not a language profile | Kernel, approved core APIs, other support modules |
| `frontend/foundation.rhm` | Circuits, ports, connections, elaboration, basic types, selection, and casts | Kernel, support, approved core type APIs |
| `frontend/layers/` | Independently selectable notation and abstractions over existing semantics | Kernel, support, approved core APIs |
| `frontend/standard.rhm` | Aggregation only; defines no feature behavior | Foundation and all standard layers |
| `language.rhm`, `base/language.rhm` | Compose Rhombus with one public RHDL profile | Standard or foundation, plus the host-condition guard |
| `backend/` | Consume verified public IR; currently lower it through CIRCT | Core only |

The import direction is one-way. Core never imports frontend or backend code;
frontend code never imports a backend; and a backend never imports frontend
syntax or elaboration. Layers do not import sibling layers. Shared machinery
needed by multiple layers belongs in `frontend/support/`.

## Frontend layer dependencies

This table is the authoritative inventory of bundled frontend layers. Update it
when adding, removing, or changing a layer's direct dependencies.

| Layer | Provides | Direct RHDL dependencies |
|---|---|---|
| `cast.rhm` | Functional equal-width representation casts | core IR, kernel, field support |
| `comb.rhm` | Literals, arithmetic, bitwise operations, muxes, and width operations | core types, kernel, field support, mux-lookup support |
| `bool.rhm` | Nominal `Bool`, `===`, and binary `mux` | core IR, kernel |
| `enum.rhm` | Nominal encoded hardware enums and member literals | core IR, kernel, field support, mux-lookup support |
| `bundle.rhm` | Bundle declarations, records, and field access | core IR, kernel, field support |
| `vector.rhm` | `Vec` types and inferred vector construction | core types, kernel, field support |
| `memory.rhm` | Binding-derived memories, async reads, synchronous writes, and address-width helpers | core IR, kernel, clocking support, field support |
| `interface.rhm` | Roles, directional interfaces, and bulk connection | core IR, kernel, field support, instance-member support |
| `wire.rhm` | Binding-derived single-driver wires | kernel, field support |
| `sequential.rhm` | Binding-derived explicit and ambient registers | kernel, clocking support, field support |
| `conditional.rhm` | Hardware `when`, priority branches, and conditional assignment | kernel |
| `hierarchy.rhm` | Binding-derived instances, child-member access, and sync-child propagation | core IR, clocking support, instance-member support |
| `sync.rhm` | Opt-in sync circuits with ambient clock and synchronous reset | kernel, clocking support |

`frontend/support/fields.rhm` depends only on the kernel.
`frontend/support/instance-members.rhm` depends on core IR, the kernel, and
field support. Its resolver hook lets the interface layer contribute virtual
instance members without making hierarchy depend on interface.
`frontend/support/clocking.rhm` depends on core IR and types plus the kernel;
it carries frontend-only sync metadata and expands ambient policy into explicit
ports, register operands, instance inputs, and drives.

`frontend/support/mux-lookup.rhm` depends only on the kernel's deferred-value
interface. It lets independently selectable layers contribute typed selector
and key behavior to the combinational mux syntax.

The kernel's deferred-value protocol lets layers retain authoring metadata
until an operation consumes it. For example, enum members remain typed lookup
keys until the combinational layer uses the mux-lookup protocol to normalize
them to integer keys and a Bits selector for the core mux operation. These
protocols do not add frontend types or operations to the public core IR.

## Enforcement

[`tools/check-boundaries.sh`](tools/check-boundaries.sh) enforces the package
directions, prevents sibling-layer imports, keeps `standard.rhm` aggregation
only, and restricts reader shims and `.rhdl` files to their intended locations.
Run `make check-boundaries` after moving or adding modules.

The equivalence tests under `tests/frontend/` and `tests/backend/` additionally
check that direct core construction, kernel construction, explicit layer
composition, and the standard language produce the same public IR and CIRCT
representation.
