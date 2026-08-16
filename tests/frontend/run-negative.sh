#!/usr/bin/env bash
# Runs isolated #lang rhdl programs and checks their required frontend diagnostics.
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/../.." && pwd)"

exec racket -y -S "$repo_dir" "$repo_dir/tests/support/run-negative.rkt" \
  "$repo_dir/tests/frontend/invalid" \
  "$repo_dir/tests/frontend/run-negative-cases.rktd"
