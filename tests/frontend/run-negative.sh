#!/usr/bin/env bash
# Runs isolated #lang rhdl programs and checks their required frontend diagnostics.
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/../.." && pwd)"

expect_failure() {
  local source_file="$1"
  local expected="$2"
  local output
  # Invalid fixtures cannot be rebuilt with raco make, so ignore any stale
  # source-adjacent bytecode left by an earlier frontend expansion.
  if output="$(racket -y -S "$repo_dir" "$repo_dir/tests/frontend/invalid/$source_file" 2>&1)"; then
    echo "$source_file unexpectedly succeeded" >&2
    exit 1
  fi
  if [[ "$output" != *"$expected"* ]]; then
    echo "$source_file did not contain expected diagnostic: $expected" >&2
    echo "$output" >&2
    exit 1
  fi
}

expect_failure bad-input-drive.rhdl "connection target must be a driveable hardware place"
expect_failure bad-instance-combinational-cycle.rhdl "combinational cycle reaches value u.y"
expect_failure bad-instance-port.rhdl "instance u has no port or interface named missing"
expect_failure bad-interface-directions.rhdl "incompatible roles and boundary directions"
expect_failure bad-interface-member-type.rhdl "interface member type must be a DataType or InterfaceType"
expect_failure bad-interface-provider-role.rhdl "provider role must be one of the declared roles"
expect_failure bad-interface-role.rhdl "unknown interface role observer"
expect_failure bad-interface-support-role.rhdl "contract role must match the provider role"
expect_failure bad-interface-specialization-compatibility.rhdl "does not support"
expect_failure bad-interface-specialization-shape.rhdl "exactly the same wire shape"
expect_failure bad-interface-compatibility-result.rhdl "must return a host Boolean"
expect_failure bad-interface-exact-specialization.rhdl "argument does not satisfy annotation"
expect_failure bad-interface-equal-specialization-compatibility.rhdl "does not support"
expect_failure bad-interface-type.rhdl "does not support"
expect_failure bad-tilelink-a-capability.rhdl "does not support"
expect_failure bad-tilelink-b-capability.rhdl "does not support"
expect_failure bad-tilelink-bundle-shape.rhdl "exactly the same wire shape"
expect_failure bad-tilelink-source-range.rhdl "does not support"
expect_failure bad-tilelink-sink-range.rhdl "does not support"
expect_failure bad-tilelink-address-range.rhdl "does not support"
expect_failure bad-tilelink-size-range.rhdl "does not support"
expect_failure bad-tilelink-uncached-coherence.rhdl "does not support"
expect_failure bad-tilelink-link-params.rhdl "require TLClientLinkParams or TLManagerLinkParams"
expect_failure bad-tilelink-role-params.rhdl "does not support"
expect_failure bad-interface-array-zero.rhdl "length must be a positive host Int"
expect_failure bad-interface-array-count.rhdl "length must be a positive host Int"
expect_failure bad-interface-array-index.rhdl "interface array index must be a host Int"
expect_failure bad-interface-array-duplicate.rhdl "duplicate interface endpoint"
expect_failure bad-interface-array-length.rhdl "must have the same length"
expect_failure bad-interface-array-type.rhdl "does not support"
expect_failure bad-interface-array-role.rhdl "incompatible roles and boundary directions"
expect_failure bad-mux-key-type.rhdl "mux lookup keys must be host Int values"
expect_failure bad-mux-key-width.rhdl "mux lookup key does not fit its selector type"
expect_failure bad-mux-duplicate-key.rhdl "mux lookup keys must be unique"
expect_failure bad-switch-empty.rhdl "switch requires at least one case"
expect_failure bad-switch-case-after-otherwise.rhdl "switch case cannot follow otherwise"
expect_failure bad-parameter.rhdl "circuit parameters must be host values, not hardware values"
expect_failure bad-register-parameter.rhdl "circuit parameters must be host values, not hardware values"
expect_failure bad-ambient-register.rhdl "implicit clock/reset use requires an active sync_circuit"
expect_failure bad-assert-host-condition.rhdl "expected readable hardware data"
expect_failure bad-assert-wide-condition.rhdl "assert condition must be a one-bit FlatDataType"
expect_failure bad-assert-partial-domain.rhdl "explicit assertions require both ~clock and ~reset"
expect_failure bad-assert-outside-sync.rhdl "implicit clock/reset use requires an active sync_circuit"
expect_failure bad-enum-encoding.rhdl "enum encodings must be unique"
expect_failure bad-enum-width.rhdl "enum encoding does not fit the declared width"
expect_failure bad-enum-assignment.rhdl "connection source and target must have exactly the same hardware type"
expect_failure bad-enum-equality.rhdl "=== operands must have exactly the same FlatDataType"
expect_failure bad-enum-inequality.rhdl "=/= operands must have exactly the same FlatDataType"
expect_failure bad-invert-enum.rhdl "bit_not operand must have a bitwise type"
expect_failure bad-enum-member.rhdl "enum State has no member named Missing"
expect_failure bad-enum-mux-integer-key.rhdl "enum mux lookup keys must be members of the selector's enum type"
expect_failure bad-enum-mux-foreign-key.rhdl "enum mux lookup keys must be members of the selector's enum type"
expect_failure bad-enum-mux-duplicate-key.rhdl "mux lookup keys must be unique"
expect_failure bad-sync-parent.rhdl "implicit clock/reset use requires an active sync_circuit"
expect_failure bad-sync-partial-override.rhdl "explicit sync child wiring requires both clock and reset"
expect_failure bad-interface-parameter.rhdl "circuit parameters must be host values, not hardware values"
expect_failure bad-recursion.rhdl "recursive elaboration of circuit Recursive"
expect_failure bad-nested-circuit-capture.rhdl "hardware value belongs to a different module"
expect_failure bad-nested-circuit-sync-inherit.rhdl "hardware value belongs to a different module"
expect_failure bad-top-call.rhdl "circuit generators may only be called during elaborate"
expect_failure bad-width.rhdl "add operands must have exactly the same arithmetic type and width"
expect_failure bad-expanding-arithmetic-type.rhdl "expanding arithmetic operands must be Bits"
expect_failure bad-unsigned-comparison-width.rhdl "unsigned comparison operands must have exactly the same Bits width"
expect_failure bad-unsigned-comparison-type.rhdl "unsigned comparison operands must have exactly the same Bits width"
expect_failure bad-shift-amount.rhdl "shift amount must be Bits"
expect_failure bad-signed-width.rhdl "same arithmetic type and width"
expect_failure bad-signed-mixed-type.rhdl "same arithmetic type and width"
expect_failure bad-signed-comparison.rhdl "same signed arithmetic type and width"
expect_failure bad-signed-literal.rhdl "fit the declared signed width"
expect_failure bad-signed-shift-amount.rhdl "shift amount must be Bits"
expect_failure base-core-leak.rhdl "Design: unbound identifier"
expect_failure base-kernel-leak.rhdl "run_elaboration: unbound identifier"
expect_failure base-kernel-port-leak.rhdl "input: misuse as an expression"
expect_failure base-layer-leak.rhdl "Bool: unbound identifier"
expect_failure default-core-leak.rhdl "Design: unbound identifier"
expect_failure default-kernel-leak.rhdl "run_elaboration: unbound identifier"
expect_failure base-enum-leak.rhdl "hardware_enum: unbound identifier"
expect_failure base-assertion-leak.rhdl "assert: unbound identifier"
expect_failure base-sync-leak.rhdl "sync_circuit: unbound identifier"
