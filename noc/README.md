<!-- Defines the pure host-side NoC model and analysis contract and their separation from RHDL. -->

# Pure NoC model and analysis

This package defines the host-side graph vocabulary that will eventually feed
routing-relation materialization, virtual-channel dependency validation, and
route-table generation. It is intentionally independent of RHDL hardware
construction and CIRCT.

## Current scope

The current implementation provides:

- Symbolic hierarchical node and directed-link handles for topology authoring.
- Named VC groups with deterministic local VC assignment.
- Immutable symbolic topology specifications with early structural validation.
- Deterministic lowering to the normalized topology model with bidirectional
  identity-provenance lookups.
- Hierarchical prefixing and collision-checked topology composition.
- Topology-independent directed and bidirectional link helpers.
- Optional embedded structural topology declarations that expand only into
  the public authoring API.
- Optional embedded unordered routing rules that expand only into the public
  policy algebra.
- A complete pre-hardware equivalence matrix for raw, builder, and embedded
  authoring paths that does not re-materialize their routing relations.
- Authored compilation diagnostics that project normalized cycle and escape
  failures back to symbolic topology, route, and routing-rule names.
- Symbolic route classes with deterministic normalized IDs and provenance.
- Inspectable routing-policy expressions with symbolic contexts and lowering to
  the existing normalized routing relation.
- Resource-visible routing phases expressed as named VC-group transitions,
  without hidden mutable packet state.
- Generic irreversible composition of independent adaptive and escape policies.
- Separate standard definitions for line and rectangular-mesh topologies.
- A standard all-pairs traffic definition that produces ordinary symbolic
  route-class specifications for any authored topology.
- Standard XY and YX dimension-order policies defined as clients of the
  generic routing-policy interface and rectangular-mesh view.
- Generic minimal-adaptive routing over precomputed hop distances for any
  authored directed topology.
- Deterministic up*/down* routing synthesis for connected bidirectional
  topologies with an explicit root and canonical tie-breaking.
- Minimal-adaptive mesh routing with irreversible XY escape transitions,
  rejected by default whole-graph acyclicity and accepted by explicit escape
  validation.
- An irregular cyclic topology combining generic minimal adaptation with a
  user-authored spanning-tree escape policy under both proof modes.
- Nominal node, link, virtual-channel, and route-class identities.
- Explicit directed multigraph topologies.
- Positive, heterogeneous virtual-channel counts on physical links.
- Stable topology and VC normalization.
- Finite route classes with injection and destination nodes.
- Injection and held-VC routing origins.
- Physically legal candidate enumeration with automatic destination ejection.
- A host routing-relation wrapper.
- Deterministic, exactly-once materialization of every finite routing query.
- Immutable decision lookup and allowed-candidate queries that never re-run the
  user callback.
- Deterministic per-route reachability over allowed materialized decisions.
- Rejection of reachable dead ends and destinations that cannot be reached.
- Reachable-only VC dependency graph construction with merged route provenance.
- Deterministic dependency-graph acyclicity certificates and cycle witnesses.
- Escape-subnetwork closure, viable-entry, escape-only progress, and projected
  dependency-acyclicity validation with deterministic failure witnesses.
- Deterministic unit-hop distances and complete minimal-next-link sets for any
  directed topology.
- An opaque validated-routing artifact and deterministic host route-table rows.
- Deterministic router-local input and output encodings projected from that
  validated artifact.
- Deterministic whole-network plans assigning router indices, external
  injection and ejection ports, and every physical VC's source-target and
  destination-input indices without importing RHDL.

Parallel physical links and self-loops are legal. Topology construction rejects
duplicate identities, missing link endpoints, and nonpositive VC counts.

The pure packages do not lower route tables into RHDL or generate router RTL.
The separate [`rtl/`](rtl/README.md) package accepts only `RouterPlan` values
derived from `ValidatedRouting`. It lowers one router's finite local rows into
a combinational route computer and, for whole-graph-acyclic routing, a
buffered one-beat router. No RHDL dependency flows back into the pure layers.

