<!-- Documents the stabilized Ridx finite-domain model, consumer boundary, and validation workflow. -->

# Ridx

Ridx is a dependency-neutral Rhombus library for finite structural index
spaces. It gives host-side models and generators stable named coordinates,
canonical subset views, total point-indexed values, validated mappings,
symbolic axis shifts, and identity-bearing incidence without assigning those
structures any hardware, topology, placement, or scheduling meaning.

The initial Ridx vertical slice is complete. Milestones 1 through 6 established
the pure model, materialization boundary, incidence representation, NoC mesh
consumer, RHDL grid consumer, and stabilization gate. The resulting API is
intentionally narrow; future surface area requires a concrete consumer and an
equivalence gate.

## Architecture and responsibility

```text
pure Rhombus
IndexSpace / View / Shift Relation / Mapping / Incidence / Indexed
                              |
                     validate and materialize
                              v
                    consumer-owned plan
                              |
                 explicit consumer adapter
                    /                   \
                   v                     v
             RHDL elaboration       models, tests, tools
                   |
                   v
          existing public hardware IR
```

Ridx describes finite structure. It does not decide what hardware a point
contains, what an edge means, how contention is resolved, where state belongs,
which structure becomes hierarchy, or how logical axes map to physical space
or time.

RHDL is a consumer of Ridx, not part of the Ridx model. RHDL already provides
the host boundary: host values parameterize circuit generators, host loops
construct repeated structure, and host functions may construct hardware during
one elaboration. Ridx therefore needs no FFI, frontend feature, or new core IR.
Its adapter only traverses Ridx objects while invoking explicit ordinary-RHDL
construction rules.

## Package and dependency boundary

```text
ridx/
  README.md
  model/
    axis.rhm
    space.rhm
    view.rhm
    relation.rhm
    mapping.rhm
    incidence.rhm
    indexed.rhm
    main.rhm
  materialize/
    relation.rhm
    main.rhm
  rhdl/
    main.rhdl
  tests/
    model/
    materialize/
    rhdl/
```

Files under `ridx/model/` and `ridx/materialize/` use only `#lang rhombus`
and dependency-neutral host modules. They do not import RHDL, CIRCT, NoC,
RFPL, processor, protocol, simulation, or backend packages.

Files under `ridx/rhdl/` may import the public `#lang rhdl` authoring surface
and pure Ridx modules. They do not import RHDL core, frontend implementation,
backend implementation, or CIRCT packages. RHDL core, frontend, and backend do
not import Ridx.

Domain packages such as NoC may depend on pure Ridx. Ridx never depends on a
domain package. Each domain remains responsible for lowering Ridx structure
into its own identities, metadata, validation artifacts, and plans.

## Stabilized API and semantics

The public model provides:

- `Axis(name, extent)` for named positive finite axes;
- `IndexSpace(axes, ~name)` for nominal rectangular product spaces;
- bounded `IndexPoint` values with named-coordinate lookup and canonical
  ordinal calculation;
- `IndexView(space, points, ~name)` and `select_view` for canonical ordered
  subsets, including empty views;
- `Indexed(domain, entries)` and `index_by` for total host-value associations
  over a space or view;
- `Mapping(source, target, assignments)` and `mapping_by` for total validated
  point mappings and canonical inverse views;
- inspectable `shift_relation` values with explicit `drop` or `wrap` boundary
  behavior;
- `materialize_relation` for immutable, canonically ordered pair snapshots;
  and
- `Incidence(edges, sources, destinations, ~name)` for identity-bearing edges,
  inverse source and destination fibers, and an inspectable set-valued relation
  projection.

### Spaces, views, and indexed values

An `Axis` has a semantic name and a positive finite extent. Axis names are
unique within one product space and remain meaningful when axes have equal
extents. Axis names such as `x` and `y` are logical coordinates; they do not
imply physical placement, distance, wiring direction, or layout geometry.

