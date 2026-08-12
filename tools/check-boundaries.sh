#!/usr/bin/env bash
# Enforces RHDL source extensions and one-way core, frontend, and backend imports.
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir"

fail_matches() {
  local description="$1"
  local pattern="$2"
  local directory="$3"
  local matches
  matches="$(rg -n "$pattern" "$directory" --glob '*.rhm' || true)"
  if [[ -n "$matches" ]]; then
    echo "$description" >&2
    echo "$matches" >&2
    exit 1
  fi
}

fail_matches "core must not import frontend or backend modules" \
  '^[[:space:]]+"[^"]*(frontend|backend)/' rhdl/core
fail_matches "frontend must not import backend modules" \
  '^[[:space:]]+"[^"]*backend/' rhdl/frontend
fail_matches "backend must not import frontend modules" \
  '^[[:space:]]+"[^"]*frontend/' rhdl/backend
fail_matches "language assembly must not import backend modules" \
  '^[[:space:]]+"[^"]*backend/' rhdl/language.rhm

unexpected_top_level="$(find rhdl -maxdepth 1 -type f \
  ! -name 'main.rkt' ! -name 'language.rhm' -print)"
if [[ -n "$unexpected_top_level" ]]; then
  echo "rhdl root may contain only the reader shim and language assembly" >&2
  echo "$unexpected_top_level" >&2
  exit 1
fi

unexpected_racket="$(find rhdl -type f -name '*.rkt' ! -path 'rhdl/main.rkt' -print)"
if [[ -n "$unexpected_racket" ]]; then
  echo "only the #lang reader shim may use the .rkt extension" >&2
  echo "$unexpected_racket" >&2
  exit 1
fi

unexpected_rhdl="$(find . -path './.git' -prune -o -type f -name '*.rhdl' \
  ! -path './examples/*' ! -path './tests/frontend/*' -print)"
if [[ -n "$unexpected_rhdl" ]]; then
  echo ".rhdl files may appear only in examples and frontend fixtures" >&2
  echo "$unexpected_rhdl" >&2
  exit 1
fi