## Dependency boundary

Files under `noc/model/`, `noc/authoring/`, `noc/analysis/`, `noc/language/`,
`noc/plan/`, and `noc/std/` use only `#lang rhombus` and other modules in the pure NoC package.
They must not import RHDL core, frontend, backend, standard-library hardware
modules, or CIRCT integration. Core model, authoring, analysis, and planning
modules must not import `noc/std`; reusable topology and routing definitions
depend on the core abstractions, never the reverse.

Files under `noc/rtl/` may import the public `#lang rhdl` language and reusable
RHDL standard primitives, plus the pure NoC model and plan. They must not
import RHDL core, frontend implementation, backend, or CIRCT modules.

The hardware bridge is tested separately by the focused route-computer and
one-beat-router frontend, CIRCT, and Verilator fixtures. The route-computer
fixture exhausts every encoded input of every router in a small validated
network. The router fixture checks one-to-one allocation, independent
backpressure, ejection contention, and packet conservation. Neither consumer
grants hardware code access to unvalidated relations or proof construction.

Run the focused checks from the repository root:

```sh
env PLTCOLLECTS="$(pwd):" raco test noc/tests/model-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/authoring/topology-authoring-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/authoring/topology-composition-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/authoring/route-class-authoring-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/authoring/routing-policy-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/authoring/routing-phase-authoring-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/authoring/escape-composition-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/language/topology-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/language/routing-test.rhm
bash noc/tests/language/run-negative.sh
env PLTCOLLECTS="$(pwd):" raco test noc/tests/equivalence/irregular-three-way-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/equivalence/mesh-xy-three-way-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/equivalence/adaptive-escape-three-way-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/equivalence/composition-three-way-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/support/routing-equivalence-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/plan/authored-diagnostics-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/plan/router-plan-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/plan/network-plan-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/std/topology/line-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/std/topology/rectangular-mesh-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/std/traffic/all-pairs-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/std/routing/dimension-order-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/std/routing/minimal-adaptive-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/std/routing/adaptive-minimal-escape-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/std/routing/up-down-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/examples/mesh-topology-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/examples/mesh-traffic-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/examples/mesh-xy-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/examples/mesh-phased-xy-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/examples/mesh-adaptive-escape-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/examples/irregular-adaptive-escape-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/materialize-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/reachability-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/dependency-graph-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/acyclicity-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/escape-validation-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/hop-distance-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/validated-routing-test.rhm
bash noc/check-boundaries.sh
```

## Topology authoring

The authoring layer lets users name topology objects without allocating the
numeric identities used by graph analysis. A `NamePath` is a nonempty list of
path segments; `NodeRef` and `LinkRef` are nominal handles containing those
paths. Topology composition can therefore qualify a fragment beneath a new
path without relying on globally meaningful numeric IDs.

A `TopologyLink` remains directed and owns one or more named `VCGroup` values.
Groups are sorted by name during construction, then each group's VCs are
assigned increasing local indices. Nodes and links are likewise sorted by
their full paths before lowering. The same complete `TopologySpec` therefore
always produces the same normalized IDs regardless of declaration order.

`lower_topology` returns a `LoweredTopology` containing the normalized
`Topology` and bidirectional bindings for every node, link, and VC. Routing
authoring and diagnostics can use meaningful names such as
`mesh/router[0]` and `mesh/east/escape[0]`, while all existing analysis
continues to consume `NodeId`, `LinkId`, and `VCId` values.

`prefix_topology` qualifies every node, link, endpoint, and derived VC beneath
one hierarchical name. `compose_topologies` combines already qualified
fragments and optional cross-fragment directed links, with `TopologySpec`
validation rejecting any remaining collisions. Composition order cannot
change normalized identities because complete symbolic paths determine the
canonical order.

`directed_link` preserves the normalized model's directed-edge semantics, and
`bidirectional_link` expands to two separately named directed links. These
composition operations make no assumptions about topology families,
coordinates, directions, or routing metrics. A user-defined topology view only
needs to contain an ordinary `TopologySpec`; it can expose any additional
domain queries without modifying core authoring or analysis modules.

