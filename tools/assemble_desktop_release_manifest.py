#!/usr/bin/env python3
"""Vygeneruje desktop-manifest.json pro GitHub Release (SHA-256 jen u ZIP pro auto-update)."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest().lower()


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--repo", required=True, help="owner/name")
    p.add_argument("--tag", required=True, help="např. desktop-v1.0.4")
    p.add_argument("--zip", type=Path, required=True)
    p.add_argument("--out", type=Path, required=True)
    args = p.parse_args()

    ver = args.tag.removeprefix("desktop-v").strip()
    if not ver:
        raise SystemExit("empty version after desktop-v prefix")

    repo = args.repo.strip()
    base = f"https://github.com/{repo}/releases/download/{args.tag}"
    notes = f"https://github.com/{repo}/releases/tag/{args.tag}"

    zip_url = f"{base}/ambilight_desktop_windows_x64.zip"
    setup_url = f"{base}/ambilight_desktop_windows_x64_setup.exe"
    dmg_url = f"{base}/ambilight_desktop_macos.dmg"
    linux_url = f"{base}/ambilight_desktop_linux_x64.tar.gz"

    manifest = {
        "version": ver,
        "channel": "stable",
        "release_notes_url": notes,
        "release_page_url": notes,
        "assets": {
            "windows_x64": {
                "url": zip_url,
                "sha256": _sha256(args.zip),
                "kind": "zip",
            },
            "windows_x64_setup": {
                "url": setup_url,
                "sha256": "",
                "kind": "browser",
            },
            "macos_dmg": {
                "url": dmg_url,
                "sha256": "",
                "kind": "browser",
            },
            "linux_x64": {
                "url": linux_url,
                "sha256": "",
                "kind": "browser",
            },
        },
    }

    args.out.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print("Wrote", args.out)


if __name__ == "__main__":
    main()
