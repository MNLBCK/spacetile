import Cocoa
import ApplicationServices
import CoreGraphics

@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ id: inout CGWindowID) -> AXError

struct ManagedWindow {
    let element: AXUIElement
    let id: CGWindowID
    let appName: String
    let title: String
    let isFocused: Bool
    let zOrder: Int
}

class WindowManager {
    static let shared = WindowManager()

    private var lastRunTime: Date?
    private var cycleIndex: Int = 0

    @discardableResult
    func optimize(verbose: Bool = true) -> Bool {
        guard AXIsProcessTrusted() else {
            print("[\u{001B}[31mFEHLER\u{001B}[0m] Bedienungshilfen-Berechtigung (Accessibility) nicht erteilt!")
            print("Bitte in macOS: Systemeinstellungen → Datenschutz & Sicherheit → Bedienungshilfen aktivieren.")
            return false
        }

        let config = Config.load()

        // 1. Determine target display
        guard let targetScreen = findTargetScreen() else {
            if verbose { print("[\u{001B}[31mFEHLER\u{001B}[0m] Kein aktiver Bildschirm gefunden.") }
            return false
        }

        guard let primaryScreen = NSScreen.screens.first else { return false }
        let primaryHeight = primaryScreen.frame.height

        let vf = targetScreen.visibleFrame
        let axVisibleRect = CGRect(
            x: vf.origin.x,
            y: primaryHeight - (vf.origin.y + vf.height),
            width: vf.width,
            height: vf.height
        )

        let workArea = axVisibleRect.insetBy(dx: config.margin, dy: config.margin)
        guard workArea.width > 200 && workArea.height > 200 else { return false }

        // 2. Find visible windows on current Space
        let windows = collectWindowsOnCurrentSpace(screenBounds: axVisibleRect, ignoredApps: Set(config.ignoredApps))
        if windows.isEmpty {
            if verbose { print("[\u{001B}[33mINFO\u{001B}[0m] Keine relevanten Fenster im aktuellen Space gefunden.") }
            return true
        }

        let appNames = Array(Set(windows.map { $0.appName })).sorted()
        let resKey = "\(Int(targetScreen.frame.width))x\(Int(targetScreen.frame.height))"

        // 3. Ratio determination (Cycle vs. Memory vs. Semantic Heuristic)
        let now = Date()
        var effectiveRatio: Double = config.masterRatio
        var layoutReason: String = "Standard Master-Stack (\(Int(effectiveRatio * 100))%)"

        let isRapidCycle = (lastRunTime != nil && now.timeIntervalSince(lastRunTime!) < 2.2 && !config.cycleRatios.isEmpty)
        if isRapidCycle {
            cycleIndex = (cycleIndex + 1) % config.cycleRatios.count
            effectiveRatio = config.cycleRatios[cycleIndex]
            layoutReason = "Zyklus-Umschaltung (\(Int(effectiveRatio * 100))%)"
        } else {
            cycleIndex = 0

            // Check learned space memory
            if config.enableSpaceLearning,
               let profile = SpaceMemory.shared.findProfile(apps: appNames, resolution: resKey),
               let learned = profile.learnedMasterRatio, profile.observationsCount >= 2 {
                effectiveRatio = learned
                layoutReason = "🧠 Gelerntes Space-Gedächtnis (\(Int(learned * 100))%)"
            }
            // Check semantic Side-by-Side (Notes + Browser)
            else if config.sideBySideForNotesAndBrowser && windows.count == 2 {
                let categories = windows.map { getAppCategory(appName: $0.appName, config: config) }
                if (categories.contains("browser") && categories.contains("notes")) ||
                   (categories.contains("notes") && categories.contains("custom")) {
                    effectiveRatio = 0.50
                    layoutReason = "📖 Side-by-Side (50/50 Lese- & Notizmodus)"
                }
            }
        }
        lastRunTime = now

        if verbose {
            print("[\u{001B}[32mSpaceTile\u{001B}[0m] Optimiere \(windows.count) Fenster auf '\(targetScreen.localizedName)' [\(layoutReason)]...")
        }

        // 4. Calculate frames with intelligent constraints
        let frames = calculateLayout(
            windows: windows,
            area: workArea,
            screen: targetScreen,
            config: config,
            ratio: effectiveRatio,
            isRapidCycle: isRapidCycle
        )

        // 5. Apply positions & sizes
        for (index, win) in windows.enumerated() {
            let targetFrame = frames[index]
            setWindowFrame(win.element, target: targetFrame)

            if verbose {
                let tag = win.isFocused ? "\u{001B}[32m★ Master\u{001B}[0m" : "\u{001B}[37m  Stack \u{001B}[0m"
                let titleShort = win.title.isEmpty ? "(ohne Titel)" : String(win.title.prefix(32))
                let category = getAppCategory(appName: win.appName, config: config)
                print(String(format: " %@[%@ (%@)] \"%@\" -> %dx%d @ (%d, %d)",
                             tag,
                             win.appName,
                             category,
                             titleShort,
                             Int(targetFrame.width),
                             Int(targetFrame.height),
                             Int(targetFrame.origin.x),
                             Int(targetFrame.origin.y)))
            }
        }

        return true
    }

