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
- Symbolic route classes with deterministic normalized IDs and provenance.
- Inspectable routing-policy expressions with symbolic contexts and lowering to
  the existing normalized routing relation.
- Resource-visible routing phases expressed as named VC-group transitions,
  without hidden mutable packet state.
- Separate standard definitions for line and rectangular-mesh topologies.
- A standard all-pairs traffic definition that produces ordinary symbolic
  route-class specifications for any authored topology.
- Standard XY and YX dimension-order policies defined as clients of the
  generic routing-policy interface and rectangular-mesh view.
- Minimal-adaptive mesh routing with irreversible XY escape transitions,
  intentionally rejected by the current whole-graph acyclicity proof.
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
- An opaque validated-routing artifact and deterministic host route-table rows.

Parallel physical links and self-loops are legal. Topology construction rejects
duplicate identities, missing link endpoints, and nonpositive VC counts.

The package does not yet lower route tables into RHDL or generate router RTL.

## Dependency boundary

Files under `noc/model/`, `noc/authoring/`, `noc/analysis/`, `noc/plan/`, and
`noc/std/` use only `#lang rhombus` and other modules in the pure NoC package.
They must not import RHDL core, frontend, backend, standard-library hardware
modules, or CIRCT integration. Core model, authoring, analysis, and planning
modules must not import `noc/std`; reusable topology and routing definitions
depend on the core abstractions, never the reverse.

Run the focused checks from the repository root:

```sh
env PLTCOLLECTS="$(pwd):" raco test noc/tests/model-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/authoring/topology-authoring-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/authoring/topology-composition-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/authoring/route-class-authoring-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/authoring/routing-policy-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/authoring/routing-phase-authoring-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/std/topology/line-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/std/topology/rectangular-mesh-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/std/traffic/all-pairs-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/std/routing/dimension-order-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/std/routing/adaptive-minimal-escape-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/examples/mesh-topology-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/examples/mesh-traffic-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/examples/mesh-xy-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/examples/mesh-phased-xy-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/examples/mesh-adaptive-escape-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/materialize-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/reachability-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/dependency-graph-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/acyclicity-test.rhm
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
order, copies opaque metadata unchanged, and retains bidirectional provenance.

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

The mesh-phased-XY example is a user-level composition rather than another
core policy primitive. It uses `x-phase` VCs while consuming x displacement,
irreversibly enters `y-phase` on the first y hop, and remains there. The example
demonstrates phase inspection, raw-relation equivalence, reachable-dead-end
diagnostics, and pruning of unreachable phase transitions under the current
acyclic dependency proof.

`AdaptiveMinimalEscapePolicy` allows every Manhattan-distance-reducing
adaptive direction, so a packet may choose either dimension while both differ.
Injection and adaptive forwarding may instead acquire an escape VC following
XY order. Escape forwarding is closed over the selected escape groups and may
never return to an adaptive group. Adaptive and escape group sets are explicit,
nonempty, disjoint, and validated against the mesh view.

The mesh-adaptive-escape example deliberately does not produce
`ValidatedRouting` for the full policy. Reachability succeeds, but the existing
whole-graph acyclicity checker reports a stable cycle containing only adaptive
VCs. The independently materialized raw callback, reversed declarations, and
prefixed topology produce the same decisions and cycle witness. Restricting the
same topology and traffic to escape-only XY produces `ValidatedRouting`.

This isolates a proof-system limitation rather than an authoring or lowering
limitation. Accepting the full adaptive policy requires a separately specified
escape-subnetwork theorem, certificate, and implementation assumptions; the
current validator has not been weakened or bypassed.

## Model

`NodeId`, `LinkId`, `VCId`, and `RouteClassId` are nominal identities backed by
nonnegative host integers. A `VCId` consists of a physical link identity and a
zero-based local VC index.

A `PhysicalLink` is a directed edge:

```text
PhysicalLink(id, source, destination, vc_count)
```

`Topology` sorts nodes and links by identity. VC enumeration follows sorted
link identity and then increasing local VC index, making subsequent graph and
table construction deterministic.

A `RouteClass` currently identifies one injection node and one destination
node. Its `metadata` field is opaque to the model and may carry distinctions
such as a virtual network or traffic class for a user routing function.

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
witness.

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

## Validated routing and route tables

`compile_routing` is the single validation gate from `RoutingProblem` to
hardware-consumable domain data. It runs materialization, reachability,
dependency-graph construction, and acyclicity checking in order. An acyclic
input produces `ValidatedRouting`; a cyclic input produces its
`DependencyCycle`. Reachability and model errors remain explicit failures.

Only the validation module can construct `ValidatedRouting`. The artifact
retains the normalized topology, route classes, materialized and reachable
relations, dependency graph, rank certificate, proof assumptions, validator
version, and deterministic `RouteTable`.

There is one table row for each route class's legal injection origin and each
reachable held VC. A row records its router node, whether it ejects, and the
allowed output VCs copied from the exact materialized snapshot that passed
validation. Unreachable materialized origins are omitted so routing decisions
excluded from the dependency proof cannot leak into generated hardware. No
route-table operation can reach or re-run the user callback.
