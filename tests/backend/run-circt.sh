#!/usr/bin/env bash
# Runs curated or comprehensive CIRCT lowering, Verilog golden, and simulation checks.
set -euo pipefail

mode="${1:-run}"
fixture_scope=curated
compare_goldens=true
update_goldens=false
simulate_fixtures=true
simulation_only=false
run_direct_fixtures=true
case "$mode" in
  run) ;;
  --verify-only)
    compare_goldens=false
    simulate_fixtures=false
    ;;
  --simulate-only)
    compare_goldens=false
    simulation_only=true
    ;;
  --golden-only)
    fixture_scope=all
    simulate_fixtures=false
    run_direct_fixtures=false
    ;;
  --full)
    fixture_scope=all
    ;;
  --update-goldens)
    fixture_scope=all
    compare_goldens=false
    update_goldens=true
    simulate_fixtures=false
    run_direct_fixtures=false
    ;;
  *)
    echo "usage: $0 [--verify-only|--simulate-only|--golden-only|--full|--update-goldens]" >&2
    exit 2
    ;;
esac

if [[ -n "${FIXTURE:-}" && -n "${FIXTURES:-}" ]]; then
  echo "set either FIXTURE or FIXTURES, not both" >&2
  exit 2
fi

# This semantic spine crosses every lowering family whose external-tool behavior
# is not already established by the backend's host-side text tests. FIXTURE
# always selects an explicit fixture, including fixtures outside this set.
integration_fixtures=(
  alu enum-state shifts signed-integers generated-adder
  vector-update vec-shift-register-param
  async-read-memory sync-memory-masked simple-memory-ram sync-ram
  clocked-dpi assertions hierarchy bundle interface-array
  queue-options rr-arbiter ctrl-queue-options
  dont-care decode noc-route-computer noc-router noc-network
  nested-bundle aggregate-memory one-hot-aggregate priority-encoder
  rv32i-alu rv64i-alu-integrated
  credited-flow credited-monitor credited-monitor-overgrant
  chi-foundation chi-full-flits chi-link chi-monitor chi-transaction chi-transaction-sn chi-ram
  tilelink-protocol tilelink-ram
  ricket-core ricket-dcache
)

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

golden_circt_version="firtool-1.155.0"
circt_version="$("$circt_opt" --version | sed -n 's/^CIRCT //p')"
if [[ "$compare_goldens" == true && "$circt_version" != "$golden_circt_version" ]]; then
  if [[ "$mode" == --golden-only ]]; then
    echo "Verilog goldens require CIRCT $golden_circt_version; found ${circt_version:-an unknown version}" >&2
    exit 1
  fi
  compare_goldens=false
  echo "CIRCT ${circt_version:-version unknown}: skipping version-specific Verilog golden comparisons"
fi

cd "$repo_dir"

fixture_selected() {
  local fixture="$1"

  if [[ -n "${FIXTURE:-}" ]]; then
    [[ "$fixture" == "$FIXTURE" ]]
    return
  fi
  if [[ -n "${FIXTURES:-}" ]]; then
    local requested_fixture
    for requested_fixture in $FIXTURES; do
      [[ "$fixture" == "$requested_fixture" ]] && return 0
    done
    return 1
  fi
  if [[ "$fixture_scope" == all ]]; then
    return 0
  fi
  local integration_fixture
  for integration_fixture in "${integration_fixtures[@]}"; do
    [[ "$fixture" == "$integration_fixture" ]] && return 0
  done
  return 1
}

direct_fixture_selected() {
  local fixture="$1"
  local top="$2"

  fixture_selected "$fixture" || return 1
  [[ "$run_direct_fixtures" == true ]] || return 1
  if [[ "$simulation_only" == true && -z "$top" \
      && "$fixture" != credited-monitor \
      && "$fixture" != credited-monitor-overgrant ]]; then
    return 1
  fi
  return 0
}

