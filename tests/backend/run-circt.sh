#!/usr/bin/env bash
# Verifies RHDL-produced CIRCT IR, exports it with CIRCT, and simulates the result.
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/../.." && pwd)"
test_tmp_dir="$(mktemp -d /tmp/rhdl-circt.XXXXXX)"
trap 'rm -rf "$test_tmp_dir"' EXIT

circt_opt="${CIRCT_OPT:-$repo_dir/.tools/firtool-1.155.0/bin/circt-opt}"
if [[ ! -x "$circt_opt" ]]; then
  if command -v circt-opt >/dev/null 2>&1; then
    circt_opt="$(command -v circt-opt)"
  else
    echo "circt-opt not found; run 'make setup-circt' or set CIRCT_OPT" >&2
    exit 1
  fi
fi

cd "$repo_dir"

run_fixture() {
  local fixture="$1"
  local top="$2"
  local mlir="$test_tmp_dir/$fixture.mlir"
  local verilog="$test_tmp_dir/$fixture.sv"
  local object_dir="$test_tmp_dir/${fixture}_obj"

  racket -S "$repo_dir" "tests/backend/emit-$fixture.rhm" > "$mlir"
  "$circt_opt" "$mlir" -o /dev/null
  "$circt_opt" --lower-seq-to-sv --export-verilog "$mlir" -o /dev/null > "$verilog"
  verilator --binary --timing --build-jobs 0 --top-module "$top" \
    --Mdir "$object_dir" \
    "$verilog" "tests/backend/verilog/${fixture}_tb.sv"
  "$object_dir/V$top"
}

run_fixture adder adder_tb
run_fixture alu alu_tb
run_fixture width-ops width_ops_tb
run_fixture counter counter_tb
run_fixture hierarchy hierarchy_tb
