#!/usr/bin/env bash
# Enforces RHDL source conventions, package imports, and standard, base, and Golf profile composition.
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir"

search_sources() {
  local pattern="$1"
  shift
  if command -v rg >/dev/null 2>&1; then
    rg -n "$pattern" "$@" --glob '*.rhm' --glob '*.rhdl' --glob '*.rkt'
  else
    find "$@" -type f \( -name '*.rhm' -o -name '*.rhdl' -o -name '*.rkt' \) \
      -exec grep -nHE "$pattern" {} +
  fi
}

fail_matches() {
  local description="$1"
  local pattern="$2"
  local directory="$3"
  local matches
  matches="$(search_sources "$pattern" "$directory" || true)"
  if [[ -n "$matches" ]]; then
    echo "$description" >&2
    echo "$matches" >&2
    exit 1
  fi
}

fail_matches "core must not import analysis, frontend, backend, or formal modules" \
  '^[[:space:]]+"[^"]*(analysis|frontend|backend|formal)/' rhdl/core
fail_matches "analysis must depend only on core and other analysis modules" \
  '^[[:space:]]+"[^"]*(frontend|backend|formal|std)/' rhdl/analysis
fail_matches "host annotations must remain dependency-neutral" \
  '^[[:space:]]+.*(rhdl/|noc/|riscv/|tilelink/|chi/|rfpl/|cores/|sim/)' host
fail_matches "frontend must not import backend or formal modules" \
  '^[[:space:]]+"[^"]*(backend|formal)/' rhdl/frontend
fail_matches "frontend must not import the optional standard library" \
  '^[[:space:]]+"[^"]*std/' rhdl/frontend
fail_matches "backend must not import frontend or formal modules" \
  '^[[:space:]]+"[^"]*(frontend|formal)/' rhdl/backend
fail_matches "formal engine must not import frontend, backend, or standard-library modules" \
  '(frontend/|backend/|std/)' rhdl/formal
fail_matches "standard library must not import RHDL implementation packages" \
  '^[[:space:]]+.*(core/|analysis/|backend/|frontend/|formal/)' rhdl/std
fail_matches "RHDL packages must not import the external TileLink domain library" \
  '^[[:space:]]+.*tilelink/' rhdl
fail_matches "RHDL packages must not import the external CHI domain library" \
  '^[[:space:]]+.*chi/' rhdl
fail_matches "simulation adapters must not import RHDL implementation packages" \
  '^[[:space:]]+.*(core/|analysis/|backend/|frontend/)' sim
fail_matches "standard language assembly must not import analysis, core, backend, or formal modules" \
  '^[[:space:]]+"[^"]*(analysis|core|backend|formal)/' rhdl/language.rhm
fail_matches "base language assembly must not import analysis, core, backend, or formal modules" \
  '^[[:space:]]+"[^"]*(analysis|core|backend|formal)/' rhdl/base/language.rhm
fail_matches "Golf language assembly must not import analysis, core, backend, or formal modules" \
  '^[[:space:]]+"[^"]*(analysis|core|backend|formal)/' rhdl/golf/language.rhm
fail_matches "Golf syntax must not depend on analysis, core, backend, optional libraries, or domain packages" \
  '^[[:space:]]+.*(analysis/|core/|backend/|formal/|std/|tilelink/|chi/|noc/|rfpl/|riscv/|cores/|sim/)' rhdl/golf/surface.rhm
fail_matches "the standard frontend must aggregate only the foundation and frontend layers" \
  '^[[:space:]]+"[^"]*(analysis/|core/|kernel\.rhm|support/)' rhdl/frontend/standard.rhm
fail_matches "the standard frontend must not implement feature behavior" \
  '^[[:space:]]*(def|fun|class|interface|operator|expr\.|defn\.|annot\.|dot\.|reducer\.)' rhdl/frontend/standard.rhm
