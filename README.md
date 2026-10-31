# SpaceTile 🚀

<div align="center">
  <img src="assets/AppIcon.png" alt="SpaceTile App Icon" width="160" />
  <p><strong>Ergonomic on-demand window tiling & optimization for macOS.</strong></p>
  <p>Runs quietly in the background as a native daemon. Optimizes your active space on shortcut command.</p>
</div>

---

## ✨ Features

* ⚡ **Global Hyper-Key Shortcuts:**
  * **`Hyper + Space`** (`⌃⌥⇧⌘ + Space`): Instantly rearranges windows into an ergonomic dynamic grid.
  * **`Hyper + Return`** (`⌃⌥⇧⌘ + Return`): Designates the active/focused window as the **Master** window (2/3 viewport).
  * **`Hyper + L`** (`⌃⌥⇧⌘ + L`): **Locks/Unlocks** the active window in place. Locked windows remain stationary; other windows tile around them.
  * **`Hyper + S`** (`⌃⌥⇧⌘ + S`): Opens the native SwiftUI **Settings GUI** in the foreground.

* 📐 **Smart 10×6 Grid & Window Scoring (1–100):**
  * **Terminal Protection on 4K/Ultrawide:** Prevents terminal windows from being stretched across 62% (2400px+) of the display. Terminals request low weight (~30 score) and stay within an ergonomic ~1200px (1/3 column).
  * **Signature 3×3 Layout for 6 Windows:**
    * **Master Window (e.g. Browser / Code):** 2/3 width, 2/3 height (top-left).
    * **Right Stack (3 Windows):** 1/3 width, 1/3 height each (stacked vertically).
    * **Bottom Stack (2 Windows):** 1/3 width, 1/3 height each (side-by-side under Master).
  * **Notes + Browser Side-by-Side:** Automatically provides an equal 50/50 reading split when notes and browsers are paired.

* 🛡️ **Robust macOS App Bundle & Real-Time Permissions:**
  * Built as a native application bundle (`~/Applications/SpaceTile.app`) with code signing and designated requirement `com.guppi.spacetile`.
  * **Zero Permission Drops:** Because macOS TCC tracks the bundle ID `com.guppi.spacetile`, Accessibility permissions persist across builds and restarts.
  * **Self-Aware Detection:** Live detection via `AXIsProcessTrustedWithOptions` and system accessibility notifications (`com.apple.accessibility.api`). The GUI updates immediately the moment you toggle permissions in System Settings!

---

## 📥 Installation from GitHub

To install SpaceTile on any Mac from GitHub:

```bash
# 1. Clone the repository
git clone https://github.com/guppi/spacetile.git ~/Code/spacetile

# 2. Enter directory and run the installation script
cd ~/Code/spacetile
./install.sh
```

### What `install.sh` does automatically:
1. Compiles the optimized release binary with the Swift Package Manager.
2. Packages `SpaceTile.app` inside `~/Applications/` with the vector icon (`AppIcon.icns`).
3. Signs the bundle with the persistent identifier `com.guppi.spacetile`.
4. Creates a CLI symlink at `~/.local/bin/spacetile`.
5. Registers and launches the background daemon via LaunchAgent (`~/Library/LaunchAgents/com.guppi.spacetile.plist`).

---

## 🔐 Granting macOS Accessibility Permissions

SpaceTile requires Accessibility permissions to read window positions and move windows:

1. Open **System Settings** → **Privacy & Security** → **Accessibility** (Bedienungshilfen).
2. Toggle **SpaceTile** to **ON** (showing the geometric SpaceTile logo).
3. Verify in your terminal with:
   ```bash
   spacetile status
   ```
   You should see:
   ```text
   SpaceTile Status:
    - App Bundle:    Installed (~/Applications/SpaceTile.app)
    - CLI Symlink:   Active (~/Users/guppi/.local/bin/spacetile)
    - LaunchAgent:   Registered
    - Service:       Active (PID: ...)
    - Accessibility: Granted
   ```

---

## 💻 CLI Commands

The `spacetile` CLI tool is available from anywhere in your shell:

| Command | Description |
|---|---|
| `spacetile optimize` / `spacetile` | Rearranges windows in the current space immediately |
| `spacetile master` | Promotes the currently focused window to Master |
| `spacetile lock` | Toggles position lock for the currently focused window |
| `spacetile gui` | Opens the native Settings window |
| `spacetile gui daemon` | Opens Settings directly on the Daemon & Logs tab |
| `spacetile status` | Displays live service, app bundle, and permission status |
| `spacetile restart` | Safely restarts the background LaunchAgent daemon |
| `spacetile install` | Re-bundles and registers `SpaceTile.app` and LaunchAgent |
| `spacetile uninstall` | Completely stops and removes SpaceTile and its LaunchAgent |

---

## ⚙️ Configuration

Configuration is stored in `~/.config/spacetile/config.json`. You can edit it manually or visually via the GUI (**`Hyper + S`**):

* **Shortcuts:** Customize any of the 4 hotkeys with the interactive "Record New" recorder.
* **Weights & Dimensions:** Adjust scores (1–100), minimum width/height, and maximum width for each application.
* **Animation:** Choose between **Instant (Zero-Lag)** or **Smooth Glide**.
* **Ignored Apps:** Add applications to skip (e.g. system utilities, palettes).

---

## 🗑️ Uninstallation

To completely remove SpaceTile:

```bash
cd ~/Code/spacetile
./uninstall.sh
```
