#!/usr/bin/env bash
# Verifies dependency classification and audits every tracked executable source path.
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
classifier="$repo_dir/tools/ci-changes.sh"

classification_for() {
  "$classifier" --paths "$@"
}

field_value() {
  local output="$1"
  local field="$2"
  sed -n "s/^${field}=//p" <<< "$output"
}

check_field() {
  local path="$1"
  local field="$2"
  local expected="$3"
  local output actual
  output="$(classification_for "$path")"
  actual="$(field_value "$output" "$field")"
  if [[ "$actual" != "$expected" ]]; then
    echo "$path: expected $field=$expected, got $actual" >&2
    return 1
  fi
}

check_matrix_entry() {
  local path="$1"
  local field="$2"
  local target="$3"
  local output matrix
  output="$(classification_for "$path")"
  matrix="$(field_value "$output" "$field")"
  if [[ "$matrix" != *"\"target\":\"$target\""* ]]; then
    echo "$path: $field does not contain $target" >&2
    echo "$matrix" >&2
    return 1
  fi
}

check_no_jobs() {
  local path="$1"
  local output
  output="$(classification_for "$path")"
  if [[ "$(field_value "$output" host)" != false \
      || "$(field_value "$output" circt)" != false \
      || "$(field_value "$output" fesvr)" != false \
      || "$(field_value "$output" examples)" != false ]]; then
    echo "$path: expected no CI jobs" >&2
    echo "$output" >&2
    return 1
  fi
}

check_no_jobs README.md
check_no_jobs tests/backend/README.md
check_no_jobs tools/emacs/rhdl-mode.el
check_no_jobs vlsi/src/rhdl-top.rhdl

check_matrix_entry rhdl/core/ir.rhm host_matrix ci-host-foundation-test
check_matrix_entry rhdl/core/ir.rhm circt_matrix ci-circt-language-test
check_field rhdl/core/ir.rhm fesvr true
check_matrix_entry rhdl/analysis/clocking.rhm host_matrix ci-host-foundation-test
check_matrix_entry tests/analysis/clocking-test.rhm host_matrix ci-host-foundation-test
check_matrix_entry rhdl/std/flow.rhdl host_matrix ci-host-cores-test
check_matrix_entry rhdl/std/flow.rhdl circt_matrix ci-circt-std-test
check_matrix_entry host/annotations.rhm host_matrix ci-host-foundation-test
check_matrix_entry tests/frontend/conditional-fixture.rhdl host_matrix ci-host-foundation-test
check_matrix_entry tests/frontend/invalid/bad-width.rhdl host_matrix ci-host-foundation-test
check_matrix_entry ridx/model/axis.rhm host_matrix ci-host-models-test
check_matrix_entry ridx/tests/model/milestone1-test.rhm host_matrix ci-host-models-test
check_matrix_entry noc/rtl/router.rhdl host_matrix ci-host-models-test
check_matrix_entry noc/rtl/router.rhdl circt_matrix ci-circt-protocols-test
check_matrix_entry chi/link.rhdl host_matrix ci-host-protocols-test
check_matrix_entry chi/link.rhdl circt_matrix ci-circt-protocols-test
check_matrix_entry cores/ricket/core.rhdl host_matrix ci-host-cores-test
check_matrix_entry cores/ricket/core.rhdl circt_matrix ci-circt-cores-test
check_matrix_entry cores/ricket/core.rhdl example_matrix examples-ricket
check_matrix_entry cores/ricket/core-flow.rhdl host_matrix ci-host-cores-test
check_matrix_entry cores/ricket/core-flow.rhdl circt_matrix ci-circt-cores-test
check_matrix_entry cores/ricket/core-flow.rhdl example_matrix examples-ricket
check_matrix_entry examples/rhdl/alu.rhdl example_matrix examples-rhdl
check_matrix_entry examples/rhdl/alu.rhdl circt_matrix ci-circt-language-test
check_matrix_entry examples/clocking/single-clock.rhm example_matrix examples-clocking
check_matrix_entry examples/std/flow-control.rhdl example_matrix examples-std
check_matrix_entry examples/noc/noc-router.rhdl example_matrix examples-noc
check_matrix_entry examples/noc/noc-router.rhdl circt_matrix ci-circt-protocols-test
check_matrix_entry examples/noc/wormhole-router-diagram.rhdl example_matrix examples-noc
check_matrix_entry examples/lop/adder-core.rhm example_matrix examples-lop
check_matrix_entry examples/rfpl/circuit-pair.rhdl example_matrix examples-rfpl
check_matrix_entry examples/rfpl/circuit-pair.rhdl circt_matrix rfpl-circt-test
check_matrix_entry examples/ridx/grid.rhdl example_matrix examples-ridx
check_matrix_entry examples/ridx/grid.rhdl circt_matrix ci-circt-protocols-test
check_matrix_entry examples/riscv/instruction-fields.rhdl example_matrix examples-riscv
check_matrix_entry examples/riscv/instruction-fields.rhdl circt_matrix ci-circt-cores-test
check_matrix_entry examples/chi/ram.rhdl example_matrix examples-chi
check_matrix_entry examples/chi/ram.rhdl circt_matrix ci-circt-protocols-test
check_matrix_entry examples/cores/ricket.rhdl example_matrix examples-cores
check_matrix_entry examples/cores/ricket.rhdl circt_matrix ci-circt-cores-test
check_matrix_entry examples/ricket/core-diagram.rhdl example_matrix examples-ricket
check_matrix_entry tools/write-ricket-core-diagram.rhm example_matrix examples-ricket
check_matrix_entry tools/write-noc-router-diagram.rhm example_matrix examples-noc
check_field tools/run-racket-tests.sh host true
check_field tools/run-racket-tests.sh circt false
check_field tools/run-racket-tests.sh examples true
check_field tests/backend/verilog/adder_tb.sv circt true
check_field sim/fesvr/direct_mem_htif.cc fesvr true
check_field tests/fesvr/fesvr-rtl-test.rhm fesvr true
check_field tools/emit-fesvr-stub-soc.rhm fesvr true
check_field unrecognized/new-tool.py host true
check_field unrecognized/new-tool.py circt true
check_field unrecognized/new-tool.py fesvr true
check_field unrecognized/new-tool.py examples true

