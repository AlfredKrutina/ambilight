#!/usr/bin/env bash
# Flutter's macOS xcodebuild invocation does not pass -allowProvisioningUpdates (unlike iOS).
# First-time error: "No profiles for '…' were found … pass -allowProvisioningUpdates to xcodebuild".
# Run this once (with Xcode logged in under Settings → Accounts), then `flutter run -d macos`.
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
MACOS_DIR="$ROOT/macos"
DD="$ROOT/build/macos_provision_derived_data"
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
  DEST_DEBUG="platform=macOS,arch=arm64"
else
  DEST_DEBUG="platform=macOS,arch=x86_64"
fi
DEST_RELEASE="generic/platform=macOS"

LOCAL_SIGNING="$MACOS_DIR/Runner/Configs/LocalSigning.xcconfig"
echo "Workspace: $MACOS_DIR/Runner.xcworkspace"
echo "DerivedData: $DD"

if [[ ! -f "$LOCAL_SIGNING" ]]; then
  echo "Chybí $LOCAL_SIGNING — zkopíruj LocalSigning.xcconfig.example a nastav DEVELOPMENT_TEAM." >&2
  exit 1
fi
if grep -qE 'YOUR_TEAM_ID_HERE|__EDIT_ME__|REPLACE_WITH|NOTHING_HERE' "$LOCAL_SIGNING"; then
  echo "V LocalSigning.xcconfig je stále zástupný text místo skutečného DEVELOPMENT_TEAM (10 znaků z Xcode)." >&2
  echo "Otevři soubor a oprav řádek DEVELOPMENT_TEAM = …" >&2
  exit 1
fi

run_build() {
  local config="$1"
  local dest="$2"
  echo ""
  echo "=== xcodebuild $config (destination: $dest) -allowProvisioningUpdates ==="
  xcrun xcodebuild \
    -workspace "$MACOS_DIR/Runner.xcworkspace" \
    -scheme Runner \
    -configuration "$config" \
    -destination "$dest" \
    -derivedDataPath "$DD" \
    -allowProvisioningUpdates \
    build
}

run_build Debug "$DEST_DEBUG"
run_build Release "$DEST_RELEASE"
echo ""
echo "Provisioning step finished. Next: cd \"$ROOT\" && flutter run -d macos"