## Embedded topology syntax

The optional `noc/language` package provides a structural `topology:`
expression for explicit graphs:

```rhombus
def network = topology:
  vc_group adaptive: 2
  vc_group escape: 1
  node a
  node b
  bidirectional (a_to_b, b_to_a):
    a <-> b
    vcs [adaptive, escape]
```

The form resolves its node, link, and VC-group identifiers lexically within
the declaration and returns an ordinary `TopologySpec`. Declarations may
appear in any order. `TopologySpec.node` and `TopologySpec.link` recover named
handles without exposing macro-generated local bindings. Duplicate and unknown
names are rejected during expansion at the relevant identifier; host values
such as VC counts remain subject to the public constructors' runtime checks.

Every accepted clause expands only into `NodeRef`, `LinkRef`, `VCGroup`,
`TopologyLink`, and `TopologySpec`. It does not lower numeric identities,
define topology families, materialize routing, invoke validation, or construct
hardware. Generated lines, meshes, and user topology views remain ordinary
functions in `std` or user modules.

## Embedded routing syntax

The same optional package provides a `routing:` expression whose named rules
form an unordered legal-routing relation:

```rhombus
def policy = routing:
  rule inject_adaptive:
    origin injection
    routes [request_route]
    candidate_vcs [adaptive]
    use adaptive_policy
  rule enter_escape:
    origin forwarding
    current_vcs [adaptive]
    candidate_vcs [escape]
    use escape_policy
```

Each rule lowers to `routing_phase(name,
policy_intersection(constraints))`; the complete form lowers to
`policy_union(rules)`. Both public combinators sort their children by stable
description, so rule and constraint order cannot imply preference or
arbitration priority. A rule name is inspectable diagnostic metadata, not
hidden packet state.

The initial constraints are `use`, `origin injection`, `origin forwarding`,
`routes`, `current_vcs`, `candidate_vcs`, and `candidate_links`. VC-group
identifiers become ordinary group-name strings. Route classes, candidate
links, and `use` policies remain host expressions, allowing hierarchical
lookups and user-defined abstractions without adding macro-only semantics.
Empty rules and selections, duplicate rule or group names, malformed origins,
and unknown clauses are rejected during expansion with source locations.
Unknown topology objects and non-policy runtime values remain errors of the
existing public authoring and lowering APIs.

Standard routing algorithms have no dedicated syntax. Dimension order,
minimal adaptation, up*/down*, and `with_escape` remain ordinary policies
passed through `use`. Consequently the syntax cannot construct a routing
relation, certificate, route table, or validated artifact by another path;
all decisions still pass through `lower_routing_policy`, finite
materialization, reachability, dependency analysis, and the selected proof
regime.

## Authored diagnostics and equivalence gate

`compile_authored_routing` is a pure host-side facade over the ordinary
authoring and validation APIs. Policy lowering records a
`LoweredRoutingDecision` beside each Boolean relation result during the same
evaluation that materialization requested. Reading or formatting the resulting
provenance never invokes the routing policy again. The normalized
`RoutingProblem`, `ValidatedRouting`, dependency graph, certificate, and route
table remain unchanged.

When whole-graph validation finds a cycle, the authored compilation attaches
an `AuthoredDependencyCycle`. Its edges use `VCRef` names and its causes retain
the originating `RouteClassRef`, symbolic origin and candidate VC, and the
matching `routing_phase` names. Escape closure, missing-entry, and
missing-route failures receive the same symbolic projection where their
normalized evidence permits it. Raw-model clients continue to use
`compile_routing` directly and do not depend on authoring types.

The pre-hardware equivalence tests independently cover an irregular directed
topology with explicit VC phases, a coordinate-bearing 2x2 mesh with XY
routing, adaptive-minimal routing under both whole-graph and escape proofs,
and prefixed topology-fragment composition. Each raw, builder, and embedded
form is reduced to a `RoutingSemantics` fingerprint containing the normalized
topology and route classes, materialized and reachable decisions, dependency
graph, proof result, route-table rows, assumptions, and validator version.
Hardware emission remains outside this package.

