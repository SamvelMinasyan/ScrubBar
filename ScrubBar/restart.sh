#!/bin/bash
# Restart ScrubBar without rebuilding (preserves permissions)

echo "🔄 Restarting ScrubBar..."
killall ScrubBar 2>/dev/null
sleep 0.5
open /Applications/ScrubBar.app
echo "✅ ScrubBar restarted!"
