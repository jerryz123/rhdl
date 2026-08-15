#!/usr/bin/env bash
# Enforces dependency and generated-file boundaries for the concrete RV64I core.
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir"

forbidden_imports="$(rg -n '^[[:space:]]+"[^"]*(rhdl/backend|tests/|examples/)' core \
  --glob '*.rhm' --glob '*.rhdl' --glob '!tests/**' || true)"
if [[ -n "$forbidden_imports" ]]; then
  echo "concrete core sources must not import backends, tests, or examples" >&2
  echo "$forbidden_imports" >&2
  exit 1
fi

alu_domain_imports="$(rg -n '^[[:space:]]+"[^"]*riscv/' core/alu.rhdl || true)"
if [[ -n "$alu_domain_imports" ]]; then
  echo "the integer ALU must remain independent of instruction catalogs" >&2
  echo "$alu_domain_imports" >&2
  exit 1
fi

compiled_directories="$(find core -type d -name compiled -print)"
if [[ -n "$compiled_directories" ]]; then
  echo "generated Racket bytecode must not live under core/" >&2
  echo "$compiled_directories" >&2
  exit 1
fi
