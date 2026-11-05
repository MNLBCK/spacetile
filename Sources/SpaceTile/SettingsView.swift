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
            // Sleek 16:9 Monitor Enclosure Harmonized with Dock Icon
            ZStack {
                // Monitor Bezel (Dark Space Titanium)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(red: 0.13, green: 0.14, blue: 0.17))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )

                // Screen Glass Area
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color(red: 0.05, green: 0.06, blue: 0.08))
                    .padding(2)

                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    let pad: CGFloat = 3.0
                    let gap: CGFloat = 1.8

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
                        // Master Window (Electric Cyan -> Azure Gradient matching Dock AppIcon)
                        RoundedRectangle(cornerRadius: 2.2)
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.10, green: 0.83, blue: 0.99), Color(red: 0.05, green: 0.48, blue: 0.94)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 2.2)
                                    .stroke(Color(red: 0.51, green: 0.92, blue: 0.99).opacity(0.85), lineWidth: 0.8)
                            )
                            .frame(width: max(0, masterFrame.width), height: max(0, masterFrame.height))
                            .offset(x: masterFrame.origin.x, y: masterFrame.origin.y)

                        // Secondary Windows (Frosted Slate)
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

            // Sleek Brushed Aluminum Stand (Neck + Base matching Dock Icon)
            VStack(spacing: 0.5) {
                Rectangle()
                    .fill(Color(red: 0.70, green: 0.73, blue: 0.78))
                    .frame(width: width * 0.12, height: 2.0)

                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(red: 0.70, green: 0.73, blue: 0.78))
                    .frame(width: width * 0.36, height: 2.2)
            }
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
            .fill(Color(red: 0.44, green: 0.47, blue: 0.56))
            .overlay(
                RoundedRectangle(cornerRadius: 1.5)
                    .stroke(Color.white.opacity(0.85), lineWidth: 0.8)
            )
            .frame(width: max(0, frame.width), height: max(0, frame.height))
            .offset(x: frame.origin.x, y: frame.origin.y)
    }
}

// MARK: - Live Grid Interactive Visualizer (Exact Usable Aspect Ratio, Real Windows, Semi-Transparent, Drag & Drop Swap, Double-Click Main)
struct LiveGridView: View {
    let windows: [ManagedWindow]
    let mainIDs: [CGWindowID]
    let onToggleMain: (CGWindowID, String) -> Void
    let onClearAllMain: () -> Void
    let onToggleLock: (CGWindowID) -> Void
    let onToggleFloat: (CGWindowID) -> Void
    let onSwapWindows: (CGWindowID, CGWindowID) -> Void

    @State private var draggedWindowID: CGWindowID? = nil
    @State private var dragTranslation: CGSize = .zero
    @State private var hoveredDropTargetID: CGWindowID? = nil

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
                    Image(systemName: "arrow.triangle.swap")
                        .font(.caption2)
                        .foregroundColor(.cyan)
                    Text("Drag to swap slots • Double-click or Right-click to toggle Main (⭐)")
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

    private var currentScreen: NSScreen? {
        NSScreen.main ?? NSScreen.screens.first
    }

    private var workAreaAspect: CGFloat {
        guard let vf = currentScreen?.visibleFrame, vf.height > 0 else { return 16.0 / 9.0 }
        return max(1.0, vf.width) / max(1.0, vf.height)
    }

    private var axRect: CGRect {
        guard let screen = currentScreen else {
            return CGRect(x: 0, y: 0, width: 1920, height: 1080)
        }
        let vf = screen.visibleFrame
        let primaryH = NSScreen.screens.first?.frame.height ?? vf.height
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

    private func windowBoxHeader(win: ManagedWindow, isMain: Bool, isDropTarget: Bool) -> some View {
        HStack(spacing: 3) {
            Circle().fill(Color.red.opacity(0.85)).frame(width: 5, height: 5)
            Circle().fill(Color.orange.opacity(0.85)).frame(width: 5, height: 5)
            Circle().fill(Color.green.opacity(0.85)).frame(width: 5, height: 5)

            Text(win.appName)
                .font(.system(size: 9, weight: .bold))
                .lineLimit(1)

            Spacer()

            if isDropTarget {
                Image(systemName: "arrow.triangle.swap")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
            } else if win.isFloating {
                Text("✈ FLOAT")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 3).padding(.vertical, 1)
                    .background(Color.purple.opacity(0.35))
                    .foregroundColor(.purple)
                    .cornerRadius(2)
            } else if win.isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 8))
                    .foregroundColor(.orange)
            } else if isMain {
                Text("⭐ MAIN")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 3).padding(.vertical, 1)
                    .background(Color.cyan.opacity(0.35))
                    .foregroundColor(.cyan)
                    .cornerRadius(2)
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

        let isMain = mainIDs.contains(win.id)
        let isBeingDragged = (draggedWindowID == win.id)
        let isDropTarget = (hoveredDropTargetID == win.id)

        let strokeColor: Color = {
            if isDropTarget { return Color.cyan }
            if isBeingDragged { return Color.white }
            if win.isFloating { return Color.purple.opacity(0.85) }
            if win.isLocked { return Color.orange.opacity(0.85) }
            if isMain { return Color.cyan.opacity(0.85) }
            return Color.white.opacity(0.20)
        }()

        let bgColor: Color = {
            if isDropTarget { return Color.cyan.opacity(0.48) }
            if isBeingDragged { return Color.cyan.opacity(0.40) }
            if win.isFloating { return Color.purple.opacity(0.30) }
            if isMain { return Color.cyan.opacity(0.32) }
            return Color(red: 0.22, green: 0.25, blue: 0.32).opacity(0.45)
        }()

        let curX = isBeingDragged ? (boxX + dragTranslation.width) : boxX
        let curY = isBeingDragged ? (boxY + dragTranslation.height) : boxY

        return VStack(alignment: .leading, spacing: 2) {
            windowBoxHeader(win: win, isMain: isMain, isDropTarget: isDropTarget)

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
        .background(bgColor)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(strokeColor, lineWidth: (isDropTarget || isMain) ? 2.0 : 1.0))
        .cornerRadius(4)
        .shadow(color: isBeingDragged ? Color.black.opacity(0.45) : Color.clear, radius: 8, x: 0, y: 4)
        .scaleEffect(isBeingDragged ? 1.04 : (isDropTarget ? 1.02 : 1.0))
        .zIndex(isBeingDragged ? 999 : (isDropTarget ? 500 : Double(100 - index)))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onToggleMain(win.id, win.appName)
        }
        .contextMenu {
            Button(isMain ? "Aus Main-Fenstern entfernen" : "Zu Main-Fenstern hinzufügen") {
                onToggleMain(win.id, win.appName)
            }
            if !mainIDs.isEmpty {
                Button("Alle Main aufheben (Gleichmäßiges Raster)") {
                    onClearAllMain()
                }
            }
            if !win.isFloating {
                Button(win.isLocked ? "Unlock Position" : "Lock Position") {
                    onToggleLock(win.id)
                }
            }
            Button(win.isFloating ? "Unpin (Return to Grid)" : "Float Window (Always on Top)") {
                onToggleFloat(win.id)
            }
        }
        .gesture(
            DragGesture(coordinateSpace: .local)
                .onChanged { gesture in
                    draggedWindowID = win.id
                    dragTranslation = gesture.translation

                    let dragCenter = CGPoint(
                        x: boxX + boxW / 2.0 + gesture.translation.width,
                        y: boxY + boxH / 2.0 + gesture.translation.height
                    )

                    let target = windows.first { other in
                        guard other.id != win.id else { return false }
                        let oRawX = (other.currentFrame.origin.x - axRect.origin.x) / axRect.width
                        let oRawY = (other.currentFrame.origin.y - axRect.origin.y) / axRect.height
                        let oRawW = other.currentFrame.width / axRect.width
                        let oRawH = other.currentFrame.height / axRect.height

                        let oRelX = max(0, min(0.95, oRawX))
                        let oRelY = max(0, min(0.95, oRawY))
                        let oRelW = max(0.08, min(1.0 - oRelX, oRawW))
                        let oRelH = max(0.08, min(1.0 - oRelY, oRawH))

                        let oX = oRelX * canvasW
                        let oY = oRelY * canvasH
                        let oW = oRelW * canvasW
                        let oH = oRelH * canvasH
                        return CGRect(x: oX, y: oY, width: oW, height: oH).contains(dragCenter)
                    }
                    hoveredDropTargetID = target?.id
                }
                .onEnded { _ in
                    if let targetID = hoveredDropTargetID {
                        onSwapWindows(win.id, targetID)
                    }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        draggedWindowID = nil
                        dragTranslation = .zero
                        hoveredDropTargetID = nil
                    }
                }
        )
        .offset(x: curX, y: curY)
    }
}

