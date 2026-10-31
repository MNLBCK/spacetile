import SwiftUI
import Combine
import ApplicationServices

// MARK: - Animated 6-Window Visualizer (2/3 Master + 3 Right Stack + 2 Bottom Stack)
struct AnimatedTileVisualizer: View {
    @State private var layoutStep = 0
    let timer = Timer.publish(every: 3.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.cyan.opacity(0.35), lineWidth: 1.5)
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
                // Mode 1: Side-by-Side (50/50)
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
                    // Master
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
                                .stroke(Color.white.opacity(0.4), lineWidth: 1)
                        )
                        .frame(width: masterFrame.width, height: masterFrame.height)
                        .offset(x: masterFrame.origin.x, y: masterFrame.origin.y)
                        .shadow(color: .cyan.opacity(0.4), radius: 4)

                    // Right 1
                    tileView(frame: r1Frame)
                    // Right 2
                    tileView(frame: r2Frame)
                    // Right 3
                    if mode != 1 { tileView(frame: r3Frame) }

                    // Bottom 1 & 2 (Signature layout)
                    if mode == 0 {
                        tileView(frame: b1Frame)
                        tileView(frame: b2Frame)
                    }
                }
                .animation(.spring(response: 0.6, dampingFraction: 0.72), value: layoutStep)
            }
        }
        .frame(width: 84, height: 60)
        .onReceive(timer) { _ in
            layoutStep += 1
        }
        .onTapGesture {
            layoutStep += 1
        }
    }

    private func tileView(frame: CGRect) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.white.opacity(0.24))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
            )
            .frame(width: max(0, frame.width), height: max(0, frame.height))
            .offset(x: frame.origin.x, y: frame.origin.y)
    }
}

// MARK: - Main Settings View (English, Compact, No-Scroll)
struct SettingsView: View {
    @State private var config: Config = Config.load()
    @State private var memory: [SpaceProfile] = SpaceMemory.shared.profiles
    @State private var statusMessage: String?
    @State private var currentWindows: [ManagedWindow] = []
    @State private var selectedTab: Int = 0
    @State private var recordingField: String? = nil
    @State private var isAccessibilityGranted: Bool = AXIsProcessTrusted()
    @State private var localEventMonitor: Any? = nil

