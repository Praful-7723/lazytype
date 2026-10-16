#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$DIR/dist"
APP_NAME="LazyType"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "==> Building fresh LazyType binary..."
"$DIR/scripts/build-mac.sh"

echo "==> Creating macOS App Bundle at $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS" "$RESOURCES"

# Copy binary
cp "$DIR/bin/LazyTypeCompanion" "$MACOS/$APP_NAME"
chmod +x "$MACOS/$APP_NAME"

# Copy web assets into Resources for standalone app distribution
mkdir -p "$RESOURCES/phone" "$RESOURCES/demo"
cp -R "$DIR/phone/public" "$RESOURCES/phone/"
cp -R "$DIR/demo/demo.html" "$RESOURCES/demo/"

# Copy icons
if [ -f "$DIR/dist/AppIcon.icns" ]; then
    cp "$DIR/dist/AppIcon.icns" "$RESOURCES/AppIcon.icns"
fi

# Create Info.plist with LSUIElement (Menu Bar Accessory)
cat << 'PLIST' > "$CONTENTS/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>LazyType</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.lazytype.companion</string>
    <key>CFBundleName</key>
    <string>LazyType</string>
    <key>CFBundleDisplayName</key>
    <string>LazyType Companion</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 LazyType. All rights reserved.</string>
</dict>
</plist>
PLIST

echo "==> App bundle successfully created at $APP_BUNDLE"
ls -ld "$APP_BUNDLE"