update_reference() {
  local source_file="$1"
  local reference_export="$2"
  local verilog="$3"
  local rewritten="$test_tmp_dir/updated-$(basename "$source_file")"
  local marker="def $reference_export = @str|<<{"
  local marker_count

  marker_count="$(grep -Fxc "$marker" "$source_file" || true)"
  if [[ "$marker_count" != 1 ]]; then
    echo "$source_file must contain exactly one '$marker' line" >&2
    exit 1
  fi

  awk -v marker="$marker" -v replacement="$verilog" '
    $0 == marker {
      print
      while ((getline line < replacement) > 0) print line
      replacing = 1
      next
    }
    replacing && $0 == "}>>|" {
      print
      replacing = 0
      next
    }
    !replacing { print }
    END { if (replacing) exit 2 }
  ' "$source_file" > "$rewritten"
  mv "$rewritten" "$source_file"
}

prepare_example() {
  local fixture="$1"
  local example="$2"
  local reference_export="$3"
  local mlir="$test_tmp_dir/$fixture.mlir"
  local verilog="$test_tmp_dir/$fixture.sv"
  local expected="$test_tmp_dir/$fixture.expected.sv"
  local has_firmem=false
  local -a circt_args=(
    --strip-debuginfo-with-pred='drop-suffix=.mlir'
    --canonicalize
    --cse
    --prettify-verilog
  )

  if grep -q 'seq.hlmem' "$mlir"; then
    circt_args+=(--lower-seq-hlmem)
  fi
  if grep -q 'seq.firmem' "$mlir"; then
    circt_args+=(--lower-seq-firmem)
    has_firmem=true
  fi
  circt_args+=(
    --lower-sim-to-sv
    --lower-verif-to-sv
    --lower-seq-to-sv='disable-mem-randomization=true disable-reg-randomization=true'
  )
  if [[ "$has_firmem" == true ]]; then
    circt_args+=(--hw-memory-sim='disable-mem-randomization=true disable-reg-randomization=true read-enable-mode=undefined')
  fi
  circt_args+=(--sv-mask-non-synthesizable='mode=ifdef macro=SYNTHESIS')
  circt_args+=(--export-verilog)
  "$circt_opt" "${circt_args[@]}" "$mlir" -o /dev/null \
    | sed -e '1{/^\/\/ Generated by CIRCT /d;}' \
          -e '/^\/\/ VCS coverage exclude_file$/d' \
    | perl -0pe 's/\n+\z//' > "$verilog"

  if [[ "$update_goldens" == true ]]; then
    update_reference "$example" "$reference_export" "$verilog"
    return 0
  fi

  if [[ "$compare_goldens" != true ]]; then
    return 0
  fi

  if ! diff -u --label "$example:$reference_export" \
      --label "generated $fixture Verilog" "$expected" "$verilog"; then
    echo "$fixture Verilog differs from its example-owned reference" >&2
    exit 1
  fi
}

golden_fixture() {
  local fixture="$1"
  local example="$2"
  local design_export="${3:-design}"
  local reference_export="${4:-verilog_reference}"

  fixture_selected "$fixture" || return 0
  [[ "$simulation_only" == false ]] || return 0
  prepare_example "$fixture" "$example" "$reference_export"
}

run_fixture() {
  local fixture="$1"
  local top="$2"
  local example="$3"
  local design_export="${4:-design}"
  local reference_export="${5:-verilog_reference}"
  local verilog="$test_tmp_dir/$fixture.sv"
  local object_dir="$test_tmp_dir/${fixture}_obj"
  local build_log="$test_tmp_dir/$fixture.verilator.log"
  local dpi_source="$repo_dir/tests/backend/verilog/${fixture}_dpi.cpp"

  fixture_selected "$fixture" || return 0
  prepare_example "$fixture" "$example" "$reference_export"
  [[ "$simulate_fixtures" == true ]] || return 0

  local verilator_args=(
    --binary --timing --assert --build-jobs 0 --top-module "$top"
    --Mdir "$object_dir"
    "$verilog" "tests/backend/verilog/${fixture}_tb.sv"
  )
  if [[ -f "$dpi_source" ]]; then
    verilator_args+=("$dpi_source")
  fi

  if ! verilator "${verilator_args[@]}" > "$build_log" 2>&1; then
    cat "$build_log" >&2
    return 1
  fi
  "$object_dir/V$top"
}

