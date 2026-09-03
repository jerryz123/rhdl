#!/usr/bin/env python3
# Verifies that mapped simulation used the intended logical scope and functional models.

import argparse
import json
from pathlib import Path
import sys


def fail(message: str) -> None:
    print(f"mapped simulation manifest check failed: {message}", file=sys.stderr)
    raise SystemExit(2)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--top", required=True)
    parser.add_argument("--policy-top", required=True)
    parser.add_argument("--scope-prefix", required=True)
    arguments = parser.parse_args()

    try:
        manifest = json.loads(arguments.manifest.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        fail(str(error))
    if manifest.get("schema_version") != 2:
        fail("expected a site-aware schema_version 2 manifest")
    selection = manifest.get("selection_policy", {})
    expected = {
        "top": arguments.top,
        "policy_top": arguments.policy_top,
        "scope_prefix": arguments.scope_prefix,
    }
    for name, value in expected.items():
        if selection.get(name) != value:
            fail(f"expected {name}={value}, got {selection.get(name)}")

    sites = manifest.get("sites")
    totals = manifest.get("totals", {})
    if not isinstance(sites, list) or totals.get("memory_sites") != len(sites):
        fail("site list and totals disagree")
    mapped = [site for site in sites if site.get("decision") == "macro"]
    if not mapped or totals.get("mapped_sites") != len(mapped):
        fail("expected at least one mapped site and consistent totals")
    for site in mapped:
        model = site.get("functional_verilog")
        if not isinstance(model, str) or not Path(model).is_file():
            fail(f"mapped site {site.get('path')} has no usable functional model")
        mapping = site.get("mapping", {})
        if mapping.get("interface") != "openram_1rw1r":
            fail(f"mapped site {site.get('path')} has an unsupported interface")

    print(
        f"validated {len(mapped)} mapped site(s) across "
        f"{len(sites)} {arguments.policy_top}-relative memories"
    )


if __name__ == "__main__":
    main()
