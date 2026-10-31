import SwiftUI
import Combine
import ApplicationServices

// MARK: - Animated 16:9 Display Visualizer (No Glow, Settings Matched Colors)
struct AnimatedTileVisualizer: View {
    var width: CGFloat = 64
    var height: CGFloat = 36
    @State private var layoutStep = 0
    let timer = Timer.publish(every: 2.4, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 1.5) {
            // Sleek 16:9 Monitor Enclosure
            ZStack {
                // Monitor Bezel
                RoundedRectangle(cornerRadius: 3.5)
                    .fill(Color(NSColor.darkGray).opacity(0.55))
                    .overlay(
                        RoundedRectangle(cornerRadius: 3.5)
                            .stroke(Color.primary.opacity(0.25), lineWidth: 1)
                    )

                // Screen Glass Area
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    let pad: CGFloat = 2.5
                    let gap: CGFloat = 1.5

                    let innerW = w - 2 * pad
                    let innerH = h - 2 * pad

                    let cellW = (innerW - 2 * gap) / 3.0
                    let cellH = (innerH - 2 * gap) / 3.0

                    // Mode 0: 6-Window Signature (2/3 Top-Left Master, 3 Right, 2 Bottom)
                    // Mode 1: 50/50 Side-by-Side
                    // Mode 2: Master-Stack (62/38)
                    let mode = layoutStep % 3

                    let masterFrame: CGRect = {
                        if mode == 0 {
                            return CGRect(x: pad, y: pad, width: 2 * cellW + gap, height: 2 * cellH + gap)
                        } else if mode == 1 {
                            return CGRect(x: pad, y: pad, width: (innerW - gap) * 0.50, height: innerH)
                        } else {
                            return CGRect(x: pad, y: pad, width: (innerW - gap) * 0.62, height: innerH)
                        }
                    }()

                    let r1Frame: CGRect = {
                        if mode == 0 {
                            return CGRect(x: pad + 2 * (cellW + gap), y: pad, width: cellW, height: cellH)
                        } else if mode == 1 {
                            return CGRect(x: pad + (innerW - gap) * 0.50 + gap, y: pad, width: (innerW - gap) * 0.50, height: (innerH - gap) / 2)
                        } else {
                            return CGRect(x: pad + (innerW - gap) * 0.62 + gap, y: pad, width: (innerW - gap) * 0.38, height: (innerH - 2 * gap) / 3)
                        }
                    }()

                    let r2Frame: CGRect = {
                        if mode == 0 {
                            return CGRect(x: pad + 2 * (cellW + gap), y: pad + cellH + gap, width: cellW, height: cellH)
                        } else if mode == 1 {
                            return CGRect(x: pad + (innerW - gap) * 0.50 + gap, y: pad + (innerH - gap) / 2 + gap, width: (innerW - gap) * 0.50, height: (innerH - gap) / 2)
                        } else {
                            return CGRect(x: pad + (innerW - gap) * 0.62 + gap, y: pad, width: (innerW - gap) * 0.38, height: (innerH - 2 * gap) / 3)
                        }
                    }()

                    let r3Frame: CGRect = {
                        if mode == 0 {
                            return CGRect(x: pad + 2 * (cellW + gap), y: pad + 2 * (cellH + gap), width: cellW, height: cellH)
                        } else if mode == 1 {
                            return CGRect(x: pad + (innerW - gap) * 0.50 + gap, y: pad + (innerH - gap) / 2 + gap, width: (innerW - gap) * 0.50, height: 0)
                        } else {
                            return CGRect(x: pad + (innerW - gap) * 0.62 + gap, y: pad + 2 * ((innerH - 2 * gap) / 3 + gap), width: (innerW - gap) * 0.38, height: (innerH - 2 * gap) / 3)
                        }
                    }()

                    let b1Frame: CGRect = {
                        if mode == 0 {
                            return CGRect(x: pad, y: pad + 2 * (cellH + gap), width: cellW, height: cellH)
                        } else {
                            return CGRect(x: pad, y: pad, width: 0, height: 0)
                        }
                    }()

                    let b2Frame: CGRect = {
                        if mode == 0 {
                            return CGRect(x: pad + cellW + gap, y: pad + 2 * (cellH + gap), width: cellW, height: cellH)
                        } else {
                            return CGRect(x: pad, y: pad, width: 0, height: 0)
                        }
                    }()

                    ZStack(alignment: .topLeading) {
                        // Master Window (Settings Blue/Cyan palette, No Blur Glow)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.0, green: 0.38, blue: 0.58), Color(red: 0.01, green: 0.52, blue: 0.78)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(Color.cyan.opacity(0.65), lineWidth: 0.8)
                            )
                            .frame(width: max(0, masterFrame.width), height: max(0, masterFrame.height))
                            .offset(x: masterFrame.origin.x, y: masterFrame.origin.y)

                        // Secondary Windows (Frosted slate)
                        miniTile(frame: r1Frame)
                        miniTile(frame: r2Frame)
                        if mode != 1 { miniTile(frame: r3Frame) }
                        if mode == 0 {
                            miniTile(frame: b1Frame)
                            miniTile(frame: b2Frame)
                        }
                    }
                    .animation(.spring(response: 0.50, dampingFraction: 0.75), value: layoutStep)
                }
            }
            .frame(width: width, height: height)

            // Sleek Aluminum Monitor Foot / Stand
            RoundedRectangle(cornerRadius: 1)
                .fill(Color(NSColor.tertiaryLabelColor).opacity(0.6))
                .frame(width: width * 0.28, height: 2.2)
        }
        .onReceive(timer) { _ in
            layoutStep += 1
        }
        .onTapGesture {
            layoutStep += 1
        }
    }

    private func miniTile(frame: CGRect) -> some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(Color(NSColor.textColor).opacity(0.18))
            .overlay(
                RoundedRectangle(cornerRadius: 1.5)
                    .stroke(Color(NSColor.textColor).opacity(0.35), lineWidth: 0.6)
            )
            .frame(width: max(0, frame.width), height: max(0, frame.height))
            .offset(x: frame.origin.x, y: frame.origin.y)
    }
}