## Standard topology definitions

Reusable topology families live under `noc/std/topology/`, outside the core
authoring API. `directed_line` and `bidirectional_line` use stable `node[N]`,
`forward[N]`, and `reverse[N]` local names and can be instantiated multiple
times through generic prefixing.

A `RectangularMesh` is a typed view over an ordinary `TopologySpec`. It names
routers by coordinate and records each link's source coordinate, destination
coordinate, direction, and the declared VC groups. Positive x is east and
positive y is north. Queries such as `node_at`, `coordinate_of`,
`direction_of`, `outgoing_link`, and
`inverse_link` let future routing policies use topology semantics without
parsing names or inspecting normalized IDs. Prefixing a mesh qualifies its
symbolic handles while preserving the same coordinates and directions.

Line and mesh definitions are examples of libraries built on the authoring
contract, not concepts understood by the finite model, graph analysis, or
validated-routing artifact. User packages can define alternative topology
views in exactly the same way.

Concrete network choices belong under `noc/examples/` or in user packages.
The mesh-topology example selects one mesh size and VC-group configuration by
importing only the public authoring and standard-topology APIs; reusable
packages do not import that instance.

## Route-class authoring

`RouteClassRef` gives a finite route class a hierarchical symbolic name, while
`RouteClassSpec` keeps its source and destination as `NodeRef` values. The
generic `lower_route_classes` operation resolves those endpoints through one
exact `LoweredTopology`, assigns route-class IDs by canonical symbolic-name
order, and retains bidirectional provenance.

This layer defines only explicit route-class semantics. Reusable traffic sets
such as all ordered source/destination pairs belong under `noc/std/traffic/`,
and concrete selections belong under `noc/examples/` or in user packages.

## Standard traffic definitions

`all_pairs` generates ordinary `RouteClassSpec` values for every ordered pair
of symbolic nodes in any `TopologySpec`. Local routes are excluded by default
and can be included explicitly. Route names encode marked endpoint path
segments, so hierarchical node names remain deterministic and unambiguous
without depending on normalized `NodeId` values.

The definition performs no lowering or routing analysis. The mesh-traffic
example independently selects the reusable example mesh, applies `all_pairs`,
and lowers the result through that mesh's `LoweredTopology`.

## Routing-policy authoring

A `RoutingPolicy` is an inspectable host-side predicate expression over a
symbolic `RoutingContext`. Each context contains the original `RouteClassSpec`,
a symbolic injection or forwarding origin, the current `NodeRef`, and the
candidate `VCRef`. Topology-specific user libraries can therefore inspect the
candidate link through the VC reference without parsing normalized IDs.

The initial policy algebra can match route classes, distinguish injection from
forwarding, select candidate links, restrict named VC groups, and combine
predicates through unordered union or intersection. Composite children are
stored in deterministic description order; their order never implies routing
preference or arbitration priority. A labeled custom predicate is the explicit
escape hatch for semantics not yet represented by standard policy nodes.

`lower_routing_policy` validates symbolic route, link, and VC-group references
against one `LoweredRouteClasses` value, then returns an ordinary
`RoutingRelation`. Its callback translates each normalized materialization
query back into a symbolic context. It does not evaluate the finite query
domain itself, construct route tables, or bypass the existing materializer and
validation pipeline.

Routing phases use the held VC group as explicit resource-visible history.
`match_current_vc_groups` selects forwarding origins by that group,
`inject_into_vc_groups` defines initial acquisition, and
`transition_vc_groups` relates held and candidate groups. `routing_phase`
attaches an inspectable name to a policy branch without changing its Boolean
relation semantics. Lowering validates group references recursively through
named phases and ordinary policy composition.

This phase model deliberately adds no mutable phase field to a packet or route
class. A phase change is a VC acquisition visible to the existing finite
routing state and dependency graph. Unreachable phase branches are handled by
the existing reachability pass, while a missing reachable transition remains
a reachable-dead-end error.

