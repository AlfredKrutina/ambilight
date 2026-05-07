#!/usr/bin/env bash
# Lokální podepsané DMG (Release + hardened runtime + podpis DMG).
#
# Bez placeného Apple Developer účtu máš jen „Apple Development“ — DMG jde předat,
# ale na jiném Macu často: Pravý klik → Otevřít (Gatekeeper). Notarizace vyžaduje typicky Developer ID.
#
# Příprava:
#   1) LocalSigning.xcconfig — DEVELOPMENT_TEAM
#   2) DistributionSigning.xcconfig — viz DistributionSigning.xcconfig.example (Apple Development nebo Developer ID)
#   3) Notarizace jen s Developer ID a profilem v Klíčence:
#        NOTARY_KEYCHAIN_PROFILE=ambi-notary bash tools/local_build_macos_distribution_dmg.sh
#
# Seznam identit:  security find-identity -v -p codesigning
#
# Volitelně:
#   OUT=/cesta/out.dmg
#   MACOS_CODESIGN_IDENTITY="Apple Development: …"  — jen podpis DMG (nepředává se do Xcode)
#   SKIP_NOTARY=1  — bez notarytool
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESKTOP="${ROOT}/ambilight_desktop"
DIST_CFG="${DESKTOP}/macos/Runner/Configs/DistributionSigning.xcconfig"
OUT="${OUT:-${ROOT}/ambilight_desktop_macos_distribution.dmg}"

export PATH="/opt/homebrew/bin:/usr/local/bin:${PATH}"

command -v flutter >/dev/null 2>&1 || { echo "error: flutter not on PATH" >&2; exit 1; }

_has_brew_create_dmg() {
  local p bp
  bp="$(brew --prefix 2>/dev/null || true)"
  [[ -n "$bp" && -x "$bp/bin/create-dmg" ]] && return 0
  [[ -x /opt/homebrew/bin/create-dmg ]] && return 0
  [[ -x /usr/local/bin/create-dmg ]] && return 0
  return 1
}

if ! _has_brew_create_dmg; then
  echo "error: brew install create-dmg — potřeba pro rozložení DMG." >&2
  exit 1
fi

if [[ -z "${MACOS_CODESIGN_IDENTITY:-}" ]] && [[ ! -f "$DIST_CFG" ]]; then
  echo "" >&2
  echo "error: Chybí podpis pro distribuci." >&2
  echo "       Buď vytvoř ${DIST_CFG} ze souboru DistributionSigning.xcconfig.example," >&2
  echo "       nebo nastav MACOS_CODESIGN_IDENTITY=\"Apple Development: …\" (viz security find-identity)." >&2
  echo "" >&2
  exit 1
fi

# Nepřepisuj CODE_SIGN_IDENTITY před flutter build — Runner má Automatic signing;
# celý řetězec certifikátu („Apple Development: e‑mail …“) Xcode odmítne.
# MACOS_CODESIGN_IDENTITY použij jen jako výslovný podpis DMG (volitelné).

# Xcode/codesign předá při buildu .app (notář vyžaduje hardened runtime).
export ENABLE_HARDENED_RUNTIME=YES
export CODE_SIGNING_ALLOWED=YES

line="$(grep -E '^\s*version:\s*' "${DESKTOP}/pubspec.yaml" | head -1)"
ver="$(echo "$line" | sed -E 's/^\s*version:\s*([^ +]+).*/\1/')"
GIT_SHA="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo "local")"

_first_codesign_identity_matching() {
  local needle="$1"
  security find-identity -v -p codesigning 2>/dev/null \
    | awk -F'"' -v n="$needle" '$0 ~ n { print $2; exit }'
}

