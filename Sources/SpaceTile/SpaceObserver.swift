import Cocoa
import CoreGraphics

class SpaceObserver {
    static let shared = SpaceObserver()

    private var timer: Timer?
    private var lastRecordedHash: String = ""
    private var settleCounter: Int = 0

    func start() {
        guard timer == nil else { return }
        // Check window state every 15 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            self?.checkCurrentSpaceState()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func checkCurrentSpaceState() {
        let config = Config.load()
        guard config.enableSpaceLearning else { return }

        guard let screen = NSScreen.main else { return }
        let resKey = "\(Int(screen.frame.width))x\(Int(screen.frame.height))"

        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return }

        var onScreenWindows: [(appName: String, width: Double, height: Double, x: Double, y: Double)] = []

        for win in list {
            let layer = win[kCGWindowLayer as String] as? Int ?? -1
            let owner = win[kCGWindowOwnerName as String] as? String ?? ""
            let bounds = win[kCGWindowBounds as String] as? [String: Any] ?? [:]
            let w = bounds["Width"] as? Double ?? 0
            let h = bounds["Height"] as? Double ?? 0
            let x = bounds["X"] as? Double ?? 0
            let y = bounds["Y"] as? Double ?? 0

            if layer == 0 && w > 200 && h > 200 && !config.ignoredApps.contains(owner) {
                onScreenWindows.append((appName: owner, width: w, height: h, x: x, y: y))
            }
        }

        guard onScreenWindows.count >= 2 else { return }

        // The first on-screen window is typically the frontmost/active window
        guard let frontApp = NSWorkspace.shared.frontmostApplication?.localizedName,
              let activeWin = onScreenWindows.first(where: { $0.appName == frontApp }) ?? onScreenWindows.first else {
            return
        }

        let appNames = Array(Set(onScreenWindows.map { $0.appName })).sorted()
        let currentHash = "\(resKey)_\(appNames.joined(separator: "+"))_\(Int(activeWin.width))"

        if currentHash == lastRecordedHash {
            settleCounter += 1
            // If the user has worked with this layout for at least ~45s (3 cycles)
            if settleCounter == 3 {
                let primaryWidth = screen.visibleFrame.width
                let ratio = min(0.85, max(0.20, activeWin.width / primaryWidth))
                SpaceMemory.shared.recordObservation(apps: appNames, resolution: resKey, observedMasterRatio: ratio)
            }
        } else {
            lastRecordedHash = currentHash
            settleCounter = 0
        }
    }

    @discardableResult
    func learnCurrentLayoutNow() -> String? {
        guard let screen = NSScreen.main else { return nil }
        let resKey = "\(Int(screen.frame.width))x\(Int(screen.frame.height))"

        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return nil }

        let config = Config.load()
        var onScreenWindows: [(appName: String, width: Double)] = []

        for win in list {
            let layer = win[kCGWindowLayer as String] as? Int ?? -1
            let owner = win[kCGWindowOwnerName as String] as? String ?? ""
            let bounds = win[kCGWindowBounds as String] as? [String: Any] ?? [:]
            let w = bounds["Width"] as? Double ?? 0
            let h = bounds["Height"] as? Double ?? 0

            if layer == 0 && w > 200 && h > 200 && !config.ignoredApps.contains(owner) {
                onScreenWindows.append((appName: owner, width: w))
            }
        }

        guard let first = onScreenWindows.first else { return nil }
        let appNames = Array(Set(onScreenWindows.map { $0.appName })).sorted()
        let ratio = min(0.85, max(0.20, first.width / screen.visibleFrame.width))

        SpaceMemory.shared.recordObservation(apps: appNames, resolution: resKey, observedMasterRatio: ratio)
        return "Gelernt: \(appNames.joined(separator: " + ")) mit Master-Breite \(Int(ratio * 100))%"
    }
}
