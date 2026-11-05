import Cocoa

class MenuBarController: NSObject, NSMenuDelegate {
    static let shared = MenuBarController()

    private var statusItem: NSStatusItem?
    private let menu = NSMenu()
    private var statusTimer: Timer?
    private var longPressTimer: Timer?
    private var isLongPressTriggered = false
    private var mouseDownTime: Date = Date.distantPast

    func setup() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = makeMenuBarIcon(active: ServiceInstaller.statusInfo().isRunning)
            button.imagePosition = .imageOnly
            button.toolTip = "SpaceTile (Linksklick: Schnellaktion • Rechtsklick / Halten: Menü)"
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp])
        }
        menu.delegate = self
        self.statusItem = item
        buildMenu()

        // Periodically verify daemon status and reflect it via icon coloring
        statusTimer?.invalidate()
        statusTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.refreshIcon()
        }
    }

    func refreshIcon() {
        let isRunning = ServiceInstaller.statusInfo().isRunning
        statusItem?.button?.image = makeMenuBarIcon(active: isRunning)
    }

    // MARK: - 16:9 Display Icon Harmonized with Dock Icon Palette
    private func makeMenuBarIcon(active: Bool) -> NSImage {
        let size = NSSize(width: 22, height: 16)
        let img = NSImage(size: size, flipped: false) { _ in
            NSGraphicsContext.current?.imageInterpolation = .high

            // 1. Aluminum Stand Base & Neck (matches Dock Icon)
            let standColor = active
                ? NSColor(red: 0.70, green: 0.73, blue: 0.78, alpha: 0.95)
                : NSColor(white: 0.50, alpha: 0.35)

            let neckRect = NSRect(x: 9.75, y: 1.8, width: 2.5, height: 1.8)
            standColor.setFill()
            neckRect.fill()

            let baseRect = NSRect(x: 7.0, y: 0.8, width: 8.0, height: 1.4)
            let basePath = NSBezierPath(roundedRect: baseRect, xRadius: 0.7, yRadius: 0.7)
            basePath.fill()

            // 2. 16:9 Display Outer Bezel (Dark Space Titanium)
            let bezelRect = NSRect(x: 1.0, y: 3.4, width: 20.0, height: 11.6)
            let bezelPath = NSBezierPath(roundedRect: bezelRect, xRadius: 2.0, yRadius: 2.0)
            if active {
                NSColor(red: 0.13, green: 0.14, blue: 0.17, alpha: 1.0).setFill()
                bezelPath.fill()
                NSColor(white: 0.40, alpha: 0.4).setStroke()
                bezelPath.lineWidth = 0.6
                bezelPath.stroke()
            } else {
                NSColor(white: 0.18, alpha: 0.45).setFill()
                bezelPath.fill()
                NSColor(white: 0.35, alpha: 0.20).setStroke()
                bezelPath.lineWidth = 0.6
                bezelPath.stroke()
            }

            // 3. Inner Screen Glass
            let screenRect = NSRect(x: 1.8, y: 4.2, width: 18.4, height: 10.0)
            let screenPath = NSBezierPath(roundedRect: screenRect, xRadius: 1.2, yRadius: 1.2)
            if active {
                NSColor(red: 0.05, green: 0.06, blue: 0.08, alpha: 1.0).setFill()
            } else {
                NSColor(white: 0.10, alpha: 0.45).setFill()
            }
            screenPath.fill()

            // 4. Windows Layout on Display Screen
            // Left: Master Window Tile
            let masterRect = NSRect(x: 2.6, y: 5.0, width: 8.8, height: 8.4)
            let masterPath = NSBezierPath(roundedRect: masterRect, xRadius: 1.2, yRadius: 1.2)

            if active {
                // Electric Cyan to Azure Gradient (Sampled from Dock AppIcon.png)
                let grad = NSGradient(
                    starting: NSColor(red: 0.05, green: 0.48, blue: 0.94, alpha: 1.0),
                    ending: NSColor(red: 0.10, green: 0.83, blue: 0.99, alpha: 1.0)
                )
                grad?.draw(in: masterPath, angle: 90)

                NSColor(red: 0.51, green: 0.92, blue: 0.99, alpha: 0.85).setStroke()
                masterPath.lineWidth = 0.6
                masterPath.stroke()
            } else {
                // Grayed out when daemon is inactive
                NSColor(white: 0.35, alpha: 0.35).setFill()
                masterPath.fill()
                NSColor(white: 0.50, alpha: 0.25).setStroke()
                masterPath.lineWidth = 0.5
                masterPath.stroke()
            }

            // Right: Auxiliary Stack Tiles (Frosted Slate)
            let trRect = NSRect(x: 12.3, y: 9.4, width: 7.1, height: 4.0)
            let trPath = NSBezierPath(roundedRect: trRect, xRadius: 0.8, yRadius: 0.8)

            let brRect = NSRect(x: 12.3, y: 5.0, width: 7.1, height: 4.0)
            let brPath = NSBezierPath(roundedRect: brRect, xRadius: 0.8, yRadius: 0.8)

            if active {
                NSColor(red: 0.22, green: 0.22, blue: 0.25, alpha: 1.0).setFill()
                trPath.fill()
                brPath.fill()

                NSColor(white: 0.55, alpha: 0.25).setStroke()
                trPath.lineWidth = 0.5
                trPath.stroke()
                brPath.lineWidth = 0.5
                brPath.stroke()
            } else {
                NSColor(white: 0.25, alpha: 0.30).setFill()
                trPath.fill()
                brPath.fill()

                NSColor(white: 0.40, alpha: 0.20).setStroke()
                trPath.lineWidth = 0.5
                trPath.stroke()
                brPath.lineWidth = 0.5
                brPath.stroke()
            }

            return true
        }
        img.isTemplate = false
        return img
    }

    // MARK: - Short Click (Quick Action) vs. Long-Press / Right-Click (Menu)
    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            executeQuickAction()
            return
        }

        switch event.type {
        case .rightMouseDown, .rightMouseUp:
            cancelLongPressTimer()
            showMenu()

        case .leftMouseDown:
            isLongPressTriggered = false
            mouseDownTime = Date()
            cancelLongPressTimer()
            longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                self.isLongPressTriggered = true
                self.showMenu()
            }

        case .leftMouseUp:
            let elapsed = Date().timeIntervalSince(mouseDownTime)
            cancelLongPressTimer()
            if isLongPressTriggered || elapsed >= 0.35 {
                // Already triggered menu via long press
                return
            }
            // Rapid short left-click: Trigger Quick Action!
            executeQuickAction()

        default:
            break
        }
    }

    private func cancelLongPressTimer() {
        longPressTimer?.invalidate()
        longPressTimer = nil
    }

    private func executeQuickAction() {
        let config = Config.load()
        switch config.menuBarQuickAction.lowercased() {
        case "actions", "quickmenu", "quick-menu":
            showQuickActionsMenu()
        case "settings", "gui":
            openGUIAction()
        case "master":
            setMasterAction()
        case "uniform", "clear-master":
            clearMasterAction()
        case "menu":
            showMenu()
        case "rearrange", "optimize":
            fallthrough
        default:
            rearrangeAction()
        }
    }

    // MARK: - Compact Quick Actions Menu (Left-Click Option)
    @objc func showQuickActionsMenu() {
        let quickMenu = NSMenu()

        let titleItem = NSMenuItem(title: "SpaceTile Schnellaktionen", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        let font = NSFont.boldSystemFont(ofSize: 12)
        titleItem.attributedTitle = NSAttributedString(string: "⚡ SpaceTile Schnellaktionen", attributes: [.font: font])
        quickMenu.addItem(titleItem)

        quickMenu.addItem(NSMenuItem.separator())

        let rearrangeItem = NSMenuItem(title: "Fenster jetzt anordnen", action: #selector(rearrangeAction), keyEquivalent: " ")
        rearrangeItem.keyEquivalentModifierMask = [.control, .option, .shift, .command]
        rearrangeItem.target = self
        quickMenu.addItem(rearrangeItem)

        let masterItem = NSMenuItem(title: "Fokussiertes Fenster als Master", action: #selector(setMasterAction), keyEquivalent: "\r")
        masterItem.keyEquivalentModifierMask = [.control, .option, .shift, .command]
        masterItem.target = self
        quickMenu.addItem(masterItem)

        if WindowManager.shared.masterWindowID != nil {
            let clearMasterItem = NSMenuItem(title: "Master aufheben (Gleichmäßig)", action: #selector(clearMasterAction), keyEquivalent: "")
            clearMasterItem.target = self
            quickMenu.addItem(clearMasterItem)
        }

        let floatItem = NSMenuItem(title: "Fenster pinnen (Immer oben float)", action: #selector(toggleFloatAction), keyEquivalent: "f")
        floatItem.keyEquivalentModifierMask = [.control, .option, .shift, .command]
        floatItem.target = self
        quickMenu.addItem(floatItem)

        let settingsItem = NSMenuItem(title: "Einstellungen öffnen...", action: #selector(openGUIAction), keyEquivalent: "s")
        settingsItem.keyEquivalentModifierMask = [.control, .option, .shift, .command]
        settingsItem.target = self
        quickMenu.addItem(settingsItem)

        quickMenu.addItem(NSMenuItem.separator())

        let fullMenuItem = NSMenuItem(title: "Vollständiges Menü öffnen...", action: #selector(showMenu), keyEquivalent: "")
        fullMenuItem.target = self
        quickMenu.addItem(fullMenuItem)

        statusItem?.popUpMenu(quickMenu)
    }

    @objc func showMenu() {
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

        // 4. Menu Bar Quick Action Selection Submenu
        let clickMenu = NSMenu()

        let actRearrange = NSMenuItem(title: "Fenster anordnen (Rearrange)", action: #selector(setQuickActionRearrange), keyEquivalent: "")
        actRearrange.target = self
        actRearrange.state = (config.menuBarQuickAction == "rearrange") ? .on : .off
        clickMenu.addItem(actRearrange)

        let actActions = NSMenuItem(title: "Aktions-Menü öffnen (Kompakt)", action: #selector(setQuickActionActions), keyEquivalent: "")
        actActions.target = self
        actActions.state = (config.menuBarQuickAction == "actions") ? .on : .off
        clickMenu.addItem(actActions)

        let actSettings = NSMenuItem(title: "Einstellungen öffnen", action: #selector(setQuickActionSettings), keyEquivalent: "")
        actSettings.target = self
        actSettings.state = (config.menuBarQuickAction == "settings") ? .on : .off
        clickMenu.addItem(actSettings)

        let actMaster = NSMenuItem(title: "Fokussiertes Fenster als Master", action: #selector(setQuickActionMaster), keyEquivalent: "")
        actMaster.target = self
        actMaster.state = (config.menuBarQuickAction == "master") ? .on : .off
        clickMenu.addItem(actMaster)

        let actUniform = NSMenuItem(title: "Master aufheben (Gleichmäßig)", action: #selector(setQuickActionUniform), keyEquivalent: "")
        actUniform.target = self
        actUniform.state = (config.menuBarQuickAction == "uniform") ? .on : .off
        clickMenu.addItem(actUniform)

        let actMenu = NSMenuItem(title: "Vollständiges Menü öffnen", action: #selector(setQuickActionMenu), keyEquivalent: "")
        actMenu.target = self
        actMenu.state = (config.menuBarQuickAction == "menu") ? .on : .off
        clickMenu.addItem(actMenu)

        let clickParent = NSMenuItem(title: "Schnellaktion (Linksklick)", action: nil, keyEquivalent: "")
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
    @objc private func setQuickActionRearrange() {
        var cfg = Config.load()
        cfg.menuBarQuickAction = "rearrange"
        cfg.save()
    }

    @objc private func setQuickActionActions() {
        var cfg = Config.load()
        cfg.menuBarQuickAction = "actions"
        cfg.save()
    }

    @objc private func setQuickActionSettings() {
        var cfg = Config.load()
        cfg.menuBarQuickAction = "settings"
        cfg.save()
    }

    @objc private func setQuickActionMaster() {
        var cfg = Config.load()
        cfg.menuBarQuickAction = "master"
        cfg.save()
    }

    @objc private func setQuickActionUniform() {
        var cfg = Config.load()
        cfg.menuBarQuickAction = "uniform"
        cfg.save()
    }

    @objc private func setQuickActionMenu() {
        var cfg = Config.load()
        cfg.menuBarQuickAction = "menu"
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.refreshIcon()
        }
    }

    @objc private func quitAction() {
        NSApp.terminate(nil)
    }
}
