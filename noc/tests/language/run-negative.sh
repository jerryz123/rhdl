#!/usr/bin/env bash
# Runs invalid topology-language fixtures and checks their source-located diagnostics.
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/../../.." && pwd)"
compiled_root="$(mktemp -d "${TMPDIR:-/tmp}/rhdl-noc-language.XXXXXX")"
trap 'rm -rf "$compiled_root"' EXIT

PLTCOMPILEDROOTS="$compiled_root" racket -S "$repo_dir" \
  "$repo_dir/noc/tests/language/run-negative.rkt"
