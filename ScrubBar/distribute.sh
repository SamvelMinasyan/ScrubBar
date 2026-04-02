#!/bin/bash
# Build ScrubBar and create a zip for sharing with friends.

set -e
cd "$(dirname "$0")"

echo "═══════════════════════════════════════════════════════════"
echo "  📦 ScrubBar - Build for Distribution"
echo "═══════════════════════════════════════════════════════════"
echo ""

./build_app.sh || exit 1

echo ""
echo "📦 Creating zip for distribution..."
ZIP_NAME="ScrubBar-macOS.zip"
rm -f "$ZIP_NAME"
ditto -c -k --sequesterRsrc --keepParent ScrubBar.app "$ZIP_NAME"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  ✅ Done!"
echo ""
echo "  File: $(pwd)/$ZIP_NAME"
echo ""
echo "  Send this zip to your friends. They should:"
echo "  1. Unzip and move ScrubBar.app to Applications"
echo "  2. Right-click ScrubBar.app → Open (first time only)"
echo "  3. System Settings → Privacy & Security → Accessibility → Enable ScrubBar"
echo "═══════════════════════════════════════════════════════════"
