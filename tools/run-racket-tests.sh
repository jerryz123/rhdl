#!/usr/bin/env bash
# Runs one test batch in the caller's clean bytecode root or a fresh local root.
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
compiled_root="${PLTCOMPILEDROOTS:-}"

if [[ -z "$compiled_root" ]]; then
  compiled_root="$(mktemp -d /tmp/rhdl-test-compiled.XXXXXX)"
  trap 'rm -rf "$compiled_root"' EXIT
fi

env PLTCOMPILEDROOTS="$compiled_root" PLTCOLLECTS="$repo_dir": \
  raco test --direct "$@"
