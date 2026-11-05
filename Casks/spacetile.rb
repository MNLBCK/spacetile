cask "spacetile" do
  version "1.6.0"
  sha256 "4d7e4ec78bc6b5b311b40ac07c509df78e0644f29b8bcfafd82d28a503ffb53c"

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
