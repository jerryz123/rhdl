#!/usr/bin/env bash
# Runs invalid topology-language fixtures and checks their source-located diagnostics.
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/../../.." && pwd)"
fixture_dir="$repo_dir/noc/tests/language/invalid"
compiled_root="$(mktemp -d "${TMPDIR:-/tmp}/rhdl-noc-language.XXXXXX")"
trap 'rm -rf "$compiled_root"' EXIT

expect_failure() {
  local source_file="$1"
  local expected="$2"
  local output
  if output="$(PLTCOMPILEDROOTS="$compiled_root" racket -y -S "$repo_dir" "$fixture_dir/$source_file" 2>&1)"; then
    echo "$source_file unexpectedly succeeded" >&2
    exit 1
  fi
  if [[ "$output" != *"$expected"* ]]; then
    echo "$source_file did not contain expected diagnostic: $expected" >&2
    echo "$output" >&2
    exit 1
  fi
  if [[ "$output" != *"$source_file:"* ]]; then
    echo "$source_file diagnostic did not retain its source location" >&2
    echo "$output" >&2
    exit 1
  fi
}

expect_failure duplicate-node.rhm.invalid "duplicate topology node repeated"
expect_failure duplicate-link.rhm.invalid "duplicate topology link forward"
expect_failure unknown-node.rhm.invalid "unknown topology node missing"
expect_failure unknown-group.rhm.invalid "unknown topology VC group missing"
expect_failure malformed-clause.rhm.invalid "expected vc_group, node, directed, or bidirectional topology declaration"
expect_failure empty-vcs.rhm.invalid "directed topology link requires at least one VC group"
expect_failure duplicate-link-group.rhm.invalid "duplicate VC group escape on topology link broken"
