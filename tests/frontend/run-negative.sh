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
expect_failure bad-input-drive.rhdl "connection target must be a driveable hardware place"
expect_failure bad-instance-port.rhdl "instance u has no port or interface named missing"
expect_failure bad-interface-directions.rhdl "incompatible roles and boundary directions"
expect_failure bad-interface-member-type.rhdl "interface member type must be a DataType or InterfaceType"
expect_failure bad-interface-role.rhdl "unknown interface role observer"
expect_failure bad-interface-type.rhdl "same interface type"
expect_failure bad-mux-key-type.rhdl "mux lookup keys must be host Int values"
expect_failure bad-mux-key-width.rhdl "mux lookup key does not fit its selector type"
expect_failure bad-mux-duplicate-key.rhdl "mux lookup keys must be unique"
expect_failure bad-parameter.rhdl "circuit parameters must be host values, not hardware values"
expect_failure bad-register-parameter.rhdl "circuit parameters must be host values, not hardware values"
expect_failure bad-ambient-register.rhdl "implicit clock/reset use requires an active sync_circuit"
expect_failure bad-enum-encoding.rhdl "enum encodings must be unique"
expect_failure bad-enum-width.rhdl "enum encoding does not fit the declared width"
expect_failure bad-enum-assignment.rhdl "connection source and target must have exactly the same hardware type"
expect_failure bad-enum-equality.rhdl "=== operands must have exactly the same FlatDataType"
expect_failure bad-enum-member.rhdl "enum State has no member named Missing"
expect_failure bad-enum-mux-integer-key.rhdl "enum mux lookup keys must be members of the selector's enum type"
expect_failure bad-enum-mux-foreign-key.rhdl "enum mux lookup keys must be members of the selector's enum type"
expect_failure bad-enum-mux-duplicate-key.rhdl "mux lookup keys must be unique"
expect_failure bad-sync-parent.rhdl "implicit clock/reset use requires an active sync_circuit"
expect_failure bad-sync-partial-override.rhdl "explicit sync child wiring requires both clock and reset"
expect_failure bad-interface-parameter.rhdl "circuit parameters must be host values, not hardware values"
expect_failure bad-recursion.rhdl "recursive elaboration of circuit Recursive"
expect_failure bad-top-call.rhdl "circuit generators may only be called during elaborate"
expect_failure bad-width.rhdl "add operands must have exactly the same Bits width"
expect_failure bad-expanding-arithmetic-type.rhdl "expanding arithmetic operands must be Bits"
expect_failure bad-unsigned-comparison-width.rhdl "unsigned comparison operands must have exactly the same Bits width"
expect_failure bad-unsigned-comparison-type.rhdl "unsigned comparison operands must have exactly the same Bits width"
expect_failure bad-shift-amount.rhdl "shift amount must be Bits"
expect_failure base-core-leak.rhdl "Design: unbound identifier"
expect_failure base-kernel-leak.rhdl "run_elaboration: unbound identifier"
expect_failure base-kernel-port-leak.rhdl "input: misuse as an expression"
expect_failure base-layer-leak.rhdl "Bool: unbound identifier"
expect_failure default-core-leak.rhdl "Design: unbound identifier"
expect_failure default-kernel-leak.rhdl "run_elaboration: unbound identifier"
expect_failure base-enum-leak.rhdl "hardware_enum: unbound identifier"
expect_failure base-sync-leak.rhdl "sync_circuit: unbound identifier"
