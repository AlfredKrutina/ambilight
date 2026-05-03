#!/usr/bin/env python3
"""Vygeneruje manifest.json pro GitHub Pages z výstupního build/ (ESP-IDF)."""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--build-dir", type=Path, required=True)
    p.add_argument("--out", type=Path, required=True)
    p.add_argument("--base-url", required=True, help="např. https://owner.github.io/repo/firmware/latest")
    p.add_argument("--version", required=True)
    p.add_argument("--chip", default="esp32c6")
    args = p.parse_args()

    flash_args = args.build_dir / "flash_project_args"
    if not flash_args.is_file():
        raise SystemExit(f"Chybí {flash_args}")

    text = flash_args.read_text(encoding="utf-8").strip().splitlines()
    if not text:
        raise SystemExit("flash_project_args je prázdný")

    first = text[0].strip()
    flash_mode = "dio"
    flash_freq = "80m"
    flash_size = "detect"
    m = re.match(
        r"--flash_mode\s+(\S+)\s+--flash_freq\s+(\S+)\s+--flash_size\s+(\S+)",
        first,
    )
    if m:
        flash_mode, flash_freq, flash_size = m.group(1), m.group(2), m.group(3)

    raw_parts: list[tuple[int, dict[str, str]]] = []
    base = args.base_url.rstrip("/")

    for line in text[1:]:
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        m2 = re.match(r"(0x[0-9a-fA-F]+)\s+(\S+)", line)
        if not m2:
            continue
        off, rel = m2.group(1), m2.group(2)
        bin_path = args.build_dir / rel
        if not bin_path.is_file():
            raise SystemExit(f"Chybí binárka {bin_path}")
        name = bin_path.name
        url = f"{base}/{name}"
        off_i = int(off, 16)
        raw_parts.append(
            (
                off_i,
                {
                    "offset": off.lower(),
                    "file": name,
                    "url": url,
                    "sha256": _sha256(bin_path),
                },
            )
        )

    raw_parts.sort(key=lambda t: t[0])
    parts = [p[1] for p in raw_parts]

    ota_url = ""
    app_rows = [
        p
        for p in raw_parts
        if "bootloader" not in p[1]["file"].lower()
        and "partition" not in p[1]["file"].lower()
    ]
    if app_rows:
        amb = [p for p in app_rows if "ambilight" in p[1]["file"].lower()]
        pick = max(amb if amb else app_rows, key=lambda t: t[0])
        ota_url = pick[1]["url"]

    # Širší kompatibilita při flashi z PC (skutečná velikost čipu se detekuje za běhu).
    flash_size_pub = "detect"

    manifest = {
        "schema": 1,
        "version": args.version,
        "chip": args.chip,
        "serial_flash": {
            "flash_mode": flash_mode,
            "flash_freq": flash_freq,
            "flash_size": flash_size_pub,
            "flash_size_esptool_hint": flash_size,
            "parts": parts,
        },
        "ota_http_url": ota_url,
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print("Wrote", args.out)


if __name__ == "__main__":
    main()
