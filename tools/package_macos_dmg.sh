#!/usr/bin/env bash
# Jednoduchý DMG: .app + alias Applications (bez Homebrew create-dmg).
# GitHub desktop_release na main používá tools/build_macos_dmg.sh (rozvržení + pozadí) — tento skript je záložní / lokální rychlovka.
# POZOR: hdiutil používá -fs (ne -filesystem); „-filesystem“ na runneru padne (unknown option).
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 <path/to/App.app> <output.dmg> <volume-name>" >&2
  exit 1
fi

APP="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
OUT="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
VOL="$3"

if [[ ! -d "$APP" ]]; then
  echo "missing app bundle: $APP" >&2
  exit 1
fi

STAGING="$(mktemp -d "${TMPDIR:-/tmp}/ambi-dmg.XXXXXX")"
cleanup() { rm -rf "$STAGING"; }
trap cleanup EXIT

cp -a "$APP" "$STAGING/"
ln -sf /Applications "$STAGING/Applications"

rm -f "$OUT"
hdiutil create \
  -volname "$VOL" \
  -fs HFS+ \
  -srcfolder "$STAGING" \
  -ov \
  -format UDZO \
  -imagekey zlib-level=9 \
  "$OUT"

echo "DMG OK: $OUT"