// MARK: - Main Settings View
struct SettingsView: View {
    @State private var config: Config = Config.load()
    @State private var originalConfig: Config = Config.load()
    @State private var showUnsavedChangesAlert: Bool = false
    private var hasUnsavedChanges: Bool {
        config != originalConfig
    }
    @State private var statusMessage: String?
    @State private var currentWindows: [ManagedWindow] = []
    @State private var currentMainIDs: [CGWindowID] = WindowManager.shared.mainWindowIDs
    private var currentMasterID: CGWindowID? { currentMainIDs.first }
    private var currentSecondaryFocusID: CGWindowID? { currentMainIDs.count > 1 ? currentMainIDs[1] : nil }
    @State private var selectedTab: Int
    @State private var recordingField: String? = nil
    @State private var showFeedbackSheet: Bool = false
    @State private var feedbackSheetType: FeedbackType = .feature
    @State private var isAccessibilityGranted: Bool = WindowManager.canControlWindows()
    @State private var daemonStatus: (isRunning: Bool, pid: Int?) = ServiceInstaller.statusInfo()
    @State private var recentLogs: [String] = ServiceInstaller.getRecentLogs()
    @State private var localEventMonitor: Any? = nil

    @State private var newRulePattern: String = ""
    @State private var newRuleScore: Int = 75
    @State private var newRuleAppName: String = ""

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
        case "spacing", "layout", "motion", "2": tab = 2
        case "scoring", "scores", "weights", "apps", "memory", "spacememory", "rules", "3": tab = 3
        case "daemon", "logs", "4": tab = 4
        case "about", "info", "5": tab = 5
        default: tab = 0
        }
        _selectedTab = State(initialValue: tab)
    }

    let pollTimer = Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 16) {
                // Larger Animated 16:9 Display Icon
                AnimatedTileVisualizer(width: 80, height: 45)

                // Prominently Larger Title
                VStack(alignment: .leading, spacing: 2) {
                    Text("SpaceTile")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))

                    Text("Intelligent On-Demand Window Tiling for macOS")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Status & Action in One Single Aligned Line on the Right
                HStack(spacing: 12) {
                    if !isAccessibilityGranted {
                        Label("Accessibility Required", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color.red)
                            .clipShape(Capsule())
                    }

                    Label(daemonStatus.isRunning ? "Daemon Active" : "Daemon Stopped", systemImage: daemonStatus.isRunning ? "bolt.fill" : "pause.fill")
                        .font(.subheadline.bold())
                        .foregroundColor(daemonStatus.isRunning ? .cyan : .orange)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background((daemonStatus.isRunning ? Color.cyan : Color.orange).opacity(0.15))
                        .clipShape(Capsule())

                    // Prominently Taller Rearrange Now Button (60px Height)
                    Button(action: triggerOptimizeNow) {
                        HStack(spacing: 10) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 18, weight: .bold))
                            Text("Rearrange Now")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .frame(height: 60)
                        .padding(.horizontal, 22)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.cyan)
                }
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
                Text("Shortcuts").tag(1)
                Text("Spacing & Motion").tag(2)
                Text("Weights & Memory").tag(3)
                Text("Daemon").tag(4)
                Text("About SpaceTile").tag(5)
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
                case 2: spacingTab
                case 3: weightsAndMemoryTab
                case 4: daemonTab
                case 5: aboutTab
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
                    saveConfig()
                    showStatus("Defaults restored.")
                }

                Button("Save Changes") {
                    saveConfig()
                }
                .keyboardShortcut(.defaultAction)

                Button("Close") {
                    requestClose()
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        }
        .frame(width: 940, height: 740)
        .onExitCommand {
            requestClose()
        }
        .alert("Ungespeicherte Änderungen", isPresented: $showUnsavedChangesAlert) {
            Button("Speichern & Schließen") {
                saveConfig()
                SettingsWindowController.shared.forceClose()
            }
            Button("Nicht speichern", role: .destructive) {
                config = originalConfig
                SettingsWindowController.shared.forceClose()
            }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Du hast ungespeicherte Änderungen vorgenommen. Möchtest du diese vor dem Schließen speichern?")
        }
        .onAppear {
            refreshData()
            checkStatus()
            setupCloseAndEscHandler()
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
        .onReceive(DistributedNotificationCenter.default().publisher(for: NSNotification.Name("com.guppi.spacetile.locksChanged"))) { _ in
            DispatchQueue.main.async {
                refreshData()
            }
        }
        .onReceive(DistributedNotificationCenter.default().publisher(for: NSNotification.Name("com.guppi.spacetile.masterChanged"))) { _ in
            DispatchQueue.main.async {
                refreshData()
            }
        }
        .onReceive(DistributedNotificationCenter.default().publisher(for: NSNotification.Name("com.guppi.spacetile.secondaryFocusChanged"))) { _ in
            DispatchQueue.main.async {
                refreshData()
            }
        }
        .onReceive(DistributedNotificationCenter.default().publisher(for: NSNotification.Name("com.guppi.spacetile.windowsRearranged"))) { _ in
            DispatchQueue.main.async {
                refreshData()
            }
        }
        .onChange(of: selectedTab) { _ in
            stopRecording()
            if selectedTab == 4 {
                recentLogs = ServiceInstaller.getRecentLogs()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("com.guppi.spacetile.switchTab"))) { notif in
            if let tabName = notif.object as? String {
                switch tabName.lowercased() {
                case "grid", "live", "space", "0": selectedTab = 0
                case "shortcuts", "hotkeys", "1": selectedTab = 1
                case "spacing", "layout", "motion", "2": selectedTab = 2
                case "scoring", "scores", "weights", "apps", "memory", "spacememory", "rules", "3": selectedTab = 3
                case "daemon", "logs", "4": selectedTab = 4
                case "about", "info", "5": selectedTab = 5
                default: break
                }
            }
        }
        .onDisappear {
            stopRecording()
            removeEscHandler()
        }
        .sheet(isPresented: $showFeedbackSheet) {
            FeedbackSheetView(isPresented: $showFeedbackSheet, selectedType: feedbackSheetType)
        }
    }

    // MARK: - Tab 0: Live Grid (True Usable Aspect Ratio, Grid Spanning, Semi-Transparent, Drag & Drop Swap, Double-Click Master)
    var liveGridTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            LiveGridView(
                windows: currentWindows,
                mainIDs: currentMainIDs,
                onToggleMain: { winID, appName in
                    toggleMainWindow(id: winID)
                },
                onClearAllMain: {
                    clearAllMain()
                },
                onToggleLock: { winID in
                    let isLocked = WindowManager.shared.lockedWindowIDs.contains(winID)
                    WindowManager.shared.setWindowLocked(id: winID, locked: !isLocked)
                    refreshData()
                },
                onToggleFloat: { winID in
                    let isFloat = WindowManager.shared.floatingWindowIDs.contains(winID)
                    WindowManager.shared.setWindowFloating(id: winID, floating: !isFloat)
                    refreshData()
                },
                onSwapWindows: { idA, idB in
                    swapWindows(idA: idA, idB: idB)
                }
            )

            HStack {
                Text("Erkannte Fenster auf aktuellem Space (\(currentWindows.count)):")
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
                    Text("Keine verwaltbaren Fenster erkannt.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
            } else {
                // Table Column Headers for Clean Visual Alignment
                HStack(spacing: 8) {
                    Text("Programm")
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)
                        .frame(width: 125, alignment: .leading)

                    Text("Status")
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)
                        .frame(width: 82, alignment: .center)

                    Text("Gewicht")
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)
                        .frame(width: 78, alignment: .center)

                    Text("Fenstertitel")
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("Aktionen")
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)
                        .frame(width: 210, alignment: .trailing)
                }
                .padding(.horizontal, 8)
                .padding(.top, 2)

                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 5) {
                        ForEach(Array(currentWindows.enumerated()), id: \.element.id) { index, win in
                            activeWindowRow(index: index, win: win)
                        }
                    }
                    .padding(.vertical, 2)
                    .padding(.trailing, 4)
                }
                .frame(maxHeight: 280)
            }
        }
    }

    private func activeWindowRow(index: Int, win: ManagedWindow) -> some View {
        let isMain = currentMainIDs.contains(win.id)
        return HStack(spacing: 8) {
            // 1. App Name (fixed 125px)
            Text(win.appName)
                .font(.subheadline.bold())
                .frame(width: 125, alignment: .leading)
                .lineLimit(1)

            // 2. Status Badge (fixed 82px)
            Group {
                if win.isFloating {
                    Text("✈ Floating")
                        .font(.caption2.bold())
                        .foregroundColor(.purple)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.purple.opacity(0.18))
                        .cornerRadius(4)
                } else if win.isLocked {
                    Text("🔒 Locked")
                        .font(.caption2.bold())
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.orange.opacity(0.18))
                        .cornerRadius(4)
                } else if isMain {
                    Text("⭐ Main")
                        .font(.caption2.bold())
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.cyan.opacity(0.18))
                        .cornerRadius(4)
                } else {
                    Text("🪟 Support")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(4)
                }
            }
            .frame(width: 82, alignment: .center)

            // 3. Weight / Score Stepper for THIS concrete window (fixed 78px)
            HStack(spacing: 2) {
                Button(action: {
                    let newScore = max(10, win.score - 5)
                    WindowManager.shared.setWindowScoreOverride(id: win.id, score: newScore)
                    refreshData()
                }) {
                    Text("-")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 14, height: 16)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)

                Text("\(win.score)")
                    .font(.caption.monospaced().bold())
                    .foregroundColor(win.score > 65 ? .cyan : (win.score < 36 ? .orange : .primary))
                    .frame(width: 26, alignment: .center)

                Button(action: {
                    let newScore = min(100, win.score + 5)
                    WindowManager.shared.setWindowScoreOverride(id: win.id, score: newScore)
                    refreshData()
                }) {
                    Text("+")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 14, height: 16)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
            .frame(width: 78, alignment: .center)

            // 4. Window Title (Middle-truncated, takes remaining space)
            Text(win.title.isEmpty ? "(Kein Fenstertitel)" : win.title)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 5. Action Buttons (fixed 210px, aligned columns)
            HStack(spacing: 5) {
                Button(win.isFloating ? "Unfloat" : "Float") {
                    WindowManager.shared.setWindowFloating(id: win.id, floating: !win.isFloating)
                    refreshData()
                }
                .buttonStyle(.bordered)
                .tint(win.isFloating ? .purple : .primary)
                .controlSize(.small)
                .frame(width: 58)

                if !win.isFloating {
                    Button(win.isLocked ? "Unlock" : "Lock") {
                        WindowManager.shared.setWindowLocked(id: win.id, locked: !win.isLocked)
                        refreshData()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .frame(width: 58)
                } else {
                    Spacer().frame(width: 58)
                }

                if isMain {
                    Button(action: {
                        removeMainWindow(id: win.id)
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .heavy))
                            Text("Main")
                                .font(.caption2.bold())
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
                    .controlSize(.small)
                    .frame(width: 74)
                    .help("Klicken, um aus Main-Fenstern zu entfernen")
                } else if !win.isLocked && !win.isFloating {
                    Button(action: {
                        addMainWindow(id: win.id)
                    }) {
                        Text("+ Main")
                            .font(.caption2.bold())
                    }
                    .buttonStyle(.bordered)
                    .tint(.cyan)
                    .controlSize(.small)
                    .frame(width: 74)
                    .help("Klicken, um als Main-Fenster hinzuzufügen")
                } else {
                    Spacer().frame(width: 74)
                }
            }
            .frame(width: 210, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isMain ? Color.cyan.opacity(0.12) : Color.secondary.opacity(0.05))
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            if !win.isLocked && !win.isFloating {
                toggleMainWindow(id: win.id)
            }
        }
    }

    // MARK: - Tab 1: Shortcuts (Large Legible Badges, Single Hyper Explanation)
    var shortcutsTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupBox {
                HStack(spacing: 14) {
                    Image(systemName: "command.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.cyan)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Hyper Key = ⌃ Control + ⌥ Option + ⇧ Shift + ⌘ Command")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text("Tipp: In Tools wie Karabiner-Elements oder Raycast kann die Feststelltaste (Caps Lock) als Hyper belegt werden – für extrem schnelle Ein-Finger-Bedienung.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(6)
            }

            GroupBox(label: Label("Globale Tastenkombinationen (Hotkeys)", systemImage: "keyboard")) {
                VStack(spacing: 8) {
                    shortcutRow(
                        title: "Rearrange Windows",
                        desc: "Ordnet alle Fenster im aktuellen Space sofort im dynamischen Raster an",
                        shortcut: config.shortcut,
                        field: "optimize"
                    )
                    Divider()
                    shortcutRow(
                        title: "Fenster zu Main hinzufügen (+)",
                        desc: "Macht das aktive Fenster zu einem hervorgehobenen Main-Fenster",
                        shortcut: config.addMainShortcut,
                        field: "addMain"
                    )
                    Divider()
                    shortcutRow(
                        title: "Aus Main-Fenstern entfernen (-)",
                        desc: "Nimmt das aktive Fenster aus den Main-Fenstern heraus (wird Support-Fenster)",
                        shortcut: config.removeMainShortcut,
                        field: "removeMain"
                    )
                    Divider()
                    shortcutRow(
                        title: "Main-Status umschalten (Toggle)",
                        desc: "Schaltet Main für aktives Fenster um (schnelles doppeltes Drücken hebt alle Main auf)",
                        shortcut: config.masterShortcut,
                        field: "master"
                    )
                    Divider()
                    shortcutRow(
                        title: "Lock/Unlock Active Window",
                        desc: "Sperrt Fenster an seiner Position; reserviert dessen Raster-Kacheln",
                        shortcut: config.lockShortcut,
                        field: "lock"
                    )
                    Divider()
                    shortcutRow(
                        title: "Toggle Floating Window",
                        desc: "Schwebt zentriert Always-on-Top im Vordergrund; wird beim Tiling ignoriert",
                        shortcut: config.floatShortcut,
                        field: "float"
                    )
                    Divider()
                    shortcutRow(
                        title: "Open Settings GUI",
                        desc: "Öffnet dieses Einstellungsfenster zentriert auf dem Bildschirm",
                        shortcut: config.guiShortcut,
                        field: "gui"
                    )
                }
                .padding(8)
            }
        }
    }

    private func shortcutRow(title: String, desc: String, shortcut: ShortcutConfig, field: String) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if recordingField == field {
                Button("Tasten auf der Tastatur drücken...") { stopRecording() }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
            } else {
                Text(shortcut.cleanDisplayString)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 16).padding(.vertical, 7)
                    .background(Color.cyan.opacity(0.14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.cyan.opacity(0.40), lineWidth: 1.2)
                    )
                    .cornerRadius(6)

                Button("Neu aufnehmen") { startRecording(field: field) }
                    .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Tab 2: Spacing & Motion (Grid Sizing, Motion Glide, SkyLight Freezing)
    var spacingTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupBox(label: Label("Raster & Bildschirmabstände", systemImage: "square.grid.3x3")) {
                VStack(spacing: 12) {
                    HStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Innerer Abstand (Gap):")
                                    .fontWeight(.medium)
                                Slider(value: $config.gap, in: 0...32, step: 1)
                                Text("\(Int(config.gap)) px")
                                    .font(.caption.monospaced().bold())
                                    .frame(width: 45)
                            }
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Äußerer Rand (Margin):")
                                    .fontWeight(.medium)
                                Slider(value: $config.margin, in: 0...48, step: 1)
                                Text("\(Int(config.margin)) px")
                                    .font(.caption.monospaced().bold())
                                    .frame(width: 45)
                            }
                        }
                    }

                    Divider()

                    HStack {
                        Text("Einzel-Fenster Modus:")
                            .fontWeight(.medium)
                        Spacer()
                        Picker("", selection: $config.singleWindowMode) {
                            Text("Zentriert (Ergonomisch)").tag("centered")
                            Text("Maximiert (Volle Arbeitsfläche)").tag("maximized")
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 360)
                    }
                }
                .padding(8)
            }

            GroupBox(label: Label("Fenster-Animation & Glätte", systemImage: "speedometer")) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Bewegungsmodus:")
                            .fontWeight(.medium)
                        Spacer()
                        Picker("", selection: $config.animationMode) {
                            Text("Direkt (Sofort)").tag("instant")
                            Text("Flüssige Gleit-Animation").tag("smooth")
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 320)
                    }

                    if config.animationMode == "smooth" {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 24) {
                                HStack(spacing: 8) {
                                    Text("Dauer:")
                                    Slider(value: $config.animationDuration, in: 0.06...0.35, step: 0.02)
                                    Text("\(Int(config.animationDuration * 1000)) ms")
                                        .font(.caption.monospaced().bold())
                                        .frame(width: 55)
                                }

                                HStack(spacing: 8) {
                                    Text("Schritte:")
                                    Slider(value: Binding(
                                        get: { Double(config.animationSteps) },
                                        set: { config.animationSteps = Int($0) }
                                    ), in: 4...20, step: 1)
                                    Text("\(config.animationSteps) Frames")
                                        .font(.caption.monospaced().bold())
                                        .frame(width: 65)
                                }
                            }

                            Toggle("Fensterinhalte während Animation einfrieren", isOn: $config.freezeContentDuringResize)
                                .font(.subheadline.bold())
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(10)
            }

            GroupBox(label: Label("Menüleiste & Schnellzugriff", systemImage: "menubar.rectangle")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Schnellaktion (Linksklick auf Logo):")
                            .fontWeight(.medium)
                        Spacer()
                        Picker("", selection: $config.menuBarQuickAction) {
                            Text("Fenster anordnen (Rearrange)").tag("rearrange")
                            Text("Aktions-Menü öffnen (Kompakt)").tag("actions")
                            Text("Einstellungen öffnen").tag("settings")
                            Text("Fenster zu Main hinzufügen (+)").tag("add_main")
                            Text("Aus Main entfernen (-)").tag("remove_main")
                            Text("Main-Status umschalten").tag("toggle_main")
                            Text("Alle Main aufheben (Gleichmäßig)").tag("uniform")
                            Text("Vollständiges Menü öffnen").tag("menu")
                        }
                        .labelsHidden()
                        .frame(width: 340)
                    }

                    Text("Hinweis: Rechtsklick oder langes Drücken (> 0,35s) auf das Logo öffnet immer das vollständige Menü.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(10)
            }
        }
    }

    // MARK: - Tab 3: Weights & Memory (App Weights, Concrete Window Rules & SpaceMemory)
    var weightsAndMemoryTab: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 14) {
                // Header Bar
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Fenster-Gewichtung & Adaptives Gedächtnis")
                            .font(.headline)
                        Text("Bestimmt die Priorität von Programmen und konkreten Fenstern. Höhere Gewichte (66-100) erhalten mehr Spalten oder den Master-Fokus, kompakte Gewichte (10-35) bleiben schmal.")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        scoreBadge(label: "Kompakt (10-35)", color: .orange)
                        scoreBadge(label: "Ausgewogen (36-65)", color: .blue)
                        scoreBadge(label: "Breit (66-100)", color: .cyan)
                    }
                }

                // Section 1: Programm-Kategorien (Standard-Gewichte)
                GroupBox(label: Label("Programm-Kategorien (Standard-Gewichte)", systemImage: "square.stack.3d.up")) {
                    VStack(spacing: 6) {
                        weightCategoryRow(
                            title: "Terminal Apps",
                            appsList: ["iTerm2", "Terminal", "Ghostty", "kitty", "Alacritty"],
                            desc: "Kompakte Arbeitsbreite; ideal für Shell & Logs",
                            icon: "terminal"
                        )
                        weightCategoryRow(
                            title: "Web Browser",
                            appsList: ["Google Chrome", "Safari", "Arc", "Firefox"],
                            desc: "Breitere Ansicht für moderne Webseiten & DevTools",
                            icon: "globe"
                        )
                        weightCategoryRow(
                            title: "Code Editoren",
                            appsList: ["Code", "Xcode", "Cursor"],
                            desc: "Großzügige Code-Ansicht für Sidebars und Split-Panes",
                            icon: "chevron.left.forwardslash.chevron.right"
                        )
                        weightCategoryRow(
                            title: "Notizen & Dokumente",
                            appsList: ["Obsidian", "Notes", "Bear"],
                            desc: "Ausgewogene Lesebreite; 50/50 gepaart mit Browser",
                            icon: "note.text"
                        )
                    }
                    .padding(4)
                }

                // Section 2: Konkrete Fensterregeln (Titel-Erkennung)
                GroupBox(label: Label("Konkrete Fensterregeln (Titel-Erkennung)", systemImage: "sparkle.magnifyingglass")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Weisen Sie spezifischen Einzelfenstern anhand ihres Fenstertitels ein eigenes Gewicht zu (z. B. Terminal mit 'openclaw' oder 'nvim' -> Score 85).")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        // Add Rule Form
                        HStack(spacing: 8) {
                            TextField("Titel enthält (z. B. openclaw, nvim, logs)", text: $newRulePattern)
                                .textFieldStyle(.roundedBorder)

                            TextField("App (optional, z. B. iTerm2)", text: $newRuleAppName)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 170)

                            HStack(spacing: 2) {
                                Button("-") { newRuleScore = max(10, newRuleScore - 5) }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                Text("\(newRuleScore)")
                                    .font(.caption.monospaced().bold())
                                    .frame(width: 28)
                                Button("+") { newRuleScore = min(100, newRuleScore + 5) }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                            }

                            Button(action: addWindowRule) {
                                Label("Regel speichern", systemImage: "plus")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.cyan)
                            .disabled(newRulePattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }

                        if !config.windowRules.isEmpty {
                            VStack(spacing: 4) {
                                ForEach(config.windowRules) { rule in
                                    HStack(spacing: 10) {
                                        Image(systemName: "text.magnifyingglass")
                                            .foregroundColor(.cyan)

                                        Text("\"\(rule.pattern)\"")
                                            .font(.caption.bold())

                                        if let app = rule.appName, !app.isEmpty {
                                            Text("in \(app)")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }

                                        Spacer()

                                        Text("Score: \(rule.score)")
                                            .font(.caption.monospaced().bold())
                                            .foregroundColor(rule.score > 65 ? .cyan : (rule.score < 36 ? .orange : .blue))

                                        Button(action: { removeWindowRule(id: rule.id) }) {
                                            Image(systemName: "trash")
                                                .font(.caption)
                                                .foregroundColor(.red)
                                        }
                                        .buttonStyle(.plain)
                                        .help("Regel löschen")
                                    }
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Color.secondary.opacity(0.05))
                                    .cornerRadius(6)
                                }
                            }
                        }
                    }
                    .padding(6)
                }

                // Section 3: Feineinstellung einzelner Apps
                GroupBox(label: Label("Programm-Feineinstellungen", systemImage: "slider.horizontal.3")) {
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 4) {
                            ForEach(config.appWeights) { appWeight in
                                individualAppWeightRow(item: appWeight)
                            }
                        }
                        .padding(.vertical, 2)
                        .padding(.trailing, 4)
                    }
                    .frame(maxHeight: 140)
                }

                // Section 4: Adaptives Layout-Gedächtnis (SpaceMemory)
                GroupBox(label: Label("Adaptives Layout-Gedächtnis (SpaceMemory)", systemImage: "brain.head.profile")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SpaceMemory ist ein heuristisches Online-Lernverfahren (gleitender exponentieller Durchschnitt): Es merkt sich Ihre bevorzugten Fensterverhältnisse pro Bildschirmauflösung und App-Kombination automatisch.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Toggle("Automatisches Anpassen an gelernte Verhältnisse aktiv", isOn: $config.enableSpaceLearning)
                            .toggleStyle(.switch)
                            .onChange(of: config.enableSpaceLearning) { _ in
                                config.save()
                            }

                        HStack {
                            Text("Gelernte Profile (\(SpaceMemory.shared.profiles.count)):")
                                .font(.subheadline.bold())
                            Spacer()

                            Button(action: {
                                if let msg = SpaceObserver.shared.learnCurrentLayoutNow() {
                                    showStatus(msg)
                                } else {
                                    showStatus("Konnte Layout nicht erfassen.")
                                }
                            }) {
                                Label("Aktuellen Space einlernen", systemImage: "camera.badge.ellipsis")
                            }
                            .buttonStyle(.bordered)

                            if !SpaceMemory.shared.profiles.isEmpty {
                                Button(action: {
                                    SpaceMemory.shared.clear()
                                    showStatus("SpaceMemory-Profile gelöscht.")
                                }) {
                                    Label("Speicher leeren", systemImage: "trash")
                                }
                                .buttonStyle(.bordered)
                                .foregroundColor(.red)
                            }
                        }

                        if SpaceMemory.shared.profiles.isEmpty {
                            Text("Noch keine Profile gelernt. Nutzen Sie 'Aktuellen Space einlernen' oder ordnen Sie Fenster mit Hyper+Space an.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 6)
                        } else {
                            VStack(spacing: 6) {
                                ForEach(SpaceMemory.shared.profiles) { prof in
                                    spaceProfileRow(prof)
                                }
                            }
                        }
                    }
                    .padding(6)
                }
            }
            .padding(.trailing, 4)
        }
    }

    private func addWindowRule() {
        let pattern = newRulePattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pattern.isEmpty else { return }
        let app = newRuleAppName.trimmingCharacters(in: .whitespacesAndNewlines)
        let rule = WindowRuleConfig(
            pattern: pattern,
            appName: app.isEmpty ? nil : app,
            score: newRuleScore
        )
        config.windowRules.append(rule)
        config.save()
        newRulePattern = ""
        newRuleAppName = ""
        showStatus("Regel für Fenster mit '\(pattern)' gespeichert.")
    }

    private func removeWindowRule(id: String) {
        config.windowRules.removeAll { $0.id == id }
        config.save()
        showStatus("Fensterregel entfernt.")
    }

    private func weightCategoryRow(title: String, appsList: [String], desc: String, icon: String) -> some View {
        let firstApp = appsList.first ?? ""
        let currentScore = scoreFor(appName: firstApp)

        return HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.cyan)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(title).fontWeight(.semibold)
                    Text("(\(appsList.joined(separator: ", ")))")
                        .font(.caption2).foregroundColor(.secondary).lineLimit(1)
                }
                Text(desc).font(.caption2).foregroundColor(.secondary)
            }

            Spacer()

            // Interactive +/- Stepper Buttons
            HStack(spacing: 6) {
                Button(action: { adjustCategory(apps: appsList, delta: -5) }) {
                    Image(systemName: "minus")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.bordered)
                .help("Decrease weight for \(title) by 5")

                Text("\(currentScore)")
                    .font(.system(.subheadline, design: .monospaced).bold())
                    .frame(width: 36, alignment: .center)
                    .foregroundColor(currentScore > 65 ? .cyan : (currentScore < 36 ? .orange : .blue))

                Button(action: { adjustCategory(apps: appsList, delta: 5) }) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.bordered)
                .help("Increase weight for \(title) by 5")
            }
        }
        .padding(7)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(8)
    }

    private func individualAppWeightRow(item: AppWeightConfig) -> some View {
        HStack(spacing: 10) {
            Text(item.appName)
                .font(.caption.bold())
                .frame(width: 140, alignment: .leading)

            if let maxW = item.maxWidth {
                Text("Max: \(Int(maxW))px")
                    .font(.caption2.monospaced())
                    .foregroundColor(.secondary)
            } else {
                Text("Uncapped")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 5) {
                Button(action: { adjustScore(for: item.appName, delta: -5) }) {
                    Image(systemName: "minus")
                        .font(.system(size: 9, weight: .bold))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Text("\(item.score)")
                    .font(.system(.caption, design: .monospaced).bold())
                    .frame(width: 30, alignment: .center)
                    .foregroundColor(item.score > 65 ? .cyan : (item.score < 36 ? .orange : .blue))

                Button(action: { adjustScore(for: item.appName, delta: 5) }) {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.secondary.opacity(0.04))
        .cornerRadius(4)
    }

    private func adjustScore(for appName: String, delta: Int) {
        if let idx = config.appWeights.firstIndex(where: { $0.appName.lowercased() == appName.lowercased() }) {
            config.appWeights[idx].score = max(10, min(100, config.appWeights[idx].score + delta))
        } else {
            let base = defaultScoreFor(appName: appName)
            config.appWeights.append(AppWeightConfig(
                appName: appName,
                score: max(10, min(100, base + delta)),
                minWidth: 500,
                minHeight: 400
            ))
        }
        scheduleSaveConfig()
        showStatus("Set weight for '\(appName)' to \(scoreFor(appName: appName)).")
    }

    private func adjustCategory(apps: [String], delta: Int) {
        for app in apps {
            if let idx = config.appWeights.firstIndex(where: { $0.appName.lowercased() == app.lowercased() }) {
                config.appWeights[idx].score = max(10, min(100, config.appWeights[idx].score + delta))
            } else {
                let base = defaultScoreFor(appName: app)
                config.appWeights.append(AppWeightConfig(
                    appName: app,
                    score: max(10, min(100, base + delta)),
                    minWidth: 500,
                    minHeight: 400
                ))
            }
        }
        scheduleSaveConfig()
        showStatus("Updated category weights by \(delta > 0 ? "+\(delta)" : "\(delta)").")
    }

    private func scoreFor(appName: String) -> Int {
        if let item = config.appWeights.first(where: { $0.appName.lowercased() == appName.lowercased() }) {
            return item.score
        }
        return defaultScoreFor(appName: appName)
    }

    private func defaultScoreFor(appName: String) -> Int {
        let lower = appName.lowercased()
        if lower.contains("term") || lower.contains("kitty") || lower.contains("alacritty") || lower.contains("ghostty") { return 32 }
        if lower.contains("chrome") || lower.contains("safari") || lower.contains("firefox") || lower.contains("arc") { return 72 }
        if lower.contains("code") || lower.contains("xcode") || lower.contains("cursor") { return 75 }
        if lower.contains("notes") || lower.contains("obsidian") || lower.contains("bear") { return 50 }
        return 50
    }

    private func scoreBadge(label: String, color: Color) -> some View {
        Text(label)
            .font(.caption2.bold())
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(4)
    }

    // MARK: - Tab 3: Daemon (Space-Efficient Controls & Real-Time Logs)
    var daemonTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Streamlined, Space-Efficient Control Bar
            GroupBox(label: Label("Daemon Status & Controls", systemImage: "bolt.horizontal.circle.fill")) {
                HStack(spacing: 16) {
                    // Accessibility Status
                    HStack(spacing: 8) {
                        Circle()
                            .fill(isAccessibilityGranted ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(isAccessibilityGranted ? "Accessibility: Granted" : "Accessibility: Missing")
                                .font(.caption.bold())
                            Text("macOS System Permissions")
                                .font(.caption2).foregroundColor(.secondary)
                        }
                    }

                    Divider().frame(height: 24)

                    // Daemon Process Status
                    HStack(spacing: 8) {
                        Circle()
                            .fill(daemonStatus.isRunning ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 4) {
                                Text(daemonStatus.isRunning ? "Daemon: Running" : "Daemon: Stopped")
                                    .font(.caption.bold())
                                if let pid = daemonStatus.pid {
                                    Text("(\(pid))").font(.caption2.monospaced()).foregroundColor(.secondary)
                                }
                            }
                            Text("LaunchAgent (com.guppi.spacetile)")
                                .font(.caption2).foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // Quick Actions
                    Button("Open System Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                        _ = WindowManager.isAccessibilityGranted(prompt: true)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Restart Daemon") {
                        showStatus("Restarting daemon...")
                        ServiceInstaller.restartAndReopenSettings(targetTab: "daemon")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
                    .controlSize(.small)

                    if daemonStatus.isRunning {
                        Button("Stop") {
                            ServiceInstaller.stop()
                            checkStatus()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .foregroundColor(.red)
                    } else {
                        Button("Start") {
                            ServiceInstaller.start()
                            checkStatus()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .padding(6)
            }

            // Expanded Real-time macOS Terminal Log Frame (Fills Available Space Cleanly)
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
                .padding(.vertical, 7)
                .background(Color.black.opacity(0.85))

                ScrollView {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(recentLogs, id: \.self) { line in
                            Text(line)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.green.opacity(0.9))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                }
                .frame(maxHeight: .infinity)
                .background(Color.black.opacity(0.92))
            }
            .frame(maxHeight: .infinity)
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
                    Text("Version \(Config.version) (macOS Native)")
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

            // Feedback & Community Reporting Card
            GroupBox(label: Label("Feedback, Ideen & Fehlerberichte", systemImage: "bubble.left.and.exclamationmark.bubble.right.fill")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Hast du eine Idee für eine neue Funktion oder ist ein Problem aufgetreten? Reiche Vorschläge und Fehlerberichte direkt auf GitHub ein – optional mit Systemdaten und Diagnose-Logs.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        Button(action: {
                            feedbackSheetType = .feature
                            showFeedbackSheet = true
                        }) {
                            Label("Funktion vorschlagen", systemImage: "lightbulb.fill")
                                .padding(.horizontal, 8).padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.cyan)

                        Button(action: {
                            feedbackSheetType = .bug
                            showFeedbackSheet = true
                        }) {
                            Label("Bug melden (mit Logs)", systemImage: "ladybug.fill")
                                .padding(.horizontal, 8).padding(.vertical, 4)
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)

                        Spacer()

                        Button(action: {
                            if let url = URL(string: Config.issuesURL) {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            Label("GitHub Issues", systemImage: "arrow.up.right.square")
                                .padding(.horizontal, 8).padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                    }
                }
                .padding(6)
            }
            .frame(maxWidth: 500)

            VStack(spacing: 12) {
                Text("SpaceTile ist freie Open-Source-Software.")
                    .font(.subheadline).foregroundColor(.secondary)

                HStack(spacing: 16) {
                    Button(action: {
                        if let url = URL(string: Config.repoURL) {
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
            .padding(.top, 4)

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
            case "addMain": self.config.addMainShortcut = newShortcut
            case "removeMain": self.config.removeMainShortcut = newShortcut
            case "master": self.config.masterShortcut = newShortcut
            case "lock": self.config.lockShortcut = newShortcut
            case "float": self.config.floatShortcut = newShortcut
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
        if selectedTab == 4 {
            recentLogs = ServiceInstaller.getRecentLogs()
        }
    }

    @State private var saveWorkItem: DispatchWorkItem? = nil

    private func scheduleSaveConfig() {
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [self] in
            config.save()
        }
        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: item)
    }

    func swapWindows(idA: CGWindowID, idB: CGWindowID) {
        guard let idxA = currentWindows.firstIndex(where: { $0.id == idA }),
              let idxB = currentWindows.firstIndex(where: { $0.id == idB }) else { return }

        let nameA = currentWindows[idxA].appName
        let nameB = currentWindows[idxB].appName

        // 1. Physically swap their frames on the screen
        WindowManager.shared.swapWindowPositions(idA: idA, idB: idB)

        // 2. Animate and update frames locally in the canvas
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            let frameA = currentWindows[idxA].currentFrame
            let frameB = currentWindows[idxB].currentFrame
            currentWindows[idxA].currentFrame = frameB
            currentWindows[idxB].currentFrame = frameA
            currentWindows.swapAt(idxA, idxB)
        }

        showStatus("Swapped '\(nameA)' and '\(nameB)' on screen.")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            self.refreshData()
        }
    }



    private func spaceProfileRow(_ prof: SpaceProfile) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    ForEach(prof.apps, id: \.self) { app in
                        Text(app)
                            .font(.caption.bold())
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.cyan.opacity(0.15))
                            .foregroundColor(.cyan)
                            .cornerRadius(4)
                    }

                    Text("•")
                        .foregroundColor(.secondary)

                    Text(prof.displayResolution)
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 8) {
                    let ratio = prof.learnedMasterRatio ?? 0.50
                    let masterPct = Int(round(ratio * 100))
                    let stackPct = 100 - masterPct

                    GeometryReader { geo in
                        HStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.cyan.opacity(0.75))
                                .frame(width: max(10, geo.size.width * CGFloat(ratio) - 2))
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.secondary.opacity(0.35))
                        }
                    }
                    .frame(width: 120, height: 8)

                    Text("Master: \(masterPct)% / Stack: \(stackPct)%")
                        .font(.caption2.monospaced())
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(prof.observationsCount) observation\(prof.observationsCount == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(action: {
                SpaceMemory.shared.removeProfile(id: prof.id)
                showStatus("Removed profile for [\(prof.apps.joined(separator: ", "))].")
            }) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Delete this learned profile")
        }
        .padding(8)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(6)
    }

    func refreshData() {
        checkStatus()
        WindowManager.shared.reloadMainWindowIDs()
        WindowManager.shared.reloadLockedWindowIDs()
        WindowManager.shared.reloadFloatingWindowIDs()
        currentMainIDs = WindowManager.shared.mainWindowIDs
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let vf = screen.visibleFrame
        let primaryH = NSScreen.screens.first?.frame.height ?? vf.height
        let axRect = CGRect(x: vf.origin.x, y: primaryH - (vf.origin.y + vf.height), width: vf.width, height: vf.height)
        currentWindows = WindowManager.shared.collectWindowsOnCurrentSpace(screenBounds: axRect, ignoredApps: Set(config.ignoredApps), config: config)
    }

    func addMainWindow(id: CGWindowID) {
        showStatus("Fenster zu Main hinzugefügt...")
        WindowManager.shared.addMainWindow(id: id)
        currentMainIDs = WindowManager.shared.mainWindowIDs
        triggerOptimizeNow()
    }

    func removeMainWindow(id: CGWindowID) {
        showStatus("Aus Main-Fenstern entfernt...")
        WindowManager.shared.removeMainWindow(id: id)
        currentMainIDs = WindowManager.shared.mainWindowIDs
        triggerOptimizeNow()
    }

    func toggleMainWindow(id: CGWindowID) {
        WindowManager.shared.toggleMainWindow(id: id)
        currentMainIDs = WindowManager.shared.mainWindowIDs
        showStatus(currentMainIDs.contains(id) ? "Als Main-Fenster gesetzt..." : "Aus Main-Fenstern entfernt...")
        triggerOptimizeNow()
    }

    func clearAllMain() {
        showStatus("Alle Main-Fenster aufgehoben (Gleichmäßiges Raster)...")
        WindowManager.shared.clearMainWindows()
        currentMainIDs = []
        triggerOptimizeNow()
    }

    func setSecondaryFocus(id: CGWindowID) {
        addMainWindow(id: id)
    }

    func clearSecondaryFocus() {
        if currentMainIDs.count > 1 {
            removeMainWindow(id: currentMainIDs[1])
        }
    }

    func triggerOptimizeNow() {
        showStatus("Rearranging windows...")
        DispatchQueue.global(qos: .userInitiated).async {
            WindowManager.shared.optimize(verbose: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                self.refreshData()
                self.showStatus("Windows rearranged.")
            }
        }
    }

    func promoteToMaster(id: CGWindowID, appName: String) {
        addMainWindow(id: id)
    }

    func clearMaster() {
        clearAllMain()
    }

    func showStatus(_ msg: String) {
        statusMessage = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            statusMessage = nil
        }
    }

    func saveConfig() {
        config.save()
        originalConfig = config
        _ = HotKeyManager.shared.register(config: config)
        MenuBarController.shared.refreshIcon()
        showStatus("Settings saved successfully.")
    }

    func requestClose() {
        if hasUnsavedChanges {
            showUnsavedChangesAlert = true
        } else {
            SettingsWindowController.shared.forceClose()
        }
    }

    private func setupCloseAndEscHandler() {
        SettingsWindowController.shared.hasUnsavedChangesHandler = { [self] in
            return self.hasUnsavedChanges
        }
        SettingsWindowController.shared.requestCloseHandler = { [self] in
            self.requestClose()
        }

        if localEventMonitor == nil {
            localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
                if event.keyCode == 53 { // ESC key
                    DispatchQueue.main.async {
                        self.requestClose()
                    }
                    return nil
                }
                return event
            }
        }
    }

    private func removeEscHandler() {
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
    }
}