run_expected_assertion_failure() {
  local fixture="$1"
  local top="$2"
  local testbench="$3"
  local expected_label="$4"
  local verilog="$test_tmp_dir/$fixture.sv"
  local object_dir="$test_tmp_dir/${fixture}_failure_obj"
  local build_log="$test_tmp_dir/$fixture.failure.verilator.log"
  local run_log="$test_tmp_dir/$fixture.failure.run.log"

  fixture_selected "$fixture" || return 0
  [[ "$simulate_fixtures" == true ]] || return 0

  if ! verilator --binary --timing --assert --build-jobs 0 --top-module "$top" \
      --Mdir "$object_dir" \
      "$verilog" "$testbench" \
      > "$build_log" 2>&1; then
    cat "$build_log" >&2
    return 1
  fi
  if bash -c '"$1"; status=$?; :; exit "$status"' _ "$object_dir/V$top" \
      > "$run_log" 2>&1; then
    echo "$fixture assertion failure simulation unexpectedly succeeded" >&2
    return 1
  fi
  if ! grep -q "$expected_label" "$run_log"; then
    echo "$fixture assertion failure did not report $expected_label" >&2
    cat "$run_log" >&2
    return 1
  fi
}

verify_fixture() {
  local fixture="$1"
  local top="${2:-}"
  local mlir="$test_tmp_dir/$fixture.mlir"
  local verilog="$test_tmp_dir/$fixture.sv"
  local has_firmem=false
  local -a circt_args=(
    --canonicalize
    --cse
    --prettify-verilog
  )
  local object_dir="$test_tmp_dir/${fixture}_obj"
  local build_log="$test_tmp_dir/$fixture.verilator.log"

  direct_fixture_selected "$fixture" "$top" || return 0

  if grep -q 'seq.hlmem' "$mlir"; then
    circt_args+=(--lower-seq-hlmem)
  fi
  if grep -q 'seq.firmem' "$mlir"; then
    circt_args+=(--lower-seq-firmem)
    has_firmem=true
  fi
  circt_args+=(
    --lower-sim-to-sv
    --lower-verif-to-sv
    --lower-seq-to-sv='disable-mem-randomization=true disable-reg-randomization=true'
  )
  if [[ "$has_firmem" == true ]]; then
    circt_args+=(--hw-memory-sim='disable-mem-randomization=true disable-reg-randomization=true read-enable-mode=undefined')
  fi
  circt_args+=(--sv-mask-non-synthesizable='mode=ifdef macro=SYNTHESIS')
  circt_args+=(--export-verilog)
  "$circt_opt" "${circt_args[@]}" "$mlir" -o /dev/null > "$verilog"

  if [[ "$simulate_fixtures" == true && -n "$top" ]]; then
    if ! verilator --binary --timing --assert --build-jobs 0 --top-module "$top" \
        --Mdir "$object_dir" \
        "$verilog" "tests/backend/verilog/${fixture}_tb.sv" \
        > "$build_log" 2>&1; then
      cat "$build_log" >&2
      return 1
    fi
    "$object_dir/V$top"
  fi
}

