#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$DIR/dist"
APP_NAME="LazyType"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
DMG_NAME="LazyType-1.0.0.dmg"
FINAL_DMG="$DIST_DIR/$DMG_NAME"
TEMP_DMG="$DIST_DIR/pack.temp.dmg"
STAGING_DIR="$DIST_DIR/dmg-staging"

echo "============================================================"
echo "   Building Direct Native macOS DMG Installer: $DMG_NAME"
echo "============================================================"

# 1. Package the latest universal app bundle
echo "==> Packaging Universal 2 $APP_NAME.app..."
"$DIR/scripts/package-app.sh"

if [ ! -d "$APP_BUNDLE" ]; then
    echo "ERROR: App bundle not found at $APP_BUNDLE"
    exit 1
fi

# 2. Prepare clean staging directory with ONLY App and Applications symlink
echo "==> Preparing clean, direct staging layout..."
rm -rf "$STAGING_DIR" "$TEMP_DMG" "$FINAL_DMG"
mkdir -p "$STAGING_DIR"

# Copy App Bundle
echo "  -> Copying $APP_NAME.app..."
cp -R "$APP_BUNDLE" "$STAGING_DIR/"

# Create standard Applications symlink
echo "  -> Creating /Applications symlink..."
ln -s /Applications "$STAGING_DIR/Applications"

# Set up hidden background image
mkdir -p "$STAGING_DIR/.background"
if [ -f "$DIST_DIR/dmg-background.png" ]; then
    cp "$DIST_DIR/dmg-background.png" "$STAGING_DIR/.background/dmg-background.png"
fi

# Set custom volume icon
if [ -f "$DIST_DIR/AppIcon.icns" ]; then
    cp "$DIST_DIR/AppIcon.icns" "$STAGING_DIR/.VolumeIcon.icns"
    if command -v SetFile &> /dev/null; then
        SetFile -a C "$STAGING_DIR" 2>/dev/null || true
    fi
fi

# 3. Create temporary writable DMG to configure Finder presentation
echo "==> Creating temporary DMG container..."
hdiutil create \
    -srcfolder "$STAGING_DIR" \
    -volname "LazyType Installer" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -ov \
    "$TEMP_DMG"

# Clean staging dir
rm -rf "$STAGING_DIR"

# 4. Mount temp DMG and apply AppleScript layout for native drag-and-drop
echo "==> Mounting temp DMG to configure Finder layout..."
MOUNT_DIR=$(hdiutil attach "$TEMP_DMG" -nobrowse -noverify -noautoopen | grep -o '/Volumes/.*' | head -n 1)

if [ -n "$MOUNT_DIR" ] && [ -d "$MOUNT_DIR" ]; then
    echo "  -> Mounted at $MOUNT_DIR. Applying Finder window view options..."
    
    osascript << APPLESCRIPT || true
tell application "Finder"
    tell disk "LazyType Installer"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 150, 800, 550}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 128
        try
            set background picture of theViewOptions to file ".background:dmg-background.png"
        end try
        set position of item "LazyType.app" of container window to {150, 195}
        set position of item "Applications" of container window to {450, 195}
        update without registering applications
        delay 1
        close
    end tell
end tell
APPLESCRIPT

    # Hide background folder and volume icon
    if command -v SetFile &> /dev/null; then
        SetFile -a V "$MOUNT_DIR/.background" 2>/dev/null || true
        SetFile -a V "$MOUNT_DIR/.VolumeIcon.icns" 2>/dev/null || true
        SetFile -a C "$MOUNT_DIR" 2>/dev/null || true
    fi
    
    sync
    sleep 1
    echo "  -> Detaching volume..."
    hdiutil detach "$MOUNT_DIR" -force
else
    echo "WARNING: Could not attach for Finder layout scripting, continuing with standard create..."
fi

# 5. Compress to final read-only production DMG
echo "==> Compressing into final production DMG ($DMG_NAME)..."
hdiutil convert \
    "$TEMP_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$FINAL_DMG"

rm -f "$TEMP_DMG"

# 6. Verify DMG contents
echo "==> Verifying final DMG contents..."
VERIFY_MOUNT=$(hdiutil attach "$FINAL_DMG" -nobrowse -readonly | grep -o '/Volumes/.*' | head -n 1)
if [ -n "$VERIFY_MOUNT" ] && [ -d "$VERIFY_MOUNT" ]; then
    echo "Contents of $VERIFY_MOUNT:"
    ls -la "$VERIFY_MOUNT"
    hdiutil detach "$VERIFY_MOUNT" -force
fi

echo "============================================================"
echo "  ✓ Successfully built Direct Drag-and-Drop DMG: $FINAL_DMG"
ls -lh "$FINAL_DMG"
echo "============================================================"
