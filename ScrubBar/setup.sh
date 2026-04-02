#!/bin/bash

echo "═══════════════════════════════════════════════════════════"
echo "  🔧 ScrubBar - One-Time Setup"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Build the app with simple ad-hoc signing
echo "Step 1: Building app..."
./build_app.sh || { echo "❌ Build failed"; exit 1; }
echo ""

# Install to /Applications
echo "Step 2: Installing to /Applications..."
rm -rf /Applications/ScrubBar.app
mv ScrubBar.app /Applications/
echo "✅ Installed!"
echo ""

# Grant permissions
echo "Step 3: Permission Setup"
echo ""
echo "🚨 ACTION REQUIRED:"
echo "   1. Open System Settings -> Privacy & Security -> Accessibility"
echo "   2. Remove any old 'ScrubBar' entries (-)"
echo "   3. Add the new '/Applications/ScrubBar.app' (+)"
echo ""
read -p "Press ENTER once you've done this..."

# Launch the app
echo ""
echo "Step 4: Launching..."
open /Applications/ScrubBar.app

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  ✅ Done!"
echo "  📌 Use './restart.sh' to restart the app later."
echo "═══════════════════════════════════════════════════════════"
