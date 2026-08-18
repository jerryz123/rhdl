<!-- Defines the planned pure-host Ridx index-space algebra and its narrow RHDL elaboration boundary. -->

# Ridx finite structural index plan

## Status

Milestone 1 is implemented. Ridx now provides dependency-neutral Rhombus axes,
nominal finite product spaces and points, canonical subset views, and total
indexed host values, with focused valid and invalid tests. Symbolic relations,
mappings, materialization, incidence, and the RHDL experiment remain planned.

RHDL will be one consumer; Ridx is not an RHDL frontend layer, a hardware IR,
or an automatic hardware scheduler.

The first implementation must remain a narrow experiment until two independent
consumers demonstrate that the same abstractions are useful without importing
consumer-specific policy into Ridx.

## Decision

Build Ridx as a top-level package with a pure Rhombus core and an optional thin
RHDL adapter:

```text
pure Rhombus
IndexSpace / View / Relation / Mapping / Incidence / Indexed
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
which structure becomes hierarchy, or how logical axes map to physical space or
time.

RHDL already supplies the host boundary: host values parameterize circuit
generators, host loops construct repeated structure, and host functions may
construct hardware during one elaboration. Ridx therefore needs no FFI and no
new core IR. Its adapter only traverses Ridx objects while invoking explicit
ordinary-RHDL construction rules.

## Package boundary

The intended repository shape is:

```text
ridx/
  PLAN.md
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
  examples/
```

Files under `ridx/model/` and `ridx/materialize/` use only `#lang rhombus`
and dependency-neutral host modules. They must not import RHDL, CIRCT, NoC,
RFPL, processor, protocol, simulation, or backend packages.

Files under `ridx/rhdl/` may import the public `#lang rhdl` authoring surface
and pure Ridx modules. They must not import RHDL core, frontend implementation,
backend implementation, or CIRCT packages. RHDL core, frontend, and backend
must not import Ridx.

Domain packages such as NoC may depend on pure Ridx. Ridx never depends on a
domain package. A domain remains responsible for lowering Ridx structure into
its own identities, metadata, validation artifacts, and plans.

## Semantic model

### Axes and index spaces

An `Axis` has a semantic name and a positive finite extent. Axis names are
unique within one product space and retain their meaning even when two axes
have equal extents.

An `IndexSpace` is a finite domain with explicit identity, ordered axes, and a
canonical point enumeration. Two separately constructed spaces are distinct
even when their axes and extents match. A point belongs to exactly one space;
using it with another structurally equal space is an error.

The initial concrete space is a rectangular product of named axes. Enumeration
is deterministic and lexicographic in declared axis order. Derived views may be
empty even though declared axis extents are positive.

Ridx coordinates are logical finite indices. Axis names such as `x` and `y` do
not imply physical placement, distance, wiring direction, or layout geometry.
Those meanings require consumer-owned mappings or metadata.

### Views

A `View` is an ordered finite subset of a parent space. It retains the parent
points rather than copying them into a new unrelated space. Rows, boundaries,
interiors, windows, masks, and partition fibers are views.

View construction must preserve stable provenance and canonical enumeration.
Set-like operations eliminate duplicate points. A separate explicitly indexed
space is required when multiplicity is meaningful.

### Relations

A `Relation[A, B]` is a set of ordered point pairs between exact source and
target spaces. Its set semantics deliberately collapse duplicate pairs.

The initial symbolic relation constructors are:

- identity;
- Cartesian product;
- axis shift with explicit `drop` or `wrap` boundary behavior;
- axis permutation;
- domain and range restriction by views;
- converse;
- union and intersection over identical endpoint spaces; and
- composition with an exact intermediate space.

Known constructors remain an inspectable symbolic expression until a consumer
requests enumeration. An explicit opaque-predicate escape hatch may define a
finite relation that can be materialized but not algebraically simplified.
The API must not claim symbolic properties for opaque nodes.

Materialization produces an immutable, canonically ordered snapshot. It
evaluates each required opaque query at most once and retains no callback that a
downstream consumer could rerun.

### Mappings

A `Mapping[A, B]` is a total single-valued relation from every point in `A` to
one point in `B`. A mapping over a view represents a partial mapping over the
view's parent space without introducing separate partiality semantics.

Construction validates domain coverage, codomain membership, and
single-valuedness before exposing a mapping. Inverse lookup returns a view and
does not assume injectivity.

### Incidence and edge identity

A mathematical relation is not a sufficient representation for physical or
logical links when parallel edges or per-edge metadata matter. Ridx therefore
represents identity-bearing connectivity as:

```text
Incidence[E, A, B]
  edges:       IndexSpace[E]
  source:      Mapping[E, A]
  destination: Mapping[E, B]
```

