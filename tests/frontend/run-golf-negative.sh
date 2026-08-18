#!/usr/bin/env bash
# Runs isolated #lang rhdl/golf programs and checks their compact-syntax diagnostics.
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/../.." && pwd)"

exec racket -y -S "$repo_dir" "$repo_dir/tests/support/run-negative.rkt" \
  "$repo_dir/tests/frontend/invalid" \
  "$repo_dir/tests/frontend/run-golf-negative-cases.rktd"
