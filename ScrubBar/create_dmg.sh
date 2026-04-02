#!/bin/bash
set -e

# Configuration
APP_NAME="ScrubBar"
DMG_NAME="ScrubBar.dmg"
BUILD_SCRIPT="./build_app.sh"
STAGING_DIR="dmg_root"

# Ensure we are in the script's directory
cd "$(dirname "$0")"

echo "═══════════════════════════════════════════════════════════"
echo "  💿 ScrubBar - Creating Disk Image (DMG)"
echo "═══════════════════════════════════════════════════════════"
echo ""

# 1. Build the App
if [ -f "$BUILD_SCRIPT" ]; then
    echo "🔨 Running build script..."
    $BUILD_SCRIPT
else
    echo "❌ Error: Build script '$BUILD_SCRIPT' not found."
    exit 1
fi

# Check if app exists
if [ ! -d "$APP_NAME.app" ]; then
    echo "❌ Error: $APP_NAME.app not found after build."
    exit 1
fi

echo ""
echo "📂 Preparing DMG contents..."

# 2. Prepare Staging Directory
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

# Copy App
cp -R "$APP_NAME.app" "$STAGING_DIR/"

# Create Applications Symlink
ln -s /Applications "$STAGING_DIR/Applications"

# 3. Create DMG
echo "💿 Generating $DMG_NAME..."
rm -f "$DMG_NAME"

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov -format UDZO \
    "$DMG_NAME"

# 4. Cleanup
echo "🧹 Cleaning up..."
rm -rf "$STAGING_DIR"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  ✅ Success!"
echo "  DMG Created: $(pwd)/$DMG_NAME"
echo "═══════════════════════════════════════════════════════════"
