#!/usr/bin/env bash
# Enforces that the pure NoC model remains independent of RHDL and CIRCT implementation packages.
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir"

forbidden_imports="$(rg -n '^[[:space:]]+\"[^\"]*(rhdl/|circt)' noc/model --glob '*.rhm' || true)"
if [[ -n "$forbidden_imports" ]]; then
  echo "pure NoC model must not import RHDL or CIRCT modules" >&2
  echo "$forbidden_imports" >&2
  exit 1
fi

unexpected_rhdl="$(find noc -type f -name '*.rhdl' -print)"
if [[ -n "$unexpected_rhdl" ]]; then
  echo "pure NoC sources and tests must use #lang rhombus modules" >&2
  echo "$unexpected_rhdl" >&2
  exit 1
fi
