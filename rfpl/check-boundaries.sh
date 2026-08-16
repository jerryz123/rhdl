#!/usr/bin/env bash
# Enforces RFPL's one-way dependency on RHDL's structural construction surface.
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir"

if rg -n '^[[:space:]]+"[^\"]*rfpl/' rhdl --glob '*.rhm' --glob '*.rhdl'; then
  echo "RHDL must not import RFPL" >&2
  exit 1
fi

if rg -n 'rhdl/frontend/(standard\.rhm|layers/(assertion|bool|bundle|cast|comb|conditional|dpi|enum|expanding-arithmetic|interface|memory|one-hot|sequential|signed|sync-memory|sync|vector|wire)\.rhm)' \
    rfpl/frontend --glob '*.rhm'; then
  echo "RFPL frontend must not import RHDL logic or state layers" >&2
  exit 1
fi

unexpected_racket="$(find rfpl -type f -name '*.rkt' ! -path 'rfpl/main.rkt' -print)"
if [[ -n "$unexpected_racket" ]]; then
  echo "only the RFPL reader shim may use the .rkt extension" >&2
  echo "$unexpected_racket" >&2
  exit 1
fi

unexpected_rfpl="$(find . -path './.git' -prune -o -type f -name '*.rfpl' \
  ! -path './examples/rfpl/*' ! -path './rfpl/tests/*' -print)"
if [[ -n "$unexpected_rfpl" ]]; then
  echo ".rfpl files may appear only in RFPL examples and fixtures" >&2
  echo "$unexpected_rfpl" >&2
  exit 1
fi
