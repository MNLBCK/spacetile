import Cocoa
import ApplicationServices
import CoreGraphics

@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ id: inout CGWindowID) -> AXError

struct ManagedWindow {
    let element: AXUIElement?
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

    private let stateLock = NSLock()
    private(set) var lockedWindowIDs: Set<CGWindowID> = []
    private(set) var masterWindowID: CGWindowID?
    private var lastRunTime: Date?

    static var lockedStoreURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".config/spacetile/locked_windows.json")
    }

    static var masterStoreURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".config/spacetile/master_window.json")
    }

    init() {
        reloadLockedWindowIDs()
        reloadMasterWindowID()
    }

    func reloadMasterWindowID() {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard FileManager.default.fileExists(atPath: WindowManager.masterStoreURL.path),
              let data = try? Data(contentsOf: WindowManager.masterStoreURL),
              let id = try? JSONDecoder().decode(UInt32.self, from: data) else {
            self.masterWindowID = nil
            return
        }
        self.masterWindowID = CGWindowID(id)
    }

    func persistMasterWindowID() {
        stateLock.lock()
        let currentID = masterWindowID
        stateLock.unlock()

        let url = WindowManager.masterStoreURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let id = currentID {
            if let data = try? JSONEncoder().encode(UInt32(id)) {
                try? data.write(to: url, options: .atomic)
            }
        } else {
            try? FileManager.default.removeItem(at: url)
        }
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("com.guppi.spacetile.masterChanged"),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    func setMasterWindow(id: CGWindowID) {
        stateLock.lock()
        self.masterWindowID = id
        stateLock.unlock()
        persistMasterWindowID()
        _ = optimize(verbose: true, forcedMasterID: id)
    }

    func clearMasterWindow() {
        stateLock.lock()
        self.masterWindowID = nil
        stateLock.unlock()
        persistMasterWindowID()
        _ = optimize(verbose: true)
    }

    func reloadLockedWindowIDs() {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard FileManager.default.fileExists(atPath: WindowManager.lockedStoreURL.path),
              let data = try? Data(contentsOf: WindowManager.lockedStoreURL),
              let list = try? JSONDecoder().decode([UInt32].self, from: data) else {
            self.lockedWindowIDs = []
            return
        }
        self.lockedWindowIDs = Set(list.map { CGWindowID($0) })
    }

    func persistLockedWindowIDs() {
        stateLock.lock()
        let list = Array(lockedWindowIDs).map { UInt32($0) }
        stateLock.unlock()

        let url = WindowManager.lockedStoreURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(list) {
            try? data.write(to: url, options: .atomic)
        }
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("com.guppi.spacetile.locksChanged"),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    func setWindowLocked(id: CGWindowID, locked: Bool) {
        reloadLockedWindowIDs()
        if locked {
            lockedWindowIDs.insert(id)
        } else {
            lockedWindowIDs.remove(id)
        }
        persistLockedWindowIDs()
    }

    static func isAccessibilityGranted(prompt: Bool = false) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func canControlWindows() -> Bool {
        if isAccessibilityGranted(prompt: false) {
            return true
        }
        // Direct probe against an EXTERNAL application (never ourselves!)
        let myPid = NSRunningApplication.current.processIdentifier
        for app in NSWorkspace.shared.runningApplications {
            if app.processIdentifier != myPid && app.activationPolicy == .regular {
                let appRef = AXUIElementCreateApplication(app.processIdentifier)
                var winRef: CFTypeRef?
                let status = AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &winRef)
                if status == .success {
                    return true
                }
                if status.rawValue == -25211 { // kAXErrorAPIDisabled
                    return false
                }
            }
        }
        return false
    }

    static func ensureAccessibility(prompt: Bool = true) -> Bool {
        if canControlWindows() {
            return true
        }
        if prompt {
            _ = isAccessibilityGranted(prompt: true)
        }
        return canControlWindows()
    }

    func toggleLockForFocusedWindow() -> (locked: Bool, appName: String)? {
        reloadLockedWindowIDs()
        guard let front = NSWorkspace.shared.frontmostApplication else { return nil }
        let appRef = AXUIElementCreateApplication(front.processIdentifier)
        var winRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &winRef) == .success,
              let win = winRef, CFGetTypeID(win) == AXUIElementGetTypeID() else { return nil }

        var winID: CGWindowID = 0
        guard _AXUIElementGetWindow(win as! AXUIElement, &winID) == .success else { return nil }

        let appName = front.localizedName ?? "App"
        if lockedWindowIDs.contains(winID) {
            lockedWindowIDs.remove(winID)
            persistLockedWindowIDs()
            print("[\u{001B}[33mSpaceTile\u{001B}[0m] Unlocked window for '\(appName)' (ID: \(winID))")
            return (false, appName)
        } else {
            lockedWindowIDs.insert(winID)
            persistLockedWindowIDs()
            print("[\u{001B}[32mSpaceTile\u{001B}[0m] Locked window for '\(appName)' (ID: \(winID)) at current position.")
            return (true, appName)
        }
    }

    func setFocusedAsMaster() -> Bool {
        guard let front = NSWorkspace.shared.frontmostApplication else { return false }
        if front.processIdentifier == ProcessInfo.processInfo.processIdentifier || front.localizedName == "SpaceTile" {
            return false
        }
        let appRef = AXUIElementCreateApplication(front.processIdentifier)
        var winRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &winRef) == .success,
              let win = winRef, CFGetTypeID(win) == AXUIElementGetTypeID() else { return false }

        var winID: CGWindowID = 0
        guard _AXUIElementGetWindow(win as! AXUIElement, &winID) == .success else { return false }

        setMasterWindow(id: winID)
        return true
    }

    @discardableResult
    func optimize(verbose: Bool = true, forcedMasterID: CGWindowID? = nil, forcedRatio: Double? = nil) -> Bool {
        guard WindowManager.ensureAccessibility(prompt: true) else {
            print("[\u{001B}[31mERROR\u{001B}[0m] Accessibility permission not granted!")
            return false
        }

        reloadLockedWindowIDs()
        reloadMasterWindowID()
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

        // Handle forced master or active master
        let effectiveMasterID = forcedMasterID ?? masterWindowID
        if let fid = effectiveMasterID, let idx = windows.firstIndex(where: { $0.id == fid }) {
            let chosen = windows.remove(at: idx)
            windows.insert(chosen, at: 0)
            if masterWindowID != fid {
                masterWindowID = fid
                persistMasterWindowID()
            }
        }

        // Apply learned ratio from SpaceMemory if not forced
        var effectiveRatio = forcedRatio
        if effectiveRatio == nil && config.enableSpaceLearning {
            let appNames = Array(Set(windows.map { $0.appName })).sorted()
            let resKey = "\(Int(targetScreen.frame.width))x\(Int(targetScreen.frame.height))"
            if let profile = SpaceMemory.shared.findProfile(apps: appNames, resolution: resKey),
               let learned = profile.learnedMasterRatio {
                effectiveRatio = learned
                if verbose {
                    print("[\u{001B}[32mSpaceMemory\u{001B}[0m] Applied learned ratio: \(Int(learned * 100))% for [\(appNames.joined(separator: ", "))]")
                }
            }
        }

        // Calculate layout with Grid & Scoring Engine (with strict tile reservation for locked windows)
        let frames = calculateGridScoringLayout(
            windows: windows,
            workArea: workArea,
            screen: targetScreen,
            config: config,
            forcedRatio: effectiveRatio
        )

        // Apply frames
        if config.animationMode == "smooth" && config.animationDuration > 0.02 {
            var moves: [(element: AXUIElement, start: CGRect, target: CGRect)] = []
            for (i, win) in windows.enumerated() {
                if win.isLocked { continue }
                if let elem = win.element {
                    moves.append((element: elem, start: win.currentFrame, target: frames[i]))
                }
            }
            animateWindowsSmooth(
                moves: moves,
                duration: config.animationDuration,
                steps: config.animationSteps,
                freezeContent: config.freezeContentDuringResize
            )
        } else {
            for (i, win) in windows.enumerated() {
                if win.isLocked { continue }
                if let elem = win.element {
                    setWindowFrameImmediate(elem, target: frames[i])
                }
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

        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("com.guppi.spacetile.windowsRearranged"),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )

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

        var resultFrames = windows.map { $0.currentFrame }
        let lockedIndices = windows.indices.filter { windows[$0].isLocked }
        let unlockedIndices = windows.indices.filter { !windows[$0].isLocked }

        // If all windows are locked, keep current frames
        if unlockedIndices.isEmpty {
            return resultFrames
        }

        // Case A: NO windows are locked -> Standard unconstrained layout across entire workArea
        if lockedIndices.isEmpty {
            return calculateUnconstrainedLayout(
                windows: windows,
                workArea: workArea,
                screen: screen,
                config: config,
                forcedRatio: forcedRatio
            )
        }

        // Case B: ONE OR MORE windows are locked -> Reserve their grid tiles!
        let gap = config.gap
        let is4K = screen.frame.width >= 2560
        let totalCols: Int = is4K ? 12 : 6
        let totalRows: Int = is4K ? 6 : 4

        let colWidth = (workArea.width - CGFloat(totalCols - 1) * gap) / CGFloat(totalCols)
        let rowHeight = (workArea.height - CGFloat(totalRows - 1) * gap) / CGFloat(totalRows)

        func rectFor(col: Int, row: Int, colSpan: Int, rowSpan: Int) -> CGRect {
            let x = workArea.origin.x + CGFloat(col) * (colWidth + gap)
            let y = workArea.origin.y + CGFloat(row) * (rowHeight + gap)
            let w = CGFloat(colSpan) * colWidth + CGFloat(colSpan - 1) * gap
            let h = CGFloat(rowSpan) * rowHeight + CGFloat(rowSpan - 1) * gap
            return CGRect(x: floor(x), y: floor(y), width: floor(w), height: floor(h))
        }

        // Initialize 2D grid
        var isFree = Array(repeating: Array(repeating: true, count: totalRows), count: totalCols)

        // Lock tiles under locked windows
        for lIdx in lockedIndices {
            let curFrame = windows[lIdx].currentFrame
            resultFrames[lIdx] = curFrame

            for c in 0..<totalCols {
                for r in 0..<totalRows {
                    let cell = rectFor(col: c, row: r, colSpan: 1, rowSpan: 1)
                    let overlap = cell.intersection(curFrame)
                    if !overlap.isNull && overlap.width > cell.width * 0.20 && overlap.height > cell.height * 0.20 {
                        isFree[c][r] = false
                    }
                }
            }
        }

        // Find bounding box of free cells
        var minFreeCol = totalCols
        var maxFreeCol = -1
        var minFreeRow = totalRows
        var maxFreeRow = -1
        var freeCount = 0

        for c in 0..<totalCols {
            for r in 0..<totalRows {
                if isFree[c][r] {
                    freeCount += 1
                    minFreeCol = min(minFreeCol, c)
                    maxFreeCol = max(maxFreeCol, c)
                    minFreeRow = min(minFreeRow, r)
                    maxFreeRow = max(maxFreeRow, r)
                }
            }
        }

        if freeCount == 0 {
            return resultFrames
        }

        // Check if the free space forms a solid rectangular sub-workArea
        var isSolidSubRect = true
        for c in minFreeCol...maxFreeCol {
            for r in minFreeRow...maxFreeRow {
                if !isFree[c][r] {
                    isSolidSubRect = false
                    break
                }
            }
            if !isSolidSubRect { break }
        }

        if isSolidSubRect {
            let subCols = maxFreeCol - minFreeCol + 1
            let subRows = maxFreeRow - minFreeRow + 1
            let subWorkArea = rectFor(col: minFreeCol, row: minFreeRow, colSpan: subCols, rowSpan: subRows)

            let subWindows = unlockedIndices.map { windows[$0] }
            let subFrames = calculateUnconstrainedLayout(
                windows: subWindows,
                workArea: subWorkArea,
                screen: screen,
                config: config,
                forcedRatio: forcedRatio
            )

            for (i, uIdx) in unlockedIndices.enumerated() {
                resultFrames[uIdx] = subFrames[i]
            }
            return resultFrames
        }

        // Free cells form non-rectangular or fragmented areas (e.g. L-shape) -> Allocate maximal free rectangles
        struct FreeRect {
            let col: Int
            let row: Int
            let colSpan: Int
            let rowSpan: Int
            var area: Int { colSpan * rowSpan }
        }

        func findLargestFreeRect() -> FreeRect? {
            var best: FreeRect? = nil
            for c in 0..<totalCols {
                for r in 0..<totalRows {
                    if isFree[c][r] {
                        var maxW = 0
                        while c + maxW < totalCols && isFree[c + maxW][r] {
                            maxW += 1
                        }
                        for w in 1...maxW {
                            var maxH = 0
                            while r + maxH < totalRows {
                                var rowOk = true
                                for dc in 0..<w {
                                    if !isFree[c + dc][r + maxH] {
                                        rowOk = false
                                        break
                                    }
                                }
                                if !rowOk { break }
                                maxH += 1
                            }
                            if maxH > 0 {
                                let candidate = FreeRect(col: c, row: r, colSpan: w, rowSpan: maxH)
                                if best == nil || candidate.area > best!.area {
                                    best = candidate
                                }
                            }
                        }
                    }
                }
            }
            return best
        }

        for (i, uIdx) in unlockedIndices.enumerated() {
            guard let best = findLargestFreeRect() else { break }
            let remainingCount = unlockedIndices.count - (i + 1)

            var spanC = best.colSpan
            var spanR = best.rowSpan

            if remainingCount > 0 {
                if best.colSpan >= 4 && best.colSpan >= best.rowSpan {
                    spanC = max(2, best.colSpan * 6 / 10)
                } else if best.rowSpan >= 4 {
                    spanR = max(2, best.rowSpan / 2)
                }
            }

            for dc in 0..<spanC {
                for dr in 0..<spanR {
                    if best.col + dc < totalCols && best.row + dr < totalRows {
                        isFree[best.col + dc][best.row + dr] = false
                    }
                }
            }

            resultFrames[uIdx] = rectFor(col: best.col, row: best.row, colSpan: spanC, rowSpan: spanR)
        }

        return resultFrames
    }

    private func calculateUnconstrainedLayout(
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

        var resultFrames = windows.map { $0.currentFrame }

        // Single Window
        if count == 1 {
            if config.singleWindowMode == "maximized" {
                resultFrames[0] = workArea
            } else {
                let w = floor(workArea.width * 0.72)
                let h = floor(workArea.height * 0.94)
                let x = floor(workArea.origin.x + (workArea.width - w) / 2)
                let y = floor(workArea.origin.y + (workArea.height - h) / 2)
                resultFrames[0] = CGRect(x: x, y: y, width: w, height: h)
            }
            return resultFrames
        }

        // 2 Windows
        if count == 2 {
            let w0 = windows[0]
            let w1 = windows[1]

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
            resultFrames[0] = rectFor(col: 0, row: 0, colSpan: masterCols, rowSpan: totalRows)
            resultFrames[1] = rectFor(col: masterCols, row: 0, colSpan: stackCols, rowSpan: totalRows)
            return resultFrames
        }

        // 3 Windows
        if count == 3 {
            let masterWin = windows[0]
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
            resultFrames[0] = rectFor(col: 0, row: 0, colSpan: masterCols, rowSpan: totalRows)
            resultFrames[1] = rectFor(col: masterCols, row: 0, colSpan: stackCols, rowSpan: r0)
            resultFrames[2] = rectFor(col: masterCols, row: r0, colSpan: stackCols, rowSpan: r1)
            return resultFrames
        }

        // 4+ Windows: Use the 3x3 Signature Layout
        let masterWin = windows[0]
        let isTermMaster = masterWin.score <= 35 ||
                           masterWin.appName.lowercased().contains("term") ||
                           masterWin.appName.lowercased().contains("kitty") ||
                           masterWin.appName.lowercased().contains("ghostty") ||
                           masterWin.appName.lowercased().contains("alacritty")

        let cellW3 = (workArea.width - 2 * gap) / 3.0
        let cellH3 = (workArea.height - 2 * gap) / 3.0

        // If Master is a Terminal on 4K, cap its width to ~1024px (never stretch to 2540px!)
        if isTermMaster && is4K {
            let termW: CGFloat = min(cellW3, CGFloat(masterWin.maxWidth ?? 1024))
            let remW: CGFloat = workArea.width - termW - gap
            let remColW: CGFloat = (remW - gap) / 2.0
            let rightX: CGFloat = workArea.origin.x + termW + gap
            let col1X = rightX
            let col2X = rightX + remColW + gap

            // Master Terminal: Col 0, 2 rows high (~1024px x 1334px)
            resultFrames[0] = CGRect(x: floor(workArea.origin.x), y: floor(workArea.origin.y), width: floor(termW), height: floor(2 * cellH3 + gap))

            if count == 4 {
                // Main secondary window gets top-right wide viewport (remW x 2/3 height)
                resultFrames[1] = CGRect(x: floor(rightX), y: floor(workArea.origin.y), width: floor(remW), height: floor(2 * cellH3 + gap))
                // Bottom left under terminal
                resultFrames[2] = CGRect(x: floor(workArea.origin.x), y: floor(workArea.origin.y + 2 * (cellH3 + gap)), width: floor(termW), height: floor(cellH3))
                // Bottom right under main secondary
                resultFrames[3] = CGRect(x: floor(rightX), y: floor(workArea.origin.y + 2 * (cellH3 + gap)), width: floor(remW), height: floor(cellH3))
                return resultFrames
            }

            if count == 5 {
                // Secondary 0: wide top area (remW x 2/3 height)
                resultFrames[1] = CGRect(x: floor(rightX), y: floor(workArea.origin.y), width: floor(remW), height: floor(2 * cellH3 + gap))
                // Bottom left under terminal
                resultFrames[2] = CGRect(x: floor(workArea.origin.x), y: floor(workArea.origin.y + 2 * (cellH3 + gap)), width: floor(termW), height: floor(cellH3))
                // Bottom two side-by-side
                resultFrames[3] = CGRect(x: floor(col1X), y: floor(workArea.origin.y + 2 * (cellH3 + gap)), width: floor(remColW), height: floor(cellH3))
                resultFrames[4] = CGRect(x: floor(col2X), y: floor(workArea.origin.y + 2 * (cellH3 + gap)), width: floor(remColW), height: floor(cellH3))
                return resultFrames
            }

            if count == 6 {
                // 1 Terminal Master (1024px, 2/3 height) + 1 Bottom-Left under terminal (1024px, 1/3 height)
                // Right side: 4 windows in clean 2x2 grid (each remColW ~1380px x cellH3 ~662px)
                resultFrames[1] = CGRect(x: floor(workArea.origin.x), y: floor(workArea.origin.y + 2 * (cellH3 + gap)), width: floor(termW), height: floor(cellH3))
                resultFrames[2] = CGRect(x: floor(col1X), y: floor(workArea.origin.y), width: floor(remColW), height: floor(cellH3))
                resultFrames[3] = CGRect(x: floor(col2X), y: floor(workArea.origin.y), width: floor(remColW), height: floor(cellH3))
                resultFrames[4] = CGRect(x: floor(col1X), y: floor(workArea.origin.y + cellH3 + gap), width: floor(remColW), height: floor(cellH3))
                resultFrames[5] = CGRect(x: floor(col2X), y: floor(workArea.origin.y + cellH3 + gap), width: floor(remColW), height: floor(cellH3))
                return resultFrames
            }

            // 7+ Windows: Terminal Master (~1024px) + right area tiled evenly
            resultFrames[1] = CGRect(x: floor(workArea.origin.x), y: floor(workArea.origin.y + 2 * (cellH3 + gap)), width: floor(termW), height: floor(cellH3))
            let remList = Array(windows.indices.dropFirst(2))
            let rightRows = max(1, (remList.count + 1) / 2)
            let rightH = (workArea.height - CGFloat(rightRows - 1) * gap) / CGFloat(rightRows)
            for (idx, rIdx) in remList.enumerated() {
                let col = idx % 2
                let row = idx / 2
                let cx = col == 0 ? col1X : col2X
                let cy = workArea.origin.y + CGFloat(row) * (rightH + gap)
                resultFrames[rIdx] = CGRect(x: floor(cx), y: floor(cy), width: floor(remColW), height: floor(rightH))
            }
            return resultFrames
        }

        func rect3x3(c: Int, r: Int, cSpan: Int, rSpan: Int) -> CGRect {
            let x = workArea.origin.x + CGFloat(c) * (cellW3 + gap)
            let y = workArea.origin.y + CGFloat(r) * (cellH3 + gap)
            let w = CGFloat(cSpan) * cellW3 + CGFloat(cSpan - 1) * gap
            let h = CGFloat(rSpan) * cellH3 + CGFloat(rSpan - 1) * gap
            return CGRect(x: floor(x), y: floor(y), width: floor(w), height: floor(h))
        }

        if count == 4 {
            // Master (2/3 width, 2/3 height)
            resultFrames[0] = rect3x3(c: 0, r: 0, cSpan: 2, rSpan: 2)
            // Bottom (under master: 2/3 width, 1/3 height)
            resultFrames[1] = rect3x3(c: 0, r: 2, cSpan: 2, rSpan: 1)
            // Right stack (2 windows: 1/3 width, 1/2 height each)
            let halfH = (workArea.height - gap) / 2.0
            let rightX = workArea.origin.x + 2 * (cellW3 + gap)
            resultFrames[2] = CGRect(x: floor(rightX), y: floor(workArea.origin.y), width: floor(cellW3), height: floor(halfH))
            resultFrames[3] = CGRect(x: floor(rightX), y: floor(workArea.origin.y + halfH + gap), width: floor(cellW3), height: floor(halfH))
            return resultFrames
        }

        if count == 5 {
            // Master (2/3 width, 2/3 height)
            resultFrames[0] = rect3x3(c: 0, r: 0, cSpan: 2, rSpan: 2)
            // Bottom 2 windows (under master: each 1/3 width, 1/3 height)
            resultFrames[1] = rect3x3(c: 0, r: 2, cSpan: 1, rSpan: 1)
            resultFrames[2] = rect3x3(c: 1, r: 2, cSpan: 1, rSpan: 1)
            // Right stack (2 windows: 1/3 width, 1/2 height each)
            let halfH = (workArea.height - gap) / 2.0
            let rightX = workArea.origin.x + 2 * (cellW3 + gap)
            resultFrames[3] = CGRect(x: floor(rightX), y: floor(workArea.origin.y), width: floor(cellW3), height: floor(halfH))
            resultFrames[4] = CGRect(x: floor(rightX), y: floor(workArea.origin.y + halfH + gap), width: floor(cellW3), height: floor(halfH))
            return resultFrames
        }

        if count == 6 {
            // THE EXACT 6-WINDOW SIGNATURE 3x3 LAYOUT:
            // Master (Top-Left: 2/3 width, 2/3 height)
            resultFrames[0] = rect3x3(c: 0, r: 0, cSpan: 2, rSpan: 2)
            // Right 1 (Top-Right: 1/3 width, 1/3 height)
            resultFrames[1] = rect3x3(c: 2, r: 0, cSpan: 1, rSpan: 1)
            // Right 2 (Mid-Right: 1/3 width, 1/3 height)
            resultFrames[2] = rect3x3(c: 2, r: 1, cSpan: 1, rSpan: 1)
            // Right 3 (Bottom-Right: 1/3 width, 1/3 height)
            resultFrames[3] = rect3x3(c: 2, r: 2, cSpan: 1, rSpan: 1)
            // Bottom 1 (Bottom-Left: 1/3 width, 1/3 height)
            resultFrames[4] = rect3x3(c: 0, r: 2, cSpan: 1, rSpan: 1)
            // Bottom 2 (Bottom-Mid: 1/3 width, 1/3 height)
            resultFrames[5] = rect3x3(c: 1, r: 2, cSpan: 1, rSpan: 1)
            return resultFrames
        }

        // For 7+ windows: Master gets top-left 2/3, remaining split into right stack and bottom row
        resultFrames[0] = rect3x3(c: 0, r: 0, cSpan: 2, rSpan: 2)
        let remIndices = Array(windows.indices.dropFirst())
        let rightCount = (remIndices.count + 1) / 2
        let bottomCount = remIndices.count - rightCount

        let rightH = (workArea.height - CGFloat(rightCount - 1) * gap) / CGFloat(rightCount)
        let rightX = workArea.origin.x + 2 * (cellW3 + gap)
        for i in 0..<rightCount {
            let ry = workArea.origin.y + CGFloat(i) * (rightH + gap)
            resultFrames[remIndices[i]] = CGRect(x: floor(rightX), y: floor(ry), width: floor(cellW3), height: floor(rightH))
        }

        let bottomW = (2 * cellW3 + gap - CGFloat(bottomCount - 1) * gap) / CGFloat(bottomCount)
        let bottomY = workArea.origin.y + 2 * (cellH3 + gap)
        for i in 0..<bottomCount {
            let bx = workArea.origin.x + CGFloat(i) * (bottomW + gap)
            resultFrames[remIndices[rightCount + i]] = CGRect(x: floor(bx), y: floor(bottomY), width: floor(bottomW), height: floor(cellH3))
        }

        return resultFrames
    }

    // Private SkyLight SPIs for atomic display compositor updates
    typealias CGSConnectionID = UInt32
    @_silgen_name("CGSMainConnectionID") private static func CGSMainConnectionID() -> CGSConnectionID
    @_silgen_name("CGSDisableUpdate") private static func CGSDisableUpdate(_ cid: CGSConnectionID) -> Int32
    @_silgen_name("CGSReenableUpdate") private static func CGSReenableUpdate(_ cid: CGSConnectionID) -> Int32

    private func animateWindowsSmooth(
        moves: [(element: AXUIElement, start: CGRect, target: CGRect)],
        duration: Double,
        steps: Int,
        freezeContent: Bool
    ) {
        let totalSteps = max(4, min(24, steps))
        let interval = duration / Double(totalSteps)
        let cid = freezeContent ? WindowManager.CGSMainConnectionID() : 0

        defer {
            if freezeContent && cid != 0 {
                _ = WindowManager.CGSReenableUpdate(cid)
            }
        }

        for step in 1...totalSteps {
            let progress = Double(step) / Double(totalSteps)
            // Cubic easeInOut curve for natural acceleration and deceleration
            let ease: Double
            if progress < 0.5 {
                ease = 4.0 * progress * progress * progress
            } else {
                ease = 1.0 - pow(-2.0 * progress + 2.0, 3.0) / 2.0
            }

            // Suspend compositor flushing across window changes for this frame
            if freezeContent && cid != 0 {
                _ = WindowManager.CGSDisableUpdate(cid)
            }

            for move in moves {
                let curX = move.start.origin.x + (move.target.origin.x - move.start.origin.x) * ease
                let curY = move.start.origin.y + (move.target.origin.y - move.start.origin.y) * ease
                let curW = move.start.size.width + (move.target.size.width - move.start.size.width) * ease
                let curH = move.start.size.height + (move.target.size.height - move.start.size.height) * ease
                setWindowFrameStep(move.element, target: CGRect(x: curX, y: curY, width: curW, height: curH))
            }

            // Re-enable compositor flushing so WindowServer composites all windows together
            if freezeContent && cid != 0 {
                _ = WindowManager.CGSReenableUpdate(cid)
            }

            if step < totalSteps {
                usleep(useconds_t(interval * 1_000_000.0))
            }
        }

        // Final snap: ensure exact target frames
        if freezeContent && cid != 0 {
            _ = WindowManager.CGSDisableUpdate(cid)
        }
        for move in moves {
            setWindowFrameImmediate(move.element, target: move.target)
        }
        if freezeContent && cid != 0 {
            _ = WindowManager.CGSReenableUpdate(cid)
        }
    }

    private func setWindowFrameStep(_ element: AXUIElement, target: CGRect) {
        var size = target.size
        var pos = target.origin
        if let valSize = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, valSize)
        }
        if let valPos = AXValueCreate(.cgPoint, &pos) {
            AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, valPos)
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
               let focusedWin = focusedWinRef, CFGetTypeID(focusedWin) == AXUIElementGetTypeID() {
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
        reloadLockedWindowIDs()
        reloadMasterWindowID()
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let cgWindows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        // Clean up stale locked window IDs from closed windows
        let allWins = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
        let allIDs = Set(allWins.compactMap { $0[kCGWindowNumber as String] as? CGWindowID })
        let deadIDs = lockedWindowIDs.subtracting(allIDs)
        if !deadIDs.isEmpty {
            lockedWindowIDs.subtract(deadIDs)
            persistLockedWindowIDs()
        }
        if let mid = masterWindowID, !allIDs.contains(mid) {
            masterWindowID = nil
            persistMasterWindowID()
        }

        var onScreenMap: [CGWindowID: (order: Int, owner: String, title: String, bounds: CGRect)] = [:]
        for (order, win) in cgWindows.enumerated() {
            let layer = win[kCGWindowLayer as String] as? Int ?? -1
            let id = win[kCGWindowNumber as String] as? CGWindowID ?? 0
            let owner = win[kCGWindowOwnerName as String] as? String ?? ""
            let name = win[kCGWindowName as String] as? String ?? ""
            let bounds = win[kCGWindowBounds as String] as? [String: Any] ?? [:]
            let w = bounds["Width"] as? Double ?? 0
            let h = bounds["Height"] as? Double ?? 0
            let x = bounds["X"] as? Double ?? 0
            let y = bounds["Y"] as? Double ?? 0
            let rect = CGRect(x: x, y: y, width: w, height: h)

            let intersection = rect.intersection(screenBounds)
            let midPoint = CGPoint(x: rect.midX, y: rect.midY)
            let isMajorityOnScreen = !intersection.isNull && (intersection.width * intersection.height >= (rect.width * rect.height) * 0.5)
            if layer == 0 && w >= 150 && h >= 150 && (screenBounds.contains(midPoint) || isMajorityOnScreen) {
                if !ignoredApps.contains(owner) && owner != "SpaceTile" {
                    onScreenMap[id] = (order: order, owner: owner, title: name, bounds: rect)
                }
            }
        }

        var focusedWindowID: CGWindowID?
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            let appRef = AXUIElementCreateApplication(frontApp.processIdentifier)
            AXUIElementSetMessagingTimeout(appRef, 0.25)
            var focusedRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &focusedRef) == .success,
               let win = focusedRef, CFGetTypeID(win) == AXUIElementGetTypeID() {
                var fID: CGWindowID = 0
                if _AXUIElementGetWindow(win as! AXUIElement, &fID) == .success {
                    focusedWindowID = fID
                }
            }
        }

        var managed: [ManagedWindow] = []
        var matchedIDs = Set<CGWindowID>()

        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            let appName = app.localizedName ?? ""
            if ignoredApps.contains(appName) || appName == "SpaceTile" { continue }

            let appRef = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(appRef, 0.25)
            var winsRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &winsRef) == .success,
                  let wins = winsRef as? [AXUIElement] else { continue }

            for win in wins {
                var winID: CGWindowID = 0
                guard _AXUIElementGetWindow(win, &winID) == .success,
                      let info = onScreenMap[winID] else {
                    continue
                }

                var minRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(win, kAXMinimizedAttribute as CFString, &minRef) == .success,
                   let isMin = minRef as? Bool, isMin {
                    continue
                }

                // Filter fullscreen windows
                var fullRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(win, "AXFullScreen" as CFString, &fullRef) == .success,
                   let isFull = fullRef as? Bool, isFull {
                    continue
                }

                // Filter non-resizable windows / fixed modal dialogs
                var settable: DarwinBoolean = false
                if AXUIElementIsAttributeSettable(win, kAXSizeAttribute as CFString, &settable) == .success,
                   !settable.boolValue {
                    continue
                }

                matchedIDs.insert(winID)

                var titleRef: CFTypeRef?
                AXUIElementCopyAttributeValue(win, kAXTitleAttribute as CFString, &titleRef)
                let title = (titleRef as? String)?.isEmpty == false ? (titleRef as! String) : info.title

                let isFocused = (winID == focusedWindowID)
                let isLocked = lockedWindowIDs.contains(winID)
                let currentFrame = getWindowFrame(win) ?? info.bounds

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
                    zOrder: info.order,
                    isLocked: isLocked,
                    currentFrame: currentFrame,
                    score: score,
                    minWidth: minW,
                    minHeight: minH,
                    maxWidth: maxW
                ))
            }
        }

        // Add any remaining on-screen windows that weren't matched via AX only if locked (to reserve their tiles)
        for (winID, info) in onScreenMap {
            if !matchedIDs.contains(winID) && lockedWindowIDs.contains(winID) {
                let weightConfig = config.appWeights.first(where: { $0.appName.lowercased() == info.owner.lowercased() })
                let score = weightConfig?.score ?? defaultScoreFor(appName: info.owner)
                let minW = weightConfig?.minWidth ?? 450
                let minH = weightConfig?.minHeight ?? 350
                let maxW = weightConfig?.maxWidth

                managed.append(ManagedWindow(
                    element: nil,
                    id: winID,
                    appName: info.owner,
                    title: info.title,
                    isFocused: (winID == focusedWindowID),
                    zOrder: info.order,
                    isLocked: true,
                    currentFrame: info.bounds,
                    score: score,
                    minWidth: minW,
                    minHeight: minH,
                    maxWidth: maxW
                ))
            }
        }

        managed.sort { a, b in
            if let mid = masterWindowID {
                if a.id == mid && b.id != mid { return true }
                if b.id == mid && a.id != mid { return false }
            }
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
              let p = posRef, let s = sizeRef,
              CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID() else {
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
