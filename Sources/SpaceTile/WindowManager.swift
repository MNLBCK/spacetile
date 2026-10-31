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
    var isLocked: Bool
    var currentFrame: CGRect
    var score: Int
    var minWidth: Double
    var minHeight: Double
    var maxWidth: Double?
}

class WindowManager {
    static let shared = WindowManager()

    private(set) var lockedWindowIDs: Set<CGWindowID> = []
    private var lastRunTime: Date?

    func setWindowLocked(id: CGWindowID, locked: Bool) {
        if locked {
            lockedWindowIDs.insert(id)
        } else {
            lockedWindowIDs.remove(id)
        }
    }

    static func ensureAccessibility(prompt: Bool = true) -> Bool {
        let trusted = AXIsProcessTrusted()
        if !trusted && prompt {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
        return trusted
    }

    func toggleLockForFocusedWindow() -> (locked: Bool, appName: String)? {
        guard let front = NSWorkspace.shared.frontmostApplication else { return nil }
        let appRef = AXUIElementCreateApplication(front.processIdentifier)
        var winRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &winRef) == .success,
              let win = winRef else { return nil }

        var winID: CGWindowID = 0
        guard _AXUIElementGetWindow(win as! AXUIElement, &winID) == .success else { return nil }

        let appName = front.localizedName ?? "App"
        if lockedWindowIDs.contains(winID) {
            lockedWindowIDs.remove(winID)
            print("[\u{001B}[33mSpaceTile\u{001B}[0m] Unlocked window for '\(appName)' (ID: \(winID))")
            return (false, appName)
        } else {
            lockedWindowIDs.insert(winID)
            print("[\u{001B}[32mSpaceTile\u{001B}[0m] Locked window for '\(appName)' (ID: \(winID)) at current position.")
            return (true, appName)
        }
    }

    func setFocusedAsMaster() -> Bool {
        guard let front = NSWorkspace.shared.frontmostApplication else { return false }
        let appRef = AXUIElementCreateApplication(front.processIdentifier)
        var winRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &winRef) == .success,
              let win = winRef else { return false }

        var winID: CGWindowID = 0
        guard _AXUIElementGetWindow(win as! AXUIElement, &winID) == .success else { return false }

