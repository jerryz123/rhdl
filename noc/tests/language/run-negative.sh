#!/usr/bin/env bash
# Runs invalid topology-language fixtures and checks their source-located diagnostics.
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/../../.." && pwd)"

exec racket -y -S "$repo_dir" "$repo_dir/noc/tests/language/run-negative.rkt"
