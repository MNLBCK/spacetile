#!/usr/bin/env bash
set -e

# ==============================================================================
# SpaceTile – Release Packaging & Homebrew Cask Generator
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$ROOT_DIR"

# 1. Extract Version from Config.swift
VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    VERSION=$(grep 'static let version' "$ROOT_DIR/Sources/SpaceTile/Config.swift" | head -n1 | sed -E 's/.*"([^"]+)".*/\1/')
fi

if [ -z "$VERSION" ]; then
    echo "❌ Error: Could not detect version from Config.swift"
    exit 1
fi

echo "📦 Packaging SpaceTile v${VERSION}..."

# 2. Build Release Binary
echo "🔨 Compiling release binary with SwiftPM..."
swift build -c release

BUILD_DIR="$(swift build -c release --show-bin-path)"
BUILD_BIN="$BUILD_DIR/spacetile"

if [ ! -f "$BUILD_BIN" ]; then
    echo "❌ Error: Release binary not found at $BUILD_BIN"
    exit 1
fi

# 3. Assemble SpaceTile.app Bundle
BUNDLE_DIR="$ROOT_DIR/build/release_bundle/SpaceTile.app"
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/Contents/MacOS"
mkdir -p "$BUNDLE_DIR/Contents/Resources"

cp "$BUILD_BIN" "$BUNDLE_DIR/Contents/MacOS/spacetile"
chmod 755 "$BUNDLE_DIR/Contents/MacOS/spacetile"

# Copy Icons
if [ -f "$ROOT_DIR/assets/AppIcon.icns" ]; then
    cp "$ROOT_DIR/assets/AppIcon.icns" "$BUNDLE_DIR/Contents/Resources/AppIcon.icns"
fi
if [ -f "$ROOT_DIR/assets/AppIcon.png" ]; then
    cp "$ROOT_DIR/assets/AppIcon.png" "$BUNDLE_DIR/Contents/Resources/AppIcon.png"
fi

# Write Info.plist
cat <<EOF > "$BUNDLE_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>SpaceTile</string>
    <key>CFBundleDisplayName</key>
    <string>SpaceTile</string>
    <key>CFBundleIdentifier</key>
    <string>com.guppi.spacetile</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>spacetile</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>SpaceTile requires Accessibility permissions to tile and arrange windows.</string>
</dict>
</plist>
EOF

echo "APPL????" > "$BUNDLE_DIR/Contents/PkgInfo"

# 4. Sign Bundle with Stable Designated Requirement
echo "🔏 Signing SpaceTile.app with designated requirement 'com.guppi.spacetile'..."
codesign -s - --force --deep --identifier "com.guppi.spacetile" --requirements '=designated => identifier "com.guppi.spacetile"' "$BUNDLE_DIR"

# 5. Create Distribution Zip Archive
DIST_DIR="$ROOT_DIR/dist"
mkdir -p "$DIST_DIR"
ZIP_NAME="SpaceTile-v${VERSION}.zip"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"

echo "🗜️  Compressing into $ZIP_PATH..."
rm -f "$ZIP_PATH"
(cd "$ROOT_DIR/build/release_bundle" && zip -r -y -q "$ZIP_PATH" "SpaceTile.app")

# 6. Calculate SHA256 Checksum
SHA256=$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')
echo "$SHA256" > "$DIST_DIR/${ZIP_NAME}.sha256"

echo "✅ Distribution package created:"
echo "   Archive:  $ZIP_PATH"
echo "   SHA256:   $SHA256"

# 7. Generate Homebrew Cask Formula
CASK_DIR="$ROOT_DIR/Casks"
mkdir -p "$CASK_DIR"
CASK_FILE="$CASK_DIR/spacetile.rb"

cat <<EOF > "$CASK_FILE"
cask "spacetile" do
  version "${VERSION}"
  sha256 "${SHA256}"

  url "https://github.com/MNLBCK/spacetile/releases/download/v#{version}/SpaceTile-v#{version}.zip"
  name "SpaceTile"
  desc "Intelligent on-demand window tiling and optimization for macOS"
  homepage "https://github.com/MNLBCK/spacetile"

  depends_on macos: :ventura

  app "SpaceTile.app"
  binary "#{appdir}/SpaceTile.app/Contents/MacOS/spacetile", target: "spacetile"

  zap trash: [
    "~/.config/spacetile",
    "~/Library/LaunchAgents/com.guppi.spacetile.plist",
    "~/Library/Logs/SpaceTile",
    "~/Library/Caches/com.guppi.spacetile",
  ]
end
EOF

echo "🍺 Homebrew Cask written to: $CASK_FILE"
echo ""
echo "🚀 Next steps for release:"
echo " 1. git push origin main --tags"
echo " 2. gh release create v${VERSION} dist/${ZIP_NAME} dist/${ZIP_NAME}.sha256 --title \"v${VERSION}\" --notes \"SpaceTile Release v${VERSION}\""
echo " 3. Copy Casks/spacetile.rb to homebrew-tap repository (MNLBCK/homebrew-tap)"
