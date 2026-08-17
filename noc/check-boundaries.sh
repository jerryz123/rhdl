#!/usr/bin/env bash
# Enforces the pure NoC dependency boundary and keeps core abstractions independent of standard definitions.
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir"

search_sources() {
  local pattern="$1"
  shift
  if command -v rg >/dev/null 2>&1; then
    rg -n "$pattern" "$@" --glob '*.rhm' --glob '*.rhdl'
  else
    find "$@" -type f \( -name '*.rhm' -o -name '*.rhdl' \) \
      -exec grep -nHE "$pattern" {} +
  fi
}

forbidden_imports="$(search_sources '^[[:space:]]+\"[^\"]*(rhdl/|circt)' noc/model noc/authoring noc/analysis noc/language noc/plan noc/std || true)"
if [[ -n "$forbidden_imports" ]]; then
  echo "pure NoC model, authoring, language, standard definitions, analysis, and plan must not import RHDL or CIRCT modules" >&2
  echo "$forbidden_imports" >&2
  exit 1
fi

forbidden_std_imports="$(search_sources '^[[:space:]]+\"[^\"]*std/' noc/model noc/authoring noc/analysis noc/language noc/plan || true)"
if [[ -n "$forbidden_std_imports" ]]; then
  echo "core NoC model, authoring, language, analysis, and plan must not import standard topology or routing definitions" >&2
  echo "$forbidden_std_imports" >&2
  exit 1
fi

forbidden_rtl_imports="$(search_sources '^[[:space:]]+.*(rhdl/core/|rhdl/backend/|rhdl/frontend/|circt)' noc/rtl || true)"
if [[ -n "$forbidden_rtl_imports" ]]; then
  echo "NoC RTL must use public RHDL language and standard-library APIs, not implementation or backend modules" >&2
  echo "$forbidden_rtl_imports" >&2
  exit 1
fi

unexpected_rhdl="$(find noc -type f -name '*.rhdl' ! -path 'noc/rtl/*' -print)"
if [[ -n "$unexpected_rhdl" ]]; then
  echo "NoC .rhdl files may appear only in noc/rtl; pure sources and tests use #lang rhombus" >&2
  echo "$unexpected_rhdl" >&2
  exit 1
fi
