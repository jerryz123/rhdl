<!-- Documents the implemented Ridx finite-domain API, boundary, and focused workflow. -->

# Ridx

Ridx is a dependency-neutral Rhombus library for finite structural index
spaces. It gives host-side models and generators stable named coordinates,
canonical subset views, and total point-indexed values without assigning those
structures any hardware, topology, placement, or scheduling meaning.

RHDL is a future consumer of Ridx, not part of the Ridx model. Pure Ridx modules
never import RHDL, CIRCT, NoC, RFPL, or backend packages. Consumer packages are
responsible for translating Ridx objects into their own identities, validation
artifacts, plans, or generated structure.

The architecture, staged roadmap, and accepted non-goals are recorded in
[`PLAN.md`](PLAN.md).

## Current API

Milestone 1 provides:

- `Axis(name, extent)` for named positive finite axes;
- `IndexSpace(axes, ~name)` for nominal rectangular product spaces;
- bounded `IndexPoint` values with named-coordinate lookup and canonical
  ordinal calculation;
- `IndexView(space, points, ~name)` and `select_view` for canonical ordered
  subsets, including empty views; and
- `Indexed(domain, entries)` and `index_by` for total host-value associations
  over a space or view.

Spaces are nominal: separately constructed spaces remain distinct even when
their axes and extents match. Points compare semantically only when they belong
to the same space and have equal coordinates. Views eliminate duplicate points
and restore parent-space order. Indexed values reject foreign, duplicate, and
missing points and likewise retain domain order.

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
```

`labels.values()` follows the canonical mesh order:
`mesh{x=1,y=0}`, `mesh{x=1,y=1}`, then `mesh{x=1,y=2}`.

Symbolic relations, validated mappings, materialization, identity-bearing
incidence, and the explicit RHDL elaboration adapter are later milestones. The
current API deliberately does not infer connectivity or create hardware.

## Focused validation

Run the Milestone 1 tests from the repository root with a fresh compiled root:

```sh
ridx_compiled_root="$(mktemp -d)"
PLTCOMPILEDROOTS="$ridx_compiled_root" raco test ridx/tests/model/milestone1-test.rhm
```

The tests cover nominal space separation, deterministic enumeration, bounds and
foreign-point diagnostics, canonical and empty views, total indexed values,
and invalid axis, space, view, and indexing uses.
