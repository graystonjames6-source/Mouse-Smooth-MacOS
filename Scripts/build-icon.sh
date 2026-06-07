#!/usr/bin/env bash
# Builds Resources/AppIcon.icns from the master PNG produced by make-icon.swift.
# Run from the repo root: ./Scripts/build-icon.sh
set -euo pipefail

cd "$(dirname "$0")/.."

WORK_DIR="build/icon"
ICONSET="$WORK_DIR/AppIcon.iconset"
MASTER="$WORK_DIR/icon-1024.png"
OUT="Resources/AppIcon.icns"

mkdir -p "$ICONSET" "Resources"

# 1. Render the master 1024×1024.
swift Scripts/make-icon.swift "$MASTER"

# 2. Downsample to every size macOS expects in a .iconset.
#    The @2x variants share pixels with the next size up — same image, different filename.
sips -z   16   16 "$MASTER" --out "$ICONSET/icon_16x16.png"      >/dev/null
sips -z   32   32 "$MASTER" --out "$ICONSET/icon_16x16@2x.png"   >/dev/null
sips -z   32   32 "$MASTER" --out "$ICONSET/icon_32x32.png"      >/dev/null
sips -z   64   64 "$MASTER" --out "$ICONSET/icon_32x32@2x.png"   >/dev/null
sips -z  128  128 "$MASTER" --out "$ICONSET/icon_128x128.png"    >/dev/null
sips -z  256  256 "$MASTER" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z  256  256 "$MASTER" --out "$ICONSET/icon_256x256.png"    >/dev/null
sips -z  512  512 "$MASTER" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z  512  512 "$MASTER" --out "$ICONSET/icon_512x512.png"    >/dev/null
cp "$MASTER" "$ICONSET/icon_512x512@2x.png"

# 3. Bundle.
iconutil --convert icns "$ICONSET" --output "$OUT"
echo "Wrote $OUT"
