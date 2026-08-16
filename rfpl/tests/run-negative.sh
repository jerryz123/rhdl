#!/usr/bin/env bash
# Runs isolated invalid RFPL programs and checks their required diagnostics.
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/../.." && pwd)"

expect_failure() {
  local source_file="$1"
  local expected="$2"
  local output
  if output="$(racket -y -S "$repo_dir" "$repo_dir/rfpl/tests/invalid/$source_file" 2>&1)"; then
    echo "$source_file unexpectedly succeeded" >&2
    exit 1
  fi
  if [[ "$output" != *"$expected"* ]]; then
    echo "$source_file did not contain expected diagnostic: $expected" >&2
    echo "$output" >&2
    exit 1
  fi
}

expect_failure logic-in-floorplan.rfpl "floorplan BadLogic cannot contain rtl.add"
expect_failure circuit-top.rfpl "elaboration did not select a top floorplan"
expect_failure circuit-instantiates-floorplan.rfpl "RHDL circuit CircuitWrapper cannot instantiate RFPL floorplan Leaf"
expect_failure floorplan-outside-elaborate.rfpl "floorplan generators may only be called during elaborate"
expect_failure wrong-type-wire.rfpl "connection source and target must have exactly the same hardware type"
expect_failure undriven-output.rfpl "place result is undriven"
expect_failure missing-size.rfpl "floorplan MissingSize must declare size(width: ..., height: ...)"
expect_failure duplicate-size.rfpl "floorplan DuplicateSize declares size more than once"
expect_failure zero-size.rfpl "floorplan size width must be positive"
expect_failure negative-size.rfpl "magnitude must be a nonnegative host Int"
expect_failure unitless-size.rfpl "floorplan size width must be a Length"
expect_failure size-outside-floorplan.rfpl "size may only be declared inside a floorplan"
expect_failure missing-floorplan-coordinate.rfpl "floorplan instance placed requires an at: coordinate"
expect_failure coordinate-on-circuit.rfpl "only floorplan instances accept an at: coordinate"
expect_failure unitless-coordinate.rfpl "x must be a Length"
expect_failure negative-coordinate.rfpl "magnitude must be a nonnegative host Int"
expect_failure out-of-bounds-coordinate.rfpl "floorplan instance placed does not fit within parent OutOfBoundsCoordinate"
expect_failure multiple-root-floorplans.rfpl "only the top floorplan may be generated outside a floorplan body"
expect_failure floorplan-generated-in-circuit.rfpl "floorplan Leaf may only be generated directly inside a floorplan body"
expect_failure untracked-floorplan-coordinate.rfpl "floorplan instance placed requires an at: coordinate"
