#!/bin/bash

APP_NAME="ScrubBar"
BUILD_DIR=".build/release"

echo "🚀 Building $APP_NAME..."
swift build -c release || exit 1

echo "📦 Creating App Bundle structure..."
rm -rf "$APP_NAME.app"
mkdir -p "$APP_NAME.app/Contents/MacOS"
mkdir -p "$APP_NAME.app/Contents/Resources"

echo "📋 Copying files..."
cp "$BUILD_DIR/$APP_NAME" "$APP_NAME.app/Contents/MacOS/"
cp "$BUILD_DIR/ScrubBarCLI" "$APP_NAME.app/Contents/MacOS/"

# App icon from app_icon.svg (project root: Ipaste/app_icon.svg)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ICON_SVG="$SCRIPT_DIR/../app_icon.svg"
if [ -f "$ICON_SVG" ]; then
    echo "🎨 Building app icon from app_icon.svg..."
    ICONSET="$SCRIPT_DIR/ScrubBar.iconset"
    rm -rf "$ICONSET"
    mkdir -p "$ICONSET"
    (cd "$SCRIPT_DIR" && qlmanage -t -s 1024 -o . "$ICON_SVG" 2>/dev/null)
    if [ -f "$SCRIPT_DIR/app_icon.svg.png" ]; then
    mv "$SCRIPT_DIR/app_icon.svg.png" "$ICONSET/icon_512x512@2x.png" && \
    sips -z 512 512 "$ICONSET/icon_512x512@2x.png" --out "$ICONSET/icon_512x512.png" && \
    sips -z 512 512 "$ICONSET/icon_512x512@2x.png" --out "$ICONSET/icon_256x256@2x.png" && \
    sips -z 256 256 "$ICONSET/icon_256x256@2x.png" --out "$ICONSET/icon_256x256.png" && \
    sips -z 256 256 "$ICONSET/icon_256x256.png" --out "$ICONSET/icon_128x128@2x.png" && \
    sips -z 128 128 "$ICONSET/icon_128x128@2x.png" --out "$ICONSET/icon_128x128.png" && \
    sips -z 32 32 "$ICONSET/icon_128x128.png" --out "$ICONSET/icon_32x32.png" && \
    sips -z 64 64 "$ICONSET/icon_128x128.png" --out "$ICONSET/icon_32x32@2x.png" && \
    sips -z 16 16 "$ICONSET/icon_32x32.png" --out "$ICONSET/icon_16x16.png" && \
    sips -z 32 32 "$ICONSET/icon_32x32.png" --out "$ICONSET/icon_16x16@2x.png" && \
    iconutil -c icns "$ICONSET" -o "$SCRIPT_DIR/ScrubBar.icns" && \
    cp "$SCRIPT_DIR/ScrubBar.icns" "$APP_NAME.app/Contents/Resources/" && \
    rm -rf "$ICONSET" "$SCRIPT_DIR/ScrubBar.icns" && \
    echo "   Icon installed."; else echo "   Icon build skipped (qlmanage/sips/iconutil)."; fi
else
    echo "   No app_icon.svg found at $ICON_SVG, skipping icon."
fi

# Copy Info.plist with Services integration
if [ -f "Info.plist" ]; then
    echo "📋 Copying Info.plist with NSServices configuration..."
    cp "Info.plist" "$APP_NAME.app/Contents/Info.plist"
else
    echo "⚠️  Warning: Info.plist not found, creating minimal version..."
    cat > "$APP_NAME.app/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>ScrubBar</string>
    <key>CFBundleIdentifier</key>
    <string>com.samvelminasyan.ScrubBar</string>
    <key>CFBundleName</key>
    <string>ScrubBar</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSServices</key>
    <array>
        <dict>
            <key>NSMenuItem</key>
            <dict>
                <key>default</key>
                <string>Scrub with ScrubBar</string>
            </dict>
            <key>NSMessage</key>
            <string>handleScrubFile</string>
            <key>NSSendFileTypes</key>
            <array>
                <string>public.item</string>
            </array>
            <key>NSRequiredContext</key>
            <dict>
                <key>NSTextContent</key>
                <array>
                    <string>FilePath</string>
                </array>
            </dict>
        </dict>
    </array>
</dict>
</plist>
EOF
fi

# Create entitlements file
cat > entitlements.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
</dict>
</plist>
EOF

echo "🔐 Ad-hoc Codesigning with entitlements..."
# Use ad-hoc signing (-)
codesign --force --deep --sign - \
    --identifier "com.samvelminasyan.ScrubBar" \
    --entitlements entitlements.plist \
    --timestamp=none \
    --options runtime \
    "$APP_NAME.app" || { echo "❌ Signing failed!"; exit 1; }

# Clean up
rm entitlements.plist

echo "✅ Done! $APP_NAME.app is ready."
echo ""
echo "📌 IMPORTANT: To preserve Accessibility permissions:"
echo "   1. Build ONCE: ./build_app.sh"
echo "   2. Install ONCE: mv ScrubBar.app /Applications/"
echo "   3. Grant permissions in System Settings"
echo "   4. Use ./restart.sh to restart (NOT rebuild!)"
echo ""
echo "⚠️  Only rebuild when you change code!"
