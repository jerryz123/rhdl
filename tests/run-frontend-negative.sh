#!/usr/bin/env bash
# Runs isolated #lang rhdl programs and checks their required frontend diagnostics.
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"

expect_failure() {
  local source_file="$1"
  local expected="$2"
  local output
  if output="$(racket -S "$repo_dir" "$repo_dir/tests/frontend/$source_file" 2>&1)"; then
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
expect_failure bad-input-drive.rhdl "inputs are read only"
expect_failure bad-parameter.rhdl "generator parameter width must be a host Int"
expect_failure bad-recursion.rhdl "recursive elaboration of module generator Recursive"
expect_failure bad-top-call.rhdl "module generators may only be called from elaborate"
expect_failure bad-width.rhdl "bad-width.rhdl:10:0: add operands must have exactly the same Bits width"
