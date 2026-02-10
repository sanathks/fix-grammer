#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="Rewrite"
BUILD_DIR="$PROJECT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
INSTALL_DIR="$HOME/Applications"

if [ ! -d "$APP_BUNDLE" ]; then
    echo "Error: $APP_BUNDLE not found. Run build.sh first."
    exit 1
fi

echo "Installing $APP_NAME..."
mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALL_DIR/$APP_NAME.app"
cp -R "$APP_BUNDLE" "$INSTALL_DIR/$APP_NAME.app"

echo "Registering services..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$INSTALL_DIR/$APP_NAME.app"

echo ""
echo "Installed to $INSTALL_DIR/$APP_NAME.app"
echo ""
echo "To activate the services, you may need to:"
echo "  1. Log out and log back in, OR"
echo "  2. Restart any apps where you want to use the services"
echo ""
echo "Usage: Select text anywhere and use keyboard shortcuts to rewrite"