    private func getAppCategory(appName: String, config: Config) -> String {
        if let match = config.appConstraints.first(where: { $0.appName.lowercased() == appName.lowercased() }) {
            return match.category
        }
        let lower = appName.lowercased()
        if lower.contains("term") || lower.contains("alacritty") || lower.contains("kitty") || lower.contains("ghostty") {
            return "terminal"
        }
        if lower.contains("chrome") || lower.contains("safari") || lower.contains("firefox") || lower.contains("arc") || lower.contains("browser") {
            return "browser"
        }
        if lower.contains("notes") || lower.contains("obsidian") || lower.contains("bear") || lower.contains("textedit") || lower.contains("notion") {
            return "notes"
        }
        if lower.contains("code") || lower.contains("xcode") || lower.contains("sublime") || lower.contains("studio") {
            return "editor"
        }
        return "custom"
    }

    private func calculateLayout(
        windows: [ManagedWindow],
        area: CGRect,
        screen: NSScreen,
        config: Config,
        ratio: Double,
        isRapidCycle: Bool
    ) -> [CGRect] {
        let count = windows.count
        guard count > 0 else { return [] }

        let gap = config.gap
        let master = windows[0]
        let masterCategory = getAppCategory(appName: master.appName, config: config)

        // 1 Window
        if count == 1 {
            if config.singleWindowMode == "maximized" {
                return [area]
            } else {
                let w = area.width * 0.75
                let h = area.height * 0.95
                let x = area.origin.x + (area.width - w) / 2
                let y = area.origin.y + (area.height - h) / 2
                return [CGRect(x: x, y: y, width: w, height: h)]
            }
        }

        let availW = area.width - gap
        var masterW: Double = floor(availW * ratio)

        // Smart Constraint: Terminal on 4K/Ultra-Wide screens
        let isUltraWide = screen.frame.width >= 2560
        if config.enableSmartWeighting && !isRapidCycle && masterCategory == "terminal" && isUltraWide {
            let maxTerminalW = min(config.terminalMaxWidth4K, floor(availW * config.terminalMaxRatio4K))
            masterW = min(masterW, maxTerminalW)
        }

        let stackW = availW - masterW

        // 2 Windows
        if count == 2 {
            let r0 = CGRect(x: area.origin.x, y: area.origin.y, width: masterW, height: area.height)
            let r1 = CGRect(x: area.origin.x + masterW + gap, y: area.origin.y, width: stackW, height: area.height)
            return [r0, r1]
        }

        // 3 Windows
        if count == 3 {
            let availH = area.height - gap
            let itemH = floor(availH / 2.0)
            let itemH2 = availH - itemH

            let r0 = CGRect(x: area.origin.x, y: area.origin.y, width: masterW, height: area.height)
            let r1 = CGRect(x: area.origin.x + masterW + gap, y: area.origin.y, width: stackW, height: itemH)
            let r2 = CGRect(x: area.origin.x + masterW + gap, y: area.origin.y + itemH + gap, width: stackW, height: itemH2)
            return [r0, r1, r2]
        }

        // 4 Windows: Grid when ratio is 0.50
        if count == 4 && abs(ratio - 0.5) < 0.05 {
            let colW = floor((area.width - gap) / 2.0)
            let rowH = floor((area.height - gap) / 2.0)
            let colW2 = area.width - gap - colW
            let rowH2 = area.height - gap - rowH

            let p0 = CGRect(x: area.origin.x, y: area.origin.y, width: colW, height: rowH)
            let p1 = CGRect(x: area.origin.x + colW + gap, y: area.origin.y, width: colW2, height: rowH)
            let p2 = CGRect(x: area.origin.x, y: area.origin.y + rowH + gap, width: colW, height: rowH2)
            let p3 = CGRect(x: area.origin.x + colW + gap, y: area.origin.y + rowH + gap, width: colW2, height: rowH2)
            return [p0, p1, p2, p3]
        }

        // N Windows (1 Master, N-1 Stack)
        let stackCount = count - 1
        let totalGaps = gap * Double(stackCount - 1)
        let totalStackH = area.height - totalGaps
        let baseItemH = floor(totalStackH / Double(stackCount))

        var result: [CGRect] = []
        result.append(CGRect(x: area.origin.x, y: area.origin.y, width: masterW, height: area.height))

        var currentY = area.origin.y
        for i in 0..<stackCount {
            let itemH = (i == stackCount - 1) ? (area.origin.y + area.height - currentY) : baseItemH
            result.append(CGRect(x: area.origin.x + masterW + gap, y: currentY, width: stackW, height: itemH))
            currentY += itemH + gap
        }

        return result
    }

