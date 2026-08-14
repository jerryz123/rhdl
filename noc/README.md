<!-- Defines the pure host-side NoC model and analysis contract and their separation from RHDL. -->

# Pure NoC model and analysis

This package defines the host-side graph vocabulary that will eventually feed
routing-relation materialization, virtual-channel dependency validation, and
route-table generation. It is intentionally independent of RHDL hardware
construction and CIRCT.

## Current scope

The current implementation provides:

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

Parallel physical links and self-loops are legal. Topology construction rejects
duplicate identities, missing link endpoints, and nonpositive VC counts.

The package does not yet validate dependency-graph acyclicity or generate
route tables.

## Dependency boundary

Files under `noc/model/` and `noc/analysis/` use only `#lang rhombus` and other
modules in the pure NoC package. They must not import RHDL core, frontend,
backend, standard-library hardware modules, or CIRCT integration.

Run the focused checks from the repository root:

```sh
env PLTCOLLECTS="$(pwd):" raco test noc/tests/model-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/materialize-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/reachability-test.rhm
env PLTCOLLECTS="$(pwd):" raco test noc/tests/dependency-graph-test.rhm
bash noc/check-boundaries.sh
```

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
provenance is the evidence that the next acyclicity pass will attach to a cycle
witness.
