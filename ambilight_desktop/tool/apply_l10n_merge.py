#!/usr/bin/env python3
"""Sloučí řádky key|||EN|||CS do lib/l10n/app_en.arb a app_cs.arb (jen přidané / přepsané klíče)."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "lib" / "l10n"
PAIRS = Path(__file__).resolve().parent / "l10n_merge_pairs.txt"
SEP = "|||"


def placeholder_meta(value: str) -> dict | None:
    names = [m.group(1) for m in re.finditer(r"\{(\w+)\}", value)]
    if not names:
        return None
    return {"placeholders": {n: {} for n in names}}


def merge_en(path: Path, adds: dict[str, str]) -> None:
    data = json.loads(path.read_text(encoding="utf-8"))
    for k, v in adds.items():
        data[k] = v
    for k, v in adds.items():
        if k.startswith("@"):
            continue
        meta = placeholder_meta(v)
        if meta is not None:
            data[f"@{k}"] = meta
        elif f"@{k}" in data:
            del data[f"@{k}"]
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def merge_cs(path: Path, adds: dict[str, str]) -> None:
    raw = json.loads(path.read_text(encoding="utf-8"))
    locale = raw["@@locale"]
    out: dict[str, str] = {"@@locale": locale}
    for k, v in raw.items():
        if k == "@@locale" or k.startswith("@"):
            continue
        out[k] = v
    out.update(adds)
    path.write_text(json.dumps(out, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    add_en: dict[str, str] = {}
    add_cs: dict[str, str] = {}
    for raw in PAIRS.read_text(encoding="utf-8-sig").splitlines():
        line = raw.strip().lstrip("\ufeff")
        if not line or line.startswith("#"):
            continue
        if SEP not in raw:
            raise SystemExit(f"Missing {SEP!r}: {raw!r}")
        key, rest = raw.split(SEP, 1)
        if SEP not in rest:
            raise SystemExit(f"Bad line: {raw!r}")
        en, cs = rest.split(SEP, 1)
        k = key.strip().lstrip("\ufeff")
        if k.startswith("#"):
            continue
        add_en[k] = en.strip().replace("\\n", "\n")
        add_cs[k] = cs.strip().replace("\\n", "\n")

    merge_en(ROOT / "app_en.arb", add_en)
    merge_cs(ROOT / "app_cs.arb", add_cs)
    print(f"Merged {len(add_en)} keys from {PAIRS}")


if __name__ == "__main__":
    main()