_resolve_codesign_identity() {
  if [[ -n "${MACOS_CODESIGN_IDENTITY:-}" ]]; then
    echo "$MACOS_CODESIGN_IDENTITY"
    return 0
  fi
  if [[ -f "$DIST_CFG" ]]; then
    local id
    id="$(grep -E '^[[:space:]]*CODE_SIGN_IDENTITY[[:space:]]*=' "$DIST_CFG" 2>/dev/null | head -1 \
      | sed -E 's/^[[:space:]]*CODE_SIGN_IDENTITY[[:space:]]*=[[:space:]]*//; s/^"//; s/"[[:space:]]*$//' || true)"
    if [[ -n "$id" ]]; then
      echo "$id"
      return 0
    fi
  fi
  local fb
  fb="$(_first_codesign_identity_matching 'Developer ID Application')"
  if [[ -n "$fb" ]]; then
    echo "$fb"
    return 0
  fi
  fb="$(_first_codesign_identity_matching 'Apple Development')"
  if [[ -n "$fb" ]]; then
    echo "$fb"
    return 0
  fi
  return 1
}

IDENTITY="$(_resolve_codesign_identity || true)"
[[ -n "$IDENTITY" ]] || { echo "error: nelze zjistit CODE_SIGN_IDENTITY" >&2; exit 1; }

if [[ "$IDENTITY" != Developer\ ID\ Application:* ]]; then
  echo "" >&2
  echo "→ Používáš ne-Distributor identitu (např. Apple Development). DMG je podepsané, ale na jiném Macu často:" >&2
  echo "   Pravý klik na aplikaci → Otevřít. Bez placeného účtu + Developer ID nelze spolehnout na notarizaci." >&2
  echo "" >&2
fi

if [[ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]] && [[ "$IDENTITY" == *"Apple Development"* ]]; then
  echo "error: NOTARY_KEYCHAIN_PROFILE je nastavený, ale máš Apple Development — notarizace typicky vyžaduje Developer ID (placený program)." >&2
  echo "       Spusť bez profilu (jen podepsané DMG) nebo:  SKIP_NOTARY=1" >&2
  exit 1
fi

cd "$DESKTOP"
flutter pub get

flutter build macos --release \
  --dart-define=GIT_SHA="$GIT_SHA" \
  --dart-define=AMBI_CHANNEL=stable

APP="${DESKTOP}/build/macos/Build/Products/Release/ambilight_desktop.app"
[[ -d "$APP" ]] || { echo "error: missing $APP" >&2; exit 1; }

echo "→ Kontrola podpisu .app …" >&2
codesign --verify --deep --strict --verbose=2 "$APP"

export CREATE_DMG_USE_FINDER_LAYOUT=1
export CREATE_DMG_BIN="${CREATE_DMG_BIN:-$(brew --prefix)/bin/create-dmg}"
rm -f "$OUT"
bash "${ROOT}/tools/build_macos_dmg.sh" "$APP" "$OUT" "AmbiLight ${ver}"

echo "→ Podpis DMG …" >&2
codesign --sign "$IDENTITY" --timestamp --force "$OUT"
codesign --verify --verbose=2 "$OUT"

if [[ "${SKIP_NOTARY:-}" == "1" ]]; then
  echo "SKIP_NOTARY=1 — přeskakuji notarizaci. DMG je podepsaný, ale na jiném Macu může Gatekeeper hlásit blokaci." >&2
  echo "Hotovo: $OUT" >&2
  exit 0
fi

if [[ -z "${NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
  echo "" >&2
  echo "Hotovo (bez notarizace): $OUT" >&2
  if [[ "$IDENTITY" == Developer\ ID\ Application:* ]]; then
    echo "Pro staple + přívětivý Gatekeeper: Developer ID + NOTARY_KEYCHAIN_PROFILE (viz příklad v DistributionSigning.xcconfig.example)." >&2
  fi
  echo "" >&2
  exit 0
fi

echo "→ Notarizace (může trvat několik minut) …" >&2
xcrun notarytool submit "$OUT" --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" --wait
xcrun stapler staple "$OUT"
echo "→ Staple OK. Kontrola Gatekeeperu (install):" >&2
spctl -a -vv -t install "$OUT" 2>&1 || true

echo "Hotovo: $OUT (notarized + stapled)"
