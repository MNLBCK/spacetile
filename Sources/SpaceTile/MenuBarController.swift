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
            button.toolTip = "SpaceTile – Intelligent Window Tiling (Klick: Menü, Doppelklick: Anordnen/Settings)"
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
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

    // MARK: - Click & Double-Click Dispatcher
    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            showMenu()
            return
        }

        // 1. Right Click -> Always opens the menu immediately
        if event.type == .rightMouseUp {
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(handlePendingSingleClick), object: nil)
            showMenu()
            return
        }

        // 2. Left Click Handling
        if event.clickCount == 2 {
            // Cancel pending single-click action
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(handlePendingSingleClick), object: nil)
            handleDoubleClick()
        } else if event.clickCount == 1 {
            let config = Config.load()
            if config.menuBarSingleClickAction != "menu" && config.menuBarDoubleClickAction == config.menuBarSingleClickAction {
                executeAction(named: config.menuBarSingleClickAction)
            } else {
                // Wait briefly (0.22s) so a rapid second click can be caught as double-click
                perform(#selector(handlePendingSingleClick), with: nil, afterDelay: 0.22)
            }
        }
    }

    @objc private func handlePendingSingleClick() {
        let config = Config.load()
        executeAction(named: config.menuBarSingleClickAction)
    }

    private func handleDoubleClick() {
        let config = Config.load()
        executeAction(named: config.menuBarDoubleClickAction)
    }

    private func executeAction(named actionName: String) {
        switch actionName.lowercased() {
        case "settings", "gui":
            openGUIAction()
        case "rearrange", "optimize":
            rearrangeAction()
        case "master":
            setMasterAction()
        case "uniform", "clear-master":
            clearMasterAction()
        case "menu":
            showMenu()
        default:
            rearrangeAction()
        }
    }

    private func showMenu() {
        buildMenu()
        statusItem?.popUpMenu(menu)
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

        let floatItem = NSMenuItem(title: "Toggle Floating Window (Always on Top)", action: #selector(toggleFloatAction), keyEquivalent: "f")
        floatItem.keyEquivalentModifierMask = [.control, .option, .shift, .command]
        floatItem.target = self
        menu.addItem(floatItem)

        if WindowManager.shared.masterWindowID != nil {
            let clearMasterItem = NSMenuItem(title: "Reset Master (Uniform Grid)", action: #selector(clearMasterAction), keyEquivalent: "")
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

        // 4. Menu Bar Double-Click Action Submenu
        let clickMenu = NSMenu()
        let actRearrange = NSMenuItem(title: "Fenster anordnen (Rearrange)", action: #selector(setDoubleClickRearrange), keyEquivalent: "")
        actRearrange.target = self
        actRearrange.state = (config.menuBarDoubleClickAction == "rearrange") ? .on : .off
        clickMenu.addItem(actRearrange)

        let actSettings = NSMenuItem(title: "Einstellungen öffnen (Settings)", action: #selector(setDoubleClickSettings), keyEquivalent: "")
        actSettings.target = self
        actSettings.state = (config.menuBarDoubleClickAction == "settings") ? .on : .off
        clickMenu.addItem(actSettings)

        let actMaster = NSMenuItem(title: "Fokussiertes Fenster als Master", action: #selector(setDoubleClickMaster), keyEquivalent: "")
        actMaster.target = self
        actMaster.state = (config.menuBarDoubleClickAction == "master") ? .on : .off
        clickMenu.addItem(actMaster)

        let actUniform = NSMenuItem(title: "Master aufheben (Gleichmäßig)", action: #selector(setDoubleClickUniform), keyEquivalent: "")
        actUniform.target = self
        actUniform.state = (config.menuBarDoubleClickAction == "uniform") ? .on : .off
        clickMenu.addItem(actUniform)

        let clickParent = NSMenuItem(title: "Logo-Doppelklick Aktion", action: nil, keyEquivalent: "")
        clickParent.submenu = clickMenu
        menu.addItem(clickParent)

        menu.addItem(NSMenuItem.separator())

        // 5. GUI & System Controls
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

    // MARK: - Actions
    @objc private func setDoubleClickRearrange() {
        var cfg = Config.load()
        cfg.menuBarDoubleClickAction = "rearrange"
        cfg.save()
    }

    @objc private func setDoubleClickSettings() {
        var cfg = Config.load()
        cfg.menuBarDoubleClickAction = "settings"
        cfg.save()
    }

    @objc private func setDoubleClickMaster() {
        var cfg = Config.load()
        cfg.menuBarDoubleClickAction = "master"
        cfg.save()
    }

    @objc private func setDoubleClickUniform() {
        var cfg = Config.load()
        cfg.menuBarDoubleClickAction = "uniform"
        cfg.save()
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

    @objc private func toggleFloatAction() {
        _ = WindowManager.shared.toggleFloatForFocusedWindow()
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