// MARK: - Live Grid Interactive Visualizer (Exact Usable Aspect Ratio, Real Windows, Semi-Transparent, Double-Click Master)
struct LiveGridView: View {
    let windows: [ManagedWindow]
    let onSetMasterAndRearrange: (CGWindowID, String) -> Void
    let onToggleLock: (CGWindowID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header bar
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "square.split.2x2")
                        .foregroundColor(.cyan)
                    Text("Live Space Canvas")
                        .font(.subheadline.bold())
                }

                Spacer()

                HStack(spacing: 5) {
                    Image(systemName: "hand.tap.fill")
                        .font(.caption2)
                        .foregroundColor(.cyan)
                    Text("Double-click any window to set as Master & rearrange")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Screen Canvas (strictly matching workArea aspect ratio, no pixel labels)
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                ZStack(alignment: .topLeading) {
                    // Desktop Background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.65))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                        )

                    // Spanned Grid Raster
                    gridRaster(width: w, height: h)

                    // Render Windows
                    if windows.isEmpty {
                        VStack(spacing: 6) {
                            Image(systemName: "rectangle.badge.xmark")
                                .font(.system(size: 20))
                                .foregroundColor(.secondary)
                            Text("No application windows detected on this Space.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(width: w, height: h, alignment: .center)
                    } else {
                        ForEach(Array(windows.enumerated()), id: \.element.id) { index, win in
                            windowBox(index: index, win: win, canvasW: w, canvasH: h)
                        }
                    }
                }
            }
            .aspectRatio(workAreaAspect, contentMode: .fit)
            .frame(maxHeight: 200)
        }
    }

    private var currentScreen: NSScreen {
        NSScreen.main ?? NSScreen.screens.first!
    }

    private var workAreaAspect: CGFloat {
        let vf = currentScreen.visibleFrame
        return max(1.0, vf.width) / max(1.0, vf.height)
    }

    private var axRect: CGRect {
        let vf = currentScreen.visibleFrame
        let primaryH = NSScreen.screens.first?.frame.height ?? 0
        return CGRect(
            x: vf.origin.x,
            y: primaryH - (vf.origin.y + vf.height),
            width: vf.width,
            height: vf.height
        )
    }

    // Dynamic grid cols & rows spanned across display
    private var gridDimensions: (cols: Int, rows: Int) {
        let count = windows.count
        if count <= 1 { return (1, 1) }
        if count == 2 { return (2, 1) }
        if count <= 4 { return (2, 2) }
        if count <= 6 { return (3, 2) }
        return (10, 6)
    }

    private func gridRaster(width: CGFloat, height: CGFloat) -> some View {
        let (cols, rows) = gridDimensions
        return ZStack {
            ForEach(1..<cols, id: \.self) { c in
                let xPct = CGFloat(c) / CGFloat(cols)
                Path { p in
                    p.move(to: CGPoint(x: xPct * width, y: 0))
                    p.addLine(to: CGPoint(x: xPct * width, y: height))
                }
                .stroke(Color.primary.opacity(0.08), style: StrokeStyle(lineWidth: 0.8, dash: [3, 3]))
            }
            ForEach(1..<rows, id: \.self) { r in
                let yPct = CGFloat(r) / CGFloat(rows)
                Path { p in
                    p.move(to: CGPoint(x: 0, y: yPct * height))
                    p.addLine(to: CGPoint(x: width, y: yPct * height))
                }
                .stroke(Color.primary.opacity(0.08), style: StrokeStyle(lineWidth: 0.8, dash: [3, 3]))
            }
        }
    }

    private func windowBox(index: Int, win: ManagedWindow, canvasW: CGFloat, canvasH: CGFloat) -> some View {
        let rawX = (win.currentFrame.origin.x - axRect.origin.x) / axRect.width
        let rawY = (win.currentFrame.origin.y - axRect.origin.y) / axRect.height
        let rawW = win.currentFrame.width / axRect.width
        let rawH = win.currentFrame.height / axRect.height

        let relX = max(0, min(0.95, rawX))
        let relY = max(0, min(0.95, rawY))
        let relW = max(0.08, min(1.0 - relX, rawW))
        let relH = max(0.08, min(1.0 - relY, rawH))

        let boxX = relX * canvasW
        let boxY = relY * canvasH
        let boxW = relW * canvasW
        let boxH = relH * canvasH

        let isMaster = (index == 0)

        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Circle().fill(Color.red.opacity(0.85)).frame(width: 5, height: 5)
                Circle().fill(Color.orange.opacity(0.85)).frame(width: 5, height: 5)
                Circle().fill(Color.green.opacity(0.85)).frame(width: 5, height: 5)

                Text(win.appName)
                    .font(.system(size: 9, weight: .bold))
                    .lineLimit(1)

                Spacer()

                if win.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.orange)
                } else if isMaster {
                    Text("★ MASTER")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 3).padding(.vertical, 1)
                        .background(Color.cyan.opacity(0.35))
                        .foregroundColor(.cyan)
                        .cornerRadius(2)
                }
            }

            if boxH > 35 && !win.title.isEmpty {
                Text(win.title)
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(4)
        .frame(width: boxW, height: boxH)
        .background(
            isMaster
                ? Color.cyan.opacity(0.32)
                : Color(NSColor.controlAccentColor).opacity(0.20)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(
                    win.isLocked
                        ? Color.orange.opacity(0.85)
                        : (isMaster ? Color.cyan.opacity(0.85) : Color.primary.opacity(0.25)),
                    lineWidth: isMaster ? 1.5 : 1
                )
        )
        .cornerRadius(4)
        .offset(x: boxX, y: boxY)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onSetMasterAndRearrange(win.id, win.appName)
        }
    }
}