Spaces are nominal. Separately constructed spaces remain distinct even when
their axes and extents match. Points compare semantically only when they belong
to the same space and have equal coordinates. Product enumeration is
lexicographic in declared axis order.

A view is an ordered subset of a parent space. It retains the parent points,
eliminates duplicates, and restores parent-space order. Multiplicity requires
a separate explicitly indexed space.

`Indexed` is a total association over a space or view. It rejects foreign,
duplicate, and missing points and retains domain order. Reusable indexed values
normally hold host data such as configurations, names, types, circuit
definitions, or analysis results. Hardware values, places, instances, and
interface endpoints may be stored only ephemerally inside the active RHDL
elaboration that owns them; they must not be serialized, retained in a reusable
plan, passed as circuit parameters, or reused by another elaboration. RHDL's
ownership verifier remains authoritative.

### Mappings

A mapping is total and single-valued from every point in its source domain to
one point in its target space. A mapping over a view is partial only with
respect to the view's parent space; it introduces no separate partial-mapping
semantics. Construction validates source coverage, target membership, and
single-valuedness. Inverse lookup returns one canonical view and does not
assume injectivity.

### Relations and materialization

A relation is a set of ordered point pairs between exact source and target
spaces, so duplicate pairs collapse. The stabilized symbolic constructor is an
axis shift with explicit `drop` or `wrap` boundary behavior. Shift relations
retain their nominal space and axis meaning until explicit materialization.

Materialization produces an immutable snapshot with pairs ordered by source
point and then target point. It retains no callback or consumer construction
policy. Incidence can also project to a materialized relation when edge
multiplicity is intentionally irrelevant.

### Incidence and edge identity

A set-valued relation cannot represent parallel edges or attach metadata to
individual links. Ridx therefore represents identity-bearing connectivity as:

```text
Incidence[E, A, B]
  edges:       IndexSpace[E]
  source:      Mapping[E, A]
  destination: Mapping[E, B]
```

Distinct edge points may have identical endpoints, and self-loops are retained.
Per-edge names, lanes, widths, latency, and other metadata stay in ordinary
`Indexed(edges, ...)` values. Materializing `incidence.as_relation()` orders
pairs by the endpoint domains and collapses parallel endpoint pairs without
changing the incidence object or its metadata.

Ridx does not replace domain identities such as NoC `LinkId` or `VCId`. A
consumer may use Ridx to author regular structure, then immediately lower it
into its existing identity and validation model.

## RHDL adapter

The optional `ridx/rhdl/main.rhdl` adapter is traversal-oriented and exposes
only:

- `for_each_index_point` for canonical point traversal;
- `for_each_relation_pair` for materialized relation-pair traversal; and
- `for_each_direct_mapping` for validated destination-to-source mapping
  traversal.

Callers provide the hardware-construction callback. There is no generic
`connect_relation`: a many-to-one relation might require rejection, a mux, an
arbiter, a reduction tree, or another consumer-specific rule. One-to-many may
be legal fanout but still needs an explicit port-selection rule. Ridx never
chooses among those meanings.

The direct-mapping traversal requires every destination in its declared view
to have exactly one source. It reports duplicate, missing, and foreign mappings
with Ridx point provenance before RHDL performs final one-driver verification.

The grid consumer stores instances in the existing public `InstanceArray` and
indexes them by point ordinal. This preserves keyed child-port static
information without a frontend extension. No symbolic Ridx node survives in
the public hardware IR: elaboration emits only ordinary modules, instances,
ports, wires, operations, and connections.

## Consumers and equivalence gates

The NoC rectangular-mesh helper is the first pure consumer. It uses a local
two-axis space for node enumeration and materialized dropped shifts for
directional neighbors, then immediately constructs the existing
`MeshNodeBinding`, `MeshLinkBinding`, and `TopologySpec` values. No Ridx object
escapes through the public NoC API. NoC link naming, canonical sorting,
validation, routing, dependency analysis, and planning remain authoritative.

