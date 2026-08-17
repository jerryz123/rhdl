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

#lang rfpl --------------------> ../rfpl/frontend ------------------------> core IR

std/* -------------------------> public #lang rhdl authoring surface
tilelink/* --------------------> public #lang rhdl and generic std/* libraries
chi/* -------------------------> public #lang rhdl and generic std/* libraries
sim/* -------------------------> public #lang rhdl authoring surface
riscv/rhdl --------------------> public #lang rhdl authoring surface
user designs ------------------> optional std/* and domain libraries

host/annotations -------------> dependency-neutral Rhombus refinements

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
| [`../host/`](../host/README.md) | Dependency-neutral host refinement annotations | Rhombus only |
| [`core/`](core/README.md) | Types, IR, Builder, verification, and printing | Other core modules, `../host/`, and Rhombus libraries |
| [`frontend/kernel.rhm`](frontend/kernel.rhm) | Context-sensitive elaboration and deferred frontend hardware values over the public core | Core |
| [`frontend/support/`](frontend/support/) | Shared cross-layer protocols, macros, and static-information machinery; not a language profile | Kernel, approved core APIs, other support modules |
| [`frontend/foundation.rhm`](frontend/foundation.rhm) | Circuits, ports, connections, elaboration, basic types, selection, and casts | Kernel, support, approved core type APIs |
| [`frontend/layers/`](frontend/layers/README.md) | Independently selectable notation and abstractions over existing semantics | Kernel, support, approved core APIs |
| [`frontend/standard.rhm`](frontend/standard.rhm) | Aggregation only; defines no feature behavior | Foundation and all standard layers |
| [`language.rhm`](language.rhm), [`base/language.rhm`](base/language.rhm) | Compose ordinary Rhombus host control with one public RHDL profile | Standard or foundation |
| [`../rfpl/`](../rfpl/PLAN.md) | Physical views over existing modules: opaque hard macros and wiring-only composite floorplans with contained child coordinates | Public core IR only |
| [`std/`](std/README.md) | Optional host utilities, protocols, and circuit generators written in ordinary RHDL | Public `#lang rhdl` authoring surface only |
| [`backend/`](backend/README.md) | Consume verified public IR; currently lower it through CIRCT | Core only |
| [`../tilelink/`](../tilelink/README.md) | TileLink parameters, payloads, endpoint monitors, and an uncached RAM manager | Public `#lang rhdl` and protocol-neutral `std/` libraries |
| [`../chi/`](../chi/README.md) | AMBA CHI Issue H parameters, exact flits, protocol classifiers, credited node-role links, and link-local monitors | Public `#lang rhdl`; protocol-neutral `std/` libraries as later layers require them |
| [`../sim/`](../sim/fesvr/README.md) | Optional simulation adapters and external runtime support | Public `#lang rhdl` authoring surface only; external C++ libraries |
| [`../riscv/rhdl/`](../riscv/rhdl/README.md) | Converts RISC-V instruction encodings into generic typed decode patterns | Pure RISC-V model; public `#lang rhdl` libraries |
| [`../vlsi/`](../vlsi/README.md) | Physical-design integration fixtures and backend tool flows | Public `#lang rhdl` authoring surface; backend emission tools; external VLSI tools and harnesses |

The import direction is one-way. Core never imports frontend or backend code;
frontend code never imports a backend; and a backend never imports frontend
syntax or elaboration. Layers do not import sibling layers. Shared machinery
needed by multiple layers belongs in `frontend/support/`. Standard-library
modules and simulation adapters use public RHDL forms rather than importing
implementation modules. RFPL is a downstream annotation language: it inspects
the public RHDL IR but does not construct hardware or import frontend/backend
implementation modules. RHDL core, frontend, and backend modules never import
RFPL.

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
| `std/bits.rhdl` | Host `Pow2Int` refinement and power-of-two testing plus alignment width, checking, and downward alignment for `Bits` | None |
| `std/scoreboard.rhdl` | Single-set, single-clear occupancy `Scoreboard` and indexed busy query | `std/bits.rhdl`, `std/ready-valid.rhdl` |
| `std/interconnect.rhdl` | Protocol-neutral host-side ID ranges, masked address sets, and transfer-size sets | `std/bits.rhdl` |
| `std/decode/pattern.rhdl` | Typed host-side `Pattern` cubes, exact-literal normalization, partial records, and recursive aggregate construction | None |
| `std/decode/pattern-value.rhdl` | Partially specified hardware values from `Pattern` cubes | `std/decode/pattern.rhdl` |
| `std/decode/table.rhdl` | Validated unordered typed decode relations, grouped sparse record cases, input lifting, and row-aligned output products | `std/decode/pattern.rhdl` |
| `std/decode/espresso.rhdl` | Optional host-side Espresso discovery, PLA interchange, and minimized-cover plans | `std/decode/table.rhdl` |
| `std/decode/pla.rhdl` | Shared product-term hardware elaboration for minimized decode covers | `std/decode/espresso.rhdl`, `std/decode/table.rhdl` |
| `std/decode/generator.rhdl` | Callable `DecodeGen` and valid-tagged partial mappings selecting minimized PLA or core-decode fallback | `std/decode/pattern.rhdl`, `std/decode/table.rhdl`, `std/decode/espresso.rhdl`, `std/decode/pla.rhdl` |
| `std/decode.rhdl` | Public decode facade | `std/decode/pattern.rhdl`, `std/decode/table.rhdl`, `std/decode/generator.rhdl` |
| `std/ready-valid.rhdl` | `Valid`, `DecoupledCtrl`, `IrrevocableCtrl`, payload-bearing protocols, `fire`, and nominal endpoint/protocol introspection | None |
| `std/credited.rhdl` | Protocol-neutral bounded credited payload transport, monitoring, and nominal protocol introspection | None |
| `std/read-write.rhdl` | Generic addressed `Valid` read-or-write request flow over lane-replicated data and masks | `std/ready-valid.rhdl` |
| `std/simple-memory.rhdl` | Ordered multi-outstanding aligned byte-addressed and byte-masked `SimpleMemory` protocol | `std/bits.rhdl`, `std/ready-valid.rhdl` |
| `std/simple-memory/ram.rhdl` | Pipelined finite masked synchronous-RAM implementation of `SimpleMemory` | `std/simple-memory.rhdl`, `std/ready-valid.rhdl`, `std/flow/queue.rhdl`, `std/flow/pipe.rhdl` |
| `std/sync-ram.rhdl` | Fixed-latency lane-masked shared 1RW RAM | `std/read-write.rhdl` |
| `std/flow/stage.rhdl` | Dependent topology results, flow protocol and payload inference, and generic-handle application | `std/ready-valid.rhdl` |
| `std/flow/pipe.rhdl` | Registered fixed-latency `ValidPipe`, elastic `Pipe`/`CtrlPipe`, and configured unary stages | `std/ready-valid.rhdl`, `std/flow/stage.rhdl` |
| `std/flow/queue.rhdl` | Configurable FIFO `Queue`/`CtrlQueue` and configured unary stages | `std/ready-valid.rhdl`, `std/counter.rhdl`, `std/flow/stage.rhdl` |
| `std/flow/completion-queue.rhdl` | Reserved response buffering between ready-valid requests and nonstallable issues/completions | `std/ready-valid.rhdl`, `std/flow/queue.rhdl` |
| `std/flow/credit.rhdl` | Credited sender and receiver adapters, bounded accounting, and configured unary stages | `std/ready-valid.rhdl`, `std/credited.rhdl`, `std/flow/stage.rhdl`, `std/flow/queue.rhdl` |
| `std/flow/arbiter.rhdl` | Fixed-priority `Arbiter`/`CtrlArbiter` | `std/ready-valid.rhdl` |
| `std/flow/rr-arbiter.rhdl` | Round-robin `RRArbiter`/`CtrlRRArbiter` plus configured Array-to-endpoint arbitration | `std/ready-valid.rhdl`, `std/flow/stage.rhdl` |
| `std/flow/demux.rhdl` | Selected one-to-many `Demux`/`CtrlDemux` plus configured payload-selected routing | `std/ready-valid.rhdl`, `std/flow/stage.rhdl` |
| `std/flow/grant.rhdl` | Optional-one-hot ready-valid grant routing and merging primitives | `std/ready-valid.rhdl` |
| `std/flow/crossbar.rhdl` | Configured grant-controlled one-to-one ready-valid crossbar stage | `std/ready-valid.rhdl`, `std/flow/stage.rhdl`, `std/flow/grant.rhdl` |
| `std/flow/join.rhdl` | Atomic homogeneous `Join`/`CtrlJoin` | `std/ready-valid.rhdl` |
| `std/flow/zip.rhdl` | Configured inline binary heterogeneous atomic `zip_flow` stage | `std/ready-valid.rhdl`, `std/flow/stage.rhdl` |
| `std/flow/broadcast.rhdl` | Exactly-once buffered `Broadcast`/`CtrlBroadcast` | `std/ready-valid.rhdl` |
| `std/flow/atomic-fork.rhdl` | Combinational all-or-none `AtomicFork`/`CtrlAtomicFork` plus configured fanout stages | `std/ready-valid.rhdl`, `std/flow/stage.rhdl` |
| `std/flow/map.rhdl` | Configured protocol-preserving inline payload substitution | `std/ready-valid.rhdl`, `std/flow/stage.rhdl` |
| `std/flow/map-valid.rhdl` | Configured inline payload substitution for nonbackpressured `Valid` | `std/ready-valid.rhdl`, `std/flow/stage.rhdl` |
| `std/flow/fork-valid.rhdl` | Configured inline one-to-many fanout for nonbackpressured `Valid` | `std/ready-valid.rhdl`, `std/flow/stage.rhdl` |
| `std/flow/filter-valid.rhdl` | Configured inline predicate filtering for nonbackpressured `Valid` | `std/ready-valid.rhdl`, `std/flow/stage.rhdl` |
| `std/flow/to-valid.rhdl` | Explicit always-ready conversion from ready-valid transfers to `Valid` events | `std/ready-valid.rhdl`, `std/flow/stage.rhdl` |
| `std/flow/boundary.rhdl` | Named protocol-preserving injection from and ejection to ordinary circuit-side hardware | None |
| `std/flow/filter.rhdl` | Configured inline predicate filtering for ready-valid flows | `std/ready-valid.rhdl`, `std/flow/stage.rhdl` |
| `std/flow/gate.rhdl` | Configured combinational enable gating for ready-valid flows | `std/ready-valid.rhdl`, `std/flow/stage.rhdl` |
| `std/flow/parallel.rhdl` | Configured parallel stage, generic handle, and terminated-sink composition | `std/flow/stage.rhdl` |
| `std/flow.rhdl` | Valid-only, ready-valid, and credited protocols plus the flow-control convenience aggregate | `std/ready-valid.rhdl`, `std/credited.rhdl`, and all `std/flow/` modules |

## Frontend layer dependencies

This table is the authoritative inventory of bundled frontend layers. Update
it when adding, removing, or changing a layer's direct dependencies.

| Layer | Provides | Direct RHDL dependencies |
|---|---|---|
| `cast.rhm` | Functional equal-width representation casts and inferred canonical packing to `Bits` | core IR, kernel, field support |
| `comb.rhm` | Static packed literals, typed synthesis don't-cares, decode relations, modular arithmetic, bitwise operations, muxes, bit-vector zero extension, and width operations | core types and IR, kernel, field support, hardware-literal support, mux-lookup support |
| `signed.rhm` | Explicit-width `SInt`, two's-complement literals, sign extension, signed truncation, and signed operator participation | core types and IR, kernel, field support, hardware-literal support |
| `expanding-arithmetic.rhm` | Lossless unsigned addition and multiplication with `+&` and `*&` sugar | core types, kernel, field support |
| `bool.rhm` | Nominal `Bool`, static host-Boolean literal shadows, packed OR reduction, equality, typed membership, enum validity, signed and unsigned ordering, and binary `mux` | core types and IR, kernel, finite-enum support, field support, hardware-literal support |
| `enum.rhm` | Nominal sequential, explicit, and one-hot encoded hardware enums plus member literals | core IR, kernel, field support, finite-enum support, mux-lookup support |
| `one-hot.rhm` | One-hot selector types, literals, total `Bits` index conversion, typed mux keys, and partial `mux_onehot` selection | core IR, kernel, field support, mux-lookup support |
| `bundle.rhm` | Bundle declarations, type-named construction, generic runtime records, recursive literal shadows, and field access | core IR, kernel, field support, hardware-literal support |
| `vector.rhm` | `Vec` types, runtime vector construction, and recursive vector literal shadows | core types, kernel, field support, hardware-literal support |
| `memory.rhm` | Binding-derived memories, async reads, synchronous writes, and address-width helpers | core IR, kernel, clocking support, field support |
| `sync-memory.rhm` | Circuit-shaped synchronous memories with fixed read, write, and shared read-write ports plus optional packed-lane write masks | core IR, kernel, clocking support, field support |
| `assertion.rhm` | Reset-suppressed clocked assertions with branch-derived guards and optional labels | kernel, clocking support |
| `dpi.rhm` | Design-level DPI-C imports, result-less procedure calls, and explicit named DPI result registers | core IR, kernel, clocking support, field support |
| `interface.rhm` | Roles, directional interfaces, refinement, endpoint shapes, local links, linear callable handles and sinks, topology static information, annotations, and compatible bulk connection | core IR, kernel, field support, instance-member support |
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
  discovery, shared canonical packing, and readable and driveable field static
  information.
- `instance-members.rhm` lets layers contribute virtual instance members
  without creating sibling-layer dependencies.
- `clocking.rhm` expands frontend sync policy into explicit ports, register
  operands, instance inputs, and drives.
- `generator-parameters.rhm` extracts runtime bindings from the ordinary
  Rhombus parameter forms shared by circuit generators.
- `mux-lookup.rhm` lets independent layers contribute typed static keys,
  lookup selector behavior, and one-hot selector types without importing one
  another.

Domain libraries and adapters such as `tilelink/` and `riscv/rhdl` consume the
public language and standard libraries. They do not become frontend layers and
cannot import RHDL implementation packages.

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
designs, simulation adapters, physical-design integration fixtures, and
frontend or FESVR fixtures. `.rhm` contains Rhombus implementation and library
modules.
`.rkt` is restricted to reader shims and Racket interoperability where
collection lookup requires it.

The equivalence tests under [`../tests/frontend/`](../tests/frontend/) and
[`../tests/backend/`](../tests/backend/) check that direct core construction,
kernel construction, explicit layer composition, and the standard language
produce the same public IR and CIRCT representation.
