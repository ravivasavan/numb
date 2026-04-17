#!/bin/bash
set -euo pipefail

APP_NAME="Numb"
BUILD_DIR="build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"
ICON_SRC="Resources/AppIcon.png"

rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

swiftc -O \
    -target arm64-apple-macos12.0 \
    -framework Cocoa \
    -framework ApplicationServices \
    -o "$MACOS_DIR/$APP_NAME" \
    Sources/*.swift

cp Info.plist "$CONTENTS/Info.plist"

# Build .icns from the 1024×1024 source
ICONSET="$BUILD_DIR/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
for spec in \
    "16 icon_16x16.png" \
    "32 icon_16x16@2x.png" \
    "32 icon_32x32.png" \
    "64 icon_32x32@2x.png" \
    "128 icon_128x128.png" \
    "256 icon_128x128@2x.png" \
    "256 icon_256x256.png" \
    "512 icon_256x256@2x.png" \
    "512 icon_512x512.png" \
    "1024 icon_512x512@2x.png"
do
    set -- $spec
    sips -z "$1" "$1" "$ICON_SRC" --out "$ICONSET/$2" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$RESOURCES_DIR/AppIcon.icns"
rm -rf "$ICONSET"

# Ad-hoc sign so Accessibility can consistently identify the bundle
codesign --force --deep --sign - "$APP_DIR"

# Nudge Finder/Dock to pick up the icon on rebuilds
touch "$APP_DIR"

echo ""
echo "✓ built $APP_DIR"
echo ""
echo "next steps:"
echo "  1. open $APP_DIR   (first launch will prompt for Accessibility access)"
echo "  2. grant access in System Settings → Privacy & Security → Accessibility"
echo "  3. relaunch Numb — keyboard locks instantly; ⌘ ⌥ K to unlock"
