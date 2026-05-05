#!/usr/bin/env bash
# Sestaví Release .app a z něj UDZO DMG (stejný princip jako CI).
# Spouštěj z kořene repozitáře na Macu: bash tools/build_mac_dmg.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESKTOP="$ROOT/ambilight_desktop"
cd "$DESKTOP"

# Nepodepsaný build (vhodné pro vlastní sdílení). Pro podepsání nastav v Xcode / LocalSigning.xcconfig
# a případně unset CODE_SIGNING_ALLOWED před spuštěním.
export CODE_SIGNING_ALLOWED="${CODE_SIGNING_ALLOWED:-NO}"
export CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"

flutter pub get
flutter build macos --release \
  --dart-define=GIT_SHA="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo local)" \
  --dart-define=AMBI_CHANNEL=stable

# BSD sed nezná \s — použij [[:space:]], aby volname byl např. „AmbiLight 1.0.3+1“.
VER="$(grep -E '^[[:space:]]*version:[[:space:]]*' pubspec.yaml | head -1 | sed -E 's/^[[:space:]]*version:[[:space:]]*([^[:space:]#]+).*/\1/')"
APP="build/macos/Build/Products/Release/ambilight_desktop.app"
DMG_OUT="$DESKTOP/ambilight_desktop_macos.dmg"

if [[ ! -d "$APP" ]]; then
  echo "Chybí $APP — build selhal?" >&2
  exit 1
fi

# Rozložení jako u běžných macOS installerů: .app + zástupce „Applications“ → přetáhni do Applications.
STAGING="$DESKTOP/build/macos/dmg_staging"
RW_DMG="$DESKTOP/build/macos/ambi_dmg_rw.dmg"
APP_NAME="$(basename "$APP")"
VOLNAME="AmbiLight ${VER}"
BACKGROUND_SRC="$ROOT/tools/dmg_assets/dmg_background.png"

rm -rf "$STAGING"
mkdir -p "$STAGING/.background"
ditto "$APP" "$STAGING/$APP_NAME"
ln -sf /Applications "$STAGING/Applications"
rm -f "$STAGING/.DS_Store"
if [[ ! -f "$BACKGROUND_SRC" ]]; then
  echo "Chybí pozadí DMG: $BACKGROUND_SRC" >&2
  exit 1
fi
ditto "$BACKGROUND_SRC" "$STAGING/.background/dmg_background.png"

rm -f "$DMG_OUT" "$RW_DMG"

# UDRW obraz → AppleScript (Finder) nastaví velké ikony + pozadí → pak UDZO.
hdiutil create -quiet -srcfolder "$STAGING" -volname "$VOLNAME" -fs APFS -format UDRW -ov "$RW_DMG"

attach_out="$(hdiutil attach -readwrite -noverify -noautoopen -nobrowse -mountrandom /Volumes "$RW_DMG")"
echo "$attach_out"
line="$(echo "$attach_out" | grep '/Volumes/' | tail -1 || true)"
MOUNT_DIR="$(echo "$line" | awk -F'	' '{print $NF}')"
if [[ -z "${MOUNT_DIR:-}" ]] || [[ ! -d "$MOUNT_DIR" ]]; then
  echo "Nepodařilo se připojit RW DMG (mount=$MOUNT_DIR)." >&2
  exit 1
fi

VOL_BASE="$(basename "$MOUNT_DIR")"

layout_dmgs() {
  # Čekání kvůli občasné chybě Finderu „Can’t get disk“ (-1728).
  sleep "${DMG_APPLESCRIPT_SLEEP:-5}"
  /usr/bin/osascript "$ROOT/tools/dmg_support/finder_layout.applescript" "$VOL_BASE" "$APP_NAME" >/dev/null
}

if [[ "${SKIP_DMG_FINDER_LAYOUT:-0}" != "1" ]]; then
  echo "Finder: velké ikony, pozadí, pozice pro přetažení do Applications…"
  if layout_dmgs; then
    echo "Finder rozvržení hotovo."
  else
    echo "⚠ AppleScript pro rozvržení Finderu selhal (žádné GUI / oprávnění?). DMG bude bez vlastního okna." >&2
  fi
else
  echo "Přeskakuji Finder layout (SKIP_DMG_FINDER_LAYOUT=1)."
fi

chmod -Rf go-w "$MOUNT_DIR" 2>/dev/null || true
sync
sleep 1

hdiutil detach "$MOUNT_DIR" || hdiutil detach "$MOUNT_DIR" -force

hdiutil convert "$RW_DMG" -quiet -format UDZO -imagekey zlib-level=9 -ov -o "$DMG_OUT"
rm -f "$RW_DMG"

echo "Hotovo: $DMG_OUT"
