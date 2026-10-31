import SwiftUI
import Combine
import ApplicationServices

// MARK: - Animated Visualizer (Preserving Signature Gray Tiles + Morphing Animation)
struct AnimatedTileVisualizer: View {
    @State private var layoutStep = 0
    let timer = Timer.publish(every: 2.8, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.cyan.opacity(0.4), lineWidth: 1.5)
                )

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let pad: CGFloat = 8
                let gap: CGFloat = 4

                let innerW = w - 2 * pad
                let innerH = h - 2 * pad

                let cellW = (innerW - 2 * gap) / 3.0
                let cellH = (innerH - 2 * gap) / 3.0

                // Mode 0: 6-Window Signature Layout (2/3 Top-Left Master, 3 Right, 2 Bottom)
                // Mode 1: 50/50 Side-by-Side
                // Mode 2: Master-Stack (62/38)
                let mode = layoutStep % 3

                // Master Frame
                let masterFrame: CGRect = {
                    if mode == 0 {
                        return CGRect(x: pad, y: pad, width: 2 * cellW + gap, height: 2 * cellH + gap)
                    } else if mode == 1 {
                        return CGRect(x: pad, y: pad, width: (innerW - gap) * 0.50, height: innerH)
                    } else {
                        return CGRect(x: pad, y: pad, width: (innerW - gap) * 0.62, height: innerH)
                    }
                }()

                // Right 1 (top-right)
                let r1Frame: CGRect = {
                    if mode == 0 {
                        return CGRect(x: pad + 2 * (cellW + gap), y: pad, width: cellW, height: cellH)
                    } else if mode == 1 {
                        return CGRect(x: pad + (innerW - gap) * 0.50 + gap, y: pad, width: (innerW - gap) * 0.50, height: (innerH - gap) / 2)
                    } else {
                        return CGRect(x: pad + (innerW - gap) * 0.62 + gap, y: pad, width: (innerW - gap) * 0.38, height: (innerH - 2 * gap) / 3)
                    }
                }()

                // Right 2 (mid-right)
                let r2Frame: CGRect = {
                    if mode == 0 {
                        return CGRect(x: pad + 2 * (cellW + gap), y: pad + cellH + gap, width: cellW, height: cellH)
                    } else if mode == 1 {
                        return CGRect(x: pad + (innerW - gap) * 0.50 + gap, y: pad + (innerH - gap) / 2 + gap, width: (innerW - gap) * 0.50, height: (innerH - gap) / 2)
                    } else {
                        return CGRect(x: pad + (innerW - gap) * 0.62 + gap, y: pad + (innerH - 2 * gap) / 3 + gap, width: (innerW - gap) * 0.38, height: (innerH - 2 * gap) / 3)
                    }
                }()

                // Right 3 (bottom-right)
                let r3Frame: CGRect = {
                    if mode == 0 {
                        return CGRect(x: pad + 2 * (cellW + gap), y: pad + 2 * (cellH + gap), width: cellW, height: cellH)
                    } else if mode == 1 {
                        return CGRect(x: pad + (innerW - gap) * 0.50 + gap, y: pad + (innerH - gap) / 2 + gap, width: (innerW - gap) * 0.50, height: 0)
                    } else {
                        return CGRect(x: pad + (innerW - gap) * 0.62 + gap, y: pad + 2 * ((innerH - 2 * gap) / 3 + gap), width: (innerW - gap) * 0.38, height: (innerH - 2 * gap) / 3)
                    }
                }()

                // Bottom 1 (bottom-left under master)
                let b1Frame: CGRect = {
                    if mode == 0 {
                        return CGRect(x: pad, y: pad + 2 * (cellH + gap), width: cellW, height: cellH)
                    } else {
                        return CGRect(x: pad, y: pad, width: 0, height: 0)
                    }
                }()

                // Bottom 2 (bottom-mid under master)
                let b2Frame: CGRect = {
                    if mode == 0 {
                        return CGRect(x: pad + cellW + gap, y: pad + 2 * (cellH + gap), width: cellW, height: cellH)
                    } else {
                        return CGRect(x: pad, y: pad, width: 0, height: 0)
                    }
                }()

                ZStack(alignment: .topLeading) {
                    // Master Cyan Window
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [Color.cyan, Color.blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.5), lineWidth: 1.2)
                        )
                        .frame(width: max(0, masterFrame.width), height: max(0, masterFrame.height))
                        .offset(x: masterFrame.origin.x, y: masterFrame.origin.y)
                        .shadow(color: .cyan.opacity(0.4), radius: 4)

                    // Secondary Gray / Frosted Windows
                    grayTile(frame: r1Frame)
                    grayTile(frame: r2Frame)
                    if mode != 1 { grayTile(frame: r3Frame) }
                    if mode == 0 {
                        grayTile(frame: b1Frame)
                        grayTile(frame: b2Frame)
                    }
                }
                .animation(.spring(response: 0.55, dampingFraction: 0.72), value: layoutStep)
            }
        }
        .frame(width: 86, height: 62)
        .onReceive(timer) { _ in
            layoutStep += 1
        }
        .onTapGesture {
            layoutStep += 1
        }
    }

    private func grayTile(frame: CGRect) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color(NSColor.textColor).opacity(0.18))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color(NSColor.textColor).opacity(0.35), lineWidth: 1)
            )
            .frame(width: max(0, frame.width), height: max(0, frame.height))
            .offset(x: frame.origin.x, y: frame.origin.y)
    }
}

