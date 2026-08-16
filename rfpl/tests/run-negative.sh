#!/usr/bin/env bash
# Runs isolated invalid RFPL programs and checks their required diagnostics.
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/../.." && pwd)"

exec racket -y -S "$repo_dir" "$repo_dir/tests/support/run-negative.rkt" \
  "$repo_dir/rfpl/tests/invalid" \
  "$repo_dir/rfpl/tests/run-negative-cases.rktd"
