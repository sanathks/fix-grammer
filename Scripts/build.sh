#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="Rewrite"
BUILD_DIR="$PROJECT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

ARCH_FLAGS=""
for arch in "$@"; do
    ARCH_FLAGS="$ARCH_FLAGS --arch $arch"
done

echo "Building $APP_NAME..."
cd "$PROJECT_DIR"
swift build -c release $ARCH_FLAGS

echo "Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

if [ $# -gt 0 ]; then
    # Multi-arch build: binary is under apple/Products
    cp "$PROJECT_DIR/.build/apple/Products/Release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
else
    cp "$PROJECT_DIR/.build/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
fi
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$PROJECT_DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
cp "$PROJECT_DIR/Resources/icon.png" "$APP_BUNDLE/Contents/Resources/icon.png"
echo "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

echo "App bundle created: $APP_BUNDLE"

# Determine DMG filename based on architecture
if [ $# -eq 1 ]; then
    case "$1" in
        arm64) DMG_SUFFIX="-apple-silicon" ;;
        x86_64) DMG_SUFFIX="-intel" ;;
        *) DMG_SUFFIX="-$1" ;;
    esac
else
    DMG_SUFFIX=""
fi

# Create DMG
DMG_PATH="$BUILD_DIR/${APP_NAME}${DMG_SUFFIX}.dmg"
DMG_TEMP="$BUILD_DIR/dmg_staging"
rm -rf "$DMG_TEMP" "$DMG_PATH"
mkdir -p "$DMG_TEMP"
cp -R "$APP_BUNDLE" "$DMG_TEMP/"
ln -s /Applications "$DMG_TEMP/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_TEMP" -ov -format UDZO "$DMG_PATH"
rm -rf "$DMG_TEMP"

echo "Build complete: $DMG_PATH"
