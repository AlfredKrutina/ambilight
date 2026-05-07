#!/usr/bin/env bash
# Lokální stejný postup jako job „macos“ v .github/workflows/desktop_release.yml:
#   flutter build macos --release + stejné dart-define + vypnutý code signing + tools/build_macos_dmg.sh
# Výstup ve výchozím stavu: <kořen repa>/ambilight_desktop_macos.dmg (jako artefakt z Actions).
#
# Volitelně:
#   OUT=/cesta/k/out.dmg         — jiný výstupní soubor
#   DESKTOP_RELEASE_REF=desktop-v1.2.3 — jako release tag: verze svazku + kontrola shody s pubspec (jako CI)
#
# Závislosti: Flutter, macOS, Homebrew create-dmg (pro stejný vzhled jako CI — pozadí, šipka, ikony).
# Bez create-dmg skript ukončí chybu; výjimka: AMBILIGHT_ALLOW_PLAIN_DMG=1 (prázdný vzhled přes hdiutil).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESKTOP="${ROOT}/ambilight_desktop"
OUT="${OUT:-${ROOT}/ambilight_desktop_macos.dmg}"

# Cursor / neinteraktivní shell často nemá Homebrew v PATH — CI má brew na standardní cestě.
export PATH="/opt/homebrew/bin:/usr/local/bin:${PATH}"

_has_create_dmg() {
  command -v create-dmg >/dev/null 2>&1 && return 0
  [[ -x /opt/homebrew/bin/create-dmg ]] && return 0
  [[ -x /usr/local/bin/create-dmg ]] && return 0
  return 1
}

command -v flutter >/dev/null 2>&1 || { echo "error: flutter not on PATH" >&2; exit 1; }

if ! _has_create_dmg; then
  if [[ "${SKIP_BREW_CREATE_DMG:-}" != "1" ]] && command -v brew >/dev/null 2>&1; then
    echo "→ create-dmg chybí — instaluji: brew install create-dmg (kvůli rozložení DMG jako na webu)" >&2
    brew install create-dmg
  fi
fi

if ! _has_create_dmg; then
  if [[ "${AMBILIGHT_ALLOW_PLAIN_DMG:-}" == "1" ]]; then
    echo "→ AMBILIGHT_ALLOW_PLAIN_DMG=1: pokračuji s prostým DMG bez pozadí a šipky." >&2
  else
    echo "" >&2
    echo "error: Pro DMG se stejným vzhledem jako z GitHub Actions je potřeba create-dmg." >&2
    echo "       Spusť:  brew install create-dmg" >&2
    echo "       Nebo jen test bez grafiky:  AMBILIGHT_ALLOW_PLAIN_DMG=1 bash $0" >&2
    echo "       (viz tools/build_macos_dmg.sh — větev bez create-dmg)" >&2
    echo "" >&2
    exit 1
  fi
fi

ref="${DESKTOP_RELEASE_REF:-}"
if [[ "$ref" == desktop-v* ]]; then
  ver="${ref#desktop-v}"
  line="$(grep -E '^\s*version:\s*' "${DESKTOP}/pubspec.yaml" | head -1)"
  pub="$(echo "$line" | sed -E 's/^\s*version:\s*([^ +]+).*/\1/')"
  if [[ "$pub" != "$ver" ]]; then
    echo "error: pubspec version '$pub' does not match DESKTOP_RELEASE_REF '$ref' (want '$ver')." >&2
    exit 1
  fi
  echo "OK: pubspec $pub matches release ref."
else
  line="$(grep -E '^\s*version:\s*' "${DESKTOP}/pubspec.yaml" | head -1)"
  ver="$(echo "$line" | sed -E 's/^\s*version:\s*([^ +]+).*/\1/')"
fi

GIT_SHA="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo "local")"

cd "$DESKTOP"
flutter pub get

export CODE_SIGNING_ALLOWED=NO
export CODE_SIGN_IDENTITY="-"

flutter build macos --release \
  --dart-define=GIT_SHA="$GIT_SHA" \
  --dart-define=AMBI_CHANNEL=stable

APP="${DESKTOP}/build/macos/Build/Products/Release/ambilight_desktop.app"
[[ -d "$APP" ]] || { echo "error: missing $APP after build" >&2; exit 1; }

# Stejně jako desktop_release: zapnutý Finder layout i když máš nastavené CI=1 (test headless chování).
export CREATE_DMG_USE_FINDER_LAYOUT=1

bash "${ROOT}/tools/build_macos_dmg.sh" "$APP" "$OUT" "AmbiLight ${ver}"
echo "Hotovo: $OUT (Flutter + dart-define + create-dmg rozložení jako desktop_release)"
