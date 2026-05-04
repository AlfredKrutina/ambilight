#!/usr/bin/env python3
"""Fix common double-encoded UTF-8 mojibake in lib/l10n/app_cs.arb (bytes)."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


# Longest sequences first.
BYTE_FIXES: list[tuple[bytes, bytes]] = [
    # Typographic „ “ … and · (broken UTF-8 layers)
    (b"\xc3\xa2\xe2\x82\xac\xc5\xbe", b"\xe2\x80\x9e"),  # „
    (b"\xc3\xa2\xe2\x82\xac\xc5\x9b", b"\xe2\x80\x9c"),  # “
    (b"\xc3\xa2\xe2\x82\xac\xc2\xa6", b"\xe2\x80\xa6"),  # …
    (b"\xc3\x82\xc2\xb7", b"\xc2\xb7"),  # ·
    # "Ä…" sequences → ě / č / Č / ď
    (b"\xc3\x84\xe2\x80\xba", b"\xc4\x9b"),  # ě
    (b"\xc3\x84\xc5\xa4", b"\xc4\x8d"),  # č
    (b"\xc3\x84\xc5\x9a", b"\xc4\x8c"),  # Č
    (b"\xc3\x84\xc5\xb9", b"\xc4\x8f"),  # ď
    (b"\xc3\xa2\xe2\x82\xac\xe2\x80\x9d", b"\xe2\x80\x94"),  # —
    (b"\xc3\xa2\xe2\x82\xac\xe2\x80\x98", b"\xe2\x80\x91"),  # ‑ (NB hyphen)
    (b"\xc3\xa2\xe2\x82\xac\xe2\x80\x9c", b"\xe2\x80\x93"),  # –
    (b"\xc4\xb9\xe2\x84\xa2", b"\xc5\x99"),  # ř
    (b"\xc4\xb9\xcb\x87", b"\xc5\xa1"),  # š
    (b"\xc4\xb9\xc4\xbe", b"\xc5\xbe"),  # ž
    (b"\xc4\xb9\xc5\xbb", b"\xc5\xaf"),  # ů
    (b"\xc4\xb9\xcb\x9d", b"\xc5\xbd"),  # Ž
    (b"\xc4\xb9\xc4\x84", b"\xc5\xa5"),  # ť
    (b"\xc4\xb9\xc2\x88", b"\xc5\xa1"),  # š (variant)
    (b"\xc4\x82\xc2\xad", b"\xc3\xad"),  # í
    (b"\xc4\x82\xc2\xa9", b"\xc3\xa9"),  # é
    (b"\xc4\x82\xe2\x80\x94", b"\xc3\x97"),  # ×
    (b"\xc4\x82\xcb\x87", b"\xc3\xa1"),  # á
    (b"\xc4\x82\xcb\x9d", b"\xc3\xbd"),  # ý
    (b"\xc4\x82\xc5\x82", b"\xc3\xb3"),  # ó
    (b"\xc4\x82\xc5\x9f", b"\xc3\xba"),  # ú
]

# Ambiguous byte fixes (ň vs š); apply after BYTE_FIXES.
STRING_FIXES_CS: tuple[tuple[str, str], ...] = (
    ("Doplš IP adresu kontroléru", "Doplň IP adresu kontroléru"),
    # After Ä-byte fixes this phrase would read "Měš"; intended imperative "Měň".
    ("Měš jen pokud", "Měň jen pokud"),
)


def apply_fixes(raw: bytes) -> bytes:
    out = raw
    for bad, good in BYTE_FIXES:
        out = out.replace(bad, good)
    return out


def apply_string_fixes_cs(arb_path: Path) -> None:
    p = arb_path / "app_cs.arb"
    text = p.read_text(encoding="utf-8")
    for bad, good in STRING_FIXES_CS:
        text = text.replace(bad, good)
    p.write_text(text, encoding="utf-8")


def merge_remainder(arb_path: Path, remainder_path: Path) -> None:
    """Overlay key|||EN|||CS lines onto app_en.arb / app_cs.arb."""
    pair_re = re.compile(
        r"^([^|#\s][^|]*)\|\|\|([^|]*)\|\|\|(.*)$",
    )
    pairs: dict[str, tuple[str, str]] = {}
    for line in remainder_path.read_text(encoding="utf-8-sig").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        m = pair_re.match(line)
        if not m:
            continue
        k, en, cs = m.group(1).strip(), m.group(2), m.group(3)
        pairs[k] = (en, cs)

    for name in ("app_en.arb", "app_cs.arb"):
        p = arb_path / name
        data = json.loads(p.read_text(encoding="utf-8"))
        is_cs = name.endswith("_cs.arb")
        for key, (en, cs) in pairs.items():
            if key not in data:
                continue
            data[key] = cs if is_cs else en
        p.write_text(
            json.dumps(data, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    arb = root / "lib" / "l10n" / "app_cs.arb"
    raw = arb.read_bytes()
    fixed = apply_fixes(raw)
    arb.write_bytes(fixed)

    remainder = Path(__file__).resolve().parent / "l10n_ui_remainder.txt"
    if remainder.is_file():
        merge_remainder(root / "lib" / "l10n", remainder)

    apply_string_fixes_cs(root / "lib" / "l10n")

    final_text = arb.read_text(encoding="utf-8")
    try:
        json.loads(final_text)
    except json.JSONDecodeError as e:
        print("JSON error after merge/fixes:", e, file=sys.stderr)
        return 1

    leftover = final_text.encode("utf-8")
    # Heuristic: remaining Ă-style starters in Czech file
    if b"\xc4\x82" in leftover or b"\xc4\xb9\xe2\x84\xa2" in leftover:
        print(
            "warning: possible unfixed mojibake patterns remain",
            file=sys.stderr,
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
