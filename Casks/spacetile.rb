cask "spacetile" do
  version "1.5.8"
  sha256 "b4e32af00c9e029e868f9d34fbce3038af1aa75c2808c54ea2bc48bdeb92e536"

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
