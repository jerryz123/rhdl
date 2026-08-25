#!/usr/bin/env bash
# Runs Racket with source rebuilding unless an exact CI bytecode artifact is verified.
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
compiled_root="${PLTCOMPILEDROOTS:-}"

if [[ "${RHDL_PRECOMPILED:-}" == 1 ]]; then
  "$repo_dir/tools/racket-artifact.sh" verify
  exec racket "$@"
fi

if [[ -z "$compiled_root" ]]; then
  compiled_root="$(mktemp -d /tmp/rhdl-racket-compiled.XXXXXX)"
  trap 'rm -rf "$compiled_root"' EXIT
  env PLTCOMPILEDROOTS="$compiled_root" racket -y "$@"
  exit
fi

exec racket -y "$@"
