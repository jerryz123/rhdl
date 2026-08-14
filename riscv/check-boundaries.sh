#!/usr/bin/env bash
# Enforces that the pure RISC-V model and ISA catalog remain independent of RHDL.
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir"

forbidden_imports="$(rg -n '^[[:space:]]+"[^"]*(rhdl/|circt)' riscv/model riscv/isa riscv/annotations --glob '*.rhm' || true)"
if [[ -n "$forbidden_imports" ]]; then
  echo "pure RISC-V model, ISA, and annotation modules must not import RHDL or CIRCT" >&2
  echo "$forbidden_imports" >&2
  exit 1
fi

unexpected_rhdl="$(find riscv -type f -name '*.rhdl' -print)"
if [[ -n "$unexpected_rhdl" ]]; then
  echo "the initial RISC-V package must contain only host-side Rhombus modules" >&2
  echo "$unexpected_rhdl" >&2
  exit 1
fi
