#!/usr/bin/env bash
# Verifies that CI path classification selects exactly the affected jobs.
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
classifier="$repo_dir/tools/ci-changes.sh"

check_paths() {
  local expected="$1"
  shift
  local actual
  actual="$($classifier --paths "$@")"
  if [[ "$actual" != "$expected" ]]; then
    echo "unexpected CI classification for: $*" >&2
    diff -u <(printf '%s\n' "$expected") <(printf '%s\n' "$actual") >&2 || true
    return 1
  fi
}

empty_examples=$'examples=false\nexample_matrix={"include":[]}'
all_examples=$'examples=true\nexample_matrix={"include":[{"name":"RHDL","target":"examples-rhdl"},{"name":"standard library","target":"examples-std"},{"name":"language-oriented programming","target":"examples-lop"},{"name":"RFPL","target":"examples-rfpl"},{"name":"TileLink","target":"examples-tilelink"}]}'
rhdl_examples=$'examples=true\nexample_matrix={"include":[{"name":"RHDL","target":"examples-rhdl"}]}'
std_examples=$'examples=true\nexample_matrix={"include":[{"name":"standard library","target":"examples-std"}]}'
lop_examples=$'examples=true\nexample_matrix={"include":[{"name":"language-oriented programming","target":"examples-lop"}]}'
std_dependents=$'examples=true\nexample_matrix={"include":[{"name":"RHDL","target":"examples-rhdl"},{"name":"standard library","target":"examples-std"},{"name":"TileLink","target":"examples-tilelink"}]}'
rfpl_examples=$'examples=true\nexample_matrix={"include":[{"name":"RFPL","target":"examples-rfpl"}]}'
tilelink_examples=$'examples=true\nexample_matrix={"include":[{"name":"TileLink","target":"examples-tilelink"}]}'

host_only=$'host=true\ncirct=false\nfesvr=false\n'"$empty_examples"
host_and_circt=$'host=true\ncirct=true\nfesvr=false\n'"$empty_examples"
circt_only=$'host=false\ncirct=true\nfesvr=false\n'"$empty_examples"
fesvr_only=$'host=false\ncirct=false\nfesvr=true\n'"$empty_examples"
no_jobs=$'host=false\ncirct=false\nfesvr=false\n'"$empty_examples"
all_jobs=$'host=true\ncirct=true\nfesvr=true\n'"$all_examples"

check_paths "$no_jobs" README.md rhdl/README.md tests/backend/README.md
check_paths $'host=true\ncirct=true\nfesvr=false\n'"$all_examples" rhdl/core/ir.rhm
check_paths $'host=true\ncirct=true\nfesvr=false\n'"$std_dependents" rhdl/std/flow.rhdl
check_paths $'host=true\ncirct=true\nfesvr=false\n'"$rhdl_examples" examples/rhdl/alu.rhdl
check_paths $'host=true\ncirct=true\nfesvr=false\n'"$std_examples" examples/std/flow-control.rhdl
check_paths $'host=true\ncirct=true\nfesvr=false\n'"$lop_examples" examples/lop/adder-core.rhm
check_paths $'host=true\ncirct=true\nfesvr=false\n'"$rfpl_examples" rfpl/frontend/foundation.rhm
check_paths $'host=true\ncirct=true\nfesvr=false\n'"$tilelink_examples" tilelink/link.rhdl
check_paths $'host=true\ncirct=true\nfesvr=false\n'"$all_examples" examples/alu.rhdl
check_paths "$host_and_circt" cores/alu.rhdl cores/ricket/ricket.rhdl
check_paths "$host_only" noc/model/topology.rhm
check_paths "$host_only" riscv/isa/rv64i.rhm
check_paths "$host_and_circt" tests/backend/circt-test.rhm
check_paths "$circt_only" tests/backend/verilog/adder_tb.sv
check_paths "$fesvr_only" sim/fesvr/direct_mem_htif.cc
check_paths "$all_jobs" .github/workflows/ci.yml
check_paths $'host=true\ncirct=false\nfesvr=true\n'"$empty_examples" \
  noc/model/topology.rhm tools/install-fesvr.sh

if [[ "$($classifier --all)" != "$all_jobs" ]]; then
  echo "--all did not select every CI job" >&2
  exit 1
fi

if [[ "$($classifier 0000000000000000000000000000000000000000 HEAD)" != "$all_jobs" ]]; then
  echo "an unavailable base revision did not select every CI job" >&2
  exit 1
fi