        return optimize(verbose: true, forcedMasterID: winID)
    }

    @discardableResult
    func optimize(verbose: Bool = true, forcedMasterID: CGWindowID? = nil, forcedRatio: Double? = nil) -> Bool {
        guard WindowManager.ensureAccessibility(prompt: true) else {
            print("[\u{001B}[31mERROR\u{001B}[0m] Accessibility permission not granted!")
            return false
        }

        let config = Config.load()

        guard let targetScreen = findTargetScreen() else {
            if verbose { print("[\u{001B}[31mERROR\u{001B}[0m] Target screen not found.") }
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

        var windows = collectWindowsOnCurrentSpace(screenBounds: axVisibleRect, ignoredApps: Set(config.ignoredApps), config: config)
        if windows.isEmpty {
            if verbose { print("[\u{001B}[33mINFO\u{001B}[0m] No active windows in current Space.") }
            return true
        }

        // Handle forced master
        if let fid = forcedMasterID, let idx = windows.firstIndex(where: { $0.id == fid }) {
            let chosen = windows.remove(at: idx)
            windows.insert(chosen, at: 0)
        }

        // Calculate layout with Grid & Scoring Engine
        let frames = calculateGridScoringLayout(
            windows: windows,
            workArea: workArea,
            screen: targetScreen,
            config: config,
            forcedRatio: forcedRatio
        )

        // Apply frames
        if config.animationMode == "smooth" && config.animationDuration > 0.05 {
            var moves: [(element: AXUIElement, start: CGRect, target: CGRect)] = []
            for (i, win) in windows.enumerated() {
                if win.isLocked { continue }
                moves.append((element: win.element, start: win.currentFrame, target: frames[i]))
            }
            animateWindowsSmooth(moves: moves, duration: config.animationDuration)
        } else {
            for (i, win) in windows.enumerated() {
                if win.isLocked { continue }
                setWindowFrameImmediate(win.element, target: frames[i])
            }
        }

        if verbose {
            print("[\u{001B}[32mSpaceTile\u{001B}[0m] Arranged \(windows.count) windows on '\(targetScreen.localizedName)'")
            for (i, win) in windows.enumerated() {
                let tag = win.isLocked ? "\u{001B}[33m🔒 Locked\u{001B}[0m" : (i == 0 ? "\u{001B}[32m★ Master\u{001B}[0m" : "  Stack ")
                let f = frames[i]
                print(String(format: " %@[%@ (Score %d)] -> %dx%d @ (%d, %d)",
                             tag, win.appName, win.score, Int(f.width), Int(f.height), Int(f.origin.x), Int(f.origin.y)))
            }
        }

        return true
    }

    // MARK: - Dynamic Grid & Score Layout Engine
    private func calculateGridScoringLayout(
        windows: [ManagedWindow],
        workArea: CGRect,
        screen: NSScreen,
        config: Config,
        forcedRatio: Double?
    ) -> [CGRect] {
        let count = windows.count
        guard count > 0 else { return [] }

        let gap = config.gap
        let is4K = screen.frame.width >= 2560

        // Dynamic Grid: 10 Cols x 6 Rows on 4K/Ultrawide (60 tiles), 6 Cols x 4 Rows on standard
        let totalCols: Int = is4K ? 10 : (count <= 2 ? 6 : 8)
        let totalRows: Int = is4K ? 6 : (count <= 2 ? 2 : 4)

        let colWidth = (workArea.width - CGFloat(totalCols - 1) * gap) / CGFloat(totalCols)
        let rowHeight = (workArea.height - CGFloat(totalRows - 1) * gap) / CGFloat(totalRows)

        // Helper to convert grid coords (colStart, rowStart, colSpan, rowSpan) to CGRect
        func rectFor(col: Int, row: Int, colSpan: Int, rowSpan: Int) -> CGRect {
            let x = workArea.origin.x + CGFloat(col) * (colWidth + gap)
            let y = workArea.origin.y + CGFloat(row) * (rowHeight + gap)
            let w = CGFloat(colSpan) * colWidth + CGFloat(colSpan - 1) * gap
            let h = CGFloat(rowSpan) * rowHeight + CGFloat(rowSpan - 1) * gap
            return CGRect(x: floor(x), y: floor(y), width: floor(w), height: floor(h))
        }

        // If any window is locked, preserve its current frame
        var resultFrames = windows.map { $0.currentFrame }

        // Find available bounding space excluding locked windows
        let unlockedIndices = windows.indices.filter { !windows[$0].isLocked }
        if unlockedIndices.isEmpty { return resultFrames }

        // Single Unlocked Window
        if unlockedIndices.count == 1 {
            let idx = unlockedIndices[0]
            if config.singleWindowMode == "maximized" {
                resultFrames[idx] = workArea
            } else {
                let w = floor(workArea.width * 0.72)
                let h = floor(workArea.height * 0.94)
                let x = floor(workArea.origin.x + (workArea.width - w) / 2)
                let y = floor(workArea.origin.y + (workArea.height - h) / 2)
                resultFrames[idx] = CGRect(x: x, y: y, width: w, height: h)
            }
            return resultFrames
        }

        // 2 Unlocked Windows
        if unlockedIndices.count == 2 {
            let i0 = unlockedIndices[0]
            let i1 = unlockedIndices[1]
            let w0 = windows[i0]
            let w1 = windows[i1]

            // Determine column split based on score or forced ratio
            let masterCols: Int
            if let fr = forcedRatio {
                masterCols = max(2, min(totalCols - 2, Int(round(Double(totalCols) * fr))))
            } else if config.sideBySideForNotesAndBrowser &&
                      ((w0.score >= 65 && w1.score <= 55) || (w1.score >= 65 && w0.score <= 55)) {
                // Notes + Browser: Equal 50/50 split
                masterCols = totalCols / 2
            } else {
                // If w0 is Terminal (low score ~30): give it 3-4 cols max on 10-col grid
                if w0.score <= 35 && is4K {
                    masterCols = 3 // 30% width: ~1140px on 4K! PERFECT FOR TERMINAL!
                } else if w1.score <= 35 && is4K && w0.score > 50 {
                    masterCols = 7 // 70% width for browser, 30% for terminal
                } else {
                    let totalScore = max(1, w0.score + w1.score)
                    let ratio = Double(w0.score) / Double(totalScore)
                    masterCols = max(3, min(totalCols - 3, Int(round(Double(totalCols) * ratio))))
                }
            }

            let stackCols = totalCols - masterCols
            resultFrames[i0] = rectFor(col: 0, row: 0, colSpan: masterCols, rowSpan: totalRows)
            resultFrames[i1] = rectFor(col: masterCols, row: 0, colSpan: stackCols, rowSpan: totalRows)
            return resultFrames
        }

        // 3 Unlocked Windows
        if unlockedIndices.count == 3 {
            let mIdx = unlockedIndices[0]
            let s0 = unlockedIndices[1]
            let s1 = unlockedIndices[2]

            let masterWin = windows[mIdx]
            let masterCols: Int
            if let fr = forcedRatio {
                masterCols = max(2, min(totalCols - 2, Int(round(Double(totalCols) * fr))))
            } else if masterWin.score <= 35 && is4K {
                masterCols = 3
            } else {
                masterCols = is4K ? 6 : (totalCols * 6 / 10)
            }

            let stackCols = totalCols - masterCols
            let r0 = totalRows / 2
            let r1 = totalRows - r0
            resultFrames[mIdx] = rectFor(col: 0, row: 0, colSpan: masterCols, rowSpan: totalRows)
            resultFrames[s0] = rectFor(col: masterCols, row: 0, colSpan: stackCols, rowSpan: r0)
            resultFrames[s1] = rectFor(col: masterCols, row: r0, colSpan: stackCols, rowSpan: r1)
            return resultFrames
        }

        // 4+ Unlocked Windows: Use the 3x3 Signature Layout (Master top-left 2/3, Right stack 1/3, Bottom stack 1/3)
        let masterIdx = unlockedIndices[0]
        let remaining = Array(unlockedIndices.dropFirst())

        let cellW3 = (workArea.width - 2 * gap) / 3.0
        let cellH3 = (workArea.height - 2 * gap) / 3.0

        func rect3x3(c: Int, r: Int, cSpan: Int, rSpan: Int) -> CGRect {
            let x = workArea.origin.x + CGFloat(c) * (cellW3 + gap)
            let y = workArea.origin.y + CGFloat(r) * (cellH3 + gap)
            let w = CGFloat(cSpan) * cellW3 + CGFloat(cSpan - 1) * gap
            let h = CGFloat(rSpan) * cellH3 + CGFloat(rSpan - 1) * gap
            return CGRect(x: floor(x), y: floor(y), width: floor(w), height: floor(h))
        }

        if unlockedIndices.count == 4 {
            // Master (2/3 width, 2/3 height)
            resultFrames[masterIdx] = rect3x3(c: 0, r: 0, cSpan: 2, rSpan: 2)
            // Bottom (under master: 2/3 width, 1/3 height)
            resultFrames[remaining[0]] = rect3x3(c: 0, r: 2, cSpan: 2, rSpan: 1)
            // Right stack (2 windows: 1/3 width, 1/2 height each)
            let halfH = (workArea.height - gap) / 2.0
            let rightX = workArea.origin.x + 2 * (cellW3 + gap)
            resultFrames[remaining[1]] = CGRect(x: floor(rightX), y: floor(workArea.origin.y), width: floor(cellW3), height: floor(halfH))
            resultFrames[remaining[2]] = CGRect(x: floor(rightX), y: floor(workArea.origin.y + halfH + gap), width: floor(cellW3), height: floor(halfH))
            return resultFrames
        }

        if unlockedIndices.count == 5 {
            // Master (2/3 width, 2/3 height)
            resultFrames[masterIdx] = rect3x3(c: 0, r: 0, cSpan: 2, rSpan: 2)
            // Bottom 2 windows (under master: each 1/3 width, 1/3 height)
            resultFrames[remaining[0]] = rect3x3(c: 0, r: 2, cSpan: 1, rSpan: 1)
            resultFrames[remaining[1]] = rect3x3(c: 1, r: 2, cSpan: 1, rSpan: 1)
            // Right stack (2 windows: 1/3 width, 1/2 height each)
            let halfH = (workArea.height - gap) / 2.0
            let rightX = workArea.origin.x + 2 * (cellW3 + gap)
            resultFrames[remaining[2]] = CGRect(x: floor(rightX), y: floor(workArea.origin.y), width: floor(cellW3), height: floor(halfH))
            resultFrames[remaining[3]] = CGRect(x: floor(rightX), y: floor(workArea.origin.y + halfH + gap), width: floor(cellW3), height: floor(halfH))
            return resultFrames
        }

        if unlockedIndices.count == 6 {
            // THE EXACT 6-WINDOW SIGNATURE 3x3 LAYOUT:
            // Master (Top-Left: 2/3 width, 2/3 height)
            resultFrames[masterIdx] = rect3x3(c: 0, r: 0, cSpan: 2, rSpan: 2)
            // Right 1 (Top-Right: 1/3 width, 1/3 height)
            resultFrames[remaining[0]] = rect3x3(c: 2, r: 0, cSpan: 1, rSpan: 1)
            // Right 2 (Mid-Right: 1/3 width, 1/3 height)
            resultFrames[remaining[1]] = rect3x3(c: 2, r: 1, cSpan: 1, rSpan: 1)
            // Right 3 (Bottom-Right: 1/3 width, 1/3 height)
            resultFrames[remaining[2]] = rect3x3(c: 2, r: 2, cSpan: 1, rSpan: 1)
            // Bottom 1 (Bottom-Left: 1/3 width, 1/3 height)
            resultFrames[remaining[3]] = rect3x3(c: 0, r: 2, cSpan: 1, rSpan: 1)
            // Bottom 2 (Bottom-Mid: 1/3 width, 1/3 height)
            resultFrames[remaining[4]] = rect3x3(c: 1, r: 2, cSpan: 1, rSpan: 1)
            return resultFrames
        }

        // For 7+ windows: Master gets top-left 2/3, remaining split into right stack and bottom row
        resultFrames[masterIdx] = rect3x3(c: 0, r: 0, cSpan: 2, rSpan: 2)
        let rightCount = (remaining.count + 1) / 2
        let bottomCount = remaining.count - rightCount

        let rightH = (workArea.height - CGFloat(rightCount - 1) * gap) / CGFloat(rightCount)
        let rightX = workArea.origin.x + 2 * (cellW3 + gap)
        for i in 0..<rightCount {
            let ry = workArea.origin.y + CGFloat(i) * (rightH + gap)
            resultFrames[remaining[i]] = CGRect(x: floor(rightX), y: floor(ry), width: floor(cellW3), height: floor(rightH))
        }

        let bottomW = (2 * cellW3 + gap - CGFloat(bottomCount - 1) * gap) / CGFloat(bottomCount)
        let bottomY = workArea.origin.y + 2 * (cellH3 + gap)
        for i in 0..<bottomCount {
            let bx = workArea.origin.x + CGFloat(i) * (bottomW + gap)
            resultFrames[remaining[rightCount + i]] = CGRect(x: floor(bx), y: floor(bottomY), width: floor(bottomW), height: floor(cellH3))
        }

        return resultFrames
    }

    private func animateWindowsSmooth(moves: [(element: AXUIElement, start: CGRect, target: CGRect)], duration: Double) {
        // Fast 4-step glide (zero lag, avoids IPC congestion)
        let steps = 4
        let interval = duration / Double(steps)

        for step in 1...steps {
            let progress = Double(step) / Double(steps)
            let ease = 1.0 - pow(1.0 - progress, 2.0)

            for move in moves {
                let curX = move.start.origin.x + (move.target.origin.x - move.start.origin.x) * ease
                let curY = move.start.origin.y + (move.target.origin.y - move.start.origin.y) * ease
                let curW = move.start.size.width + (move.target.size.width - move.start.size.width) * ease
                let curH = move.start.size.height + (move.target.size.height - move.start.size.height) * ease
                setWindowFrameImmediate(move.element, target: CGRect(x: curX, y: curY, width: curW, height: curH))
            }
            if step < steps {
                usleep(useconds_t(interval * 1_000_000.0))
            }
        }

        for move in moves {
            setWindowFrameImmediate(move.element, target: move.target)
        }
    }

    func setWindowFrameImmediate(_ element: AXUIElement, target: CGRect) {
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

    private func findTargetScreen() -> NSScreen? {
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            let appRef = AXUIElementCreateApplication(frontApp.processIdentifier)
            var focusedWinRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &focusedWinRef) == .success,
               let focusedWin = focusedWinRef {
                if let frame = getWindowFrame(focusedWin as! AXUIElement) {
                    let point = CGPoint(x: frame.midX, y: frame.midY)
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

        let mouseLoc = NSEvent.mouseLocation
        for screen in NSScreen.screens {
            if screen.frame.contains(mouseLoc) {
                return screen
            }
        }

        return NSScreen.main ?? NSScreen.screens.first
    }

    func collectWindowsOnCurrentSpace(screenBounds: CGRect, ignoredApps: Set<String>, config: Config) -> [ManagedWindow] {
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
                let isLocked = lockedWindowIDs.contains(winID)
                let currentFrame = getWindowFrame(win) ?? CGRect.zero

                // Scoring lookup
                let weightConfig = config.appWeights.first(where: { $0.appName.lowercased() == appName.lowercased() })
                let score = weightConfig?.score ?? defaultScoreFor(appName: appName)
                let minW = weightConfig?.minWidth ?? 450
                let minH = weightConfig?.minHeight ?? 350
                let maxW = weightConfig?.maxWidth

                managed.append(ManagedWindow(
                    element: win,
                    id: winID,
                    appName: appName,
                    title: title,
                    isFocused: isFocused,
                    zOrder: zOrder,
                    isLocked: isLocked,
                    currentFrame: currentFrame,
                    score: score,
                    minWidth: minW,
                    minHeight: minH,
                    maxWidth: maxW
                ))
            }
        }

        managed.sort { a, b in
            if abs(a.score - b.score) > 10 {
                return a.score > b.score
            }
            if a.isFocused != b.isFocused {
                return a.isFocused
            }
            return a.zOrder < b.zOrder
        }

        return managed
    }

    private func defaultScoreFor(appName: String) -> Int {
        let lower = appName.lowercased()
        if lower.contains("term") || lower.contains("kitty") || lower.contains("alacritty") || lower.contains("ghostty") {
            return 32
        }
        if lower.contains("chrome") || lower.contains("safari") || lower.contains("firefox") || lower.contains("arc") || lower.contains("browser") {
            return 72
        }
        if lower.contains("code") || lower.contains("xcode") || lower.contains("studio") {
            return 75
        }
        if lower.contains("notes") || lower.contains("obsidian") || lower.contains("bear") {
            return 50
        }
        return 50
    }

    private func getWindowFrame(_ element: AXUIElement) -> CGRect? {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let p = posRef, let s = sizeRef else {
            return nil
        }
        var pt = CGPoint.zero
        var sz = CGSize.zero
        guard AXValueGetValue(p as! AXValue, .cgPoint, &pt),
              AXValueGetValue(s as! AXValue, .cgSize, &sz) else {
            return nil
        }
        return CGRect(origin: pt, size: sz)
    }
}
