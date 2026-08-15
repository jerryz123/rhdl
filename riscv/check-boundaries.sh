#!/usr/bin/env bash
# Enforces that the pure RISC-V model and ISA catalog remain independent of RHDL.
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir"

search_sources() {
  local pattern="$1"
  local file_glob="$2"
  shift 2
  if command -v rg >/dev/null 2>&1; then
    rg -n "$pattern" "$@" --glob "$file_glob"
  else
    find "$@" -type f -name "$file_glob" -exec grep -nHE "$pattern" {} +
  fi
}

forbidden_imports="$(search_sources '^[[:space:]]+"[^"]*(rhdl/|circt)' '*.rhm' riscv/model riscv/isa || true)"
if [[ -n "$forbidden_imports" ]]; then
  echo "pure RISC-V model and ISA modules must not import RHDL or CIRCT" >&2
  echo "$forbidden_imports" >&2
  exit 1
fi

adapter_implementation_imports="$(search_sources '^[[:space:]]+.*rhdl/(core|frontend|backend)/' '*.rhdl' riscv/rhdl || true)"
if [[ -n "$adapter_implementation_imports" ]]; then
  echo "the RISC-V/RHDL adapter may import only public RHDL language and library surfaces" >&2
  echo "$adapter_implementation_imports" >&2
  exit 1
fi

unexpected_rhdl="$(find riscv -type f -name '*.rhdl' ! -path 'riscv/rhdl/*' -print)"
if [[ -n "$unexpected_rhdl" ]]; then
  echo "RISC-V hardware modules must be isolated under riscv/rhdl/" >&2
  echo "$unexpected_rhdl" >&2
  exit 1
fi
