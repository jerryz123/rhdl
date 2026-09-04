#!/usr/bin/env bash
# Enforces ownership, dependency, and generated-file boundaries for processor cores.
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

search_production_sources() {
  local pattern="$1"
  if command -v rg >/dev/null 2>&1; then
    rg -n "$pattern" cores --glob '*.rhm' --glob '*.rhdl' \
      --glob '!tests/**' --glob '!*/tests/**'
  else
    find cores -type f \( -name '*.rhm' -o -name '*.rhdl' \) \
      ! -path '*/tests/*' -exec grep -nHE "$pattern" {} +
  fi
}

forbidden_imports="$(search_production_sources \
  '^[[:space:]]+"[^"]*(rhodium/backend|tests/|examples/)' || true)"
if [[ -n "$forbidden_imports" ]]; then
  echo "processor sources must not import backends, tests, or examples" >&2
  echo "$forbidden_imports" >&2
  exit 1
fi

component_domain_imports="$(
  search_sources '^[[:space:]]+"[^"]*(riscv/|rv5stage/)' \
    cores/alu.rhdl cores/branch-resolver.rhdl cores/load-store.rhdl \
    cores/multiplier.rhdl cores/divider.rhdl \
    | grep -Ev 'riscv/isa/xlen\.rhm' \
    || true
)"
if [[ -n "$component_domain_imports" ]]; then
  echo "reusable processor components may import XLen but not instruction catalogs or named cores" >&2
  echo "$component_domain_imports" >&2
  exit 1
fi

component_control_imports="$(search_sources '^[[:space:]]+"(alu|operand|branch|mem|writeback|system)-ctrl\.rhdl"' \
  cores/rv5stage/decode/alu-ctrl.rhdl \
  cores/rv5stage/decode/operand-ctrl.rhdl \
  cores/rv5stage/decode/branch-ctrl.rhdl \
  cores/rv5stage/decode/mem-ctrl.rhdl \
  cores/rv5stage/decode/multiply-ctrl.rhdl \
  cores/rv5stage/decode/divide-ctrl.rhdl \
  cores/rv5stage/decode/writeback-ctrl.rhdl \
  cores/rv5stage/decode/system-ctrl.rhdl || true)"
if [[ -n "$component_control_imports" ]]; then
  echo "RV5Stage component control decoders must not import sibling control decoders" >&2
  echo "$component_control_imports" >&2
  exit 1
fi

pipeline_transport_imports="$(search_sources 'simple-memory' \
  cores/rv5stage/core.rhdl cores/rv5stage/core-flow.rhdl || true)"
if [[ -n "$pipeline_transport_imports" ]]; then
  echo "RV5Stage pipeline must depend on its cache protocol, not SimpleMemory" >&2
  echo "$pipeline_transport_imports" >&2
  exit 1
fi

explicit_flow_syntax="$(search_sources '\|>|(map|filter|gate|zip)_flow\(|(map|filter|fork)_valid\(|atomic_fork\(|valid_arbiter\(|to_valid\(|OfferRegister\(|ValidArbiter\(|AtomicFork\(' \
  cores/rv5stage/core.rhdl || true)"
if [[ -n "$explicit_flow_syntax" ]]; then
  echo "the explicit RV5Stage core must use direct state and interface wiring" >&2
  echo "$explicit_flow_syntax" >&2
  exit 1
fi

cache_cross_imports="$(search_sources '^[[:space:]]+"[^" ]*(icache|dcache)/' \
  cores/rv5stage/icache cores/rv5stage/dcache \
  || true)"
if [[ -n "$cache_cross_imports" ]]; then
  echo "RV5Stage instruction and data cache packages must not import each other" >&2
  echo "$cache_cross_imports" >&2
  exit 1
fi

unexpected_root_sources="$(find cores -maxdepth 1 -type f \( -name '*.rhm' -o -name '*.rhdl' \) \
  ! -name 'alu.rhdl' ! -name 'branch-resolver.rhdl' \
  ! -name 'load-store.rhdl' ! -name 'multiplier.rhdl' \
  ! -name 'divider.rhdl' -print)"
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
