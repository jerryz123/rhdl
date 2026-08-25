<!-- Documents RFPL's public physical-view language, validation rules, and focused checks. -->

# RFPL physical views

RFPL annotates an already elaborated RHDL design with rectangular physical
views. It does not construct hardware, mutate the logical IR, or affect CIRCT
and SystemVerilog output. A physical design retains the original
`DesignElaboration` and adds one validated view per reachable module.

Use `#lang rfpl` for annotation modules. The language combines ordinary
Rhombus with the RFPL forms below; logical circuits remain ordinary RHDL
modules imported by the annotation.

## Views and placement

- `hard_macro(module, width: ..., height: ...)` treats a finished module as an
  opaque physical block. The module may contain arbitrary RHDL logic.
- `floorplan(module, width: ..., height: ..., placements: [...])` describes a
  wiring-only hierarchical module. Every direct child instance must appear
  exactly once and the module may contain only ports, wires, drives, and
  instances.
- `place(instance, child_view, at: (x, y))` places a direct child at an exact
  nonnegative coordinate. The child view must target the instance's module and
  its rectangle must fit within the parent outline.
- `annotate(logical, top_view)` validates the reachable view hierarchy and
  returns a `FloorplanDesign`. The view's module must be the logical design's
  top, and one logical module cannot acquire conflicting physical views.

Lengths are exact integer picometers. `nm(n)` and `um(n)` construct nanometer
and micrometer lengths without floating-point conversion. Widths and heights
must be positive.

The canonical executable example is
[`../examples/rfpl/circuit-pair.rfpl`](../examples/rfpl/circuit-pair.rfpl). It
uses `child_instance` and `instance_target` to select the finished RHDL
hierarchy rather than duplicating its structure.

## Boundaries and verification

RFPL depends only on the public completed RHDL core IR. RHDL core, frontend,
standard-library, and backend packages do not import RFPL. Physical metadata
does not appear in emitted CIRCT; the structural test verifies that annotating
a design leaves its generated hardware unchanged.

Run the focused checks from the repository root:

```sh
make rfpl-test
make rfpl-circt-test
```

The first target checks RFPL package boundaries, structural validation,
invalid uses, and examples. The second runs the RFPL-owned CIRCT fixture and
its example-owned Verilog reference.
