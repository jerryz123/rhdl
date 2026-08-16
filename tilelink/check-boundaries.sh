#!/usr/bin/env bash
# Enforces TileLink's dependency on public RHDL language and library surfaces only.
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir"

if command -v rg >/dev/null 2>&1; then
  implementation_imports="$(
    rg -n '^[[:space:]]+.*rhdl/(core|frontend|backend)/' \
      tilelink/*.rhdl \
      || true
  )"
else
  implementation_imports="$(
    grep -nHE '^[[:space:]]+.*rhdl/(core|frontend|backend)/' \
      tilelink/*.rhdl \
      || true
  )"
fi
if [[ -n "$implementation_imports" ]]; then
  echo "TileLink sources may import only public RHDL language and standard-library surfaces" >&2
  echo "$implementation_imports" >&2
  exit 1
fi

misplaced_sources="$(find rhdl/std -type f -path '*tilelink*' \
  \( -name '*.rhdl' -o -name '*.rhm' \) -print)"
if [[ -n "$misplaced_sources" ]]; then
  echo "TileLink sources must remain outside rhdl/std" >&2
  echo "$misplaced_sources" >&2
  exit 1
fi
