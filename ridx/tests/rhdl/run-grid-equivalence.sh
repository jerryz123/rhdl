#!/usr/bin/env bash
# Verifies exact CIRCT MLIR and generated Verilog equivalence for the Ridx RHDL grid.
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/../../.." && pwd)"
test_tmp_dir="$(mktemp -d /tmp/ridx-rhdl-grid.XXXXXX)"
compiled_root="$test_tmp_dir/compiled"
mkdir -p "$compiled_root"
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
env PLTCOMPILEDROOTS="$compiled_root" PLTCOLLECTS="$repo_dir:" racket -y \
  ridx/tests/rhdl/emit-explicit-grid.rhm > "$test_tmp_dir/explicit.mlir"
env PLTCOMPILEDROOTS="$compiled_root" PLTCOLLECTS="$repo_dir:" racket -y \
  ridx/tests/rhdl/emit-ridx-grid.rhm > "$test_tmp_dir/ridx.mlir"
diff -u "$test_tmp_dir/explicit.mlir" "$test_tmp_dir/ridx.mlir"

circt_args=(
  --strip-debuginfo-with-pred='drop-suffix=.mlir'
  --canonicalize
  --cse
  --prettify-verilog
  --lower-sim-to-sv
  --lower-verif-to-sv
  --lower-seq-to-sv='disable-mem-randomization=true disable-reg-randomization=true'
  --sv-mask-non-synthesizable='mode=ifdef macro=SYNTHESIS'
  --export-verilog
)
"$circt_opt" "${circt_args[@]}" "$test_tmp_dir/explicit.mlir" \
  -o /dev/null > "$test_tmp_dir/explicit.sv"
"$circt_opt" "${circt_args[@]}" "$test_tmp_dir/ridx.mlir" \
  -o /dev/null > "$test_tmp_dir/ridx.sv"
diff -u "$test_tmp_dir/explicit.sv" "$test_tmp_dir/ridx.sv"
