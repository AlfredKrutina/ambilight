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

VER="$(grep -E '^\s*version:\s*' pubspec.yaml | head -1 | sed -E 's/^\s*version:\s*([^ +]+).*/\1/')"
APP="build/macos/Build/Products/Release/ambilight_desktop.app"
DMG_OUT="$DESKTOP/ambilight_desktop_macos.dmg"

if [[ ! -d "$APP" ]]; then
  echo "Chybí $APP — build selhal?" >&2
  exit 1
fi

rm -f "$DMG_OUT"
hdiutil create -volname "AmbiLight ${VER}" -srcfolder "$APP" -ov -format UDZO "$DMG_OUT"

echo "Hotovo: $DMG_OUT"
