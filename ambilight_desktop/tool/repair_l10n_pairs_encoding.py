#!/usr/bin/env python3
"""Opraví dvojnásobně dekódovaná UTF-8 řetězce v sloupcích EN/CS (PowerShell Set-Content)."""
from pathlib import Path

PAIRS = Path(__file__).resolve().parent / "l10n_merge_pairs.txt"
SEP = "|||"


def fix_utf8_mojibake(s: str) -> str:
    if not any(x in s for x in ("Ã", "Â", "â€", "Å", "Ä", "Ĺ", "ż", "Ă")):
        return s
    out = s
    for _ in range(4):
        try:
            nxt = out.encode("latin-1").decode("utf-8")
            if nxt == out:
                break
            out = nxt
        except (UnicodeDecodeError, UnicodeEncodeError):
            break
    return out


def main() -> None:
    raw_lines = PAIRS.read_text(encoding="utf-8-sig").splitlines()
    out: list[str] = []
    for raw in raw_lines:
        line = raw.strip().lstrip("\ufeff")
        if not line or line.startswith("#"):
            out.append(raw)
            continue
        if SEP not in raw:
            out.append(raw)
            continue
        key, rest = raw.split(SEP, 1)
        if SEP not in rest:
            out.append(raw)
            continue
        en, cs = rest.split(SEP, 1)
        en_f = fix_utf8_mojibake(en)
        cs_f = fix_utf8_mojibake(cs)
        k0 = key.strip().lstrip("\ufeff")
        out.append(f"{k0}{SEP}{en_f}{SEP}{cs_f}")
    PAIRS.write_text("\n".join(out) + "\n", encoding="utf-8")
    print(f"Repaired encoding in {PAIRS}")


if __name__ == "__main__":
    main()
