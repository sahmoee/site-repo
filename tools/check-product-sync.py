#!/usr/bin/env python3
"""Detect product documentation or approved artwork that changed after the website review."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

SITE = Path(__file__).resolve().parents[1]
DOCUMENTS = SITE.parent
MANIFEST = SITE / "product-sync.json"
SOURCES = {
    "stocked": {
        "features": DOCUMENTS / "stocked/README.md",
        "artwork": DOCUMENTS / "stocked/Brand/Stocked-AppIcon-Master.png",
        "page": SITE / "apps/stocked/index.html",
    },
    "sesh": {
        "features": DOCUMENTS / "The-Sesh/README.md",
        "artwork": DOCUMENTS / "The-Sesh/The SESH./Icons/AppIcon-1024-master.png",
        "page": SITE / "apps/sesh/index.html",
    },
    "nova": {
        "features": DOCUMENTS / "Nova/README.md",
        "artwork": DOCUMENTS / "Nova/Nova/Resources/Brand/Nova-AppIcon-Pastel-Master.png",
        "page": SITE / "apps/nova/index.html",
    },
    "gir": {
        # GIR's current branch keeps its shipped feature summary and approved banner
        # at repository level. The former docs/assets paths belonged to an earlier
        # branch and made a missing path look like a product/artwork change forever.
        "features": DOCUMENTS / "GIR/README.md",
        "artwork": DOCUMENTS / "GIR/data/images/banner.png",
        "page": SITE / "apps/gir/index.html",
    },
}

def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def snapshot() -> dict[str, dict[str, str]]:
    result = {}
    for product, paths in SOURCES.items():
        result[product] = {}
        for kind, path in paths.items():
            if not path.exists():
                result[product][kind] = "missing"
            else:
                result[product][kind] = digest(path)
    return result

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--record", action="store_true", help="record the current reviewed source state")
    args = parser.parse_args()
    current = snapshot()
    if args.record or not MANIFEST.exists():
        MANIFEST.write_text(json.dumps({"schemaVersion": 1, "products": current}, indent=2) + "\n")
        print("Recorded current product sources.")
        return 0
    recorded = json.loads(MANIFEST.read_text()).get("products", {})
    changes = []
    for product, values in current.items():
        for kind, value in values.items():
            if recorded.get(product, {}).get(kind) != value:
                changes.append(f"{product}: {kind}")
    if changes:
        print("Website review needed:")
        print("\n".join(f"- {change}" for change in changes))
        return 1
    print("Website product pages match the last reviewed source state.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
