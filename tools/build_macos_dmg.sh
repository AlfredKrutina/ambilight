#!/usr/bin/env bash
# Profesionální DMG pro macOS (CI i lokálně):
# - create-dmg: alias Applications (--app-drop-link), schovaná přípona .app, APFS, UDZO,
#   větší okno ikon; pozadí tools/dmg_assets/dmg_background.png (1440×880 @2× k oknu 720×440) —
#   šipka + „Drag to Applications“ mezi ikonami .app a zástupce Applications.
# - AppleScript (rozvržení Finderu): bez něj create-dmg neumístí ikony ani pozadí okna (viz --skip-jenkins).
#   Na CI se --skip-jenkins použije jen když je CI/GITHUB_ACTIONS a chybí CREATE_DMG_USE_FINDER_LAYOUT=1
#   (desktop_release mac job exportuje …=1). Lokálně stejný DMG jako na webu: tools/local_build_macos_release_dmg.sh
# - Fallback bez brew create-dmg: hdiutil + ditto + symlink Applications + APFS + UDZO.
#
# Použití: build_macos_dmg.sh <cesta/k/App.app> <výstupní.dmg> [název_svazku]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKGROUND="${SCRIPT_DIR}/dmg_assets/dmg_background.png"

app="${1:?usage: $0 <App.app> <out.dmg> [volume_name]}"
out="${2:?}"
volname="${3:-AmbiLight}"

[[ -d "$app" ]] || { echo "error: not a directory: $app" >&2; exit 1; }

app_name="$(basename "$app")"
staging="$(mktemp -d "${TMPDIR:-/tmp}/ambi-dmg-staging.XXXXXX")"
cleanup() { rm -rf "$staging"; }
trap cleanup EXIT

if [[ "$out" == /* ]]; then
  out_abs="$out"
else
  out_abs="$(pwd)/$out"
fi
mkdir -p "$(dirname "$out_abs")"
rm -f "$out_abs"

ditto "$app" "$staging/$app_name"
xattr -cr "$staging/$app_name" 2>/dev/null || true

bg_args=()
if [[ -f "$BACKGROUND" ]]; then
  bg_args+=(--background "$BACKGROUND")
else
  echo "tip: pro pozadí okna přidej ${BACKGROUND} (volitelné)." >&2
fi

# Cursor/minimální PATH často nemá brew binárku — obnov stejně jako local_build / CI.
export PATH="/opt/homebrew/bin:/usr/local/bin:${PATH}"

_create_dmg_bin() {
  if command -v create-dmg >/dev/null 2>&1; then
    command -v create-dmg
    return 0
  fi
  local x
  for x in /opt/homebrew/bin/create-dmg /usr/local/bin/create-dmg; do
    if [[ -x "$x" ]]; then
      echo "$x"
      return 0
    fi
  done
  return 1
}

if _dmg_cmd="$(_create_dmg_bin)"; then
  ci_flags=()
  # Bez AppleScriptu se ignoruje --window-size, --icon, --app-drop-link i pozadí okna.
  if [[ -n "${GITHUB_ACTIONS:-}" || -n "${CI:-}" ]] && [[ "${CREATE_DMG_USE_FINDER_LAYOUT:-}" != "1" ]]; then
    ci_flags+=(--skip-jenkins)
  fi
  # Souřadnice = Finder AppleScript „position“ od levého horního rohu obsahu okna (body ~okna 720×440).
  # Pozadí má šipku zleva doprava a text dole — ikony držíme v dolní polovině (vyšší Y = níž), .app vlevo u začátku šipky,
  # Applications vpravo u hrotu (create-dmg příklady často ~185–205 / ~520–600 na šířce ~660–720).
  _dmg_win_w=720
  _dmg_win_h=440
  _dmg_icon_size=116
  # Nižší řádek (nad textem „Drag to Applications“ na pozadí); Applications výrazně vpravo u hrotu šipky.
  _dmg_icon_y=312
  _dmg_app_x=165
  _dmg_apps_x=585
  # Při set -u a prázdném poli způsobí "${arr[@]}" na některých bashích chybu „unbound variable“.
  "$_dmg_cmd" \
    ${ci_flags[@]+"${ci_flags[@]}"} \
    ${bg_args[@]+"${bg_args[@]}"} \
    --volname "$volname" \
    --filesystem APFS \
    --window-pos 200 120 \
    --window-size "$_dmg_win_w" "$_dmg_win_h" \
    --icon-size "$_dmg_icon_size" \
    --text-size 14 \
    --icon "$app_name" "$_dmg_app_x" "$_dmg_icon_y" \
    --hide-extension "$app_name" \
    --app-drop-link "$_dmg_apps_x" "$_dmg_icon_y" \
    --format UDZO \
    "$out_abs" \
    "$staging"
else
  echo "" >&2
  echo "VAROVÁNÍ: create-dmg není k dispozici — DMG vznikne jen jako složka + symlink Applications." >&2
  echo "         Chybí pozadí se šipkou, velikost okna a pozice ikon (není to stejné jako na webu / CI)." >&2
  echo "         Řešení: brew install create-dmg   nebo spusť tools/local_build_macos_release_dmg.sh" >&2
  echo "" >&2
  if [[ -f "$BACKGROUND" ]]; then
    mkdir -p "$staging/.background"
    ditto "$BACKGROUND" "$staging/.background/dmg_background.png"
  fi
  ln -sf /Applications "$staging/Applications"
  hdiutil create \
    -volname "$volname" \
    -fs APFS \
    -srcfolder "$staging" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$out_abs"
fi

echo "DMG OK: $out_abs"
