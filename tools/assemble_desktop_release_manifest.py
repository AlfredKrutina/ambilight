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
    p.add_argument("--tag", required=True, help="např. desktop-v1.0.4 nebo desktop-main")
    p.add_argument(
        "--manifest-version",
        default="",
        help="SemVer do pole version (pro desktop-main povinné; jinak z tagu desktop-v…)",
    )
    p.add_argument("--zip", type=Path, required=True)
    p.add_argument(
        "--setup-exe",
        type=Path,
        default=None,
        help="Volitelný Inno installer; když chybí, windows_x64_setup se do manifestu nedá.",
    )
    p.add_argument(
        "--dmg",
        type=Path,
        default=None,
        help="Volitelný macOS DMG; když chybí, macos_dmg se do manifestu nedá.",
    )
    p.add_argument(
        "--linux-tarball",
        type=Path,
        default=None,
        help="Volitelný Linux tarball; když chybí, linux_x64 se do manifestu nedá.",
    )
    p.add_argument("--out", type=Path, required=True)
    args = p.parse_args()

    ver = args.manifest_version.strip()
    if not ver:
        ver = args.tag.removeprefix("desktop-v").strip()
        if not ver:
            raise SystemExit("empty version: dej --manifest-version nebo tag desktop-vX.Y.Z")

    if not args.zip.is_file():
        raise SystemExit(f"ZIP neexistuje: {args.zip}")

    repo = args.repo.strip()
    base = f"https://github.com/{repo}/releases/download/{args.tag}"
    notes = f"https://github.com/{repo}/releases/tag/{args.tag}"

    assets: dict[str, dict[str, str]] = {
        "windows_x64": {
            "url": f"{base}/ambilight_desktop_windows_x64.zip",
            "sha256": _sha256(args.zip),
            "kind": "zip",
        },
    }

    setup = args.setup_exe
    if setup is None:
        cand = args.zip.with_name("ambilight_desktop_windows.exe")
        setup = cand if cand.is_file() else None
    if setup is not None and setup.is_file():
        assets["windows_x64_setup"] = {
            "url": f"{base}/ambilight_desktop_windows.exe",
            "sha256": "",
            "kind": "browser",
        }

    dmg = args.dmg
    if dmg is None:
        # CI ukládá DMG do artifacts/mac/ — volající může předat cestu; jinak jen URL pokud soubor existuje vedle.
        pass
    if dmg is not None and dmg.is_file():
        assets["macos_dmg"] = {
            "url": f"{base}/ambilight_desktop_macos.dmg",
            "sha256": "",
            "kind": "browser",
        }
    else:
        # DMG se v CI vždy publikuje; URL necháme i bez lokálního souboru (browser-only).
        assets["macos_dmg"] = {
            "url": f"{base}/ambilight_desktop_macos.dmg",
            "sha256": "",
            "kind": "browser",
        }

    linux = args.linux_tarball
    if linux is not None and linux.is_file():
        assets["linux_x64"] = {
            "url": f"{base}/ambilight_desktop_linux_x64.tar.gz",
            "sha256": "",
            "kind": "browser",
        }
    else:
        assets["linux_x64"] = {
            "url": f"{base}/ambilight_desktop_linux_x64.tar.gz",
            "sha256": "",
            "kind": "browser",
        }

    manifest = {
        "version": ver,
        "channel": "stable",
        "release_notes_url": notes,
        "release_page_url": notes,
        "assets": assets,
    }

    args.out.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print("Wrote", args.out, "assets=", ",".join(assets.keys()))


if __name__ == "__main__":
    main()
