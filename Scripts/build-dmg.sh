#!/usr/bin/env bash
# Builds a release DMG of Mouse Smooth.
#
# Three-step dance, because Xcode's in-build codesign fails when source
# files carry the `com.apple.provenance` xattr (added automatically on
# macOS 14+ when files live under ~/Desktop, ~/Documents, etc.):
#
#   1. Build Release with codesign disabled.
#   2. Strip xattrs from the built .app — `codesign` refuses to sign over
#      "resource fork, Finder information, or similar detritus".
#   3. Sign the bundle ad-hoc with --deep --force so Info.plist + Resources
#      are sealed. Without this seal Gatekeeper rejects the download as
#      "damaged" on macOS Sonoma / Sequoia.
#
# Usage: ./Scripts/build-dmg.sh [version]
#   version defaults to MARKETING_VERSION from project.yml.

set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-$(awk -F'"' '/MARKETING_VERSION/ {print $2; exit}' project.yml)}"
if [[ -z "${VERSION}" ]]; then
  echo "Could not infer version. Pass it explicitly: ./Scripts/build-dmg.sh 0.1.2" >&2
  exit 1
fi

APP="build/Build/Products/Release/Mouse Smooth.app"
DMG="dist/MouseSmooth-v${VERSION}.dmg"

mkdir -p dist

echo "==> Regenerating Xcode project"
rm -rf MouseSmooth.xcodeproj
xcodegen generate >/dev/null

echo "==> Building Release (signing disabled)"
rm -rf build/Build
xcodebuild \
  -project MouseSmooth.xcodeproj \
  -scheme MouseSmooth \
  -configuration Release \
  -derivedDataPath ./build \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build >/dev/null

echo "==> Stripping extended attributes from .app"
xattr -cr "$APP"

echo "==> Signing bundle ad-hoc (deep, force)"
codesign --force --deep --sign - --timestamp=none "$APP"

echo "==> Verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP"
codesign -dv "$APP" 2>&1 | grep -E 'Info.plist|Sealed Resources|Signature'

echo "==> Building DMG"
rm -f "$DMG"
create-dmg \
  --volname "Mouse Smooth" \
  --window-size 540 380 \
  --icon-size 128 \
  --icon "Mouse Smooth.app" 140 190 \
  --app-drop-link 400 190 \
  --no-internet-enable \
  "$DMG" \
  "$APP" >/dev/null

echo
echo "Done: $DMG"
ls -lh "$DMG"
