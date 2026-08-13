#!/usr/bin/env bash
# Runs isolated #lang rhdl programs and checks their required frontend diagnostics.
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/../.." && pwd)"

expect_failure() {
  local source_file="$1"
  local expected="$2"
  local output
  if output="$(racket -S "$repo_dir" "$repo_dir/tests/frontend/invalid/$source_file" 2>&1)"; then
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
expect_failure bad-instance-port.rhdl "instance u has no port named missing"
expect_failure bad-mux-key-type.rhdl "mux lookup keys must be host Int values"
expect_failure bad-mux-key-width.rhdl "mux lookup key does not fit its selector type"
expect_failure bad-mux-duplicate-key.rhdl "mux lookup keys must be unique"
expect_failure bad-parameter.rhdl "circuit parameters must be host Int values"
expect_failure bad-recursion.rhdl "recursive elaboration of circuit Recursive"
expect_failure bad-top-call.rhdl "circuit generators may only be called during elaborate"
expect_failure bad-width.rhdl "add operands must have exactly the same Bits width"