// MARK: - Live 10x6 Matrix Visualizer
struct LiveMatrixVisualizer: View {
    let windows: [ManagedWindow]

    var body: some View {
        VStack(spacing: 6) {
            // Header bar for matrix
            HStack {
                Label("Virtual Desktop Matrix (10 × 6 Grid)", systemImage: "square.grid.3x3.fill")
                    .font(.caption.bold())
                    .foregroundColor(.cyan)

                Spacer()

                Text(windows.isEmpty ? "Simulated Layout • 3 Windows" : "\(windows.count) Active Windows on Space")
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.cyan.opacity(0.12))
                    .foregroundColor(.cyan)
                    .cornerRadius(4)
            }

            // Matrix Screen Canvas
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.65))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )

                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    let masterW = max(180, w * 0.58)
                    let stackW = max(120, w - masterW - 8)
                    let stackH = (h - 8) / 2.0

                    HStack(spacing: 8) {
                        // Master Window Slot (60% width, 100% height)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                HStack(spacing: 4) {
                                    Circle().fill(Color.red.opacity(0.85)).frame(width: 7, height: 7)
                                    Circle().fill(Color.orange.opacity(0.85)).frame(width: 7, height: 7)
                                    Circle().fill(Color.green.opacity(0.85)).frame(width: 7, height: 7)
                                    Text(masterAppName)
                                        .font(.caption2.bold())
                                        .lineLimit(1)
                                }
                                Spacer()
                                HStack(spacing: 4) {
                                    if isMasterLocked {
                                        Image(systemName: "lock.fill")
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                    }
                                    Text("MASTER (60%)")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .padding(.horizontal, 5).padding(.vertical, 1)
                                        .background(Color.blue.opacity(0.2))
                                        .foregroundColor(.blue)
                                        .cornerRadius(3)
                                }
                            }

                            Spacer()

                            VStack(alignment: .leading, spacing: 2) {
                                Text(masterTitle)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                Text("Cols 1-6 • Rows 1-6 (10x6 Grid Matrix)")
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .foregroundColor(.cyan.opacity(0.9))
                            }
                        }
                        .padding(8)
                        .frame(width: masterW, height: h)
                        .background(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.22), Color.cyan.opacity(0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.cyan.opacity(0.4), lineWidth: 1.2)
                        )
                        .cornerRadius(6)

                        // Secondary Stack Column (40% width)
                        VStack(spacing: 8) {
                            // Stack 1 (Top)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(stack1AppName)
                                        .font(.caption2.bold())
                                        .lineLimit(1)
                                    Spacer()
                                    Text("STACK 1 (40%)")
                                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                        .padding(.horizontal, 4).padding(.vertical, 1)
                                        .background(Color.secondary.opacity(0.15))
                                        .cornerRadius(3)
                                }
                                Spacer()
                                Text("Cols 7-10 • Rows 1-3")
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            .padding(6)
                            .frame(width: stackW, height: stackH)
                            .background(Color(NSColor.textColor).opacity(0.08))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                            .cornerRadius(6)

                            // Stack 2 (Bottom)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(stack2AppName)
                                        .font(.caption2.bold())
                                        .lineLimit(1)
                                    Spacer()
                                    Text("STACK 2 (40%)")
                                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                        .padding(.horizontal, 4).padding(.vertical, 1)
                                        .background(Color.secondary.opacity(0.15))
                                        .cornerRadius(3)
                                }
                                Spacer()
                                Text("Cols 7-10 • Rows 4-6")
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            .padding(6)
                            .frame(width: stackW, height: stackH)
                            .background(Color(NSColor.textColor).opacity(0.08))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                            .cornerRadius(6)
                        }
                    }
                    .padding(6)
                }
            }
            .frame(height: 125)
        }
    }

    private var masterAppName: String {
        windows.first?.appName ?? "VS Code / Cursor"
    }

    private var masterTitle: String {
        windows.first?.title.isEmpty == false ? windows.first!.title : "Primary Editor / Document"
    }

    private var isMasterLocked: Bool {
        windows.first?.isLocked ?? false
    }

    private var stack1AppName: String {
        windows.count > 1 ? windows[1].appName : "Arc / Safari Browser"
    }

    private var stack2AppName: String {
        windows.count > 2 ? windows[2].appName : "iTerm2 / Terminal"
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
        case "space", "grid", "0": tab = 0
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
                AnimatedTileVisualizer()
                    .frame(width: 58, height: 44)
                    .shadow(color: .cyan.opacity(0.35), radius: 4, x: 0, y: 2)

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

                // Prominent Rearrange Now Button
                Button(action: triggerOptimizeNow) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                        Text("Rearrange Now")
                            .fontWeight(.bold)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)

                // Close Settings Button
                Button(action: { SettingsWindowController.shared.close() }) {
                    Label("Close", systemImage: "xmark")
                        .font(.callout.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.75))

            // Accessibility Warning Banner (Dismisses as soon as granted)
            if !isAccessibilityGranted {
                HStack(spacing: 12) {
                    Image(systemName: "hand.raised.fill")
                        .foregroundColor(.red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Accessibility Permission Missing")
                            .font(.subheadline.bold())
                        Text("Enable SpaceTile in macOS System Settings -> Privacy & Security -> Accessibility.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Open System Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                        _ = WindowManager.ensureAccessibility(prompt: true)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)

                    Button("Restart Daemon") {
                        showStatus("Restarting daemon...")
                        ServiceInstaller.restartAndReopenSettings(targetTab: "daemon")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.12))
            }

            Divider()

            // Segmented Tabs (5 Views matching Stitch)
            Picker("", selection: $selectedTab) {
                Text("Active Space & Live Grid").tag(0)
                Text("Shortcuts & Grid").tag(1)
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
                case 0: activeSpaceTab
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

    // MARK: - Tab 0: Active Space & Live Grid Matrix (from Stitch)
    var activeSpaceTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            LiveMatrixVisualizer(windows: currentWindows)

            HStack {
                Text("Recognized Windows on Active Space (\(currentWindows.count)):")
                    .font(.subheadline.bold())
                Spacer()
                Button(action: refreshData) {
                    Label("Sync Space", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 2)

            if currentWindows.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                    Text("No manageable application windows detected on this Space.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 16)
            } else {
                VStack(spacing: 6) {
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
        .padding(7)
        .background(Color.secondary.opacity(index == 0 ? 0.12 : 0.05))
        .cornerRadius(7)
    }

    // MARK: - Tab 1: Shortcuts & Grid (with multi-step smoothness & content freeze)
    var shortcutsTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            GroupBox(label: Label("Global Hotkeys (Record New)", systemImage: "keyboard")) {
                VStack(spacing: 6) {
                    shortcutRow(title: "Rearrange Windows", desc: "Tiles all windows into the dynamic 10x6 grid", shortcut: config.shortcut, field: "optimize")
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
                    HStack(spacing: 20) {
                        Picker("Mode:", selection: $config.animationMode) {
                            Text("Direct (Zero-Lag Snap)").tag("instant")
                            Text("Smooth Motion Glide").tag("smooth")
                        }
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

    // MARK: - Tab 2: Window Scores (1-100) & Appetite (from Stitch)
    var windowScoresTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Window Appetite Scores (1 - 100)")
                        .font(.headline)
                    Text("Higher scores reserve more columns on the 10x6 grid. Terminals are kept focused (~32 score, max 1024px width), while Browsers & IDEs expand (~70-75 score).")
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

    // MARK: - Tab 3: Daemon & Real-time Logs (from Stitch)
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
                        _ = WindowManager.ensureAccessibility(prompt: true)
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

            // Real-time macOS Terminal Log Frame (from Stitch)
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

    // MARK: - Tab 4: About SpaceTile (with telemetry badges & coffee)
    var aboutTab: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 4)

            HStack(spacing: 20) {
                AnimatedTileVisualizer()
                    .scaleEffect(1.2)
                    .frame(width: 95, height: 72)
                    .shadow(color: .cyan.opacity(0.35), radius: 6, x: 0, y: 3)

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
                    Text("Version 1.3.0 (macOS Native)")
                        .font(.subheadline).foregroundColor(.secondary)
                    Text("Grid-based ergonomic window allocation for macOS.")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.06))
            .cornerRadius(12)

            // Telemetry Badges (from Stitch)
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
        if let primary = NSScreen.main {
            let vf = primary.visibleFrame
            let h = NSScreen.screens.first?.frame.height ?? 0
            let axRect = CGRect(x: vf.origin.x, y: h - (vf.origin.y + vf.height), width: vf.width, height: vf.height)
            currentWindows = WindowManager.shared.collectWindowsOnCurrentSpace(screenBounds: axRect, ignoredApps: Set(config.ignoredApps), config: config)
        }
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
