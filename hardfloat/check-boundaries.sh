#!/usr/bin/env bash
# Enforces the public-authoring and generated-file boundaries of the HardFloat port.
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir"

forbidden_imports="$(
  rg -n '^[[:space:]]+.*(rhdl/(core|analysis|frontend|backend|formal)|riscv/|cores/|sims/|tests/|examples/)' \
    hardfloat/rtl hardfloat/main.rhdl --glob '*.rhdl' || true
)"
if [[ -n "$forbidden_imports" ]]; then
  echo "HardFloat production code may import only public RHDL libraries and its own package" >&2
  echo "$forbidden_imports" >&2
  exit 1
fi

compiled_directories="$(find hardfloat -type d -name compiled -print)"
if [[ -n "$compiled_directories" ]]; then
  echo "generated Racket bytecode must not live under hardfloat/" >&2
  echo "$compiled_directories" >&2
  exit 1
fi
