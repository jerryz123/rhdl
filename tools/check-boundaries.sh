#!/usr/bin/env bash
# Enforces RHDL source conventions, layer imports, and standard/base profile composition.
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
fail_matches "standard language assembly must not import core or backend modules" \
  '^[[:space:]]+"[^"]*(core|backend)/' rhdl/language.rhm
fail_matches "base language assembly must not import core or backend modules" \
  '^[[:space:]]+"[^"]*(core|backend)/' rhdl/base/language.rhm
fail_matches "the standard frontend must aggregate public modules instead of core or kernel" \
  '^[[:space:]]+"[^"]*(core/|kernel\.rhm)' rhdl/frontend/standard.rhm
fail_matches "the base frontend must not depend on optional frontend modules" \
  '^[[:space:]]+"[^"]*(extensions/|standard\.rhm)' rhdl/frontend/base.rhm
fail_matches "frontend extensions must not depend on the standard aggregator" \
  '^[[:space:]]+"[^"]*standard\.rhm' rhdl/frontend/extensions

unexpected_top_level="$(find rhdl -maxdepth 1 -type f \
  ! -name 'main.rkt' ! -name 'language.rhm' -print)"
if [[ -n "$unexpected_top_level" ]]; then
  echo "rhdl root may contain only the reader shim and language assembly" >&2
  echo "$unexpected_top_level" >&2
  exit 1
fi

unexpected_racket="$(find rhdl -type f -name '*.rkt' \
  ! -path 'rhdl/main.rkt' \
  ! -path 'rhdl/base/main.rkt' \
  ! -path 'rhdl/base/lang/reader.rkt' -print)"
if [[ -n "$unexpected_racket" ]]; then
  echo "only #lang reader shims may use the .rkt extension" >&2
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
