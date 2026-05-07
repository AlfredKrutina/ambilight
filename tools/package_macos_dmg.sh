#!/usr/bin/env bash
# DMG jako na macOS: okno se .app + zástupce „Applications“ (drag & drop).
# Čistý -srcfolder jen na .app je nepohodlný a často vypadá „špatně“.
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
# Alias „Applications“ pro instalaci přetažením (stejný vzor jako create-dmg bez další závislosti).
ln -sf /Applications "$STAGING/Applications"

rm -f "$OUT"
hdiutil create \
  -volname "$VOL" \
  -filesystem HFS+ \
  -srcfolder "$STAGING" \
  -ov \
  -format UDZO \
  "$OUT"

echo "DMG OK: $OUT"