// MARK: - Main Settings View
struct SettingsView: View {
    @State private var config: Config = Config.load()
    @State private var statusMessage: String?
    @State private var currentWindows: [ManagedWindow] = []
    @State private var selectedTab: Int
    @State private var recordingField: String? = nil
    @State private var isAccessibilityGranted: Bool = WindowManager.canControlWindows()
    @State private var daemonStatus: (isRunning: Bool, pid: Int?) = ServiceInstaller.statusInfo()
    @State private var recentLogs: [String] = ServiceInstaller.getRecentLogs()
    @State private var localEventMonitor: Any? = nil

    static func loadAppIcon() -> NSImage? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let paths = [
            "\(home)/Applications/SpaceTile.app/Contents/Resources/AppIcon.png",
            "\(home)/Code/spacetile/assets/AppIcon.png"
        ]
        for p in paths {
            if let img = NSImage(contentsOfFile: p) { return img }
        }
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        return nil
    }

    init(tabName: String? = nil) {
        let tab: Int
        switch tabName?.lowercased() {
        case "grid", "live", "space", "0": tab = 0
        case "shortcuts", "hotkeys", "1": tab = 1
        case "scoring", "scores", "weights", "apps", "2": tab = 2
        case "daemon", "logs", "3": tab = 3
        case "about", "info", "4": tab = 4
        default: tab = 0
        }
        _selectedTab = State(initialValue: tab)
    }

    let pollTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 14) {
                AnimatedTileVisualizer(width: 58, height: 32.6)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text("SpaceTile")
                            .font(.title2.bold())

                        // Dynamic Accessibility Status
                        if isAccessibilityGranted {
                            Label("Accessibility: Granted", systemImage: "checkmark.circle.fill")
                                .font(.caption2.bold())
                                .foregroundColor(.green)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.green.opacity(0.15))
                                .cornerRadius(4)
                        } else {
                            Label("Accessibility: Required", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption2.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.red)
                                .cornerRadius(4)
                        }

                        // Dynamic Daemon Status
                        Label(daemonStatus.isRunning ? "Daemon Active" : "Daemon Stopped", systemImage: daemonStatus.isRunning ? "bolt.fill" : "pause.fill")
                            .font(.caption2.bold())
                            .foregroundColor(daemonStatus.isRunning ? .cyan : .orange)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background((daemonStatus.isRunning ? Color.cyan : Color.orange).opacity(0.15))
                            .cornerRadius(4)
                    }
                    Text("Intelligent On-Demand Window Tiling for macOS")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Prominent Rearrange Now Button (Taller, distinct primary action)
                Button(action: triggerOptimizeNow) {
                    HStack(spacing: 7) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .bold))
                        Text("Rearrange Now")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .frame(height: 34)
                    .padding(.horizontal, 16)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.cyan)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.75))

            // Accessibility Warning Banner (Dismisses as soon as granted)
            if !isAccessibilityGranted {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 12) {
                        Image(systemName: "hand.raised.fill")
                            .font(.title3)
                            .foregroundColor(.red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Accessibility Permission Required")
                                .font(.subheadline.bold())
                            Text("SpaceTile needs Accessibility access in macOS System Settings -> Privacy & Security -> Accessibility to arrange windows.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()

                        Button("Open System Settings") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                NSWorkspace.shared.open(url)
                            }
                            _ = WindowManager.isAccessibilityGranted(prompt: true)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)

                        Button("Reveal SpaceTile in Finder") {
                            NSWorkspace.shared.selectFile("/Users/guppi/Applications/SpaceTile.app", inFileViewerRootedAtPath: "/Users/guppi/Applications")
                        }
                        .buttonStyle(.bordered)
                    }

                    Text("💡 If 'spacetile' (CLI) is toggled on, please also toggle or drag 'SpaceTile.app' into the list.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.12))
            }

            Divider()

            // Segmented Tabs
            Picker("", selection: $selectedTab) {
                Text("Live Grid").tag(0)
                Text("Shortcuts & Spacing").tag(1)
                Text("Window Scores (1-100)").tag(2)
                Text("Daemon & Logs").tag(3)
                Text("About SpaceTile").tag(4)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 6)

            // Content Area (Fixed Height, Fits Cleanly without Scrolling)
            VStack {
                switch selectedTab {
                case 0: liveGridTab
                case 1: shortcutsTab
                case 2: windowScoresTab
                case 3: daemonTab
                case 4: aboutTab
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)

            Divider()

            // Footer
            HStack(spacing: 12) {
                if let msg = statusMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundColor(.green)
                }

                Spacer()

                Button("Reset Defaults") {
                    config = Config.default
                    config.save()
                    _ = HotKeyManager.shared.register(config: config)
                    showStatus("Defaults restored.")
                }

                Button("Save Changes") {
                    config.save()
                    _ = HotKeyManager.shared.register(config: config)
                    showStatus("Settings saved successfully.")
                }
                .keyboardShortcut(.defaultAction)

                Button("Close") {
                    SettingsWindowController.shared.close()
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        }
        .frame(width: 880, height: 620)
        .onAppear {
            refreshData()
            checkStatus()
        }
        .onReceive(pollTimer) { _ in
            checkStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            checkStatus()
            refreshData()
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.activeSpaceDidChangeNotification)) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                refreshData()
            }
        }
        .onReceive(DistributedNotificationCenter.default().publisher(for: NSNotification.Name("com.apple.accessibility.api"))) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                checkStatus()
                refreshData()
            }
        }
        .onDisappear {
            stopRecording()
        }
    }

    // MARK: - Tab 0: Live Grid (True Usable Aspect Ratio, Grid Spanning, Semi-Transparent, Double-Click Master)
    var liveGridTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            LiveGridView(
                windows: currentWindows,
                onSetMasterAndRearrange: { winID, appName in
                    WindowManager.shared.optimize(verbose: true, forcedMasterID: winID)
                    refreshData()
                    showStatus("Promoted '\(appName)' to Master & rearranged.")
                },
                onToggleLock: { winID in
                    let isLocked = WindowManager.shared.lockedWindowIDs.contains(winID)
                    WindowManager.shared.setWindowLocked(id: winID, locked: !isLocked)
                    refreshData()
                }
            )

            HStack {
                Text("Recognized Windows on Current Space (\(currentWindows.count)):")
                    .font(.subheadline.bold())
                Spacer()
                Button(action: refreshData) {
                    Label("Sync Space", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 2)

            if currentWindows.isEmpty {
                VStack(spacing: 4) {
                    Text("No manageable windows detected.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 5) {
                    ForEach(Array(currentWindows.prefix(4).enumerated()), id: \.element.id) { index, win in
                        activeWindowRow(index: index, win: win)
                    }
                }
            }
        }
    }

    private func activeWindowRow(index: Int, win: ManagedWindow) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(win.appName).fontWeight(.bold)
                    if win.isLocked {
                        Text("🔒 Locked")
                            .font(.caption2.bold())
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(4)
                    } else if index == 0 {
                        Text("★ Master")
                            .font(.caption2.bold())
                            .foregroundColor(.green)
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Color.green.opacity(0.15))
                            .cornerRadius(4)
                    }
                    Text("Score: \(win.score)")
                        .font(.caption2.monospaced())
                        .foregroundColor(.secondary)
                }
                Text(win.title.isEmpty ? "(No title)" : win.title)
                    .font(.caption).foregroundColor(.secondary).lineLimit(1)
            }

            Spacer()

            Button(win.isLocked ? "Unlock" : "Lock Position") {
                WindowManager.shared.setWindowLocked(id: win.id, locked: !win.isLocked)
                refreshData()
            }
            .buttonStyle(.bordered)

            if index != 0 && !win.isLocked {
                Button("Set as Master") {
                    WindowManager.shared.optimize(verbose: true, forcedMasterID: win.id)
                    refreshData()
                    showStatus("Set \(win.appName) as Master.")
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
            }
        }
        .padding(6)
        .background(Color.secondary.opacity(index == 0 ? 0.12 : 0.05))
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            WindowManager.shared.optimize(verbose: true, forcedMasterID: win.id)
            refreshData()
            showStatus("Promoted '\(win.appName)' to Master & rearranged.")
        }
    }

    // MARK: - Tab 1: Shortcuts & Spacing (with multi-step smoothness & content freeze)
    var shortcutsTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            GroupBox(label: Label("Global Hotkeys (Record New)", systemImage: "keyboard")) {
                VStack(spacing: 6) {
                    shortcutRow(title: "Rearrange Windows", desc: "Tiles all windows into the dynamic grid", shortcut: config.shortcut, field: "optimize")
                    Divider()
                    shortcutRow(title: "Set Window as Master", desc: "Promotes focused window to master slot", shortcut: config.masterShortcut, field: "master")
                    Divider()
                    shortcutRow(title: "Lock/Unlock Active Window", desc: "Locks window in place; reserves its grid tiles", shortcut: config.lockShortcut, field: "lock")
                    Divider()
                    shortcutRow(title: "Open Settings GUI", desc: "Opens this configuration window", shortcut: config.guiShortcut, field: "gui")
                }
                .padding(5)
            }

            GroupBox(label: Label("Grid & Window Sizing", systemImage: "square.grid.3x3")) {
                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Inner Gap:")
                            Slider(value: $config.gap, in: 0...32, step: 1)
                            Text("\(Int(config.gap)) px").font(.caption.monospaced()).frame(width: 45)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Outer Margin:")
                            Slider(value: $config.margin, in: 0...48, step: 1)
                            Text("\(Int(config.margin)) px").font(.caption.monospaced()).frame(width: 45)
                        }
                    }
                }
                .padding(5)
            }

            GroupBox(label: Label("Window Animation & Smoothness", systemImage: "speedometer")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Text("Mode:")
                            .font(.subheadline.bold())
                            .fixedSize()

                        Picker("", selection: $config.animationMode) {
                            Text("Direct (Zero-Lag Snap)").tag("instant")
                            Text("Smooth Motion Glide").tag("smooth")
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 320)

                        Text(config.animationMode == "instant" ? "Instant snap, zero lag, no IPC stutter." : "Multi-step cubic ease glide.")
                            .font(.caption).foregroundColor(.secondary)
                    }

                    if config.animationMode == "smooth" {
                        HStack(spacing: 24) {
                            HStack {
                                Text("Duration:")
                                Slider(value: $config.animationDuration, in: 0.06...0.35, step: 0.02)
                                Text("\(Int(config.animationDuration * 1000)) ms").font(.caption.monospaced()).frame(width: 55)
                            }

                            HStack {
                                Text("Steps:")
                                Slider(value: Binding(
                                    get: { Double(config.animationSteps) },
                                    set: { config.animationSteps = Int($0) }
                                ), in: 4...20, step: 1)
                                Text("\(config.animationSteps) frames").font(.caption.monospaced()).frame(width: 65)
                            }
                        }

                        Toggle("Freeze window content redraw during resize (Atomic Display Sync)", isOn: $config.freezeContentDuringResize)
                            .font(.caption.bold())
                        Text("Uses SkyLight CGSDisableUpdate/CGSReenableUpdate to prevent apps (Chrome, VSCode, iTerm2) from layout-thrashing on every intermediate frame.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(5)
            }
        }
    }

    private func shortcutRow(title: String, desc: String, shortcut: ShortcutConfig, field: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).fontWeight(.medium)
                Text(desc).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            if recordingField == field {
                Button("Press Keys on Keyboard...") { stopRecording() }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
            } else {
                Text(shortcut.displayString)
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.12))
                    .cornerRadius(6)
                    .font(.system(.caption, design: .monospaced))

                Button("Record New") { startRecording(field: field) }
            }
        }
    }

    // MARK: - Tab 2: Window Scores (1-100) & Appetite
    var windowScoresTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Window Appetite Scores (1 - 100)")
                        .font(.headline)
                    Text("Higher scores reserve more columns on the grid. Terminals stay focused (~32 score, max 1024px width), while Browsers & IDEs expand (~70-75 score).")
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                HStack(spacing: 8) {
                    scoreBadge(label: "Compact (1-35)", color: .orange)
                    scoreBadge(label: "Balanced (50)", color: .blue)
                    scoreBadge(label: "Wide (70+)", color: .cyan)
                }
            }

            VStack(spacing: 7) {
                scoreAppCategoryCard(
                    title: "Terminal Apps",
                    apps: "iTerm2, Terminal, Ghostty, Kitty, Alacritty",
                    score: 32,
                    desc: "Capped to 3 columns on 10x6 4K grid (max 1024px width)",
                    icon: "terminal"
                )
                scoreAppCategoryCard(
                    title: "Web Browsers",
                    apps: "Google Chrome, Safari, Arc, Firefox",
                    score: 72,
                    desc: "Claims 6-7 columns on 10x6 grid (2300px+)",
                    icon: "globe"
                )
                scoreAppCategoryCard(
                    title: "Code Editors",
                    apps: "VS Code, Xcode, Cursor",
                    score: 75,
                    desc: "Generous code viewing width for sidebars & split panes",
                    icon: "chevron.left.forwardslash.chevron.right"
                )
                scoreAppCategoryCard(
                    title: "Notes & Documents",
                    apps: "Obsidian, Apple Notes, Bear",
                    score: 50,
                    desc: "Balanced reading column; 50/50 when paired with browser",
                    icon: "note.text"
                )
            }

            GroupBox(label: Label("Smart Pairing Rules", systemImage: "link")) {
                Toggle("Auto Side-by-Side (50/50) when Browser is paired with Notes", isOn: $config.sideBySideForNotesAndBrowser)
                    .fontWeight(.medium)
            }
        }
    }

    private func scoreBadge(label: String, color: Color) -> some View {
        Text(label)
            .font(.caption2.bold())
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(4)
    }

    private func scoreAppCategoryCard(title: String, apps: String, score: Int, desc: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.cyan)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(title).fontWeight(.semibold)
                    Text("(\(apps))").font(.caption2).foregroundColor(.secondary).lineLimit(1)
                }
                Text(desc).font(.caption2).foregroundColor(.secondary)
            }

            Spacer()

            Text("Score: \(score)")
                .font(.system(.caption, design: .monospaced).bold())
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(score > 60 ? Color.blue.opacity(0.18) : Color.orange.opacity(0.18))
                .foregroundColor(score > 60 ? .blue : .orange)
                .cornerRadius(6)
        }
        .padding(8)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(8)
    }

    // MARK: - Tab 3: Daemon & Real-time Logs
    var daemonTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            GroupBox(label: Label("macOS System Permissions", systemImage: "hand.raised.fill")) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(isAccessibilityGranted ? Color.green : Color.red)
                                .frame(width: 9, height: 9)
                            Text(isAccessibilityGranted ? "Accessibility Permission: Granted" : "Accessibility Permission: Missing")
                                .fontWeight(.bold)
                        }
                        Text(isAccessibilityGranted ? "SpaceTile has full permission to detect window positions and arrange windows." : "Enable SpaceTile in System Settings -> Privacy & Security -> Accessibility.")
                            .font(.caption).foregroundColor(.secondary)
                    }

                    Spacer()

                    Button("Open System Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                        _ = WindowManager.isAccessibilityGranted(prompt: true)
                    }
                    .buttonStyle(.bordered)

                    Button("Reveal in Finder") {
                        NSWorkspace.shared.selectFile("/Users/guppi/Applications/SpaceTile.app", inFileViewerRootedAtPath: "/Users/guppi/Applications")
                    }
                    .buttonStyle(.bordered)

                    Button(action: {
                        checkStatus()
                        if isAccessibilityGranted {
                            showStatus("✓ Verified: Accessibility permissions are active!")
                        } else {
                            showStatus("❌ Missing: Please enable SpaceTile in System Settings.")
                        }
                    }) {
                        Label("Verify", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(5)
            }

            GroupBox(label: Label("Background Service Control", systemImage: "gearshape.2.fill")) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(daemonStatus.isRunning ? Color.green : Color.red)
                                .frame(width: 9, height: 9)
                            Text(daemonStatus.isRunning ? "Daemon is Running" : "Daemon is Stopped")
                                .fontWeight(.bold)
                            if let pid = daemonStatus.pid {
                                Text("(PID: \(pid))").font(.caption.monospaced()).foregroundColor(.secondary)
                            }
                        }
                        Text("Auto-starts at login via ~/Library/LaunchAgents/com.guppi.spacetile.plist")
                            .font(.caption).foregroundColor(.secondary)
                    }

                    Spacer()

                    Button("Restart Daemon") {
                        showStatus("Restarting daemon...")
                        ServiceInstaller.restartAndReopenSettings(targetTab: "daemon")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)

                    if daemonStatus.isRunning {
                        Button("Stop") {
                            ServiceInstaller.stop()
                            checkStatus()
                        }
                        .foregroundColor(.red)
                    } else {
                        Button("Start") {
                            ServiceInstaller.start()
                            checkStatus()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(5)
            }

            // Real-time macOS Terminal Log Frame
            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 6) {
                        Circle().fill(Color.red.opacity(0.85)).frame(width: 9, height: 9)
                        Circle().fill(Color.orange.opacity(0.85)).frame(width: 9, height: 9)
                        Circle().fill(Color.green.opacity(0.85)).frame(width: 9, height: 9)
                        Text("zsh · spacetile-daemon (~/Library/Logs/SpaceTile/stdout.log)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.75))
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Circle().fill(Color.green).frame(width: 6, height: 6)
                            Text("STREAMING")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(.green)
                        }

                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(recentLogs.joined(separator: "\n"), forType: .string)
                            showStatus("Logs copied to clipboard!")
                        }) {
                            Label("Copy", systemImage: "doc.on.doc")
                                .font(.caption2)
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.white.opacity(0.8))

                        Button(action: {
                            recentLogs = ServiceInstaller.getRecentLogs()
                            showStatus("Logs refreshed.")
                        }) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                                .font(.caption2)
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.85))

                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(recentLogs, id: \.self) { line in
                            Text(line)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.green.opacity(0.9))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                }
                .frame(height: 140)
                .background(Color.black.opacity(0.92))
            }
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.12), lineWidth: 1))
        }
    }

    // MARK: - Tab 4: About SpaceTile (with 16:9 visualizer, telemetry badges & coffee)
    var aboutTab: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 4)

            HStack(spacing: 20) {
                AnimatedTileVisualizer(width: 88, height: 49.5)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("SpaceTile")
                            .font(.title.bold())
                        if let icon = SettingsView.loadAppIcon() {
                            Image(nsImage: icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                                .cornerRadius(5)
                        }
                    }
                    Text("Version 1.4.0 (macOS Native)")
                        .font(.subheadline).foregroundColor(.secondary)
                    Text("Grid-based ergonomic window allocation for macOS.")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.06))
            .cornerRadius(12)

            // Telemetry Badges
            HStack(spacing: 16) {
                telemetryCard(title: "Core Engine", val: "Swift 5.9", icon: "cpu")
                telemetryCard(title: "IPC Latency", val: "< 20ms", icon: "bolt.fill")
                telemetryCard(title: "License", val: "MIT Open Source", icon: "checkmark.seal.fill")
            }
            .frame(maxWidth: 500)

            VStack(spacing: 12) {
                Text("SpaceTile is free and open source. Enjoying it?")
                    .font(.subheadline).foregroundColor(.secondary)

                HStack(spacing: 16) {
                    Button(action: {
                        if let url = URL(string: "https://github.com/guppi/spacetile") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        Label("GitHub Repository", systemImage: "link")
                            .padding(.horizontal, 10).padding(.vertical, 6)
                    }

                    Button(action: {
                        if let url = URL(string: "https://buymeacoffee.com/spacetile") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "cup.and.saucer.fill")
                            Text("Buy Me a Coffee").fontWeight(.semibold)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.85, green: 0.47, blue: 0.02)) // #d97706 warm amber
                }
            }
            .padding(.top, 6)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func telemetryCard(title: String, val: String, icon: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.cyan)
            Text(val)
                .font(.subheadline.bold())
                .foregroundColor(.primary)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(8)
    }

    // MARK: - Shortcut Recording
    func startRecording(field: String) {
        stopRecording()
        recordingField = field

        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            var mods: [String] = []
            let flags = event.modifierFlags

            let isHyper = flags.contains(.command) && flags.contains(.option) && flags.contains(.control) && flags.contains(.shift)
            if isHyper {
                mods = ["hyper"]
            } else {
                if flags.contains(.command) { mods.append("command") }
                if flags.contains(.option) { mods.append("option") }
                if flags.contains(.control) { mods.append("control") }
                if flags.contains(.shift) { mods.append("shift") }
            }

            let keyName = KeyCodes.name(for: event.keyCode)
            let newShortcut = ShortcutConfig(modifiers: mods.isEmpty ? ["hyper"] : mods, key: keyName)

            switch field {
            case "optimize": self.config.shortcut = newShortcut
            case "master": self.config.masterShortcut = newShortcut
            case "lock": self.config.lockShortcut = newShortcut
            case "gui": self.config.guiShortcut = newShortcut
            default: break
            }

            self.config.save()
            _ = HotKeyManager.shared.register(config: self.config)
            self.showStatus("Updated shortcut for '\(field)'.")

            DispatchQueue.main.async {
                self.stopRecording()
            }
            return nil
        }
    }

    func stopRecording() {
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        recordingField = nil
    }

    // MARK: - Helpers
    func checkStatus() {
        let granted = WindowManager.canControlWindows()
        if granted != isAccessibilityGranted {
            isAccessibilityGranted = granted
            if granted {
                showStatus("Accessibility permission detected!")
            }
        }
        daemonStatus = ServiceInstaller.statusInfo()
        recentLogs = ServiceInstaller.getRecentLogs()
    }

    func refreshData() {
        checkStatus()
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let vf = screen.visibleFrame
        let primaryH = NSScreen.screens.first?.frame.height ?? 0
        let axRect = CGRect(x: vf.origin.x, y: primaryH - (vf.origin.y + vf.height), width: vf.width, height: vf.height)
        currentWindows = WindowManager.shared.collectWindowsOnCurrentSpace(screenBounds: axRect, ignoredApps: Set(config.ignoredApps), config: config)
    }

    func triggerOptimizeNow() {
        WindowManager.shared.optimize(verbose: true)
        refreshData()
        showStatus("Windows rearranged.")
    }

    func showStatus(_ msg: String) {
        statusMessage = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            statusMessage = nil
        }
    }
}
