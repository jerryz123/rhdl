#!/usr/bin/env bash
# Runs isolated invalid TileLink programs and checks their package-owned diagnostics.
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/../.." && pwd)"

expect_failure() {
  local source_file="$1"
  local expected="$2"
  local output
  if output="$(racket -y -S "$repo_dir" "$repo_dir/tilelink/tests/invalid/$source_file" 2>&1)"; then
    echo "$source_file unexpectedly succeeded" >&2
    exit 1
  fi
  if [[ "$output" != *"$expected"* ]]; then
    echo "$source_file did not contain expected diagnostic: $expected" >&2
    echo "$output" >&2
    exit 1
  fi
}

expect_failure bad-tilelink-a-capability.rhdl "does not support"
expect_failure bad-tilelink-b-capability.rhdl "does not support"
expect_failure bad-tilelink-bundle-shape.rhdl "exactly the same wire shape"
expect_failure bad-tilelink-source-range.rhdl "does not support"
expect_failure bad-tilelink-sink-range.rhdl "does not support"
expect_failure bad-tilelink-address-range.rhdl "does not support"
expect_failure bad-tilelink-size-range.rhdl "does not support"
expect_failure bad-tilelink-uncached-coherence.rhdl "does not support"
expect_failure bad-tilelink-link-params.rhdl "require TLClientParams or TLManagerParams"
expect_failure bad-tilelink-role-params.rhdl "does not support"
