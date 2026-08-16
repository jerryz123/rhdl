#!/usr/bin/env bash
# Ensures every concretely materialized example design owns and exports a Verilog reference.
set -euo pipefail

allow_empty=false
source_roots=()
for argument in "$@"; do
  if [[ "$argument" == "--allow-empty" ]]; then
    allow_empty=true
  elif [[ "$argument" == --* ]]; then
    echo "usage: $0 [--allow-empty] [SOURCE_ROOT ...]" >&2
    exit 2
  else
    source_roots+=("$argument")
  fi
done
if (( ${#source_roots[@]} == 0 )); then
  source_roots=(examples)
fi

for source_root in "${source_roots[@]}"; do
  if [[ ! -e "$source_root" ]]; then
    echo "example source root not found: $source_root" >&2
    exit 2
  fi
done

status=0
while IFS= read -r source_file; do
  while IFS= read -r design_export; do
    if [[ "$design_export" == "design" ]]; then
      reference_export="verilog_reference"
    else
      reference_export="${design_export%_design}_verilog_reference"
    fi

    if ! grep -Fq "def $reference_export = @str|<<{" "$source_file"; then
      echo "$source_file: $design_export requires $reference_export" >&2
      status=1
    elif ! grep -Eq "^[[:space:]]+$reference_export$" "$source_file"; then
      echo "$source_file: $reference_export must be exported" >&2
      status=1
    elif [[ "$allow_empty" == false ]] &&
         ! sed -n "/^def $reference_export = @str|<<{/,/^}>>|/p" "$source_file" |
           sed '1d;$d' | grep -q '[^[:space:]]'; then
      echo "$source_file: $reference_export must contain generated Verilog" >&2
      status=1
    fi

    manifest_entry="|$source_file|$design_export|$reference_export'"
    if ! grep -Fq "$manifest_entry" tests/backend/run-circt.sh; then
      echo "$source_file: $design_export and $reference_export require a backend manifest entry" >&2
      status=1
    fi
  done < <(sed -n 's/^def \([A-Za-z0-9_]*design\) = .*/\1/p' "$source_file")

  if [[ "$allow_empty" == false ]]; then
    while IFS= read -r circuit_name; do
      if ! grep -Eq "^module ${circuit_name}([_(]|$)" "$source_file"; then
        echo "$source_file: circuit $circuit_name has no colocated Verilog module" >&2
        status=1
      fi
    done < <(sed -n -E 's/^(sync_)?circuit ([A-Za-z0-9_]+).*/\2/p' "$source_file")
  fi
done < <(find "${source_roots[@]}" -type f \( -name '*.rhm' -o -name '*.rhdl' \) | sort)

exit "$status"
