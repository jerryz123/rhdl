#!/usr/bin/env bash
# Classifies changed repository paths into the CI jobs that must run.
set -euo pipefail

host=false
circt=false
fesvr=false

mark_all() {
  host=true
  circt=true
  fesvr=true
}

emit_jobs() {
  echo "host=$host"
  echo "circt=$circt"
  echo "fesvr=$fesvr"
}

classify_path() {
  local path="$1"
  case "$path" in
    .github/workflows/ci.yml|tools/ci-changes.sh|tools/check-ci-changes.sh)
      mark_all
      ;;
    Makefile|rhdl/*.rhm|rhdl/*.rhdl|rhdl/*.rkt|cores/*.rhm|cores/*.rhdl|cores/*.rkt|cores/*.sh|examples/*.rhm|examples/*.rhdl|tests/backend/*.rhm|tests/backend/*.rkt)
      host=true
      circt=true
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
