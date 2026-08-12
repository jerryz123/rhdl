#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
test_tmp_dir="$(mktemp -d /tmp/rhdl-verilator.XXXXXX)"
trap 'rm -rf "$test_tmp_dir"' EXIT

cd "$repo_dir"

racket tests/emit-adder.rhm > "$test_tmp_dir/adder.sv"
verilator --binary --timing --build-jobs 0 --top-module adder_tb \
  --Mdir "$test_tmp_dir/adder_obj" \
  "$test_tmp_dir/adder.sv" tests/verilog/adder_tb.sv
"$test_tmp_dir/adder_obj/Vadder_tb"

racket tests/emit-counter.rhm > "$test_tmp_dir/counter.sv"
verilator --binary --timing --build-jobs 0 --top-module counter_tb \
  --Mdir "$test_tmp_dir/counter_obj" \
  "$test_tmp_dir/counter.sv" tests/verilog/counter_tb.sv
"$test_tmp_dir/counter_obj/Vcounter_tb"

racket tests/emit-hierarchy.rhm > "$test_tmp_dir/hierarchy.sv"
verilator --binary --timing --build-jobs 0 --top-module hierarchy_tb \
  --Mdir "$test_tmp_dir/hierarchy_obj" \
  "$test_tmp_dir/hierarchy.sv" tests/verilog/hierarchy_tb.sv
"$test_tmp_dir/hierarchy_obj/Vhierarchy_tb"
