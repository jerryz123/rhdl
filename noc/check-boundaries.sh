#!/usr/bin/env bash
# Enforces the pure NoC dependency boundary and keeps core abstractions independent of standard definitions.
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir"

forbidden_imports="$(rg -n '^[[:space:]]+\"[^\"]*(rhdl/|circt)' noc/model noc/authoring noc/analysis noc/plan noc/std --glob '*.rhm' || true)"
if [[ -n "$forbidden_imports" ]]; then
  echo "pure NoC model, authoring, standard definitions, analysis, and plan must not import RHDL or CIRCT modules" >&2
  echo "$forbidden_imports" >&2
  exit 1
fi

forbidden_std_imports="$(rg -n '^[[:space:]]+\"[^\"]*std/' noc/model noc/authoring noc/analysis noc/plan --glob '*.rhm' || true)"
if [[ -n "$forbidden_std_imports" ]]; then
  echo "core NoC model, authoring, analysis, and plan must not import standard topology or routing definitions" >&2
  echo "$forbidden_std_imports" >&2
  exit 1
fi

unexpected_rhdl="$(find noc -type f -name '*.rhdl' -print)"
if [[ -n "$unexpected_rhdl" ]]; then
  echo "pure NoC sources and tests must use #lang rhombus modules" >&2
  echo "$unexpected_rhdl" >&2
  exit 1
fi
