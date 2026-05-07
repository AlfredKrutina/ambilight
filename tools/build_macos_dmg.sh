#!/usr/bin/env bash
# DMG pro macOS: preferuje create-dmg (ikonové rozložení + alias Applications pro přetahování).
# Fallback bez brew: hdiutil + symlink Applications → stejná funkce, bez „prof“ rozvržení oken.
# Použití: build_macos_dmg.sh <cesta/k/App.app> <výstupní.dmg> [název_svazku]
set -euo pipefail

app="${1:?usage: $0 <App.app> <out.dmg> [volume_name]}"
out="${2:?}"
volname="${3:-AmbiLight}"

[[ -d "$app" ]] || { echo "error: not a directory: $app" >&2; exit 1; }

app_name="$(basename "$app")"
staging="$(mktemp -d "${TMPDIR:-/tmp}/ambi-dmg-staging.XXXXXX")"
cleanup() { rm -rf "$staging"; }
trap cleanup EXIT

# Absolutní cíl + adresář výstupu
if [[ "$out" == /* ]]; then
  out_abs="$out"
else
  out_abs="$(pwd)/$out"
fi
mkdir -p "$(dirname "$out_abs")"
rm -f "$out_abs"

# Jen .app ve zdrojové složce — create-dmg přidává Applications samostatně přes --app-drop-link
ditto "$app" "$staging/$app_name"
xattr -cr "$staging/$app_name" 2>/dev/null || true

if command -v create-dmg >/dev/null 2>&1; then
  ci_flags=()
  # GitHub Actions / headless: bez kosmetického AppleScriptu (Finder), DMG + alias Applications stejně vznikne
  if [[ -n "${GITHUB_ACTIONS:-}" || -n "${CI:-}" ]]; then
    ci_flags+=(--skip-jenkins)
  fi
  create-dmg \
    "${ci_flags[@]}" \
    --volname "$volname" \
    --window-pos 200 120 \
    --window-size 660 400 \
    --icon-size 88 \
    --icon "$app_name" 168 205 \
    --hide-extension "$app_name" \
    --app-drop-link 448 205 \
    --format UDZO \
    "$out_abs" \
    "$staging"
else
  echo "tip: brew install create-dmg — lepší rozvržení ikon v okně Finderu; používám hdiutil + Applications." >&2
  ln -sf /Applications "$staging/Applications"
  hdiutil create -volname "$volname" -srcfolder "$staging" -ov -format UDZO "$out_abs"
fi

echo "DMG OK: $out_abs"