fixture_specs=(
  'adder|adder_tb|examples/lop/adder-standard.rhdl|design|verilog_reference'
  'adder4|adder4_tb|examples/rhdl/adder4.rhdl|design|verilog_reference'
  'generated-adder|generated_adder_tb|examples/rhdl/generated-adder.rhdl|design|verilog_reference'
  'alu|alu_tb|examples/rhdl/alu.rhdl|design|verilog_reference'
  'enum-state|enum_state_tb|examples/rhdl/enum-state.rhdl|design|verilog_reference'
  'enum-state-lookup||examples/rhdl/enum-state.rhdl|lookup_design|lookup_verilog_reference'
  'enum-opcode||examples/rhdl/enum-state.rhdl|opcode_design|opcode_verilog_reference'
  'one-hot|one_hot_tb|examples/rhdl/one-hot.rhdl|design|verilog_reference'
  'one-hot-enum||examples/rhdl/one-hot-enum.rhdl|design|verilog_reference'
  'shifts|shifts_tb|examples/rhdl/shifts.rhdl|design|verilog_reference'
  'width-ops|width_ops_tb|examples/rhdl/width-ops.rhdl|design|verilog_reference'
  'vector|vector_tb|examples/rhdl/vector.rhdl|design|verilog_reference'
  'vector-carry||examples/rhdl/vector.rhdl|carry_design|carry_verilog_reference'
  'vector-update|vector_update_tb|examples/rhdl/vector-update.rhdl|design|verilog_reference'
  'vector-register-update|vector_register_update_tb|examples/rhdl/vector-update.rhdl|register_design|register_verilog_reference'
  'vec-shift-register|vec_shift_register_tb|examples/rhdl/vec-shift-register.rhdl|design|verilog_reference'
  'vec-shift-register-param|vec_shift_register_param_tb|examples/rhdl/vec-shift-register-param.rhdl|design|verilog_reference'
  'predicate-filter|predicate_filter_tb|examples/rhdl/predicate-filter.rhdl|design|verilog_reference'
  'wire|wire_tb|examples/rhdl/wire.rhdl|design|verilog_reference'
  'async-read-memory|async_read_memory_tb|examples/rhdl/async-read-memory.rhdl|design|verilog_reference'
  'sync-memory|sync_memory_tb|examples/rhdl/sync-memory.rhdl|design|verilog_reference'
  'sync-memory-1rw|sync_memory_1rw_tb|examples/rhdl/sync-memory-1rw.rhdl|design|verilog_reference'
  'sync-memory-masked|sync_memory_masked_tb|examples/rhdl/sync-memory-masked.rhdl|design|verilog_reference'
  'simple-memory||examples/std/simple-memory.rhdl|design|verilog_reference'
  'simple-memory-alignment||examples/std/simple-memory.rhdl|alignment_design|alignment_verilog_reference'
  'simple-memory-activity||examples/std/simple-memory.rhdl|activity_design|activity_verilog_reference'
  'simple-memory-flow||examples/std/simple-memory-flow.rhdl|design|verilog_reference'
  'simple-memory-ram|simple_memory_ram_tb|examples/std/simple-memory-ram.rhdl|design|verilog_reference'
  'multi-write-memory|multi_write_memory_tb|examples/rhdl/multi-write-memory.rhdl|design|verilog_reference'
  'clocked-dpi|clocked_dpi_tb|examples/rhdl/clocked-dpi.rhdl|design|verilog_reference'
  'clocked-dpi-always||examples/rhdl/clocked-dpi.rhdl|always_design|always_verilog_reference'
  'clocked-dpi-explicit||examples/rhdl/clocked-dpi.rhdl|explicit_design|explicit_verilog_reference'
  'assertions|assertions_tb|examples/rhdl/assertions.rhdl|design|verilog_reference'
  'tiny-simd|tiny_simd_tb|examples/rhdl/tiny-simd.rhdl|design|verilog_reference'
  'tiny-simd-no-multiply||examples/rhdl/tiny-simd.rhdl|no_multiply_design|no_multiply_verilog_reference'
  'stack|stack_tb|examples/rhdl/stack.rhdl|design|verilog_reference'
  'counter|counter_tb|examples/rhdl/counter.rhdl|design|verilog_reference'
  'standard-counter|standard_counter_tb|examples/std/standard-counter.rhdl|design|verilog_reference'
  'multiply|multiply_tb|examples/rhdl/multiply.rhdl|design|verilog_reference'
  'expanding-arithmetic|expanding_arithmetic_tb|examples/rhdl/expanding-arithmetic.rhdl|design|verilog_reference'
  'unsigned-comparisons|unsigned_comparisons_tb|examples/rhdl/unsigned-comparisons.rhdl|design|verilog_reference'
  'signed-integers|signed_integers_tb|examples/rhdl/signed-integers.rhdl|design|verilog_reference'
  'sync-counter||examples/rhdl/sync-counter.rhdl|design|verilog_reference'
  'sync-counter-resetless||examples/rhdl/sync-counter.rhdl|resetless_design|resetless_verilog_reference'
  'sync-counter-explicit-clock||examples/rhdl/sync-counter.rhdl|explicit_clock_design|explicit_clock_verilog_reference'
  'enable-shift-register|enable_shift_register_tb|examples/rhdl/enable-shift-register.rhdl|design|verilog_reference'
  'reset-shift-register|reset_shift_register_tb|examples/rhdl/reset-shift-register.rhdl|design|verilog_reference'
  'hierarchy|hierarchy_tb|examples/rhdl/hierarchy.rhdl|design|verilog_reference'
  'rfpl-circuit-pair||examples/rfpl/circuit-pair.rhdl|design|verilog_reference'
  'nested-circuit|nested_circuit_tb|examples/rhdl/nested-circuit.rhdl|design|verilog_reference'
  'bundle|bundle_tb|examples/rhdl/bundle.rhdl|design|verilog_reference'
  'record-cast|record_cast_tb|examples/rhdl/bundle.rhdl|cast_design|cast_verilog_reference'
  'bundle-specialization-types||examples/rhdl/bundle.rhdl|specialization_design|specialization_verilog_reference'
  'bundle-conditional-specialization||examples/rhdl/bundle.rhdl|conditional_specialization_design|conditional_specialization_verilog_reference'
  'bundle-nested-swap||examples/rhdl/bundle.rhdl|nested_swap_design|nested_swap_verilog_reference'
  'bundle-hierarchy||examples/rhdl/bundle.rhdl|hierarchy_design|hierarchy_verilog_reference'
  'interface|interface_tb|examples/rhdl/interface.rhdl|design|verilog_reference'
  'interface-hierarchy||examples/rhdl/interface.rhdl|hierarchy_design|hierarchy_verilog_reference'
  'interface-specialization||examples/rhdl/interface-specialization.rhdl|design|verilog_reference'
  'interface-specialization-reversed||examples/rhdl/interface-specialization.rhdl|reversed_design|reversed_verilog_reference'
  'interface-specialization-nested||examples/rhdl/interface-specialization.rhdl|nested_design|nested_verilog_reference'
  'interface-specialization-width-adapter||examples/rhdl/interface-specialization.rhdl|width_adapter_design|width_adapter_verilog_reference'
  'ready-valid-compatibility||examples/std/ready-valid-compatibility.rhdl|design|verilog_reference'
  'interface-array|interface_array_tb|examples/rhdl/interface-array.rhdl|design|verilog_reference'
  'interface-generic-handle||examples/rhdl/interface-array.rhdl|generic_handle_design|generic_handle_verilog_reference'
  'interface-parallel-handle||examples/rhdl/interface-array.rhdl|parallel_handle_design|parallel_handle_verilog_reference'
  'interface-parallel-sink||examples/rhdl/interface-array.rhdl|parallel_sink_design|parallel_sink_verilog_reference'
  'interface-array-hierarchy||examples/rhdl/interface-array.rhdl|hierarchy_design|hierarchy_verilog_reference'
  'interface-array-sequence||examples/rhdl/interface-array.rhdl|sequence_design|sequence_verilog_reference'
  'nested-interface|nested_interface_tb|examples/rhdl/nested-interface.rhdl|design|verilog_reference'
  'nested-interface-member||examples/rhdl/nested-interface.rhdl|member_design|member_verilog_reference'
  'nested-interface-deep||examples/rhdl/nested-interface.rhdl|deep_design|deep_verilog_reference'
  'nested-interface-hierarchy||examples/rhdl/nested-interface.rhdl|hierarchy_design|hierarchy_verilog_reference'
  'pipe|pipe_tb|examples/std/flow-control.rhdl|pipe_design|pipe_verilog_reference'
  'queue|queue_tb|examples/std/flow-control.rhdl|queue_design|queue_verilog_reference'
  'queue-one|queue_one_tb|examples/std/flow-control.rhdl|queue_one_design|queue_one_verilog_reference'
  'queue-options|queue_options_tb|examples/std/flow-control.rhdl|queue_options_design|queue_options_verilog_reference'
  'arbiter|arbiter_tb|examples/std/flow-control.rhdl|arbiter_design|arbiter_verilog_reference'
  'flow-chain|flow_chain_tb|examples/std/flow-control.rhdl|chain_design|chain_verilog_reference'
  'rr-arbiter|rr_arbiter_tb|examples/std/flow-topology.rhdl|rr_arbiter_design|rr_arbiter_verilog_reference'
  'demux|demux_tb|examples/std/flow-topology.rhdl|demux_design|demux_verilog_reference'
  'join|join_tb|examples/std/flow-topology.rhdl|join_design|join_verilog_reference'
  'broadcast|broadcast_tb|examples/std/flow-topology.rhdl|broadcast_design|broadcast_verilog_reference'
  'atomic-fork|atomic_fork_tb|examples/std/flow-topology.rhdl|atomic_fork_design|atomic_fork_verilog_reference'
  'flow-map|flow_map_tb|examples/std/flow-topology.rhdl|flow_map_design|flow_map_verilog_reference'
  'flow-filter||examples/std/flow-topology.rhdl|filter_flow_design|filter_flow_verilog_reference'
  'flow-gate||examples/std/flow-topology.rhdl|gate_flow_design|gate_flow_verilog_reference'
  'flow-endpoint-first||examples/std/flow-topology.rhdl|endpoint_first_design|endpoint_first_verilog_reference'
  'flow-fan-in-project||examples/std/flow-topology.rhdl|fan_in_project_design|fan_in_project_verilog_reference'
  'flow-zip-route||examples/std/flow-topology.rhdl|zip_route_design|zip_route_verilog_reference'
  'ctrl-pipe|ctrl_pipe_tb|examples/std/ctrl-flow.rhdl|ctrl_pipe_design|ctrl_pipe_verilog_reference'
  'ctrl-queue|ctrl_queue_tb|examples/std/ctrl-flow.rhdl|ctrl_queue_design|ctrl_queue_verilog_reference'
  'ctrl-queue-options|ctrl_queue_options_tb|examples/std/ctrl-flow.rhdl|ctrl_queue_options_design|ctrl_queue_options_verilog_reference'
  'ctrl-arbiter|ctrl_arbiter_tb|examples/std/ctrl-flow.rhdl|ctrl_arbiter_design|ctrl_arbiter_verilog_reference'
  'ctrl-rr-arbiter|ctrl_rr_arbiter_tb|examples/std/ctrl-flow.rhdl|ctrl_rr_arbiter_design|ctrl_rr_arbiter_verilog_reference'
  'ctrl-demux|ctrl_demux_tb|examples/std/ctrl-flow.rhdl|ctrl_demux_design|ctrl_demux_verilog_reference'
  'ctrl-join|ctrl_join_tb|examples/std/ctrl-flow.rhdl|ctrl_join_design|ctrl_join_verilog_reference'
  'ctrl-broadcast|ctrl_broadcast_tb|examples/std/ctrl-flow.rhdl|ctrl_broadcast_design|ctrl_broadcast_verilog_reference'
  'ctrl-chain||examples/std/ctrl-flow.rhdl|ctrl_chain_design|ctrl_chain_verilog_reference'
  'full-adder||examples/rhdl/full-adder.rhdl|design|verilog_reference'
  'adder-core||examples/lop/adder-core.rhm|design|verilog_reference'
  'adder-kernel||examples/lop/adder-kernel.rhm|design|verilog_reference'
  'adder-composed||examples/lop/adder-composed.rhdl|design|verilog_reference'
  'bundle-kernel||examples/lop/bundle-kernel.rhdl|design|verilog_reference'
  'bundle-standard||examples/lop/bundle-standard.rhdl|design|verilog_reference'
  'interface-records||examples/lop/interface-records.rhdl|design|verilog_reference'
  'width-ops-kernel||examples/lop/width-ops-kernel.rhm|design|verilog_reference'
  'layered-adder||examples/rhdl/layered-adder.rhdl|design|verilog_reference'
  'host-parameters||examples/rhdl/host-parameters.rhdl|design|verilog_reference'
  'fresh-generators||examples/rhdl/fresh-generators.rhdl|design|verilog_reference'
  'dont-care||examples/std/dont-care.rhdl|design|verilog_reference'
  'decode|decode_tb|examples/std/decode.rhdl|design|verilog_reference'
  'decode-composition||examples/std/decode-composition.rhdl|design|verilog_reference'
  'noc-crossbar|noc_crossbar_tb|examples/noc/noc-crossbar.rhdl|design|verilog_reference'
  'noc-route-computer|noc_route_computer_tb|examples/noc/noc-route-computer.rhdl|design|verilog_reference'
  'noc-router|noc_router_tb|examples/noc/noc-router.rhdl|design|verilog_reference'
  'noc-network|noc_network_tb|examples/noc/noc-network.rhdl|design|verilog_reference'
  'generator-ordinary-defaults||examples/rhdl/generator-parameters.rhdl|ordinary_defaults_design|ordinary_defaults_verilog_reference'
  'generator-ordinary-overrides||examples/rhdl/generator-parameters.rhdl|ordinary_overrides_design|ordinary_overrides_verilog_reference'
  'generator-ordinary-typed-defaults||examples/rhdl/generator-parameters.rhdl|ordinary_typed_defaults_design|ordinary_typed_defaults_verilog_reference'
  'generator-ordinary-required-keyword||examples/rhdl/generator-parameters.rhdl|ordinary_required_keyword_design|ordinary_required_keyword_verilog_reference'
  'generator-sync-defaults||examples/rhdl/generator-parameters.rhdl|sync_defaults_design|sync_defaults_verilog_reference'
  'generator-sync-overrides||examples/rhdl/generator-parameters.rhdl|sync_overrides_design|sync_overrides_verilog_reference'
  'generator-sync-typed-defaults||examples/rhdl/generator-parameters.rhdl|sync_typed_defaults_design|sync_typed_defaults_verilog_reference'
  'register-forms||examples/rhdl/register-forms.rhdl|design|verilog_reference'
  'sync-ram|sync_ram_tb|examples/std/sync-ram.rhdl|design|verilog_reference'
  'table|table_tb|examples/rhdl/table.rhdl|design|verilog_reference'
  'tilelink-uncached||examples/tilelink/tilelink.rhdl|uncached_design|uncached_verilog_reference'
  'tilelink-cached||examples/tilelink/tilelink.rhdl|cached_design|cached_verilog_reference'
  'valid-pipe|valid_pipe_tb|examples/std/valid-pipe.rhdl|design|verilog_reference'
  'vec-search|vec_search_tb|examples/rhdl/vec-search.rhdl|design|verilog_reference'
)

