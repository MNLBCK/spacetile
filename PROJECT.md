# spacetile

## Purpose
- Outcome: macOS-Fenster auf Abruf ergonomisch anordnen; Master- und gesperrte Fenster berücksichtigen.
- Status: Native Swift-App mit Daemon, Einstellungsoberfläche, Homebrew Cask und GitHub Release Workflow.

## Location and environments
- Development: ~/Code/spacetile.
- Production / canonical runtime: Installer-Ziel ~/Applications/SpaceTile.app (oder /Applications/SpaceTile.app via Homebrew), CLI unter ~/.local/bin/spacetile (bzw. $(brew --prefix)/bin/spacetile), LaunchAgent com.guppi.spacetile.
- Distribution: Homebrew Cask (MNLBCK/homebrew-tap) & GitHub Releases (MNLBCK/spacetile).

## Entry points and ownership
- User entrypoint: spacetile CLI, globale Hotkeys (Hyper+Space, Hyper+Return, Hyper+L, Hyper+F, Hyper+S) und SwiftUI-Einstellungen.
- Main owning seams: Fenster-/Space-Verwaltung, Hotkeys, Konfiguration, Dienstinstallation, FeedbackReporter und Cask-Packaging.
- Configuration: ~/.config/spacetile/config.json.
- Data / integrations: macOS Accessibility, SkyLight Window Server APIs und GitHub Issue Reporter.

## Commands
- Install via Homebrew: `brew tap MNLBCK/tap && brew install --cask spacetile`
- Install from Source: `macOS 13+, Swift 5.9+; ./install.sh`
- Package Release: `./scripts/package_release.sh`
- Setup Homebrew Tap: `./scripts/setup_homebrew_tap.sh`
- Run: `spacetile gui`, `spacetile optimize`, `spacetile bug`, `spacetile feedback`
- Test: `swift build`

## Invariants and hazards
- Accessibility-Berechtigung erforderlich; TCC-Signatur `designated => identifier "com.guppi.spacetile"` sichert Berechtigung über Rebuilds hinweg.
- LaunchAgent wird via `spacetile install` registriert und bei `spacetile uninstall` gestoppt und entfernt.

## Last verified
- 2026-11-03: Release-Packaging, Homebrew Cask Generator, Feedback- & Bug-Reporter, GitHub Workflows und Issue-Templates verifiziert.
