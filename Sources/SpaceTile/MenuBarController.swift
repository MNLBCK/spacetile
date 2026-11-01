import Cocoa

class MenuBarController: NSObject, NSMenuDelegate {
    static let shared = MenuBarController()

    private var statusItem: NSStatusItem?
    private let menu = NSMenu()

    func setup() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = makeMenuBarIcon()
            button.imagePosition = .imageOnly
            button.toolTip = "SpaceTile – Intelligent Window Tiling"
        }
        item.menu = menu
        menu.delegate = self
        self.statusItem = item
        buildMenu()
    }

    private func makeMenuBarIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let img = NSImage(size: size, flipped: false) { rect in
            NSColor.clear.setFill()
            rect.fill()

            let strokeColor = NSColor.labelColor.withAlphaComponent(0.85)
            let fillColor = NSColor.labelColor.withAlphaComponent(0.20)

            // Outer border
            let outerPath = NSBezierPath(roundedRect: NSRect(x: 1, y: 1, width: 16, height: 16), xRadius: 3, yRadius: 3)
            outerPath.lineWidth = 1.2
            strokeColor.setStroke()
            outerPath.stroke()

            // Left (Master) tile
            let masterRect = NSRect(x: 2.5, y: 2.5, width: 7.0, height: 13.0)
            let masterPath = NSBezierPath(roundedRect: masterRect, xRadius: 1.5, yRadius: 1.5)
            fillColor.setFill()
            masterPath.fill()
            masterPath.lineWidth = 0.8
            strokeColor.setStroke()
            masterPath.stroke()

            // Top-right Stack tile
            let trRect = NSRect(x: 10.5, y: 9.5, width: 5.0, height: 6.0)
            let trPath = NSBezierPath(roundedRect: trRect, xRadius: 1.2, yRadius: 1.2)
            fillColor.setFill()
            trPath.fill()
            trPath.lineWidth = 0.8
            strokeColor.setStroke()
            trPath.stroke()

            // Bottom-right Stack tile
            let brRect = NSRect(x: 10.5, y: 2.5, width: 5.0, height: 6.0)
            let brPath = NSBezierPath(roundedRect: brRect, xRadius: 1.2, yRadius: 1.2)
            fillColor.setFill()
            brPath.fill()
            brPath.lineWidth = 0.8
            strokeColor.setStroke()
            brPath.stroke()

            return true
        }
        img.isTemplate = true
        return img
    }

    func menuWillOpen(_ menu: NSMenu) {
        buildMenu()
    }

    private func buildMenu() {
        menu.removeAllItems()

        // 1. Header
        let titleItem = NSMenuItem(title: "SpaceTile v\(Config.version)", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        let font = NSFont.boldSystemFont(ofSize: 12)
        titleItem.attributedTitle = NSAttributedString(string: "SpaceTile v\(Config.version)", attributes: [.font: font])
        menu.addItem(titleItem)

        // Windows on current space info
        let config = Config.load()
        if let screen = NSScreen.main ?? NSScreen.screens.first {
            let vf = screen.visibleFrame
            let primaryH = NSScreen.screens.first?.frame.height ?? vf.height
            let axRect = CGRect(x: vf.origin.x, y: primaryH - (vf.origin.y + vf.height), width: vf.width, height: vf.height)
            let windows = WindowManager.shared.collectWindowsOnCurrentSpace(screenBounds: axRect, ignoredApps: Set(config.ignoredApps), config: config)
            let statusText = "\(windows.count) window\(windows.count == 1 ? "" : "s") on current space"
            let countItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
            countItem.isEnabled = false
            menu.addItem(countItem)
        }

        menu.addItem(NSMenuItem.separator())

        // 2. Quick Actions
        let rearrangeItem = NSMenuItem(title: "Rearrange Windows", action: #selector(rearrangeAction), keyEquivalent: " ")
        rearrangeItem.keyEquivalentModifierMask = [.control, .option, .shift, .command]
        rearrangeItem.target = self
        menu.addItem(rearrangeItem)

        let masterItem = NSMenuItem(title: "Set Focused Window as Master", action: #selector(setMasterAction), keyEquivalent: "\r")
        masterItem.keyEquivalentModifierMask = [.control, .option, .shift, .command]
        masterItem.target = self
        menu.addItem(masterItem)

        let lockItem = NSMenuItem(title: "Lock/Unlock Active Window", action: #selector(toggleLockAction), keyEquivalent: "l")
        lockItem.keyEquivalentModifierMask = [.control, .option, .shift, .command]
        lockItem.target = self
        menu.addItem(lockItem)

        if WindowManager.shared.masterWindowID != nil {
            let clearMasterItem = NSMenuItem(title: "Reset to Automatic Scoring", action: #selector(clearMasterAction), keyEquivalent: "")
            clearMasterItem.target = self
            menu.addItem(clearMasterItem)
        }

        menu.addItem(NSMenuItem.separator())

        // 3. Quick Layout Ratio Presets
        let presetsMenu = NSMenu()
        let p50 = NSMenuItem(title: "Side-by-Side (50% / 50%)", action: #selector(setRatio50), keyEquivalent: "")
        p50.target = self
        presetsMenu.addItem(p50)

        let p60 = NSMenuItem(title: "Master Stack (60% / 40%)", action: #selector(setRatio60), keyEquivalent: "")
        p60.target = self
        presetsMenu.addItem(p60)

        let p70 = NSMenuItem(title: "Master Stack (70% / 30%)", action: #selector(setRatio70), keyEquivalent: "")
        p70.target = self
        presetsMenu.addItem(p70)

        let presetParent = NSMenuItem(title: "Quick Layout Splits", action: nil, keyEquivalent: "")
        presetParent.submenu = presetsMenu
        menu.addItem(presetParent)

        menu.addItem(NSMenuItem.separator())

        // 4. GUI & System Controls
        let guiItem = NSMenuItem(title: "Open SpaceTile Settings...", action: #selector(openGUIAction), keyEquivalent: "s")
        guiItem.keyEquivalentModifierMask = [.control, .option, .shift, .command]
        guiItem.target = self
        menu.addItem(guiItem)

        let restartItem = NSMenuItem(title: "Restart Background Daemon", action: #selector(restartDaemonAction), keyEquivalent: "")
        restartItem.target = self
        menu.addItem(restartItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit SpaceTile", action: #selector(quitAction), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func rearrangeAction() {
        DispatchQueue.global(qos: .userInitiated).async {
            WindowManager.shared.optimize(verbose: true)
        }
    }

    @objc private func setMasterAction() {
        DispatchQueue.global(qos: .userInitiated).async {
            _ = WindowManager.shared.setFocusedAsMaster()
        }
    }

    @objc private func toggleLockAction() {
        _ = WindowManager.shared.toggleLockForFocusedWindow()
    }

    @objc private func clearMasterAction() {
        DispatchQueue.global(qos: .userInitiated).async {
            WindowManager.shared.clearMasterWindow()
        }
    }

    @objc private func setRatio50() {
        DispatchQueue.global(qos: .userInitiated).async {
            WindowManager.shared.optimize(verbose: true, forcedRatio: 0.50)
        }
    }

    @objc private func setRatio60() {
        DispatchQueue.global(qos: .userInitiated).async {
            WindowManager.shared.optimize(verbose: true, forcedRatio: 0.60)
        }
    }

    @objc private func setRatio70() {
        DispatchQueue.global(qos: .userInitiated).async {
            WindowManager.shared.optimize(verbose: true, forcedRatio: 0.70)
        }
    }

    @objc private func openGUIAction() {
        SettingsWindowController.shared.show()
    }

    @objc private func restartDaemonAction() {
        ServiceInstaller.restart()
    }

    @objc private func quitAction() {
        NSApp.terminate(nil)
    }
}