    private func findTargetScreen() -> NSScreen? {
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            let appRef = AXUIElementCreateApplication(frontApp.processIdentifier)
            var focusedWinRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &focusedWinRef) == .success,
               let focusedWin = focusedWinRef {
                var posRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(focusedWin as! AXUIElement, kAXPositionAttribute as CFString, &posRef) == .success,
                   let val = posRef {
                    var point = CGPoint.zero
                    if AXValueGetValue(val as! AXValue, .cgPoint, &point) {
                        for screen in NSScreen.screens {
                            let primaryH = NSScreen.screens.first?.frame.height ?? 0
                            let screenAxRect = CGRect(
                                x: screen.frame.origin.x,
                                y: primaryH - (screen.frame.origin.y + screen.frame.height),
                                width: screen.frame.width,
                                height: screen.frame.height
                            )
                            if screenAxRect.contains(point) {
                                return screen
                            }
                        }
                    }
                }
            }
        }

        let mouseLoc = NSEvent.mouseLocation
        for screen in NSScreen.screens {
            if screen.frame.contains(mouseLoc) {
                return screen
            }
        }

        return NSScreen.main ?? NSScreen.screens.first
    }

    func collectWindowsOnCurrentSpace(screenBounds: CGRect, ignoredApps: Set<String>) -> [ManagedWindow] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let cgWindows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        var onScreenMap: [CGWindowID: Int] = [:]
        for (order, win) in cgWindows.enumerated() {
            let layer = win[kCGWindowLayer as String] as? Int ?? -1
            let id = win[kCGWindowNumber as String] as? CGWindowID ?? 0
            let bounds = win[kCGWindowBounds as String] as? [String: Any] ?? [:]
            let w = bounds["Width"] as? Double ?? 0
            let h = bounds["Height"] as? Double ?? 0
            let x = bounds["X"] as? Double ?? 0
            let y = bounds["Y"] as? Double ?? 0
            let rect = CGRect(x: x, y: y, width: w, height: h)

            if layer == 0 && w >= 150 && h >= 150 && rect.intersects(screenBounds) {
                onScreenMap[id] = order
            }
        }

        var focusedWindowID: CGWindowID?
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            let appRef = AXUIElementCreateApplication(frontApp.processIdentifier)
            var focusedRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &focusedRef) == .success,
               let win = focusedRef {
                var fID: CGWindowID = 0
                if _AXUIElementGetWindow(win as! AXUIElement, &fID) == .success {
                    focusedWindowID = fID
                }
            }
        }

        var managed: [ManagedWindow] = []

        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            let appName = app.localizedName ?? ""
            if ignoredApps.contains(appName) { continue }

            let appRef = AXUIElementCreateApplication(app.processIdentifier)
            var winsRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &winsRef) == .success,
                  let wins = winsRef as? [AXUIElement] else { continue }

            for win in wins {
                var winID: CGWindowID = 0
                guard _AXUIElementGetWindow(win, &winID) == .success,
                      let zOrder = onScreenMap[winID] else {
                    continue
                }

                var minRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(win, kAXMinimizedAttribute as CFString, &minRef) == .success,
                   let isMin = minRef as? Bool, isMin {
                    continue
                }

                var titleRef: CFTypeRef?
                AXUIElementCopyAttributeValue(win, kAXTitleAttribute as CFString, &titleRef)
                let title = titleRef as? String ?? ""

                let isFocused = (winID == focusedWindowID)

                managed.append(ManagedWindow(
                    element: win,
                    id: winID,
                    appName: appName,
                    title: title,
                    isFocused: isFocused,
                    zOrder: zOrder
                ))
            }
        }

        managed.sort { a, b in
            if a.isFocused != b.isFocused {
                return a.isFocused
            }
            return a.zOrder < b.zOrder
        }

        return managed
    }

    private func setWindowFrame(_ element: AXUIElement, target: CGRect) {
        var pos = target.origin
        var size = target.size

        if let valPos = AXValueCreate(.cgPoint, &pos) {
            AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, valPos)
        }

        if let valSize = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, valSize)
        }

        if let valPos = AXValueCreate(.cgPoint, &pos) {
            AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, valPos)
        }
    }
}
