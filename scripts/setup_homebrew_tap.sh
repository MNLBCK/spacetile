#!/usr/bin/env bash
set -e

# ==============================================================================
# SpaceTile – Homebrew Tap Repository Setup Script
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

TAP_NAME="homebrew-tap"
ORG_OR_USER="${1:-MNLBCK}"
TAP_REPO="${ORG_OR_USER}/${TAP_NAME}"

echo "🍺 Setting up Homebrew Tap: $TAP_REPO..."

if ! command -v gh &> /dev/null; then
    echo "❌ Error: GitHub CLI ('gh') is required but not installed."
    echo "   Install it with: brew install gh"
    exit 1
fi

if ! gh auth status &> /dev/null; then
    echo "❌ Error: Not logged in to GitHub via 'gh'."
    echo "   Log in with: gh auth login"
    exit 1
fi

CASK_SOURCE="$ROOT_DIR/Casks/spacetile.rb"
if [ ! -f "$CASK_SOURCE" ]; then
    echo "⚠️  Cask not found at $CASK_SOURCE. Generating it now..."
    "$SCRIPT_DIR/package_release.sh"
fi

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

echo "🔍 Checking if repository $TAP_REPO exists on GitHub..."
if ! gh repo view "$TAP_REPO" &> /dev/null; then
    echo "📦 Creating new public repository $TAP_REPO..."
    gh repo create "$TAP_REPO" --public --description "Homebrew Tap for SpaceTile and macOS tools by @${ORG_OR_USER}"
fi

echo "📥 Cloning $TAP_REPO into temporary workspace..."
git clone "https://github.com/${TAP_REPO}.git" "$TMP_DIR/$TAP_NAME"

cd "$TMP_DIR/$TAP_NAME"
mkdir -p Casks
cp "$CASK_SOURCE" Casks/spacetile.rb

# Create a clean README if missing
if [ ! -f "README.md" ]; then
    cat <<EOF > README.md
# Homebrew Tap for SpaceTile 🍺

Official Homebrew Tap by [@${ORG_OR_USER}](https://github.com/${ORG_OR_USER}).

## Installation

\`\`\`bash
brew tap ${ORG_OR_USER}/tap
brew install --cask spacetile
\`\`\`

## Updating

\`\`\`bash
brew update
brew upgrade --cask spacetile
\`\`\`
EOF
fi

git add Casks/spacetile.rb README.md
if git diff --staged --quiet; then
    echo "✨ Tap is already up to date with the latest Cask."
else
    git commit -m "feat(spacetile): update SpaceTile cask formula"
    git push origin HEAD
    echo "🚀 Successfully pushed updated Cask to $TAP_REPO!"
fi

echo ""
echo "=================================================================="
echo "🎉 Homebrew Tap is ready!"
echo "=================================================================="
echo "Users can now install SpaceTile with:"
echo ""
echo "   brew tap ${ORG_OR_USER}/tap"
echo "   brew install --cask spacetile"
echo "=================================================================="