fail_matches "the Golf language assembly must not implement feature behavior" \
  '^[[:space:]]*(def|fun|class|interface|operator|expr\.|defn\.|annot\.|dot\.|reducer\.)' rhdl/golf/language.rhm
fail_matches "the frontend foundation must not depend on layers or the standard aggregator" \
  '^[[:space:]]+"[^"]*(layers/|standard\.rhm)' rhdl/frontend/foundation.rhm
fail_matches "frontend support must not depend on profiles or language layers" \
  '^[[:space:]]+"[^"]*(foundation\.rhm|standard\.rhm|layers/)' rhdl/frontend/support
fail_matches "frontend layers must not depend on profiles or the standard aggregator" \
  '^[[:space:]]+"[^"]*(foundation\.rhm|standard\.rhm)' rhdl/frontend/layers
fail_matches "frontend layers must not import sibling layers" \
  '^[[:space:]]+"(bool|bundle|cast|comb|conditional|dpi|enum|expanding-arithmetic|hierarchy|interface|memory|one-hot|sequential|sync|sync-memory|vector|wire)\.rhm"' rhdl/frontend/layers

while IFS= read -r layer_file; do
  layer_name="$(basename "$layer_file")"
  if ! grep -Fq "| \`$layer_name\` |" rhdl/README.md; then
    echo "frontend layer is missing from the rhdl/README.md dependency table: $layer_file" >&2
    exit 1
  fi
done < <(find rhdl/frontend/layers -maxdepth 1 -type f -name '*.rhm' | sort)

fail_matches "core tests must not import analysis or backend modules" \
  '^[[:space:]]+"[^"]*(analysis|backend)/' tests/core
fail_matches "analysis tests must not import frontend, backend, formal, or standard-library modules" \
  '^[[:space:]]+"[^"]*(frontend|backend|formal|std)/' tests/analysis
fail_matches "frontend tests must not import backend modules" \
  '^[[:space:]]+"[^"]*backend/' tests/frontend

unexpected_top_level="$(find rhdl -maxdepth 1 -type f \
  ! -name 'README.md' ! -name 'CLOCKING_PLAN.md' \
  ! -name 'main.rkt' ! -name 'language.rhm' -print)"
if [[ -n "$unexpected_top_level" ]]; then
  echo "rhdl root may contain only architecture documents, the reader shim, and language assembly" >&2
  echo "$unexpected_top_level" >&2
  exit 1
fi

unexpected_racket="$(find rhdl -type f -name '*.rkt' \
  ! -path 'rhdl/main.rkt' \
  ! -path 'rhdl/base/main.rkt' \
  ! -path 'rhdl/base/lang/reader.rkt' \
  ! -path 'rhdl/formal/engine.rkt' \
  ! -path 'rhdl/golf/main.rkt' \
  ! -path 'rhdl/golf/lang/reader.rkt' -print)"
if [[ -n "$unexpected_racket" ]]; then
  echo "only #lang reader shims and the Rosette formal engine may use the .rkt extension" >&2
  echo "$unexpected_racket" >&2
  exit 1
fi

unexpected_rhdl="$(find . -path './.git' -prune -o -type f -name '*.rhdl' \
  ! -path './examples/*' ! -path './tests/frontend/*' ! -path './tests/formal/*' ! -path './tests/fesvr/*' \
  ! -path './rhdl/std/*' ! -path './riscv/rhdl/*' \
  ! -path './noc/rtl/*' \
  ! -path './tilelink/*' ! -path './chi/*' \
  ! -path './sim/*' ! -path './cores/*' ! -path './vlsi/src/*' -print)"
if [[ -n "$unexpected_rhdl" ]]; then
  echo ".rhdl files may appear only in std, domain libraries, public adapters, examples, concrete cores, simulation adapters, physical-design fixtures, and frontend or FESVR fixtures" >&2
  echo "$unexpected_rhdl" >&2
  exit 1
fi