Distinct edge points may have the same source and destination. This preserves
parallel links, self-loops, names, lanes, widths, latency metadata, and stable
provenance. Consumers may derive a set-valued `Relation[A, B]` when edge
multiplicity is irrelevant.

Ridx does not replace the NoC package's nominal `LinkId`, `VCId`, or validated
topology. A NoC adapter may use Ridx to generate a regular authored topology,
then lower it into the existing domain identities and validation pipeline.

### Partitions

A mathematical disjoint partition is derived from a mapping from an index
space to a finite part-key space. Each inverse image is a view. Multiple
simultaneous decompositions are represented by multiple mappings over the same
space.

Overlapping or incomplete covers are not called partitions. They may be added
later as a separate `Cover` abstraction if a concrete consumer requires them.

Partitions do not automatically create RHDL modules or physical hierarchy.
They provide stable groups that a user-owned hierarchy generator or analysis
may choose to consume.

### Indexed values

`Indexed[I, T]` is a total association from every point of one space or view to
one host value. It validates coverage and rejects foreign or duplicate keys.
Iteration follows the owning domain's canonical order.

Pure reusable `Indexed` values normally hold configurations, descriptions,
types, names, circuit definitions, analysis results, or other host data.
Hardware values, places, instances, and interface endpoints may be stored only
ephemerally inside the active RHDL elaboration that owns them. Such a collection
must not be passed as a circuit generator parameter, retained in a reusable
plan, serialized, or used by another elaboration.

RHDL ownership verification remains authoritative for hardware objects hidden
inside host containers.

## RHDL adapter

The initial adapter is deliberately traversal-oriented. It may provide:

- indexed instance construction over a space or view;
- projection of instance ports or interface endpoints into another indexed
  elaboration-local collection;
- relation or incidence traversal that invokes an explicit local hardware
  rule for each pair or edge; and
- a checked direct-wiring convenience that accepts a mapping from destinations
  to sources.

There is no generic `connect_relation` that assigns hardware meaning to an
arbitrary relation. A many-to-one relation could require rejection, a mux, an
arbiter, a reduction tree, or consumer-specific resolution. A one-to-many
relation may be legal fanout but still requires an explicit rule for port and
interface selection. Ridx never chooses among these meanings.

The checked direct-wiring path requires every destination in its declared view
to have exactly one source. It reports duplicate, missing, and foreign mappings
using Ridx point provenance before RHDL's final one-driver verification.

Generic Rhombus containers may erase the static information used by RHDL for
instance-port access, interface fields, endpoint-array indexing, and dependent
hardware types. The adapter must first attempt to lower through existing
`InstanceArray`, arrays, annotations, and public authoring forms. If that cannot
retain a precise keyed result, the only frontend addition is a general
static-information-preserving keyed instance or endpoint collection mechanism.
That mechanism belongs with the existing RHDL hierarchy or interface layer and
must not import or mention Ridx.

No symbolic Ridx node survives into the public hardware IR. Enumeration and
consumer planning complete during elaboration; the emitted IR contains only the
ordinary modules, instances, ports, wires, operations, and connections that the
explicit RHDL rule constructed.

## Determinism and diagnostics

Ridx must make deterministic structure visible rather than relying on host hash
iteration or object addresses:

- Axis order determines product-space enumeration.
- Views retain parent order.
- Relation materialization has one canonical pair order.
- Algebraic union and intersection results do not depend on operand
  construction order.
- Incidence enumeration follows edge-space order and never sorts solely by
  source and destination, which would lose distinct edge provenance.
- Diagnostics name spaces, axes, points, views, mappings, and symbolic
  relation nodes using stable descriptions.

Nominal membership and deterministic display are separate concerns. Display
names do not make independently constructed spaces interchangeable.

## Physical and temporal scope

Ridx describes where a structural rule applies. It does not schedule logical
axes over time, share resources, infer control state, or perform HLS. Every RHDL
consumer must still make the instantiated spatial hardware and state explicit.

Ridx also does not infer whether a regular logical relation is physically
reasonable. Future consumers may compute degree, cardinality, cut, placement,
or wiring diagnostics from symbolic structure, but those analyses must report
facts or require explicit mappings. They must not silently transform spatial
structure into temporal execution or automatic hierarchy.

## Initial validation

Pure Ridx tests must cover:

- nominal separation of structurally equal spaces;
- unique axis names, positive extents, point bounds, and foreign-point errors;
- deterministic product and view enumeration, including empty views;
- `drop` and `wrap` shifts at every boundary;
- permutation, restriction, converse, union, intersection, and composition;
- symbolic and materialized extensional equivalence;
- exactly-once opaque predicate evaluation during one materialization;
- mapping totality, single-valuedness, and inverse fibers;
- partitions derived from mappings;
- parallel edges and self-loops through incidence; and
- construction-order-independent descriptions and snapshots where the
  operation is mathematically unordered.

