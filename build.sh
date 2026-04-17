#!/bin/bash
set -euo pipefail

APP_NAME="NUMB"
BUILD_DIR="build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

swiftc -O \
    -target arm64-apple-macos12.0 \
    -framework Cocoa \
    -framework ApplicationServices \
    -o "$MACOS_DIR/$APP_NAME" \
    Sources/main.swift

cp Info.plist "$CONTENTS/Info.plist"

# Ad-hoc sign so Accessibility can consistently identify the bundle
codesign --force --deep --sign - "$APP_DIR"

echo ""
echo "✓ built $APP_DIR"
echo ""
echo "next steps:"
echo "  1. open $APP_DIR   (first launch will prompt for Accessibility access)"
echo "  2. grant access in System Settings → Privacy & Security → Accessibility"
echo "  3. relaunch NUMB — keyboard locks instantly; ⌘ ⌥ E to unlock"