all_output="$(classification_for .github/workflows/ci.yml)"
if [[ "$(field_value "$all_output" host)" != true \
    || "$(field_value "$all_output" circt)" != true \
    || "$(field_value "$all_output" fesvr)" != true \
    || "$(field_value "$all_output" examples)" != true ]]; then
  echo "the CI workflow must select every job" >&2
  exit 1
fi

while IFS= read -r path; do
  case "$path" in
    tests/emacs/*|tools/emacs/*|vlsi/*)
      continue
      ;;
    Makefile|*.rhm|*.rhdl|*.rkt|*.rktd|*.sh|*.sv|*.cc|*.cpp|*.h|*.S|*.ld|*.rfpl|*.yml|*.yaml)
      output="$(classification_for "$path")"
      if [[ "$(field_value "$output" host)" != true \
          && "$(field_value "$output" circt)" != true \
          && "$(field_value "$output" fesvr)" != true \
          && "$(field_value "$output" examples)" != true ]]; then
        echo "$path: tracked executable source selects no CI job" >&2
        exit 1
      fi
      ;;
  esac
done < <(git -C "$repo_dir" ls-files)

all_jobs="$($classifier --all)"
if [[ "$(field_value "$all_jobs" host)" != true \
    || "$(field_value "$all_jobs" circt)" != true \
    || "$(field_value "$all_jobs" fesvr)" != true \
    || "$(field_value "$all_jobs" examples)" != true ]]; then
  echo "--all did not select every CI job" >&2
  exit 1
fi

fallback_jobs="$($classifier 0000000000000000000000000000000000000000 HEAD)"
if [[ "$fallback_jobs" != "$all_jobs" ]]; then
  echo "an unavailable base revision did not select every CI job" >&2
  exit 1
fi