The initial RHDL fixture must check:

- one indexed cell instance per selected point;
- exact connection structure for dropped and wrapped neighbor relations;
- deterministic instance naming;
- early mapping diagnostics for missing or multiply assigned destinations;
- final RHDL type, ownership, one-driver, and cycle verification; and
- identical CIRCT and Verilog structure to an explicit-loop reference fixture.

Every Racket or Rhombus validation command uses one newly created
`PLTCOMPILEDROOTS` directory for the focused batch, and direct `racket`
invocations use `-y`. Generated compiled and Verilator artifacts remain out of
version control.

## First consumers and equivalence gates

The first pure consumer is the existing rectangular-mesh NoC authoring helper.
Ridx may replace its nested coordinate and neighbor enumeration internally, but
it must still produce the same `TopologySpec`, link identities, mesh view,
normalized topology, routing semantics fingerprint, and diagnostics. Ridx does
not replace NoC materialization, reachability, dependency analysis, validation,
or planning.

The second consumer must be independent of the NoC domain. The initial choice
is a small RHDL grid fixture whose cell instances are indexed by a two-axis
space and whose explicit local rule wires dropped or wrapped neighbors. A
host-only textual or visualization consumer should inspect the same symbolic
objects without importing RHDL.

The API is not stabilized until these consumers demonstrate all of the
following:

- the shared abstraction removes repeated coordinate and neighbor bookkeeping;
- consumer-specific identities and policies remain outside Ridx;
- error messages preserve named-axis and point provenance;
- the RHDL adapter preserves precise instance or endpoint access without
  exposing frontend internals; and
- generated hardware is semantically and structurally equivalent to explicit
  host-loop construction.

## Milestones

### Milestone 1: pure finite spaces — implemented

- Implement axes, nominal product spaces, points, views, and `Indexed` host
  values.
- Establish canonical enumeration, membership, provenance, and diagnostics.
- Add focused valid and invalid tests.

### Milestone 2: symbolic relations and mappings

- Implement the initial symbolic relation constructors and algebra.
- Add opaque finite predicates and immutable exactly-once materialization.
- Implement validated mappings, inverse views, and derived partitions.

### Milestone 3: incidence

- Add edge spaces with source and destination mappings.
- Preserve parallel edges, self-loops, and edge metadata associations.
- Derive set-valued adjacency relations without changing incidence identity.

### Milestone 4: NoC experiment

- Re-express rectangular-mesh coordinate and neighbor construction with Ridx.
- Lower into the existing authored `TopologySpec` and `RectangularMesh` view.
- Require the existing raw, builder, embedded, validation, and planning
  equivalence fingerprints to remain unchanged.

### Milestone 5: RHDL experiment

- Build the indexed cell-grid fixture using only public RHDL authoring forms.
- Add the smallest adapter needed for indexed construction and explicit
  relation traversal.
- Add a generic RHDL static-information mechanism only if the public surface
  cannot preserve keyed instance or endpoint access.
- Verify exact IR, CIRCT, and Verilog equivalence with an explicit-loop fixture.

### Milestone 6: stabilization gate

- Review the model against both independent consumers.
- Remove speculative operations without demonstrated use.
- Decide whether a `Cover`, additional symbolic relation nodes, serialization,
  or analysis APIs have concrete requirements.
- Update package documentation and boundary checks only after the experiment
  passes.

## Explicit non-goals

The initial Ridx work does not include:

- an APL dialect or array syntax for runtime hardware values;
- automatic spatial-to-temporal mapping, resource sharing, or scheduling;
- a generic graph replacement for domain-owned node and edge identities;
- implicit mux, arbitration, reduction, broadcast, or wiring semantics;
- automatic RHDL module hierarchy derived from partitions;
- physical placement, routing, congestion prediction, or RFPL geometry;
- a second hardware IR or Ridx operations in the existing core IR;
- backend or CIRCT changes;
- a general polyhedral solver or arbitrary affine-set engine;
- automatic simplification of opaque user predicates; or
- stable serialization before a real external consumer requires it.

## Completion criterion

The initial Ridx vertical slice is complete when the pure algebra is fully
tested, the NoC mesh and independent RHDL grid consume it without crossing the
dependency boundary, explicit-loop and Ridx-generated hardware are equivalent,
parallel-edge identity and one-driver constraints remain explicit, and no Ridx
concept appears in the public hardware IR.
