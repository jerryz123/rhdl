#!/usr/bin/env bash
# Runs Racket with source rebuilding unless an exact CI bytecode artifact is verified.
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "${RHDL_PRECOMPILED:-}" == 1 ]]; then
  "$repo_dir/tools/racket-artifact.sh" verify
  exec racket "$@"
fi

exec racket -y "$@"
