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

expect_failure logic-in-composite.rfpl "composite floorplan LogicTop cannot contain rtl.add"
expect_failure top-mismatch.rfpl "physical top Leaf does not match logical top Pair"
expect_failure missing-placement.rfpl "composite floorplan Pair has no placement for instance right"
expect_failure duplicate-placement.rfpl "instance left is placed more than once in composite floorplan Pair"
expect_failure wrong-view-target.rfpl "instance left targets circuit Leaf but its placement uses the view of Other"
expect_failure multiple-views.rfpl "circuit Leaf has more than one physical view"
expect_failure zero-size.rfpl "physical width must be positive"
expect_failure negative-size.rfpl "magnitude must be a nonnegative host Int"
expect_failure unitless-size.rfpl "physical width must be a Length"
expect_failure unitless-coordinate.rfpl "x must be a Length"
expect_failure negative-coordinate.rfpl "magnitude must be a nonnegative host Int"
expect_failure out-of-bounds-coordinate.rfpl "instance left does not fit within composite floorplan Pair"
