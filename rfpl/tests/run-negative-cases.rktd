;; Lists invalid RFPL fixtures and the diagnostics each must produce.

(("logic-in-composite.rfpl" "composite floorplan LogicTop cannot contain rtl.add")
 ("top-mismatch.rfpl" "physical top Leaf does not match logical top Pair")
 ("missing-placement.rfpl" "composite floorplan Pair has no placement for instance right")
 ("duplicate-placement.rfpl" "instance left is placed more than once in composite floorplan Pair")
 ("wrong-view-target.rfpl" "instance left targets circuit Leaf but its placement uses the view of Other")
 ("multiple-views.rfpl" "circuit Leaf has more than one physical view")
 ("zero-size.rfpl" "physical width must be positive")
 ("negative-size.rfpl" "magnitude must be a nonnegative host Int")
 ("unitless-size.rfpl" "physical width must be a Length")
 ("unitless-coordinate.rfpl" "x must be a Length")
 ("negative-coordinate.rfpl" "magnitude must be a nonnegative host Int")
 ("out-of-bounds-coordinate.rfpl" "instance left does not fit within composite floorplan Pair"))