`with_escape` composes independent adaptive and escape `RoutingPolicy` values
with explicit, nonempty, disjoint VC-group sets. Injection may enter either
set, forwarding from an adaptive VC may remain adaptive or enter escape, and
forwarding from an escape VC may only remain in escape. A held VC outside both
sets has no legal transition. The child policies still decide which physical
links are legal within their class; the combinator contributes only the
resource-visible, irreversible group transition. It lowers through the normal
`RoutingRelation` path and grants no special authority to validation.

## Standard routing policies

Reusable topology-specific policies live under `noc/std/routing/`, outside
core authoring and analysis. `DimensionOrderPolicy` is an inspectable client of
the generic `RoutingPolicy` interface for `RectangularMesh`. XY routing fully
consumes x displacement before y displacement; YX reverses that order. An
optional named VC-group restriction selects which VCs on the required link are
legal, while omission permits every declared group.

The policy uses mesh coordinates and typed link directions from the topology
view. It does not parse symbolic names, inspect normalized IDs, materialize the
relation, or construct route tables. The mesh-XY example applies escape-only
XY routing to the existing concrete mesh and all-pairs traffic examples, then
runs the ordinary validation pipeline to produce `ValidatedRouting`.

`MinimalAdaptivePolicy` is topology-independent. It translates symbolic
routing contexts through one exact `LoweredTopology` and admits every candidate
in an explicitly selected VC group whose physical link reduces the precomputed
hop distance to the destination by one. The caller supplies the
`HopDistances`, keeping shortest-path analysis separate from policy authoring
and avoiding repeated graph traversal during materialization. Equal-cost
branches, parallel links, injection, and forwarding all use the same rule.
The policy does not choose an escape subnetwork or imply that its complete VC
dependency graph is acyclic.

The mesh-phased-XY example is a user-level composition rather than another
core policy primitive. It uses `x-phase` VCs while consuming x displacement,
irreversibly enters `y-phase` on the first y hop, and remains there. The example
demonstrates phase inspection, raw-relation equivalence, reachable-dead-end
diagnostics, and pruning of unreachable phase transitions under the current
acyclic dependency proof.

`AdaptiveMinimalEscapePolicy` preserves the earlier mesh-specific API as a
thin compatibility wrapper. It composes generic `MinimalAdaptivePolicy`, XY
`DimensionOrderPolicy`, and `with_escape`; it no longer implements separate
Manhattan or phase-transition logic. Adaptive and escape group sets remain
explicit, nonempty, disjoint, and validated against the mesh view.

The mesh-adaptive-escape example shows both proof modes over the same full
policy. Default whole-graph acyclicity reports a stable cycle containing only
adaptive VCs. An explicit request classifying the XY VCs as escape produces an
`EscapeCertificate` and `ValidatedRouting` whose table still contains every
adaptive choice. The independently authored raw callback, reversed route
declarations, and prefixed topology produce equivalent materialized decisions,
proof graphs, certificates, and route tables. Escape-only XY remains a valid
whole-graph-acyclic comparison.

The irregular-adaptive-escape example applies the same generic pieces to a
five-node bidirectional ring with an attached leaf. Minimal adaptation derives
its choices solely from hop distances and produces an adaptive-only dependency
cycle. A user-defined tree view independently selects escape links; it is
ordinary example code rather than a core topology or routing primitive. The
escape certificate accepts the full relation and retains its adaptive choices.
Raw callback, reversed-declaration, and prefixed forms produce equivalent
materialized relations, cycle witnesses, proof graphs, orderings, and tables.

`UpDownPolicy` synthesizes a reusable escape policy for a connected
bidirectional topology. The caller supplies one exact `LoweredTopology`, an
explicit root, and the VC groups reserved for up*/down*. A deterministic BFS
rooted at that node assigns every node a unique rank using canonical symbolic
node order to break ties. Every directed link toward a lower rank is `up` and
every link toward a higher rank is `down`; self-loops and links without a
reverse direction are rejected.

