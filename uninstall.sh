#!/usr/bin/env bash
set -e

# ==============================================================================
# SpaceTile – macOS Uninstallation Script
# ==============================================================================

echo "🗑️ Uninstalling SpaceTile..."

if [ -f "$HOME/.local/bin/spacetile" ]; then
    "$HOME/.local/bin/spacetile" uninstall 2>/dev/null || true
fi

# Clean up any leftover artifacts
rm -rf "$HOME/Applications/SpaceTile.app"
rm -f "$HOME/.local/bin/spacetile"
rm -f "$HOME/Library/LaunchAgents/com.guppi.spacetile.plist"

echo "✅ SpaceTile has been completely removed from your system."
