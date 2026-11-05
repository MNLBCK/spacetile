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
    var isFloating: Bool
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
    private(set) var floatingWindowIDs: Set<CGWindowID> = []
    private(set) var mainWindowIDs: [CGWindowID] = []
    var masterWindowID: CGWindowID? { mainWindowIDs.first }
    var secondaryFocusWindowID: CGWindowID? { mainWindowIDs.count > 1 ? mainWindowIDs[1] : nil }
    private(set) var windowScoreOverrides: [CGWindowID: Int] = [:]
    private var lastRunTime: Date?
    private var lastMasterShortcutTimestamp: TimeInterval = 0

    func setWindowScoreOverride(id: CGWindowID, score: Int) {
        stateLock.lock()
        windowScoreOverrides[id] = max(10, min(100, score))
        stateLock.unlock()
    }

    func swapWindowPositions(idA: CGWindowID, idB: CGWindowID) {
        guard WindowManager.ensureAccessibility(prompt: false) else { return }
        guard let screen = findTargetScreen() ?? NSScreen.main ?? NSScreen.screens.first else { return }
        let primaryH = NSScreen.screens.first?.frame.height ?? screen.frame.height
        let vf = screen.visibleFrame
        let axRect = CGRect(x: vf.origin.x, y: primaryH - (vf.origin.y + vf.height), width: vf.width, height: vf.height)
        let config = Config.load()
        let wins = collectWindowsOnCurrentSpace(screenBounds: axRect, ignoredApps: Set(config.ignoredApps), config: config)

        guard let winA = wins.first(where: { $0.id == idA }), let elemA = winA.element,
              let winB = wins.first(where: { $0.id == idB }), let elemB = winB.element else { return }

        let frameA = winA.currentFrame
        let frameB = winB.currentFrame

        // Physically exchange their frames on screen
        setWindowFrameImmediate(elemA, target: frameB)
        setWindowFrameImmediate(elemB, target: frameA)

        // If one of them was in mainWindowIDs, exchange them
        stateLock.lock()
        if let idxA = mainWindowIDs.firstIndex(of: idA) {
            if let idxB = mainWindowIDs.firstIndex(of: idB) {
                mainWindowIDs.swapAt(idxA, idxB)
            } else {
                mainWindowIDs[idxA] = idB
            }
        } else if let idxB = mainWindowIDs.firstIndex(of: idB) {
            mainWindowIDs[idxB] = idA
        }
        stateLock.unlock()
        persistMainWindowIDs()

        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("com.guppi.spacetile.windowsRearranged"),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    static var lockedStoreURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".config/spacetile/locked_windows.json")
    }

    static var floatingStoreURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".config/spacetile/floating_windows.json")
    }

    static var mainWindowsStoreURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".config/spacetile/main_windows.json")
    }

    static var masterStoreURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".config/spacetile/master_window.json")
    }

    static var secondaryFocusStoreURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".config/spacetile/secondary_focus.json")
    }

    init() {
        reloadLockedWindowIDs()
        reloadFloatingWindowIDs()
        reloadMainWindowIDs()
    }

    func reloadMainWindowIDs() {
        stateLock.lock()
        defer { stateLock.unlock() }

        if FileManager.default.fileExists(atPath: WindowManager.mainWindowsStoreURL.path),
           let data = try? Data(contentsOf: WindowManager.mainWindowsStoreURL),
           let ids = try? JSONDecoder().decode([UInt32].self, from: data) {
            self.mainWindowIDs = ids.map { CGWindowID($0) }
            return
        }

        // Backwards compatibility migration from legacy masterStoreURL
        if FileManager.default.fileExists(atPath: WindowManager.masterStoreURL.path),
           let data = try? Data(contentsOf: WindowManager.masterStoreURL),
           let id = try? JSONDecoder().decode(UInt32.self, from: data) {
            self.mainWindowIDs = [CGWindowID(id)]
            return
        }

        self.mainWindowIDs = []
    }

    func persistMainWindowIDs() {
        stateLock.lock()
        let currentIDs = mainWindowIDs
        stateLock.unlock()

        let url = WindowManager.mainWindowsStoreURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !currentIDs.isEmpty {
            let uids = currentIDs.map { UInt32($0) }
            if let data = try? JSONEncoder().encode(uids) {
                try? data.write(to: url, options: .atomic)
            }
        } else {
            try? FileManager.default.removeItem(at: url)
        }

        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("com.guppi.spacetile.mainWindowsChanged"),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("com.guppi.spacetile.masterChanged"),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    func reloadMasterWindowID() {
        reloadMainWindowIDs()
    }

    func persistMasterWindowID() {
        persistMainWindowIDs()
    }

    func reloadSecondaryFocusWindowID() {
        reloadMainWindowIDs()
    }

    func persistSecondaryFocusWindowID() {
        persistMainWindowIDs()
    }

    func isMainWindow(id: CGWindowID) -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return mainWindowIDs.contains(id)
    }

    func addMainWindow(id: CGWindowID) {
        stateLock.lock()
        if !mainWindowIDs.contains(id) {
            mainWindowIDs.append(id)
        }
        stateLock.unlock()
        persistMainWindowIDs()
        _ = optimize(verbose: true)
    }

    func removeMainWindow(id: CGWindowID) {
        stateLock.lock()
        mainWindowIDs.removeAll(where: { $0 == id })
        stateLock.unlock()
        persistMainWindowIDs()
        _ = optimize(verbose: true)
    }

    @discardableResult
    func toggleMainWindow(id: CGWindowID) -> Bool {
        stateLock.lock()
        let isPresent = mainWindowIDs.contains(id)
        if isPresent {
            mainWindowIDs.removeAll(where: { $0 == id })
        } else {
            mainWindowIDs.append(id)
        }
        stateLock.unlock()
        persistMainWindowIDs()
        _ = optimize(verbose: true)
        return !isPresent
    }

    func clearMainWindows() {
        stateLock.lock()
        mainWindowIDs.removeAll()
        stateLock.unlock()
        persistMainWindowIDs()
        _ = optimize(verbose: true)
    }

    func getFocusedWindowID() -> CGWindowID? {
        guard let front = NSWorkspace.shared.frontmostApplication else { return nil }
        if front.processIdentifier == ProcessInfo.processInfo.processIdentifier || front.localizedName == "SpaceTile" {
            return nil
        }
        let appRef = AXUIElementCreateApplication(front.processIdentifier)
        var winRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &winRef) == .success,
              let win = winRef, CFGetTypeID(win) == AXUIElementGetTypeID() else { return nil }

        var winID: CGWindowID = 0
        guard _AXUIElementGetWindow(win as! AXUIElement, &winID) == .success else { return nil }
        return winID
    }

    func addFocusedToMain() -> Bool {
        guard let winID = getFocusedWindowID() else { return false }
        addMainWindow(id: winID)
        return true
    }

    func removeFocusedFromMain() -> Bool {
        guard let winID = getFocusedWindowID() else { return false }
        removeMainWindow(id: winID)
        return true
    }

    func toggleFocusedMain() -> Bool {
        guard let winID = getFocusedWindowID() else { return false }
        return toggleMainWindow(id: winID)
    }

    func setMasterWindow(id: CGWindowID) {
        stateLock.lock()
        mainWindowIDs.removeAll(where: { $0 == id })
        mainWindowIDs.insert(id, at: 0)
        stateLock.unlock()
        persistMainWindowIDs()
        _ = optimize(verbose: true, forcedMasterID: id)
    }

    func clearMasterWindow() {
        clearMainWindows()
    }

    func setSecondaryFocusWindow(id: CGWindowID) {
        stateLock.lock()
        if mainWindowIDs.contains(id) {
            mainWindowIDs.removeAll(where: { $0 == id })
        } else {
            if mainWindowIDs.count >= 2 {
                mainWindowIDs.insert(id, at: 1)
            } else {
                mainWindowIDs.append(id)
            }
        }
        stateLock.unlock()
        persistMainWindowIDs()
        _ = optimize(verbose: true)
    }

    func clearSecondaryFocusWindow() {
        stateLock.lock()
        if mainWindowIDs.count > 1 {
            mainWindowIDs.remove(at: 1)
        }
        stateLock.unlock()
        persistMainWindowIDs()
        _ = optimize(verbose: true)
    }

    func setFocusedAsSecondaryFocus() -> Bool {
        guard let winID = getFocusedWindowID() else { return false }
        setSecondaryFocusWindow(id: winID)
        return true
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

    func reloadFloatingWindowIDs() {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard FileManager.default.fileExists(atPath: WindowManager.floatingStoreURL.path),
              let data = try? Data(contentsOf: WindowManager.floatingStoreURL),
              let list = try? JSONDecoder().decode([UInt32].self, from: data) else {
            self.floatingWindowIDs = []
            return
        }
        self.floatingWindowIDs = Set(list.map { CGWindowID($0) })
    }

    func persistFloatingWindowIDs() {
        stateLock.lock()
        let list = Array(floatingWindowIDs).map { UInt32($0) }
        stateLock.unlock()

        let url = WindowManager.floatingStoreURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(list) {
            try? data.write(to: url, options: .atomic)
        }
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("com.guppi.spacetile.floatingChanged"),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    func setWindowFloating(id: CGWindowID, floating: Bool) {
        reloadFloatingWindowIDs()
        let cid = WindowManager.CGSMainConnectionID()
        if floating {
            if lockedWindowIDs.contains(id) {
                lockedWindowIDs.remove(id)
                persistLockedWindowIDs()
            }
            floatingWindowIDs.insert(id)
            _ = WindowManager.CGSSetWindowLevel(cid, id, 3)

            // Center window on target screen
            let allWins = collectWindowsOnCurrentSpace(screenBounds: CGRect(x: 0, y: 0, width: 10000, height: 10000), ignoredApps: [], config: Config.load())
            if let targetWin = allWins.first(where: { $0.id == id }), let elem = targetWin.element {
                if let screen = findTargetScreen() ?? NSScreen.main ?? NSScreen.screens.first {
                    let primaryH = NSScreen.screens.first?.frame.height ?? screen.frame.height
                    let vf = screen.visibleFrame
                    let axRect = CGRect(x: vf.origin.x, y: primaryH - (vf.origin.y + vf.height), width: vf.width, height: vf.height)
                    let config = Config.load()
                    let workArea = axRect.insetBy(dx: config.margin, dy: config.margin)

                    let floatW = max(550, min(targetWin.currentFrame.width, floor(workArea.width * 0.60)))
                    let floatH = max(380, min(targetWin.currentFrame.height, floor(workArea.height * 0.65)))
                    let centerX = round(workArea.origin.x + (workArea.width - floatW) / 2.0)
                    let centerY = round(workArea.origin.y + (workArea.height - floatH) / 2.0)
                    setWindowFrameImmediate(elem, target: CGRect(x: centerX, y: centerY, width: floatW, height: floatH))
                    AXUIElementPerformAction(elem, kAXRaiseAction as CFString)
                }
            }
        } else {
            floatingWindowIDs.remove(id)
            _ = WindowManager.CGSSetWindowLevel(cid, id, 0)
        }
        persistFloatingWindowIDs()
        DispatchQueue.main.async { [weak self] in
            self?.optimize(verbose: true)
        }
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

    @discardableResult
    func toggleFloatForFocusedWindow() -> (floating: Bool, appName: String)? {
        reloadFloatingWindowIDs()
        guard let front = NSWorkspace.shared.frontmostApplication else { return nil }
        let appRef = AXUIElementCreateApplication(front.processIdentifier)
        var winRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &winRef) == .success,
              let win = winRef, CFGetTypeID(win) == AXUIElementGetTypeID() else { return nil }

        var winID: CGWindowID = 0
        guard _AXUIElementGetWindow(win as! AXUIElement, &winID) == .success else { return nil }

        let appName = front.localizedName ?? "App"
        let cid = WindowManager.CGSMainConnectionID()
        if floatingWindowIDs.contains(winID) {
            floatingWindowIDs.remove(winID)
            persistFloatingWindowIDs()
            _ = WindowManager.CGSSetWindowLevel(cid, winID, 0)
            print("[\u{001B}[33mSpaceTile\u{001B}[0m] Un-floated window for '\(appName)' (ID: \(winID)) -> Returns to standard grid tiling.")
            DispatchQueue.main.async { [weak self] in
                self?.optimize(verbose: true)
            }
            return (false, appName)
        } else {
            if lockedWindowIDs.contains(winID) {
                lockedWindowIDs.remove(winID)
                persistLockedWindowIDs()
            }
            floatingWindowIDs.insert(winID)
            persistFloatingWindowIDs()
            _ = WindowManager.CGSSetWindowLevel(cid, winID, 3)

            // Center the floating window in the middle of the screen
            if let screen = findTargetScreen() ?? NSScreen.main ?? NSScreen.screens.first {
                let primaryH = NSScreen.screens.first?.frame.height ?? screen.frame.height
                let vf = screen.visibleFrame
                let axRect = CGRect(x: vf.origin.x, y: primaryH - (vf.origin.y + vf.height), width: vf.width, height: vf.height)
                let config = Config.load()
                let workArea = axRect.insetBy(dx: config.margin, dy: config.margin)

                let curFrame = getWindowFrame(win as! AXUIElement) ?? CGRect(x: 0, y: 0, width: 1100, height: 750)
                let floatW = max(550, min(curFrame.width, floor(workArea.width * 0.60)))
                let floatH = max(380, min(curFrame.height, floor(workArea.height * 0.65)))
                let centerX = round(workArea.origin.x + (workArea.width - floatW) / 2.0)
                let centerY = round(workArea.origin.y + (workArea.height - floatH) / 2.0)
                setWindowFrameImmediate(win as! AXUIElement, target: CGRect(x: centerX, y: centerY, width: floatW, height: floatH))
            }

            AXUIElementPerformAction(win as! AXUIElement, kAXRaiseAction as CFString)
            print("[\u{001B}[35mSpaceTile\u{001B}[0m] Floated window for '\(appName)' (ID: \(winID)) -> Centered & stays on top.")

            DispatchQueue.main.async { [weak self] in
                self?.optimize(verbose: true)
            }
            return (true, appName)
        }
    }

    func setFocusedAsMaster() -> Bool {
        let now = ProcessInfo.processInfo.systemUptime
        let interval = now - lastMasterShortcutTimestamp
        lastMasterShortcutTimestamp = now

        let doubleTapThreshold: TimeInterval = max(0.45, NSEvent.doubleClickInterval)

        if interval < doubleTapThreshold {
            lastMasterShortcutTimestamp = 0
            print("[\u{001B}[32mSpaceTile\u{001B}[0m] Double-tap Hyper+Return -> Alle Main-Fenster aufgehoben (Gleichmäßiges Raster).")
            clearMainWindows()
            return true
        }

        return toggleFocusedMain()
    }

    @discardableResult
    func optimize(verbose: Bool = true, forcedMasterID: CGWindowID? = nil, forcedRatio: Double? = nil) -> Bool {
        guard WindowManager.ensureAccessibility(prompt: true) else {
            print("[\u{001B}[31mERROR\u{001B}[0m] Accessibility permission not granted!")
            return false
        }

        reloadLockedWindowIDs()
        reloadFloatingWindowIDs()
        reloadMainWindowIDs()
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

        let windows = collectWindowsOnCurrentSpace(screenBounds: axVisibleRect, ignoredApps: Set(config.ignoredApps), config: config)
        if windows.isEmpty {
            if verbose { print("[\u{001B}[33mINFO\u{001B}[0m] No active windows in current Space.") }
            return true
        }

        // Separate floating windows: they stay on top and are ignored by tiling engine
        let floatingWindows = windows.filter { $0.isFloating }
        var tilingWindows = windows.filter { !$0.isFloating }

        if tilingWindows.isEmpty {
            if verbose { print("[\u{001B}[33mINFO\u{001B}[0m] All active windows on current space are floating.") }
            let cid = WindowManager.CGSMainConnectionID()
            for fWin in floatingWindows {
                if let elem = fWin.element {
                    AXUIElementPerformAction(elem, kAXRaiseAction as CFString)
                }
                _ = WindowManager.CGSSetWindowLevel(cid, fWin.id, 3)
            }
            return true
        }

        // Handle forced master or active master on tiling windows
        if let fid = forcedMasterID {
            stateLock.lock()
            if !mainWindowIDs.contains(fid) {
                mainWindowIDs.insert(fid, at: 0)
            } else if let idx = mainWindowIDs.firstIndex(of: fid), idx != 0 {
                mainWindowIDs.remove(at: idx)
                mainWindowIDs.insert(fid, at: 0)
            }
            stateLock.unlock()
            persistMainWindowIDs()
        }

        // Partition tiling windows into Main windows vs. Supporting windows
        let mainIDSet = Set(mainWindowIDs)
        var mains: [ManagedWindow] = []
        var supporting: [ManagedWindow] = []

        for win in tilingWindows {
            if mainIDSet.contains(win.id) {
                mains.append(win)
            } else {
                supporting.append(win)
            }
        }

        // Sort mains to match the order in mainWindowIDs (first chosen gets primary spot)
        mains.sort { (a, b) -> Bool in
            let idxA = mainWindowIDs.firstIndex(of: a.id) ?? 999
            let idxB = mainWindowIDs.firstIndex(of: b.id) ?? 999
            return idxA < idxB
        }

        // Combine: all Main windows first, followed by Supporting windows
        tilingWindows = mains + supporting
        let mainCount = mains.count

        // Apply learned ratio from SpaceMemory if not forced and if main windows are active
        var effectiveRatio = forcedRatio
        if effectiveRatio == nil && config.enableSpaceLearning && mainCount > 0 {
            let appNames = Array(Set(tilingWindows.map { $0.appName })).sorted()
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
            windows: tilingWindows,
            workArea: workArea,
            screen: targetScreen,
            config: config,
            forcedRatio: effectiveRatio,
            mainCount: mainCount
        )

        // Apply frames
        if config.animationMode == "smooth" && config.animationDuration > 0.02 {
            var moves: [(element: AXUIElement, start: CGRect, target: CGRect)] = []
            for (i, win) in tilingWindows.enumerated() {
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
            for (i, win) in tilingWindows.enumerated() {
                if win.isLocked { continue }
                if let elem = win.element {
                    setWindowFrameImmediate(elem, target: frames[i])
                }
            }
        }

        // Ensure all floating windows remain pinned on top in the foreground
        let cid = WindowManager.CGSMainConnectionID()
        for fWin in floatingWindows {
            if let elem = fWin.element {
                AXUIElementPerformAction(elem, kAXRaiseAction as CFString)
            }
            _ = WindowManager.CGSSetWindowLevel(cid, fWin.id, 3)
        }

        if verbose {
            let countStr = floatingWindows.isEmpty ? "\(tilingWindows.count)" : "\(tilingWindows.count) tiled (\(floatingWindows.count) floating)"
            print("[\u{001B}[32mSpaceTile\u{001B}[0m] Arranged \(countStr) windows on '\(targetScreen.localizedName)'")
            for (i, win) in tilingWindows.enumerated() {
                let isMain = mainWindowIDs.contains(win.id)
                let tag = win.isLocked ? "\u{001B}[33m🔒 Locked\u{001B}[0m" : (isMain ? "\u{001B}[32m★ Main  \u{001B}[0m" : "  Support")
                let f = frames[i]
                print(String(format: " %@[%@ (Score %d)] -> %dx%d @ (%d, %d)",
                             tag, win.appName, win.score, Int(f.width), Int(f.height), Int(f.origin.x), Int(f.origin.y)))
            }
            for fWin in floatingWindows {
                let f = fWin.currentFrame
                print(String(format: "  \u{001B}[35m✈ Float \u{001B}[0m[%@ (Score %d)] -> %dx%d @ (%d, %d) [Always on Top]",
                             fWin.appName, fWin.score, Int(f.width), Int(f.height), Int(f.origin.x), Int(f.origin.y)))
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
        forcedRatio: Double?,
        mainCount: Int
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
                forcedRatio: forcedRatio,
                mainCount: mainCount
            )
        }

        // Case B: ONE OR MORE windows are locked -> Reserve their grid tiles!
        let gap = config.gap
        let is4K = screen.frame.width >= 2000 || screen.visibleFrame.width >= 2000
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
                forcedRatio: forcedRatio,
                mainCount: mainCount
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
        forcedRatio: Double?,
        mainCount: Int
    ) -> [CGRect] {
        let count = windows.count
        guard count > 0 else { return [] }

        let gap = config.gap
        let is4K = screen.frame.width >= 2000 || screen.visibleFrame.width >= 2000

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
            if (mainCount == 0 || mainCount >= 2) && forcedRatio == nil {
                let halfW = floor((workArea.width - gap) / 2.0)
                resultFrames[0] = CGRect(x: floor(workArea.origin.x), y: floor(workArea.origin.y), width: halfW, height: floor(workArea.height))
                resultFrames[1] = CGRect(x: floor(workArea.origin.x + halfW + gap), y: floor(workArea.origin.y), width: halfW, height: floor(workArea.height))
                return resultFrames
            }

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
            if (mainCount == 0 || mainCount >= 3) && forcedRatio == nil {
                let colW = floor((workArea.width - 2 * gap) / 3.0)
                for i in 0..<3 {
                    let cx = workArea.origin.x + CGFloat(i) * (colW + gap)
                    let thisW = (i == 2) ? (workArea.origin.x + workArea.width - cx) : colW
                    resultFrames[i] = CGRect(x: floor(cx), y: floor(workArea.origin.y), width: floor(thisW), height: floor(workArea.height))
                }
                return resultFrames
            }

            if let fr = forcedRatio {
                let masterCols = max(2, min(totalCols - 2, Int(round(Double(totalCols) * fr))))
                let stackCols = totalCols - masterCols
                let r0 = totalRows / 2
                let r1 = totalRows - r0
                resultFrames[0] = rectFor(col: 0, row: 0, colSpan: masterCols, rowSpan: totalRows)
                resultFrames[1] = rectFor(col: masterCols, row: 0, colSpan: stackCols, rowSpan: r0)
                resultFrames[2] = rectFor(col: masterCols, row: r0, colSpan: stackCols, rowSpan: r1)
                return resultFrames
            }

            // 3 Equal-Width Columns:
            let colW = floor((workArea.width - 2 * gap) / 3.0)
            let col0X = workArea.origin.x
            let col1X = workArea.origin.x + colW + gap
            let col2X = workArea.origin.x + 2 * (colW + gap)
            let col2W = workArea.origin.x + workArea.width - col2X

            if mainCount == 1 {
                // 1 Main: Main in center (col1), Supporting 1 on left (col0), Supporting 2 on right (col2)
                resultFrames[1] = CGRect(x: floor(col0X), y: floor(workArea.origin.y), width: floor(colW), height: floor(workArea.height))
                resultFrames[0] = CGRect(x: floor(col1X), y: floor(workArea.origin.y), width: floor(colW), height: floor(workArea.height))
                resultFrames[2] = CGRect(x: floor(col2X), y: floor(workArea.origin.y), width: floor(col2W), height: floor(workArea.height))
            } else {
                // 2 Mains: Main 1 on left (col0), Main 2 in center (col1), Supporting on right (col2)
                resultFrames[0] = CGRect(x: floor(col0X), y: floor(workArea.origin.y), width: floor(colW), height: floor(workArea.height))
                resultFrames[1] = CGRect(x: floor(col1X), y: floor(workArea.origin.y), width: floor(colW), height: floor(workArea.height))
                resultFrames[2] = CGRect(x: floor(col2X), y: floor(workArea.origin.y), width: floor(col2W), height: floor(workArea.height))
            }
            return resultFrames
        }

        // 4+ Windows
        // Case A: Wenn KEINE Main-Fenster gesetzt sind (mainCount == 0) oder alle Main sind (mainCount >= count)
        // -> Gleichmäßiges Raster mit 100% Flächennutzung (0% Lücken)!
        if mainCount == 0 || mainCount >= count {
            if count == 4 {
                let halfW = floor((workArea.width - gap) / 2.0)
                let otherW = workArea.origin.x + workArea.width - (workArea.origin.x + halfW + gap)
                let halfH = floor((workArea.height - gap) / 2.0)
                let otherH = workArea.origin.y + workArea.height - (workArea.origin.y + halfH + gap)
                resultFrames[0] = CGRect(x: floor(workArea.origin.x), y: floor(workArea.origin.y), width: floor(halfW), height: floor(halfH))
                resultFrames[1] = CGRect(x: floor(workArea.origin.x + halfW + gap), y: floor(workArea.origin.y), width: floor(otherW), height: floor(halfH))
                resultFrames[2] = CGRect(x: floor(workArea.origin.x), y: floor(workArea.origin.y + halfH + gap), width: floor(halfW), height: floor(otherH))
                resultFrames[3] = CGRect(x: floor(workArea.origin.x + halfW + gap), y: floor(workArea.origin.y + halfH + gap), width: floor(otherW), height: floor(otherH))
                return resultFrames
            }
            if count == 5 {
                let halfH = floor((workArea.height - gap) / 2.0)
                let botH = workArea.origin.y + workArea.height - (workArea.origin.y + halfH + gap)
                let topW = floor((workArea.width - 2 * gap) / 3.0)
                let botW = floor((workArea.width - gap) / 2.0)
                let botY = workArea.origin.y + halfH + gap
                for i in 0..<3 {
                    let cx = workArea.origin.x + CGFloat(i) * (topW + gap)
                    let thisW = (i == 2) ? (workArea.origin.x + workArea.width - cx) : topW
                    resultFrames[i] = CGRect(x: floor(cx), y: floor(workArea.origin.y), width: floor(thisW), height: floor(halfH))
                }
                for i in 0..<2 {
                    let cx = workArea.origin.x + CGFloat(i) * (botW + gap)
                    let thisW = (i == 1) ? (workArea.origin.x + workArea.width - cx) : botW
                    resultFrames[3 + i] = CGRect(x: floor(cx), y: floor(botY), width: floor(thisW), height: floor(botH))
                }
                return resultFrames
            }
            if count == 6 {
                let colW = floor((workArea.width - 2 * gap) / 3.0)
                let halfH = floor((workArea.height - gap) / 2.0)
                let botH = workArea.origin.y + workArea.height - (workArea.origin.y + halfH + gap)
                for i in 0..<6 {
                    let c = i % 3
                    let r = i / 3
                    let cx = workArea.origin.x + CGFloat(c) * (colW + gap)
                    let cy = (r == 0) ? workArea.origin.y : (workArea.origin.y + halfH + gap)
                    let thisW = (c == 2) ? (workArea.origin.x + workArea.width - cx) : colW
                    let thisH = (r == 0) ? halfH : botH
                    resultFrames[i] = CGRect(x: floor(cx), y: floor(cy), width: floor(thisW), height: floor(thisH))
                }
                return resultFrames
            }
            if count == 7 {
                let halfH = floor((workArea.height - gap) / 2.0)
                let botH = workArea.origin.y + workArea.height - (workArea.origin.y + halfH + gap)
                let topW = floor((workArea.width - 3 * gap) / 4.0)
                let botW = floor((workArea.width - 2 * gap) / 3.0)
                let botY = workArea.origin.y + halfH + gap
                for i in 0..<4 {
                    let cx = workArea.origin.x + CGFloat(i) * (topW + gap)
                    let thisW = (i == 3) ? (workArea.origin.x + workArea.width - cx) : topW
                    resultFrames[i] = CGRect(x: floor(cx), y: floor(workArea.origin.y), width: floor(thisW), height: floor(halfH))
                }
                for i in 0..<3 {
                    let cx = workArea.origin.x + CGFloat(i) * (botW + gap)
                    let thisW = (i == 2) ? (workArea.origin.x + workArea.width - cx) : botW
                    resultFrames[4 + i] = CGRect(x: floor(cx), y: floor(botY), width: floor(thisW), height: floor(botH))
                }
                return resultFrames
            }
            if count == 8 {
                let colW = floor((workArea.width - 3 * gap) / 4.0)
                let halfH = floor((workArea.height - gap) / 2.0)
                let botH = workArea.origin.y + workArea.height - (workArea.origin.y + halfH + gap)
                for i in 0..<8 {
                    let c = i % 4
                    let r = i / 4
                    let cx = workArea.origin.x + CGFloat(c) * (colW + gap)
                    let cy = (r == 0) ? workArea.origin.y : (workArea.origin.y + halfH + gap)
                    let thisW = (c == 3) ? (workArea.origin.x + workArea.width - cx) : colW
                    let thisH = (r == 0) ? halfH : botH
                    resultFrames[i] = CGRect(x: floor(cx), y: floor(cy), width: floor(thisW), height: floor(thisH))
                }
                return resultFrames
            }
            if count >= 9 {
                let cols = is4K ? 4 : 3
                let rows = Int(ceil(Double(count) / Double(cols)))
                let rowH = floor((workArea.height - CGFloat(rows - 1) * gap) / CGFloat(rows))
                var winIdx = 0
                for r in 0..<rows {
                    let countInRow = (r == rows - 1) ? (count - winIdx) : cols
                    let colW = floor((workArea.width - CGFloat(countInRow - 1) * gap) / CGFloat(countInRow))
                    let cy = workArea.origin.y + CGFloat(r) * (rowH + gap)
                    let thisH = (r == rows - 1) ? (workArea.origin.y + workArea.height - cy) : rowH
                    for c in 0..<countInRow {
                        let cx = workArea.origin.x + CGFloat(c) * (colW + gap)
                        let thisW = (c == countInRow - 1) ? (workArea.origin.x + workArea.width - cx) : colW
                        resultFrames[winIdx] = CGRect(x: floor(cx), y: floor(cy), width: floor(thisW), height: floor(thisH))
                        winIdx += 1
                    }
                }
                return resultFrames
            }
        }

        // Case B: Multi-Main & Supporting Windows Layout (mainCount in 1..<count)
        // Main windows: windows[0..<mainCount] receive prominent column/top placement.
        // Supporting windows: windows[mainCount..<count] neatly stack in remaining slots with 100% area utilization (0% voids/holes).
        if is4K {
            let colW = floor((workArea.width - 2 * gap) / 3.0)
            let col0X = workArea.origin.x
            let col1X = workArea.origin.x + colW + gap
            let col2X = workArea.origin.x + 2 * (colW + gap)
            let col2W = workArea.origin.x + workArea.width - col2X

            if mainCount == 3 {
                if count == 4 {
                    // Col 0: Main 1 (100% height)
                    resultFrames[0] = CGRect(x: floor(col0X), y: floor(workArea.origin.y), width: floor(colW), height: floor(workArea.height))
                    // Col 1: Main 2 (100% height)
                    resultFrames[1] = CGRect(x: floor(col1X), y: floor(workArea.origin.y), width: floor(colW), height: floor(workArea.height))
                    // Col 2: Main 3 (top 60%) + Supporting 1 (bottom 40%)
                    let topH = floor((workArea.height - gap) * 0.60)
                    let botH = workArea.origin.y + workArea.height - (workArea.origin.y + topH + gap)
                    resultFrames[2] = CGRect(x: floor(col2X), y: floor(workArea.origin.y), width: floor(col2W), height: floor(topH))
                    resultFrames[3] = CGRect(x: floor(col2X), y: floor(workArea.origin.y + topH + gap), width: floor(col2W), height: floor(botH))
                    return resultFrames
                }
                if count == 5 {
                    let topH = floor((workArea.height - gap) * 0.60)
                    let botH = workArea.origin.y + workArea.height - (workArea.origin.y + topH + gap)
                    let botY = workArea.origin.y + topH + gap
                    // Col 0: Main 1 (top 60%) + Supporting 1 (bottom 40%)
                    resultFrames[0] = CGRect(x: floor(col0X), y: floor(workArea.origin.y), width: floor(colW), height: floor(topH))
                    resultFrames[3] = CGRect(x: floor(col0X), y: floor(botY), width: floor(colW), height: floor(botH))
                    // Col 1: Main 2 (top 60%) + Supporting 2 (bottom 40%)
                    resultFrames[1] = CGRect(x: floor(col1X), y: floor(workArea.origin.y), width: floor(colW), height: floor(topH))
                    resultFrames[4] = CGRect(x: floor(col1X), y: floor(botY), width: floor(colW), height: floor(botH))
                    // Col 2: Main 3 (100% full height)
                    resultFrames[2] = CGRect(x: floor(col2X), y: floor(workArea.origin.y), width: floor(col2W), height: floor(workArea.height))
                    return resultFrames
                }
                if count == 6 {
                    let topH = floor((workArea.height - gap) * 0.60)
                    let botH = workArea.origin.y + workArea.height - (workArea.origin.y + topH + gap)
                    let botY = workArea.origin.y + topH + gap
                    // Col 0: Main 1 + Supporting 1
                    resultFrames[0] = CGRect(x: floor(col0X), y: floor(workArea.origin.y), width: floor(colW), height: floor(topH))
                    resultFrames[3] = CGRect(x: floor(col0X), y: floor(botY), width: floor(colW), height: floor(botH))
                    // Col 1: Main 2 + Supporting 2
                    resultFrames[1] = CGRect(x: floor(col1X), y: floor(workArea.origin.y), width: floor(colW), height: floor(topH))
                    resultFrames[4] = CGRect(x: floor(col1X), y: floor(botY), width: floor(colW), height: floor(botH))
                    // Col 2: Main 3 + Supporting 3
                    resultFrames[2] = CGRect(x: floor(col2X), y: floor(workArea.origin.y), width: floor(col2W), height: floor(topH))
                    resultFrames[5] = CGRect(x: floor(col2X), y: floor(botY), width: floor(col2W), height: floor(botH))
                    return resultFrames
                }
            }

            // mainCount == 1 or mainCount == 2
            let c0Idx = (mainCount == 2) ? 0 : 1
            let c1Idx = (mainCount == 2) ? 1 : 0

            if count == 4 {
                // Col 0: Main 1 (or Supporting 1 if mainCount==1)
                resultFrames[c0Idx] = CGRect(x: floor(col0X), y: floor(workArea.origin.y), width: floor(colW), height: floor(workArea.height))
                // Col 1: Main 2 (or Main 1 centered if mainCount==1)
                resultFrames[c1Idx] = CGRect(x: floor(col1X), y: floor(workArea.origin.y), width: floor(colW), height: floor(workArea.height))
                // Col 2: 2 supporting windows stacked (each 50% height)
                let halfH = floor((workArea.height - gap) / 2.0)
                let botH = workArea.origin.y + workArea.height - (workArea.origin.y + halfH + gap)
                resultFrames[2] = CGRect(x: floor(col2X), y: floor(workArea.origin.y), width: floor(col2W), height: floor(halfH))
                resultFrames[3] = CGRect(x: floor(col2X), y: floor(workArea.origin.y + halfH + gap), width: floor(col2W), height: floor(botH))
                return resultFrames
            }

            if count == 5 {
                resultFrames[c0Idx] = CGRect(x: floor(col0X), y: floor(workArea.origin.y), width: floor(colW), height: floor(workArea.height))
                resultFrames[c1Idx] = CGRect(x: floor(col1X), y: floor(workArea.origin.y), width: floor(colW), height: floor(workArea.height))
                // Col 2: 3 auxiliary windows stacked (each 33.3% height)
                let cellH = floor((workArea.height - 2 * gap) / 3.0)
                let botH = workArea.origin.y + workArea.height - (workArea.origin.y + 2 * (cellH + gap))
                resultFrames[2] = CGRect(x: floor(col2X), y: floor(workArea.origin.y), width: floor(col2W), height: floor(cellH))
                resultFrames[3] = CGRect(x: floor(col2X), y: floor(workArea.origin.y + cellH + gap), width: floor(col2W), height: floor(cellH))
                resultFrames[4] = CGRect(x: floor(col2X), y: floor(workArea.origin.y + 2 * (cellH + gap)), width: floor(col2W), height: floor(botH))
                return resultFrames
            }

            if count == 6 {
                let topH = floor((workArea.height - gap) * (2.0 / 3.0))
                let botH = workArea.origin.y + workArea.height - (workArea.origin.y + topH + gap)
                let botY = workArea.origin.y + topH + gap

                // Col 0
                resultFrames[c0Idx] = CGRect(x: floor(col0X), y: floor(workArea.origin.y), width: floor(colW), height: floor(topH))
                resultFrames[3] = CGRect(x: floor(col0X), y: floor(botY), width: floor(colW), height: floor(botH))

                // Col 1
                resultFrames[c1Idx] = CGRect(x: floor(col1X), y: floor(workArea.origin.y), width: floor(colW), height: floor(topH))
                resultFrames[4] = CGRect(x: floor(col1X), y: floor(botY), width: floor(colW), height: floor(botH))

                // Col 2
                resultFrames[2] = CGRect(x: floor(col2X), y: floor(workArea.origin.y), width: floor(col2W), height: floor(topH))
                resultFrames[5] = CGRect(x: floor(col2X), y: floor(botY), width: floor(col2W), height: floor(botH))
                return resultFrames
            }

            if count == 7 {
                // Col 0: Focus 2 (top 2/3) + Window 3 (bottom 1/3)
                // Col 1: Master (top 2/3, centered) + Window 4 (bottom 1/3)
                // Col 2: 3 windows stacked (Window 2, 5, 6, each 1/3 height)
                let topH = floor((workArea.height - gap) * (2.0 / 3.0))
                let botH = workArea.origin.y + workArea.height - (workArea.origin.y + topH + gap)
                let botY = workArea.origin.y + topH + gap

                resultFrames[c0Idx] = CGRect(x: floor(col0X), y: floor(workArea.origin.y), width: floor(colW), height: floor(topH))
                resultFrames[3] = CGRect(x: floor(col0X), y: floor(botY), width: floor(colW), height: floor(botH))

                resultFrames[c1Idx] = CGRect(x: floor(col1X), y: floor(workArea.origin.y), width: floor(colW), height: floor(topH))
                resultFrames[4] = CGRect(x: floor(col1X), y: floor(botY), width: floor(colW), height: floor(botH))

                let cellH = floor((workArea.height - 2 * gap) / 3.0)
                let botCellH = workArea.origin.y + workArea.height - (workArea.origin.y + 2 * (cellH + gap))
                resultFrames[2] = CGRect(x: floor(col2X), y: floor(workArea.origin.y), width: floor(col2W), height: floor(cellH))
                resultFrames[5] = CGRect(x: floor(col2X), y: floor(workArea.origin.y + cellH + gap), width: floor(col2W), height: floor(cellH))
                resultFrames[6] = CGRect(x: floor(col2X), y: floor(workArea.origin.y + 2 * (cellH + gap)), width: floor(col2W), height: floor(botCellH))
                return resultFrames
            }

            if count == 8 {
                let topH = floor((workArea.height - gap) * (2.0 / 3.0))
                let botH = workArea.origin.y + workArea.height - (workArea.origin.y + topH + gap)
                let botY = workArea.origin.y + topH + gap

                resultFrames[c0Idx] = CGRect(x: floor(col0X), y: floor(workArea.origin.y), width: floor(colW), height: floor(topH))
                resultFrames[3] = CGRect(x: floor(col0X), y: floor(botY), width: floor(colW), height: floor(botH))

                resultFrames[c1Idx] = CGRect(x: floor(col1X), y: floor(workArea.origin.y), width: floor(colW), height: floor(topH))
                resultFrames[4] = CGRect(x: floor(col1X), y: floor(botY), width: floor(colW), height: floor(botH))

                let cellH = floor((workArea.height - 3 * gap) / 4.0)
                let botCellH = workArea.origin.y + workArea.height - (workArea.origin.y + 3 * (cellH + gap))
                resultFrames[2] = CGRect(x: floor(col2X), y: floor(workArea.origin.y), width: floor(col2W), height: floor(cellH))
                resultFrames[5] = CGRect(x: floor(col2X), y: floor(workArea.origin.y + cellH + gap), width: floor(col2W), height: floor(cellH))
                resultFrames[6] = CGRect(x: floor(col2X), y: floor(workArea.origin.y + 2 * (cellH + gap)), width: floor(col2W), height: floor(cellH))
                resultFrames[7] = CGRect(x: floor(col2X), y: floor(workArea.origin.y + 3 * (cellH + gap)), width: floor(col2W), height: floor(botCellH))
                return resultFrames
            }

            // count >= 9:
            let topH = floor((workArea.height - gap) * 0.55)
            let botH = workArea.origin.y + workArea.height - (workArea.origin.y + topH + gap)
            let botY = workArea.origin.y + topH + gap

            resultFrames[c0Idx] = CGRect(x: floor(col0X), y: floor(workArea.origin.y), width: floor(colW), height: floor(topH))
            resultFrames[c1Idx] = CGRect(x: floor(col1X), y: floor(workArea.origin.y), width: floor(colW), height: floor(topH))

            let rem = count - 2
            let c0Extra = rem / 3
            let c1Extra = rem / 3
            let c2Count = rem - c0Extra - c1Extra

            var curIdx = 2

            // Col 0 bottom extras
            if c0Extra > 0 {
                let eH = floor((botH - CGFloat(c0Extra - 1) * gap) / CGFloat(c0Extra))
                for i in 0..<c0Extra {
                    let ey = botY + CGFloat(i) * (eH + gap)
                    let thisH = (i == c0Extra - 1) ? (workArea.origin.y + workArea.height - ey) : eH
                    resultFrames[curIdx] = CGRect(x: floor(col0X), y: floor(ey), width: floor(colW), height: floor(thisH))
                    curIdx += 1
                }
            }

            // Col 1 bottom extras
            if c1Extra > 0 {
                let eH = floor((botH - CGFloat(c1Extra - 1) * gap) / CGFloat(c1Extra))
                for i in 0..<c1Extra {
                    let ey = botY + CGFloat(i) * (eH + gap)
                    let thisH = (i == c1Extra - 1) ? (workArea.origin.y + workArea.height - ey) : eH
                    resultFrames[curIdx] = CGRect(x: floor(col1X), y: floor(ey), width: floor(colW), height: floor(thisH))
                    curIdx += 1
                }
            }

            // Col 2 full column stack
            if c2Count > 0 {
                let eH = floor((workArea.height - CGFloat(c2Count - 1) * gap) / CGFloat(c2Count))
                for i in 0..<c2Count {
                    let ey = workArea.origin.y + CGFloat(i) * (eH + gap)
                    let thisH = (i == c2Count - 1) ? (workArea.origin.y + workArea.height - ey) : eH
                    resultFrames[curIdx] = CGRect(x: floor(col2X), y: floor(ey), width: floor(col2W), height: floor(thisH))
                    curIdx += 1
                }
            }

            return resultFrames
        }

        // Non-4K (Standard displays e.g. MacBook built-in screens)
        let c0Idx = (mainCount == 2) ? 0 : 1
        let c1Idx = (mainCount == 2) ? 1 : 0

        if count == 4 {
            let halfW = floor((workArea.width - gap) / 2.0)
            let otherW = workArea.origin.x + workArea.width - (workArea.origin.x + halfW + gap)
            let topH = floor((workArea.height - gap) * 0.60)
            let botH = workArea.origin.y + workArea.height - (workArea.origin.y + topH + gap)
            let botY = workArea.origin.y + topH + gap

            // Col 0: Main 1 (or Supporting 1) top 60% + Window 2 bottom 40%
            resultFrames[c0Idx] = CGRect(x: floor(workArea.origin.x), y: floor(workArea.origin.y), width: floor(halfW), height: floor(topH))
            resultFrames[2] = CGRect(x: floor(workArea.origin.x), y: floor(botY), width: floor(halfW), height: floor(botH))

            // Col 1: Main 2 (or Main 1) top 60% + Window 3 bottom 40%
            resultFrames[c1Idx] = CGRect(x: floor(workArea.origin.x + halfW + gap), y: floor(workArea.origin.y), width: floor(otherW), height: floor(topH))
            resultFrames[3] = CGRect(x: floor(workArea.origin.x + halfW + gap), y: floor(botY), width: floor(otherW), height: floor(botH))
            return resultFrames
        }

        if count == 5 {
            let halfW = floor((workArea.width - gap) / 2.0)
            let otherW = workArea.origin.x + workArea.width - (workArea.origin.x + halfW + gap)
            let topH = floor((workArea.height - gap) * 0.60)
            let botH = workArea.origin.y + workArea.height - (workArea.origin.y + topH + gap)
            let botY = workArea.origin.y + topH + gap

            // Top tier: Main windows
            resultFrames[c0Idx] = CGRect(x: floor(workArea.origin.x), y: floor(workArea.origin.y), width: floor(halfW), height: floor(topH))
            resultFrames[c1Idx] = CGRect(x: floor(workArea.origin.x + halfW + gap), y: floor(workArea.origin.y), width: floor(otherW), height: floor(topH))

            // Bottom tier: 3 windows evenly distributed
            let botW = floor((workArea.width - 2 * gap) / 3.0)
            for i in 0..<3 {
                let bx = workArea.origin.x + CGFloat(i) * (botW + gap)
                let thisW = (i == 2) ? (workArea.origin.x + workArea.width - bx) : botW
                resultFrames[2 + i] = CGRect(x: floor(bx), y: floor(botY), width: floor(thisW), height: floor(botH))
            }
            return resultFrames
        }

        if count == 6 {
            let colW = floor((workArea.width - 2 * gap) / 3.0)
            let topH = floor((workArea.height - gap) * (2.0 / 3.0))
            let botH = workArea.origin.y + workArea.height - (workArea.origin.y + topH + gap)
            let botY = workArea.origin.y + topH + gap

            for i in 0..<3 {
                let cx = workArea.origin.x + CGFloat(i) * (colW + gap)
                let thisW = (i == 2) ? (workArea.origin.x + workArea.width - cx) : colW
                let topIdx = (i == 0) ? c0Idx : ((i == 1) ? c1Idx : 2)
                resultFrames[topIdx] = CGRect(x: floor(cx), y: floor(workArea.origin.y), width: floor(thisW), height: floor(topH))
                let botIdx = 3 + i
                resultFrames[botIdx] = CGRect(x: floor(cx), y: floor(botY), width: floor(thisW), height: floor(botH))
            }
            return resultFrames
        }

        // 7+ on standard display: 3 columns layout with zero empty spaces
        let colW = floor((workArea.width - 2 * gap) / 3.0)
        let topH = floor((workArea.height - gap) * (2.0 / 3.0))
        let botH = workArea.origin.y + workArea.height - (workArea.origin.y + topH + gap)
        let botY = workArea.origin.y + topH + gap

        resultFrames[c0Idx] = CGRect(x: floor(workArea.origin.x), y: floor(workArea.origin.y), width: floor(colW), height: floor(topH))
        resultFrames[3] = CGRect(x: floor(workArea.origin.x), y: floor(botY), width: floor(colW), height: floor(botH))

        let col1X = workArea.origin.x + colW + gap
        resultFrames[c1Idx] = CGRect(x: floor(col1X), y: floor(workArea.origin.y), width: floor(colW), height: floor(topH))
        resultFrames[4] = CGRect(x: floor(col1X), y: floor(botY), width: floor(colW), height: floor(botH))

        let col2X = workArea.origin.x + 2 * (colW + gap)
        let col2W = workArea.origin.x + workArea.width - col2X
        let remCount = count - 5
        let stackCount = 1 + remCount
        let stackH = floor((workArea.height - CGFloat(stackCount - 1) * gap) / CGFloat(stackCount))
        resultFrames[2] = CGRect(x: floor(col2X), y: floor(workArea.origin.y), width: floor(col2W), height: floor(stackH))
        for i in 0..<remCount {
            let sy = workArea.origin.y + CGFloat(i + 1) * (stackH + gap)
            let thisH = (i == remCount - 1) ? (workArea.origin.y + workArea.height - sy) : stackH
            resultFrames[5 + i] = CGRect(x: floor(col2X), y: floor(sy), width: floor(col2W), height: floor(thisH))
        }

        return resultFrames
    }

    // Private SkyLight SPIs for atomic display compositor updates & window floating levels
    typealias CGSConnectionID = UInt32
    @_silgen_name("CGSMainConnectionID") static func CGSMainConnectionID() -> CGSConnectionID
    @_silgen_name("CGSDisableUpdate") private static func CGSDisableUpdate(_ cid: CGSConnectionID) -> Int32
    @_silgen_name("CGSReenableUpdate") private static func CGSReenableUpdate(_ cid: CGSConnectionID) -> Int32
    @_silgen_name("CGSSetWindowLevel") static func CGSSetWindowLevel(_ cid: CGSConnectionID, _ wid: UInt32, _ level: Int32) -> Int32

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
        reloadFloatingWindowIDs()
        reloadMainWindowIDs()
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let cgWindows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        // Clean up stale locked, floating, and main window IDs from closed windows
        let allWins = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
        let allIDs = Set(allWins.compactMap { $0[kCGWindowNumber as String] as? CGWindowID })
        let deadIDs = lockedWindowIDs.subtracting(allIDs)
        if !deadIDs.isEmpty {
            lockedWindowIDs.subtract(deadIDs)
            persistLockedWindowIDs()
        }
        let deadFloatIDs = floatingWindowIDs.subtracting(allIDs)
        if !deadFloatIDs.isEmpty {
            floatingWindowIDs.subtract(deadFloatIDs)
            persistFloatingWindowIDs()
        }
        let deadMainIDs = mainWindowIDs.filter { !allIDs.contains($0) }
        if !deadMainIDs.isEmpty {
            stateLock.lock()
            mainWindowIDs.removeAll { deadMainIDs.contains($0) }
            stateLock.unlock()
            persistMainWindowIDs()
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
                let isFloating = floatingWindowIDs.contains(winID)
                let currentFrame = getWindowFrame(win) ?? info.bounds

                // Scoring lookup: App weight -> Window Rule (by title) -> Live ID override
                let weightConfig = config.appWeights.first(where: { $0.appName.lowercased() == appName.lowercased() })
                var score = weightConfig?.score ?? defaultScoreFor(appName: appName)

                if let rule = config.windowRules.first(where: { rule in
                    (rule.appName == nil || rule.appName?.lowercased() == appName.lowercased()) &&
                    title.localizedCaseInsensitiveContains(rule.pattern)
                }) {
                    score = rule.score
                }

                if let overrideScore = windowScoreOverrides[winID] {
                    score = overrideScore
                }

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
                    isFloating: isFloating,
                    currentFrame: currentFrame,
                    score: score,
                    minWidth: minW,
                    minHeight: minH,
                    maxWidth: maxW
                ))
            }
        }

        // Add any remaining on-screen windows that weren't matched via AX only if locked or floating
        for (winID, info) in onScreenMap {
            if !matchedIDs.contains(winID) && (lockedWindowIDs.contains(winID) || floatingWindowIDs.contains(winID)) {
                let weightConfig = config.appWeights.first(where: { $0.appName.lowercased() == info.owner.lowercased() })
                var score = weightConfig?.score ?? defaultScoreFor(appName: info.owner)

                if let rule = config.windowRules.first(where: { rule in
                    (rule.appName == nil || rule.appName?.lowercased() == info.owner.lowercased()) &&
                    info.title.localizedCaseInsensitiveContains(rule.pattern)
                }) {
                    score = rule.score
                }

                if let overrideScore = windowScoreOverrides[winID] {
                    score = overrideScore
                }

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
                    isLocked: lockedWindowIDs.contains(winID),
                    isFloating: floatingWindowIDs.contains(winID),
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