The policy permits only an up* followed by down* turn sequence and precomputes
which `(node, destination, phase)` states can still reach the destination.
This viability filter prevents an allowed down turn from entering a branch
that would require a later forbidden up turn. Entering the selected groups
from injection or a non-up*/down* VC starts a fresh up phase, while a held
up*/down* VC carries the phase through its physical-link orientation. The
node order, link directions, and viable states remain inspectable ordinary
host data.

Synthesis grants no proof authority. Users compose the resulting policy with
`with_escape`, materialize the complete relation, and explicitly submit its
VCs through `EscapeValidationRequest`. The standard-policy tests exercise
that independent path on the irregular adaptive example and reject unsuitable
disconnected, one-way, self-loop, and incompletely provisioned topologies.

## Model

`NodeId`, `LinkId`, `VCId`, and `RouteClassId` are nominal identities backed by
nonnegative host integers. A `VCId` consists of a physical link identity and a
zero-based local VC index.

`compute_hop_distances` performs reverse breadth-first search from every
destination in a normalized directed topology. Its immutable `HopDistances`
result reports finite unit-hop distances, unreachable pairs, whether a link
strictly realizes the shortest-distance recurrence, and every minimal outgoing
link. It does not select one path or enumerate complete paths, so equal-length
alternatives and parallel physical links remain available to later adaptive
routing policies. Self-loops are never minimal because they cannot reduce the
remaining distance.

A `PhysicalLink` is a directed edge:

```text
PhysicalLink(id, source, destination, vc_count)
```

`Topology` sorts nodes and links by identity. VC enumeration follows sorted
link identity and then increasing local VC index, making subsequent graph and
table construction deterministic.

A `RouteClass` identifies one injection node and one destination node within a
single independently transported protocol-level channel. Protocol-channel,
opcode, QoS, and other payload distinctions are not part of the routing model.

Routing origins are either:

```text
Injection(node)
HeldVC(vc)
```

For an injection, physically legal candidates are all VCs on links leaving the
injection node. For a held VC, candidates are all VCs on links leaving the
current link's destination. Once an origin is at its route class's destination,
`RoutingProblem.candidates` returns an empty list to represent automatic
ejection without another routing-relation query.

The user policy is wrapped as:

```text
RoutingRelation(allows)

allows(route_class, origin, candidate_vc) -> Boolean
```

`materialize_routing` is the only analysis operation that invokes this
callback. In stable route-class, origin, and candidate order, it evaluates each
finite query once, requires a Boolean result, and returns `MaterializedRouting`.
The snapshot deliberately does not retain the callback. Its decision and
allowed-candidate methods therefore cannot re-evaluate user code.

## Reachability

`analyze_reachability` starts each route class at its injection origin and
traverses only allowed decisions stored in `MaterializedRouting`. Arrival at
the destination is automatic ejection and is terminal. The traversal rejects
every reachable non-destination origin with no allowed continuation, even when
another branch reaches the destination, and separately rejects cycles or other
subgraphs from which the destination is unreachable.

Successful analysis returns an opaque `ReachableRouting`. Each
`RouteReachability` contains VCs in deterministic discovery order and the
original `MaterializedDecision` values for reachable transitions. Decisions
in disconnected or otherwise unreachable routing states are excluded, so the
next dependency-graph pass will not report false cycles from unreachable
relation entries.

## VC dependency graph

`build_dependency_graph` projects each reachable decision of the form
`HeldVC(A) -> B` into the resource dependency edge `A -> B`. Injection
decisions are excluded because a packet holds no VC before its first
acquisition, and destination ejection acquires no resource.

The resulting opaque `VCDependencyGraph` includes all reachable VC vertices in
stable identity order. Duplicate edges are merged while retaining the original
`MaterializedDecision` values and all contributing route classes. This
provenance is the evidence that the acyclicity pass attaches to a cycle
witness. `project_dependency_graph` can retain an explicit subset of those
vertices and their induced edges without changing the originating reachable
routing evidence; escape validation uses this operation after classifying VCs.