    let pollTimer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 16) {
                AnimatedTileVisualizer()

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text("SpaceTile")
                            .font(.title2.bold())
                        if !isAccessibilityGranted {
                            Text("Permission Required")
                                .font(.caption2.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .cornerRadius(4)
                        } else {
                            Text("Active")
                                .font(.caption2.bold())
                                .foregroundColor(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.15))
                                .cornerRadius(4)
                        }
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
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)

                // Close Button
                Button(action: { SettingsWindowController.shared.close() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 6)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.7))

            // Accessibility Warning Banner
            if !isAccessibilityGranted {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                        .font(.body)

                    Text("Accessibility permission needed. If toggled ON, click 'Restart Daemon' to apply.")
                        .font(.caption)

                    Spacer()

                    Button("Open System Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                        _ = WindowManager.ensureAccessibility(prompt: true)
                    }
                    .buttonStyle(.bordered)

                    Button("Restart Daemon") {
                        restartDaemonAction()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.12))
            }

            Divider()

            // Segmented Tabs
            Picker("", selection: $selectedTab) {
                Text("Shortcuts & Animation").tag(0)
                Text("Smart Weights").tag(1)
                Text("Active Space & Master").tag(2)
                Text("Space Memory (AI)").tag(3)
                Text("About").tag(4)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 6)

            // Tab Content (Fixed Height, No Scrolling)
            VStack {
                switch selectedTab {
                case 0: shortcutsTab
                case 1: smartWeightsTab
                case 2: activeSpaceTab
                case 3: spaceMemoryTab
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

                Button("Restart Daemon") {
                    restartDaemonAction()
                }

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
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        }
        .frame(width: 840, height: 580)
        .onAppear {
            refreshData()
            checkAccessibility()
        }
        .onReceive(pollTimer) { _ in
            checkAccessibility()
        }
        .onDisappear {
            stopRecording()
        }
    }

    // MARK: - Tab 0: Shortcuts & Animation
    var shortcutsTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupBox(label: Label("Global Hotkeys", systemImage: "keyboard")) {
                VStack(spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Rearrange Windows")
                                .fontWeight(.medium)
                            Text("Rearranges on-screen windows in active Space.")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        if recordingField == "optimize" {
                            Button("Press Keys on Keyboard...") { stopRecording() }
                                .buttonStyle(.borderedProminent)
                                .tint(.orange)
                        } else {
                            Text(config.shortcut.displayString)
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.12))
                                .cornerRadius(6)
                                .font(.system(.body, design: .monospaced))

                            Button("Record New") { startRecording(field: "optimize") }
                        }
                    }

                    Divider()

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Open Settings Window")
                                .fontWeight(.medium)
                            Text("Brings up this configuration panel.")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        if recordingField == "gui" {
                            Button("Press Keys on Keyboard...") { stopRecording() }
                                .buttonStyle(.borderedProminent)
                                .tint(.orange)
                        } else {
                            Text(config.guiShortcut.displayString)
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.12))
                                .cornerRadius(6)
                                .font(.system(.body, design: .monospaced))

                            Button("Record New") { startRecording(field: "gui") }
                        }
                    }
                }
                .padding(8)
            }

            GroupBox(label: Label("Window Animation", systemImage: "wand.and.stars")) {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Animate Window Repositioning Smoothly", isOn: $config.enableAnimations)
                        .fontWeight(.medium)

                    if config.enableAnimations {
                        HStack {
                            Text("Animation Duration:")
                            Slider(value: $config.animationDuration, in: 0.10...0.60, step: 0.05)
                            Text(String(format: "%.2f s", config.animationDuration))
                                .frame(width: 50)
                        }
                    }
                }
                .padding(8)
            }

            GroupBox(label: Label("Spacing & Gaps", systemImage: "slider.horizontal.3")) {
                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Inner Gap:")
                            Slider(value: $config.gap, in: 0...30, step: 1)
                            Text("\(Int(config.gap)) px").frame(width: 45)
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Outer Margin:")
                            Slider(value: $config.margin, in: 0...40, step: 1)
                            Text("\(Int(config.margin)) px").frame(width: 45)
                        }
                    }
                }
                .padding(8)
            }
        }
    }

    // MARK: - Tab 1: Smart Weights
    var smartWeightsTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupBox(label: Label("4K & Ultra-Wide Terminal Protection", systemImage: "terminal")) {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Enable Smart Window Constraints", isOn: $config.enableSmartWeighting)
                        .fontWeight(.medium)

                    Text("On 4K monitors (3840px), terminal windows are capped to readable line lengths instead of stretching 62% (~2380px) across the display.")
                        .font(.caption).foregroundColor(.secondary)

                    Divider()

                    HStack(spacing: 24) {
                        HStack {
                            Text("Max Terminal Width:")
                            Slider(value: $config.terminalMaxWidth4K, in: 700...1600, step: 50)
                            Text("\(Int(config.terminalMaxWidth4K)) px").frame(width: 60)
                        }
                        HStack {
                            Text("Max Ratio:")
                            Slider(value: $config.terminalMaxRatio4K, in: 0.20...0.45, step: 0.01)
                            Text("\(Int(config.terminalMaxRatio4K * 100))%").frame(width: 45)
                        }
                    }
                }
                .padding(8)
            }

            GroupBox(label: Label("Reading & Research Mode", systemImage: "book.pages")) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Auto Side-by-Side (50/50) for Browser + Notes / Documentation", isOn: $config.sideBySideForNotesAndBrowser)
                        .fontWeight(.medium)
                    Text("When a browser is paired with a notes or markdown editor (Obsidian, Notes, Bear), both automatically split 50/50 for optimal reading & writing.")
                        .font(.caption).foregroundColor(.secondary)
                }
                .padding(8)
            }

            GroupBox(label: Label("Single Window Behavior", systemImage: "rectangle")) {
                Picker("When only one window is open:", selection: $config.singleWindowMode) {
                    Text("Comfortable Centered Focus (75% width)").tag("centered")
                    Text("Full Screen / Maximized").tag("maximized")
                }
                .pickerStyle(.radioGroup)
                .padding(4)
            }
        }
    }

    // MARK: - Tab 2: Active Space & Master Selection
    var activeSpaceTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Windows in Current Space (\(currentWindows.count)):")
                    .font(.headline)
                Spacer()
                Button(action: refreshData) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }

            if currentWindows.isEmpty {
                Text("No manageable windows found in this Space.")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(currentWindows.prefix(5).enumerated()), id: \.element.id) { index, win in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(win.appName)
                                        .fontWeight(.bold)
                                    if index == 0 {
                                        Text("★ Master")
                                            .font(.caption2.bold())
                                            .foregroundColor(.green)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 1)
                                            .background(Color.green.opacity(0.15))
                                            .cornerRadius(4)
                                    } else {
                                        Text("Stack \(index)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Text(win.title.isEmpty ? "(No title)" : win.title)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            if index != 0 {
                                Button("Set as Master") {
                                    WindowManager.shared.optimize(verbose: true, forcedMasterID: win.id)
                                    refreshData()
                                    showStatus("Set \(win.appName) as Master.")
                                }
                                .buttonStyle(.bordered)
                            }

                            Menu("Weight") {
                                Button("Standard (62%)") {
                                    WindowManager.shared.optimize(verbose: true, forcedMasterID: win.id, forcedRatio: 0.62)
                                    refreshData()
                                }
                                Button("Side-by-Side (50%)") {
                                    WindowManager.shared.optimize(verbose: true, forcedMasterID: win.id, forcedRatio: 0.50)
                                    refreshData()
                                }
                                Button("Wide (75%)") {
                                    WindowManager.shared.optimize(verbose: true, forcedMasterID: win.id, forcedRatio: 0.75)
                                    refreshData()
                                }
                                Button("Narrow (34% / Terminal)") {
                                    WindowManager.shared.optimize(verbose: true, forcedMasterID: win.id, forcedRatio: 0.34)
                                    refreshData()
                                }
                            }
                        }
                        .padding(8)
                        .background(Color.secondary.opacity(index == 0 ? 0.12 : 0.05))
                        .cornerRadius(8)
                    }
                }
            }
        }
    }

    // MARK: - Tab 3: Space Memory
    var spaceMemoryTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupBox(label: Label("Background Learning Engine", systemImage: "brain.head.profile")) {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Observe and Learn User Habits per Space", isOn: $config.enableSpaceLearning)
                        .fontWeight(.medium)

                    Text("SpaceTile silently observes manual window adjustments. When you work with app pairs (e.g. Chrome + iTerm2), it automatically remembers your preferred ratio.")
                        .font(.caption).foregroundColor(.secondary)

                    HStack {
                        Button("Memorize Current Space Layout Now") {
                            if let msg = SpaceObserver.shared.learnCurrentLayoutNow() {
                                memory = SpaceMemory.shared.profiles
                                showStatus(msg)
                            }
                        }
                        .buttonStyle(.borderedProminent)

                        Spacer()

                        Button("Clear Memory") {
                            SpaceMemory.shared.clear()
                            memory = []
                            showStatus("Space memory cleared.")
                        }
                        .foregroundColor(.red)
                    }
                }
                .padding(8)
            }

            Text("Learned Space Profiles (\(memory.count)):")
                .font(.headline)

            if memory.isEmpty {
                Text("No profiles learned yet. Click 'Memorize Current Space Layout' above or continue working normally.")
                    .font(.caption).foregroundColor(.secondary)
            } else {
                VStack(spacing: 6) {
                    ForEach(memory.prefix(3)) { prof in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(prof.apps.joined(separator: " + "))
                                    .fontWeight(.semibold)
                                Text("Resolution: \(prof.displayResolution) • Observations: \(prof.observationsCount)")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            if let r = prof.learnedMasterRatio {
                                Text("\(Int(r * 100))% Master")
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Color.cyan.opacity(0.15))
                                    .cornerRadius(6)
                                    .foregroundColor(.cyan)
                            }
                        }
                        .padding(8)
                        .background(Color.secondary.opacity(0.06))
                        .cornerRadius(6)
                    }
                }
            }
        }
    }

    // MARK: - Tab 4: About
    var aboutTab: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 8)

            HStack(spacing: 20) {
                AnimatedTileVisualizer()
                    .scaleEffect(1.2)
                    .frame(width: 100, height: 75)

                VStack(alignment: .leading, spacing: 4) {
                    Text("SpaceTile")
                        .font(.title.bold())
                    Text("Version 1.2.0 (macOS Native)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Designed for speed, ergonomics, and seamless multitasking.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.06))
            .cornerRadius(12)

            VStack(spacing: 12) {
                Text("SpaceTile is free and open source. Enjoying it?")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 16) {
                    Button(action: {
                        if let url = URL(string: "https://github.com/guppi/spacetile") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        Label("GitHub Repository", systemImage: "link")
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                    }

                    Button(action: {
                        if let url = URL(string: "https://buymeacoffee.com/spacetile") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 6) {
                            Text("☕")
                            Text("Buy Me a Coffee")
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
            }
            .padding(.top, 10)

            Spacer()
        }
        .frame(maxWidth: .infinity)
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

            if field == "optimize" {
                self.config.shortcut = ShortcutConfig(modifiers: mods.isEmpty ? ["hyper"] : mods, key: keyName)
            } else if field == "gui" {
                self.config.guiShortcut = ShortcutConfig(modifiers: mods.isEmpty ? ["hyper"] : mods, key: keyName)
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

    // MARK: - Actions & Helpers
    func checkAccessibility() {
        isAccessibilityGranted = AXIsProcessTrusted()
    }

    func refreshData() {
        memory = SpaceMemory.shared.profiles
        checkAccessibility()
        if let primary = NSScreen.main {
            let vf = primary.visibleFrame
            let h = NSScreen.screens.first?.frame.height ?? 0
            let axRect = CGRect(x: vf.origin.x, y: h - (vf.origin.y + vf.height), width: vf.width, height: vf.height)
            currentWindows = WindowManager.shared.collectWindowsOnCurrentSpace(screenBounds: axRect, ignoredApps: Set(config.ignoredApps))
        }
    }

    func restartDaemonAction() {
        ServiceInstaller.restart()
        checkAccessibility()
        showStatus("Daemon restarted.")
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
