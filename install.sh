#!/usr/bin/env bash
set -e

# ==============================================================================
# SpaceTile – macOS Build & Installation Script
# ==============================================================================

echo "🚀 Building SpaceTile (Release)..."
cd "$(dirname "$0")"

# 1. Compile Release Binary
swift build -c release

# Locate binary deterministically
BUILD_DIR="$(swift build -c release --show-bin-path)"
BUILD_BIN="$BUILD_DIR/spacetile"

if [ -z "$BUILD_BIN" ] || [ ! -f "$BUILD_BIN" ]; then
    echo "❌ Error: Release binary could not be found at $BUILD_BIN."
    exit 1
fi

# 2. Run App Bundle Packaging & Installation
echo "📦 Packaging SpaceTile.app into ~/Applications and configuring daemon..."
"$BUILD_BIN" install

# 3. Check PATH
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo "⚠️  Note: ~/.local/bin is not in your current PATH."
    echo "   Add the following line to your ~/.zshrc:"
    echo '   export PATH="$HOME/.local/bin:$PATH"'
fi

echo ""
echo "=================================================================="
echo "🎉 SpaceTile v1.5.3 is successfully installed!"
echo "=================================================================="
echo " • App Bundle:   ~/Applications/SpaceTile.app"
echo " • CLI Tool:     ~/.local/bin/spacetile"
echo " • LaunchAgent:  ~/Library/LaunchAgents/com.guppi.spacetile.plist"
echo ""
echo "Global Hotkeys:"
echo " • Hyper + Space:   Rearrange windows"
echo " • Hyper + Return:  Set focused window as Master"
echo " • Hyper + L:       Lock/unlock active window position"
echo " • Hyper + F:       Float window always on top (ignored by tiling)"
echo " • Hyper + S:       Open Settings GUI"
echo ""
echo "CLI Commands:"
echo " • spacetile status     Check daemon & accessibility status"
echo " • spacetile gui        Open Settings GUI"
echo " • spacetile optimize   Rearrange current space immediately"
echo " • spacetile restart    Restart the background daemon"
echo "=================================================================="