direct_fixture_specs=(
  'nested-bundle|'
  'aggregate-memory|'
  'one-hot-aggregate|'
  'priority-encoder|priority_encoder_tb'
  'rv32i-alu|rv32i_alu_tb'
  'rv64i-alu|rv64i_alu_tb'
  'rv64i-alu-decode|'
  'rv64i-alu-integrated|rv64i_alu_integrated_tb'
  'credited-flow|credited_flow_tb'
  'credited-monitor|'
  'credited-monitor-overgrant|'
  'chi-foundation|chi_foundation_tb'
  'chi-full-flits|'
  'chi-link|chi_link_tb'
  'chi-monitor|chi_monitor_tb'
  'chi-transaction|chi_transaction_tb'
  'chi-transaction-sn|chi_transaction_sn_tb'
  'chi-ram|chi_ram_tb'
  'tilelink-protocol|tilelink_protocol_tb'
  'tilelink-ram|tilelink_ram_tb'
  'load-store|load_store_tb'
  'scoreboard|scoreboard_tb'
  'ricket-register-file|ricket_register_file_tb'
  'ricket-core|ricket_core_tb'
  'ricket-core-rv32|'
  'ricket-icache|ricket_icache_tb'
  'ricket-dcache|ricket_dcache_tb'
  'ricket-dcache-rv32|'
)

