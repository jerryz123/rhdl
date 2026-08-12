#!/usr/bin/env bash
# Runs isolated #lang rhdl programs and checks their required frontend diagnostics.
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"

expect_failure() {
  local source_file="$1"
  local expected="$2"
  local output
  if output="$(racket -S "$repo_dir" "$repo_dir/tests/invalid/$source_file" 2>&1)"; then
    echo "$source_file unexpectedly succeeded" >&2
    exit 1
  fi
  if [[ "$output" != *"$expected"* ]]; then
    echo "$source_file did not contain expected diagnostic: $expected" >&2
    echo "$output" >&2
    exit 1
  fi
}

expect_failure bad-condition.rhdl "hardware values cannot control host conditions"
expect_failure bad-input-drive.rhdl "connection target must be an output, instance input, or register next state"
expect_failure bad-parameter.rhdl "circuit parameters must be host Int values"
expect_failure bad-recursion.rhdl "recursive elaboration of circuit Recursive"
expect_failure bad-top-call.rhdl "circuit generators may only be called during elaborate"
expect_failure bad-width.rhdl "add operands must have exactly the same Bits width"
