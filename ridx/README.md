<!-- Documents the implemented Ridx finite-domain API, boundary, and focused workflow. -->

# Ridx

Ridx is a dependency-neutral Rhombus library for finite structural index
spaces. It gives host-side models and generators stable named coordinates,
canonical subset views, total point-indexed values, validated mappings, and
symbolic finite relations without assigning those structures any hardware,
topology, placement, or scheduling meaning.

RHDL is a future consumer of Ridx, not part of the Ridx model. Pure Ridx modules
never import RHDL, CIRCT, NoC, RFPL, or backend packages. Consumer packages are
responsible for translating Ridx objects into their own identities, validation
artifacts, plans, or generated structure.

The architecture, staged roadmap, and accepted non-goals are recorded in
[`PLAN.md`](PLAN.md).

## Current API

Milestones 1 and 2 provide:

- `Axis(name, extent)` for named positive finite axes;
- `IndexSpace(axes, ~name)` for nominal rectangular product spaces;
- bounded `IndexPoint` values with named-coordinate lookup and canonical
  ordinal calculation;
- `IndexView(space, points, ~name)` and `select_view` for canonical ordered
  subsets, including empty views; and
- `Indexed(domain, entries)` and `index_by` for total host-value associations
  over a space or view;
- `Mapping(source, target, assignments)` and `mapping_by` for total validated
  point mappings, canonical inverse views, and a total indexed collection of
  partition fibers;
- inspectable symbolic identity, universal, shift, axis-permutation,
  restriction, converse, union, intersection, composition, and opaque-predicate
  relations; and
- `materialize_relation` for immutable, canonically ordered pair snapshots.

Spaces are nominal: separately constructed spaces remain distinct even when
their axes and extents match. Points compare semantically only when they belong
to the same space and have equal coordinates. Views eliminate duplicate points
and restore parent-space order. Indexed values reject foreign, duplicate, and
missing points and likewise retain domain order.

Relation endpoints use exact finite domains: the parent space must be the same
nominal object and the canonical point sequence must match. View names are only
diagnostic. Constructing a symbolic relation does not enumerate it or invoke an
opaque predicate. One materialization pass queries every required opaque
source/target pair at most once, even when the same symbolic node is shared,
and the resulting snapshot retains no callback.

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

`labels.values()` follows the canonical mesh order:
`mesh{x=1,y=0}`, `mesh{x=1,y=1}`, then `mesh{x=1,y=2}`. Import
`lib("ridx/materialize/main.rhm")` to convert `right_neighbor` into a canonical
pair snapshot.

Identity-bearing incidence, the NoC experiment, and the explicit RHDL
elaboration adapter are later milestones. The current API deliberately does
not infer connectivity meaning or create hardware.

## Focused validation

Run the implemented Ridx model and materialization tests from the repository
root with a fresh compiled root:

```sh
ridx_compiled_root="$(mktemp -d)"
PLTCOMPILEDROOTS="$ridx_compiled_root" raco test \
  ridx/tests/model/milestone1-test.rhm \
  ridx/tests/model/mapping-test.rhm \
  ridx/tests/materialize/relation-test.rhm
```

The tests cover nominal space separation, deterministic enumeration, bounds and
foreign-point diagnostics, canonical and empty views, total indexed values,
mapping validation and inverse fibers, every symbolic constructor, canonical
relation algebra, and exactly-once opaque predicate evaluation.