The second consumer is an independent RHDL grid fixture. Its cell instances
are indexed by a two-axis space and explicit local rules wire dropped and
wrapped neighbors. Stabilization required both consumers to demonstrate that:

- shared structure removes repeated coordinate and neighbor bookkeeping;
- consumer identities and policies remain outside Ridx;
- diagnostics preserve named-axis and point provenance;
- the RHDL adapter preserves precise instance access through public APIs; and
- generated public IR, CIRCT, and Verilog match explicit host-loop
  construction.

## Stabilization decisions

The retained surface is the subset exercised by the NoC mesh and RHDL grid,
plus incidence's necessary distinction between edge identity and set-valued
adjacency. Identity, universal product, permutation, restriction, converse,
union, intersection, composition, opaque-predicate relations, and the bulk
partition-fiber convenience were removed because neither consumer required
them.

First-class partitions, overlapping covers, serialization, generic analysis,
and additional symbolic relation nodes remain deferred. They should be added
only with a concrete consumer, explicit semantics, and an equivalence gate.

Determinism is part of the contract: axis order determines space enumeration,
views retain parent order, relation pairs have one canonical order, incidence
enumeration follows edge-space order, and diagnostics use stable descriptions
rather than host hash order or object addresses.

## Non-goals

Ridx does not provide:

- an APL dialect or array syntax for runtime hardware values;
- automatic spatial-to-temporal mapping, resource sharing, scheduling, or HLS;
- a generic graph replacement for domain-owned node and edge identities;
- implicit mux, arbitration, reduction, broadcast, or wiring semantics;
- automatic RHDL module hierarchy derived from partitions;
- physical placement, routing, congestion prediction, or RFPL geometry;
- a second hardware IR or Ridx operations in the existing core IR;
- backend or CIRCT changes;
- a general polyhedral solver or arbitrary affine-set engine; or
- speculative relation algebra, partitions, covers, serialization, or generic
  graph analysis without a demonstrated consumer.

## Example

Import the aggregate model from an ordinary Rhombus module:

```rhombus
#lang rhombus

import:
  lib("ridx/model/main.rhm") open

def mesh = IndexSpace(
  [Axis("x", 2), Axis("y", 3)],
  ~name: "mesh"
)

def right_column = select_view(
  mesh,
  fun (point): point.coordinate("x") == 1,
  ~name: "right_column"
)

def labels = index_by(
  right_column,
  fun (point): point.describe()
)

def right_neighbor = shift_relation(
  mesh,
  "x",
  1,
  ~boundary: "drop"
)
```

`labels.values()` follows canonical mesh order: `mesh{x=1,y=0}`,
`mesh{x=1,y=1}`, then `mesh{x=1,y=2}`. Import
`lib("ridx/materialize/main.rhm")` to convert `right_neighbor` into a canonical
pair snapshot.

## Focused validation

Run the pure model, materialization, and RHDL equivalence tests from the
repository root with a fresh compiled root:

```sh
ridx_compiled_root="$(mktemp -d)"
PLTCOMPILEDROOTS="$ridx_compiled_root" PLTCOLLECTS="$(pwd):" raco test \
  ridx/tests/model/milestone1-test.rhm \
  ridx/tests/model/mapping-test.rhm \
  ridx/tests/materialize/relation-test.rhm \
  ridx/tests/materialize/incidence-test.rhm \
  ridx/tests/rhdl/grid-equivalence-test.rhm
```

The tests cover nominal separation, deterministic enumeration, bounds and
foreign-point diagnostics, canonical and empty views, total indexed values,
mapping validation and inverse views, dropped and wrapped shifts, canonical
materialization, parallel edges and self-loops, per-edge metadata, and
set-valued adjacency projection.

The grid equivalence test additionally checks deterministic instance names,
dropped and wrapped connections, final RHDL verification, and exact public IR
and CIRCT equality. Run `make ridx-circt-test` with CIRCT installed to lower
both fixtures independently and require exact generated-Verilog equality.

Repository boundary checks enforce the dependency rules above:

```sh
make check-boundaries
```
