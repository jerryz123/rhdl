#!/usr/bin/env bash
# Classifies changed repository paths into the CI jobs that must run.
set -euo pipefail

host=false
circt=false
fesvr=false
examples=false
example_rhdl=false
example_std=false
example_lop=false
example_rfpl=false
example_tilelink=false

mark_example_rhdl() {
  examples=true
  example_rhdl=true
}

mark_example_std() {
  examples=true
  example_std=true
}

mark_example_lop() {
  examples=true
  example_lop=true
}

mark_example_rfpl() {
  examples=true
  example_rfpl=true
}

mark_example_tilelink() {
  examples=true
  example_tilelink=true
}

mark_all_examples() {
  mark_example_rhdl
  mark_example_std
  mark_example_lop
  mark_example_rfpl
  mark_example_tilelink
}

mark_all() {
  host=true
  circt=true
  fesvr=true
  mark_all_examples
}

emit_jobs() {
  local matrix=""

  if [[ "$example_rhdl" == true ]]; then
    matrix='{"name":"RHDL","target":"examples-rhdl"}'
  fi
  if [[ "$example_std" == true ]]; then
    [[ -n "$matrix" ]] && matrix+=,
    matrix+='{"name":"standard library","target":"examples-std"}'
  fi
  if [[ "$example_lop" == true ]]; then
    [[ -n "$matrix" ]] && matrix+=,
    matrix+='{"name":"levels of power","target":"examples-lop"}'
  fi
  if [[ "$example_rfpl" == true ]]; then
    [[ -n "$matrix" ]] && matrix+=,
    matrix+='{"name":"RFPL","target":"examples-rfpl"}'
  fi
  if [[ "$example_tilelink" == true ]]; then
    [[ -n "$matrix" ]] && matrix+=,
    matrix+='{"name":"TileLink","target":"examples-tilelink"}'
  fi

  echo "host=$host"
  echo "circt=$circt"
  echo "fesvr=$fesvr"
  echo "examples=$examples"
  echo "example_matrix={\"include\":[$matrix]}"
}

classify_path() {
  local path="$1"
  case "$path" in
    .github/workflows/ci.yml|tools/ci-changes.sh|tools/check-ci-changes.sh)
      mark_all
      ;;
    Makefile)
      host=true
      circt=true
      mark_all_examples
      ;;
    tools/check-example-verilog.sh)
      mark_all_examples
      ;;
    rhdl/core/*|rhdl/frontend/*|rhdl/base/*|rhdl/language.rhm|rhdl/main.rkt)
      host=true
      circt=true
      mark_all_examples
      ;;
    rhdl/std/*)
      host=true
      circt=true
      # Some language examples use std protocols as illustrative payloads, and
      # TileLink is implemented over std ready-valid and flow components.
      mark_example_rhdl
      mark_example_std
      mark_example_tilelink
      ;;
    rhdl/backend/*|cores/*.rhm|cores/*.rhdl|cores/*.rkt|cores/*.sh|tests/backend/*.rhm|tests/backend/*.rkt)
      host=true
      circt=true
      ;;
    examples/rhdl/*)
      host=true
      circt=true
      mark_example_rhdl
      ;;
    examples/std/*)
      host=true
      circt=true
      mark_example_std
      ;;
    examples/lop/*)
      host=true
      circt=true
      mark_example_lop
      ;;
    examples/rfpl/*)
      host=true
      circt=true
      mark_example_rfpl
      ;;
    examples/tilelink/*)
      host=true
      circt=true
      mark_example_tilelink
      ;;
    examples/*.rhm|examples/*.rhdl)
      # Conservatively classify legacy top-level paths during the directory move.
      host=true
      circt=true
      mark_all_examples
      ;;
    rfpl/tests/*)
      host=true
      ;;
    rfpl/*.rhm|rfpl/*.rhdl|rfpl/*.rkt|rfpl/*.sh)
      host=true
      circt=true
      mark_example_rfpl
      ;;
    tilelink/tests/*)
      host=true
      ;;
    tilelink/*.rhm|tilelink/*.rhdl|tilelink/*.rkt|tilelink/*.sh)
      host=true
      circt=true
      mark_example_tilelink
      ;;
    tests/core/*.rhm|tests/frontend/*.rhm|tests/frontend/*.rhm.invalid|tests/frontend/*.sh|noc/*.rhm|noc/*.rhm.invalid|noc/*.rkt|noc/*.sh|riscv/*.rhm|riscv/*.rhm.invalid|riscv/*.rkt|riscv/*.sh|tools/check-boundaries.sh)
      host=true
      ;;
    tests/backend/*.sh|tests/backend/*.sv|tests/backend/*.cpp|tools/install-circt.sh)
      circt=true
      ;;
    sim/fesvr/Makefile|sim/fesvr/*.rhdl|sim/fesvr/*.cc|sim/fesvr/*.h|tests/fesvr/*.cc|tests/fesvr/*.S|tests/fesvr/*.ld|tools/install-fesvr.sh)
      fesvr=true
      ;;
  esac
}

if [[ "${1:-}" == --all ]]; then
  mark_all
  emit_jobs
  exit 0
elif [[ "${1:-}" == --paths ]]; then
  shift
  for path in "$@"; do
    classify_path "$path"
  done
elif [[ $# == 2 ]]; then
  base_revision="$1"
  head_revision="$2"
  if [[ -z "$base_revision" || "$base_revision" =~ ^0+$ ]] \
      || ! git cat-file -e "$base_revision^{commit}" 2>/dev/null \
      || ! git cat-file -e "$head_revision^{commit}" 2>/dev/null; then
    mark_all
    emit_jobs
    exit 0
  fi
  if ! changed_paths="$(git diff --name-only "$base_revision" "$head_revision")"; then
    mark_all
    emit_jobs
    exit 0
  fi
  while IFS= read -r path; do
    classify_path "$path"
  done <<< "$changed_paths"
else
  echo "usage: $0 --all | --paths PATH... | BASE_REVISION HEAD_REVISION" >&2
  exit 2
fi

emit_jobs
