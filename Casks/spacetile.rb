cask "spacetile" do
  version "1.5.7"
  sha256 "402d84fb6819f19131a9f3bc2077ccf25d613793b02656e4aeed15d713dcd192"

  url "https://github.com/MNLBCK/spacetile/releases/download/v#{version}/SpaceTile-v#{version}.zip"
  name "SpaceTile"
  desc "Intelligent on-demand window tiling and optimization for macOS"
  homepage "https://github.com/MNLBCK/spacetile"

  depends_on macos: ">= :ventura"

  app "SpaceTile.app"
  binary "#{appdir}/SpaceTile.app/Contents/MacOS/spacetile", target: "spacetile"

  postflight do
    system_command "#{appdir}/SpaceTile.app/Contents/MacOS/spacetile",
                   args: ["install"],
                   sudo: false
  end

  uninstall_preflight do
    system_command "#{appdir}/SpaceTile.app/Contents/MacOS/spacetile",
                   args: ["uninstall"],
                   sudo: false
  end

  zap trash: [
    "~/.config/spacetile",
    "~/Library/LaunchAgents/com.guppi.spacetile.plist",
    "~/Library/Logs/SpaceTile",
    "~/Library/Caches/com.guppi.spacetile",
  ]
end
