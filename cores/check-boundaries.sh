#!/usr/bin/env bash
# Enforces ownership, dependency, and generated-file boundaries for processor cores.
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir"

forbidden_imports="$(rg -n '^[[:space:]]+"[^"]*(rhdl/backend|tests/|examples/)' cores \
  --glob '*.rhm' --glob '*.rhdl' \
  --glob '!tests/**' --glob '!*/tests/**' || true)"
if [[ -n "$forbidden_imports" ]]; then
  echo "processor sources must not import backends, tests, or examples" >&2
  echo "$forbidden_imports" >&2
  exit 1
fi

component_domain_imports="$(rg -n '^[[:space:]]+"[^"]*(riscv/|ricket/)' \
  cores/alu.rhdl cores/branch-resolver.rhdl cores/load-store.rhdl || true)"
if [[ -n "$component_domain_imports" ]]; then
  echo "reusable processor components must remain independent of instruction catalogs" >&2
  echo "$component_domain_imports" >&2
  exit 1
fi

component_control_imports="$(rg -n '^[[:space:]]+"(alu|operand|branch|mem|writeback|trap)-ctrl\.rhdl"' \
  cores/ricket/decode/alu-ctrl.rhdl \
  cores/ricket/decode/operand-ctrl.rhdl \
  cores/ricket/decode/branch-ctrl.rhdl \
  cores/ricket/decode/mem-ctrl.rhdl \
  cores/ricket/decode/writeback-ctrl.rhdl \
  cores/ricket/decode/trap-ctrl.rhdl || true)"
if [[ -n "$component_control_imports" ]]; then
  echo "Ricket component control decoders must not import sibling control decoders" >&2
  echo "$component_control_imports" >&2
  exit 1
fi

pipeline_transport_imports="$(rg -n 'simple-memory' \
  cores/ricket/core-pipeline.rhdl || true)"
if [[ -n "$pipeline_transport_imports" ]]; then
  echo "Ricket pipeline must depend on its cache protocol, not SimpleMemory" >&2
  echo "$pipeline_transport_imports" >&2
  exit 1
fi

cache_cross_imports="$(rg -n '^[[:space:]]+"[^" ]*(icache|dcache)/' \
  cores/ricket/icache cores/ricket/dcache \
  --glob '*.rhm' --glob '*.rhdl' || true)"
if [[ -n "$cache_cross_imports" ]]; then
  echo "Ricket instruction and data cache packages must not import each other" >&2
  echo "$cache_cross_imports" >&2
  exit 1
fi

unexpected_root_sources="$(find cores -maxdepth 1 -type f \( -name '*.rhm' -o -name '*.rhdl' \) \
  ! -name 'alu.rhdl' ! -name 'branch-resolver.rhdl' \
  ! -name 'load-store.rhdl' -print)"
if [[ -n "$unexpected_root_sources" ]]; then
  echo "only reusable processor components may live directly under cores/" >&2
  echo "$unexpected_root_sources" >&2
  exit 1
fi

compiled_directories="$(find cores -type d -name compiled -print)"
if [[ -n "$compiled_directories" ]]; then
  echo "generated Racket bytecode must not live under cores/" >&2
  echo "$compiled_directories" >&2
  exit 1
fi
