cask "spacetile" do
  version "1.5.9"
  sha256 "118331c6a101d809fad7a04274b29f0934e0259e9147d1b566a3b3697a59f0fa"

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