## Acyclicity proof

`check_dependency_acyclicity` applies the initial deliberately narrow deadlock
criterion to the union of reachable VC dependencies. It returns one of two
opaque results:

- `AcyclicCertificate` contains a deterministic topological order. Its index is
  the VC rank, and every dependency edge points from a lower rank to a higher
  rank.
- `DependencyCycle` contains a closed, directed sequence of the original graph
  edges. Each edge still exposes the route classes and materialized routing
  decisions responsible for it.

Ties in the topological order and cycle search are resolved by stable VC
identity. This makes certificates and failure witnesses reproducible. The
criterion proves routing deadlock freedom only under the documented VC
hold-and-request model; it does not prove fairness, starvation freedom,
livelock freedom, or correctness of a future RTL implementation.

## Escape-subnetwork validation

`EscapeValidationRequest(topology, escape_vcs)` binds a nonempty, normalized
set of VC identities to one exact topology. Authored topologies can lower
named groups with `LoweredTopology.vc_ids_in_groups`, while raw-model clients
can supply `VCId` values directly. The request contains no routing callback and
does not infer proof authority from the class of an authored policy.

`validate_escape_subnetwork` consumes the already materialized relation, its
full reachability result, and its full dependency graph. It checks that every
reachable transition from an escape-held VC remains in escape, computes
escape-only backward viability to the destination, requires a viable escape
entry from every reachable non-destination injection or non-escape-held state,
and proves the reachable escape dependency projection acyclic. Success retains
opaque closure, per-route entry and progress evidence. Failure returns the
first deterministic `EscapeClosureViolation`, `MissingEscapeEntry`,
`MissingEscapeRoute`, or escape-projected `DependencyCycle`.

The escape theorem requires an implementation to let a packet continuously
request an available escape transition and eventually grant that persistent
request. It does not claim general arbitration fairness, starvation freedom,
or livelock freedom.

## Validated routing and route tables

`compile_routing` is the single validation gate from `RoutingProblem` to
hardware-consumable domain data. It runs materialization, reachability,
and dependency-graph construction exactly once. By default it applies
whole-graph acyclicity as before. Passing
`~escape: EscapeValidationRequest(...)` explicitly selects escape-subnetwork
validation. An accepted request produces an opaque `EscapeCertificate` with
the escape reachability and closure evidence, projected dependency graph,
topological ordering, validator version, and implementation assumptions.
Reachability and model errors remain explicit failures.

Only the validation module can construct `ValidatedRouting`. The artifact
retains the normalized topology, route classes, materialized and reachable
relations, full dependency graph, selected certificate, proof assumptions,
validator version, and deterministic `RouteTable`.

There is one table row for each route class's legal injection origin and each
reachable held VC. A row records its router node, whether it ejects, and the
allowed output VCs copied from the exact materialized snapshot that passed
validation. Unreachable materialized origins are omitted so routing decisions
excluded from the dependency proof cannot leak into generated hardware. No
route-table operation can reach or re-run the user callback. Escape-certified
tables are still projected from the complete materialized relation, so legal
adaptive choices outside the escape proof graph are retained exactly.

`RouterPlan(validated_routing, node)` is the only per-node projection consumed
by route-computer RTL. It retains the validated artifact, uses the global
stable route encoding, and assigns dense local origin and output-VC indices.
It states whether the node has injection and ejection endpoints. Local origins
consist of an injection slot when a route starts at the node plus every VC on
its incoming physical links. Local output bits correspond exactly to VCs on
outgoing physical links. Unused physical slots remain representable but have
no route row and therefore decode invalid.

Each `RouterPlanRow` points back to its validated `RouteTableRow` and records
the global route key, local origin key, and local output mask. An ejection-only
router legitimately has zero output VCs; the RHDL ABI uses one constant-zero
padding bit because hardware `Bits` values cannot have width zero. The padding
does not denote a VC and `output_count` remains zero.
