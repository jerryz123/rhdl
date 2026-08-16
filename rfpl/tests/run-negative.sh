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