fixture_declared() {
  local wanted="$1"
  local spec fixture
  for spec in "${fixture_specs[@]}" "${direct_fixture_specs[@]}"; do
    IFS='|' read -r fixture _ <<< "$spec"
    [[ "$fixture" == "$wanted" ]] && return 0
  done
  return 1
}

for integration_fixture in "${integration_fixtures[@]}"; do
  if ! fixture_declared "$integration_fixture"; then
    echo "curated CIRCT fixture is not declared: $integration_fixture" >&2
    exit 1
  fi
done

for requested_fixture in ${FIXTURE:-} ${FIXTURES:-}; do
  if ! fixture_declared "$requested_fixture"; then
    echo "requested CIRCT fixture is not declared: $requested_fixture" >&2
    exit 1
  fi
done

for direct_spec in "${direct_fixture_specs[@]}"; do
  IFS='|' read -r direct_fixture _ <<< "$direct_spec"
  for example_spec in "${fixture_specs[@]}"; do
    IFS='|' read -r example_fixture _ <<< "$example_spec"
    if [[ "$direct_fixture" == "$example_fixture" ]]; then
      echo "CIRCT fixture has duplicate example and direct paths: $direct_fixture" >&2
      exit 1
    fi
  done
done

materialize_args=()
for spec in "${fixture_specs[@]}"; do
  IFS='|' read -r fixture top example design_export reference_export <<< "$spec"
  if fixture_selected "$fixture" \
      && [[ "$simulation_only" == false || -n "$top" ]]; then
    materialize_args+=(example "$fixture" "$example" "$design_export" "$reference_export")
  fi
