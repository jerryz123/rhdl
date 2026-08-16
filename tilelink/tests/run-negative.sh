#!/usr/bin/env bash
# Runs isolated invalid TileLink programs and checks their package-owned diagnostics.
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/../.." && pwd)"

exec racket -y -S "$repo_dir" "$repo_dir/tests/support/run-negative.rkt" \
  "$repo_dir/tilelink/tests/invalid" \
  "$repo_dir/tilelink/tests/run-negative-cases.rktd"
