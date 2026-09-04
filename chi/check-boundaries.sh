#!/usr/bin/env bash
# Enforces CHI's dependency on public Rhodium language and library surfaces only.
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir"

if command -v rg >/dev/null 2>&1; then
  implementation_imports="$(
    rg -n '^[[:space:]]+.*rhodium/(core|frontend|backend)/' \
      chi/*.rhdl \
      || true
  )"
else
  implementation_imports="$(
    grep -nHE '^[[:space:]]+.*rhodium/(core|frontend|backend)/' \
      chi/*.rhdl \
      || true
  )"
fi
if [[ -n "$implementation_imports" ]]; then
  echo "CHI sources may import only public Rhodium language and standard-library surfaces" >&2
  echo "$implementation_imports" >&2
  exit 1
fi

pure_noc_imports="$(
  if command -v rg >/dev/null 2>&1; then
    rg -n '^[[:space:]]+.*(rhodium/|circt)' \
      chi/noc-authoring.rhm || true
  else
    grep -nHE '^[[:space:]]+.*(rhodium/|circt)' \
      chi/noc-authoring.rhm || true
  fi
)"
if [[ -n "$pure_noc_imports" ]]; then
  echo "pure CHI-to-NoC compilation must not import Rhodium or CIRCT modules" >&2
  echo "$pure_noc_imports" >&2
  exit 1
fi

misplaced_sources="$(find rhodium/std -type f -path '*chi*' \
  \( -name '*.rhdl' -o -name '*.rhm' \) -print)"
if [[ -n "$misplaced_sources" ]]; then
  echo "CHI sources must remain outside rhodium/std" >&2
  echo "$misplaced_sources" >&2
  exit 1
fi