done

for spec in "${direct_fixture_specs[@]}"; do
  IFS='|' read -r fixture top <<< "$spec"
  if direct_fixture_selected "$fixture" "$top"; then
    materialize_args+=(emitter "$fixture" "tests/backend/emit-$fixture.rhm")
  fi
done

if (( ${#materialize_args[@]} > 0 )); then
  racket -y -S "$repo_dir" tests/backend/load-example.rkt \
    materialize "$test_tmp_dir" "${materialize_args[@]}"
fi

for spec in "${fixture_specs[@]}"; do
  IFS='|' read -r fixture top example design_export reference_export <<< "$spec"
  if [[ -n "$top" ]]; then
    run_fixture "$fixture" "$top" "$example" "$design_export" "$reference_export"
  else
    golden_fixture "$fixture" "$example" "$design_export" "$reference_export"
  fi
done

for spec in "${direct_fixture_specs[@]}"; do
  IFS='|' read -r fixture top <<< "$spec"
  verify_fixture "$fixture" "$top"
done

run_expected_assertion_failure assertions assertions_fail_tb \
  tests/backend/verilog/assertions_fail_tb.sv request_holds
run_expected_assertion_failure credited-monitor \
  credited_monitor_underflow_tb \
  tests/backend/verilog/credited-monitor-underflow_tb.sv \
  credited_transfer_has_credit
run_expected_assertion_failure credited-monitor-overgrant \
  credited_monitor_overgrant_tb \
  tests/backend/verilog/credited-monitor-overgrant_tb.sv \
  credited_grant_within_limit
run_expected_assertion_failure chi-monitor \
  chi_monitor_unsupported_opcode_tb \
  tests/backend/verilog/chi-monitor-unsupported-opcode_tb.sv \
  chi_tx_req_opcode_supported
run_expected_assertion_failure chi-transaction \
  chi_transaction_duplicate_txn_tb \
  tests/backend/verilog/chi-transaction-duplicate-txn_tb.sv \
  chi_transaction_txn_id_unique
run_expected_assertion_failure chi-transaction \
  chi_transaction_early_data_tb \
  tests/backend/verilog/chi-transaction-early-data_tb.sv \
  chi_transaction_write_data_has_dbid
run_expected_assertion_failure chi-ram chi_ram_invalid_tb \
  tests/backend/verilog/chi-ram-invalid_tb.sv \
  chi_ram_request_address_supported
run_expected_assertion_failure tilelink-ram tilelink_ram_invalid_tb \
  tests/backend/verilog/tilelink-ram-invalid_tb.sv tilelink_a_mask_supported
