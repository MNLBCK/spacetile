import SwiftUI
import Combine
import ApplicationServices

// MARK: - Animated Visualizer for GUI
struct AnimatedWindowVisualizer: View {
    @State private var layoutStep = 0
    let timer = Timer.publish(every: 2.8, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                )

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let pad: CGFloat = 6
                let gap: CGFloat = 4

                // Layout state calculation
                let isSideBySide  = (layoutStep % 3 == 1)
                let isCentered    = (layoutStep % 3 == 2)

                let masterW: CGFloat = isCentered ? (w - 2 * pad) * 0.75 :
                                       (isSideBySide ? (w - 2 * pad - gap) * 0.50 :
                                       (w - 2 * pad - gap) * 0.62)
                let masterX: CGFloat = isCentered ? pad + ((w - 2 * pad) - masterW) / 2 : pad

                let stackW: CGFloat = isSideBySide ? (w - 2 * pad - gap) * 0.50 : (w - 2 * pad - gap) * 0.38
                let stackX: CGFloat = pad + masterW + gap

                let stack1H: CGFloat = isSideBySide ? (h - 2 * pad) : ((h - 2 * pad - gap) / 2)
                let stack2H: CGFloat = isSideBySide ? 0 : ((h - 2 * pad - gap) / 2)
                let stack2Y: CGFloat = pad + stack1H + gap

                ZStack(alignment: .topLeading) {
                    // Master Tile
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
                        .frame(width: masterW, height: h - 2 * pad)
                        .offset(x: masterX, y: pad)
                        .shadow(color: .cyan.opacity(0.5), radius: 5)

                    // Secondary Tile 1
                    if !isCentered {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.white.opacity(0.25))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                            .frame(width: stackW, height: stack1H)
                            .offset(x: stackX, y: pad)
                    }

                    // Secondary Tile 2
                    if !isCentered && !isSideBySide {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.white.opacity(0.18))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .frame(width: stackW, height: stack2H)
                            .offset(x: stackX, y: stack2Y)
                    }
                }
                .animation(.spring(response: 0.65, dampingFraction: 0.75), value: layoutStep)
            }
        }
        .frame(width: 80, height: 56)
        .onReceive(timer) { _ in
            layoutStep += 1
        }
        .onTapGesture {
            layoutStep += 1
        }
    }
}

// MARK: - Main Settings View
struct SettingsView: View {
    @State private var config: Config = Config.load()
    @State private var memory: [SpaceProfile] = SpaceMemory.shared.profiles
    @State private var saveNotification: String?
    @State private var currentWindows: [ManagedWindow] = []
    @State private var selectedTab: Int = 0
    @State private var recordingField: String? = nil // "optimize" or "gui"
    @State private var isAccessibilityGranted: Bool = AXIsProcessTrusted()
    @State private var localEventMonitor: Any? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header with Animated Visualizer
            HStack(spacing: 16) {
                AnimatedWindowVisualizer()

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text("SpaceTile")
                            .font(.title2.bold())
                        if !isAccessibilityGranted {
                            Text("Bedienungshilfe fehlt")
                                .font(.caption2.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .cornerRadius(4)
                        }
                    }
                    Text("Intelligenter On-Demand Fenster-Optimierer für macOS")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: triggerOptimizeNow) {
                    Label("Jetzt anordnen", systemImage: "sparkles")
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor).opacity(0.6))

            // Accessibility Warning Banner
            if !isAccessibilityGranted {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bedienungshilfen-Berechtigung fehlt")
                            .fontWeight(.bold)
                        Text("macOS blockiert derzeit das Verschieben von Fenstern für SpaceTile. Bitte in den Systemeinstellungen aktivieren.")
                            .font(.caption)
                    }

                    Spacer()

                    Button("In macOS freischalten") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                        _ = WindowManager.ensureAccessibility(prompt: true)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.12))
            }

            Divider()

            // Tabs
            Picker("", selection: $selectedTab) {
                Text("Shortcuts & Animation").tag(0)
                Text("App-Gewichte (Smart Rules)").tag(1)
                Text("Space-Gedächtnis (KI)").tag(2)
                Text("Aktiver Space & Master").tag(3)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 10)

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if selectedTab == 0 {
                        generalSection
                    } else if selectedTab == 1 {
                        smartRulesSection
                    } else if selectedTab == 2 {
                        spaceMemorySection
                    } else {
                        activeSpaceSection
                    }
                }
                .padding()
            }

            Divider()

            // Footer
            HStack {
                if let msg = saveNotification {
                    Text(msg)
                        .font(.caption)
                        .foregroundColor(.green)
                }
                Spacer()
                Button("Standardwerte") {
                    config = Config.default
                    config.save()
                    _ = HotKeyManager.shared.register(config: config)
                    showSaveNotice("Standardwerte wiederhergestellt!")
                }
                Button("Speichern") {
                    config.save()
                    _ = HotKeyManager.shared.register(config: config)
                    showSaveNotice("Einstellungen gespeichert!")
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor).opacity(0.4))
        }
        .frame(width: 780, height: 580)
        .onAppear {
            refreshData()
            checkAccessibility()
        }
        .onDisappear {
            stopRecording()
        }
    }

    // MARK: - Tab 1: Allgemein & Shortcuts (mit Recorder)
    var generalSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupBox(label: Label("Tastaturkürzel (Neu aufnehmen)", systemImage: "keyboard")) {
                VStack(alignment: .leading, spacing: 14) {
                    // Shortcut 1: Optimize
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Fenster optimieren")
                                .fontWeight(.medium)
                            Text("Standard: Hyper + Leertaste (Caps Lock + Space)")
                                .font(.caption).foregroundColor(.secondary)
                        }

                        Spacer()

                        if recordingField == "optimize" {
                            Button("Drücke Tastenkombination...") {
                                stopRecording()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                        } else {
                            Text(config.shortcut.displayString)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.15))
                                .cornerRadius(6)
                                .font(.system(.body, design: .monospaced))

                            Button("Aufnehmen") {
                                startRecording(field: "optimize")
                            }
                        }
                    }

                    Divider()

                    // Shortcut 2: GUI Settings
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Einstellungen öffnen (GUI)")
                                .fontWeight(.medium)
                            Text("Standard: Hyper + S (Caps Lock + S)")
                                .font(.caption).foregroundColor(.secondary)
                        }

                        Spacer()

                        if recordingField == "gui" {
                            Button("Drücke Tastenkombination...") {
                                stopRecording()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                        } else {
                            Text(config.guiShortcut.displayString)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.15))
                                .cornerRadius(6)
                                .font(.system(.body, design: .monospaced))

                            Button("Aufnehmen") {
                                startRecording(field: "gui")
                            }
                        }
                    }
                }
                .padding(8)
            }

            GroupBox(label: Label("Fenster-Animationen (Wie von Geisterhand)", systemImage: "wand.and.stars")) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Fenster-Verschiebung flüssig animieren", isOn: $config.enableAnimations)
                        .fontWeight(.medium)

                    Text("Lässt Fenster bei Tastendruck geschmeidig und stufenlos an ihre Zielposition gleiten.")
                        .font(.caption).foregroundColor(.secondary)

                    if config.enableAnimations {
                        HStack {
                            Text("Animationsdauer:")
                            Slider(value: $config.animationDuration, in: 0.10...0.70, step: 0.05)
                            Text(String(format: "%.2f s", config.animationDuration))
                                .frame(width: 55)
                        }
                    }
                }
                .padding(8)
            }

            GroupBox(label: Label("Abstände & Standard-Verhältnis", systemImage: "slider.horizontal.3")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Master-Fensterbreite:")
                        Slider(value: $config.masterRatio, in: 0.40...0.80, step: 0.01)
                        Text("\(Int(config.masterRatio * 100))%")
                            .frame(width: 45)
                    }

                    HStack {
                        Text("Fenster-Lücke (Gap):")
                        Slider(value: $config.gap, in: 0...30, step: 1)
                        Text("\(Int(config.gap)) px")
                            .frame(width: 45)
                    }

                    HStack {
                        Text("Bildschirmrand (Margin):")
                        Slider(value: $config.margin, in: 0...40, step: 1)
                        Text("\(Int(config.margin)) px")
                            .frame(width: 45)
                    }
                }
                .padding(8)
            }
        }
    }

    // MARK: - Tab 2: Smart Rules & Weights
    var smartRulesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupBox(label: Label("Terminal-Schutz auf 4K & Ultra-Wide", systemImage: "terminal")) {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Intelligente Fensterbegrenzung aktiv (Smart Weighting)", isOn: $config.enableSmartWeighting)
                        .fontWeight(.medium)

                    Text("Auf 4K-Monitoren (3840px) ist ein Terminal mit 62% (~2380px) viel zu breit. SpaceTile begrenzt Terminals automatisch auf eine ergonomische Breite, während Browser oder Editor den verbleibenden Platz einnehmen.")
                        .font(.caption).foregroundColor(.secondary)

                    Divider()

                    HStack {
                        Text("Max. Terminal-Breite:")
                        Slider(value: $config.terminalMaxWidth4K, in: 700...1600, step: 50)
                        Text("\(Int(config.terminalMaxWidth4K)) px")
                            .frame(width: 65)
                    }

                    HStack {
                        Text("Max. Bildschirmanteil:")
                        Slider(value: $config.terminalMaxRatio4K, in: 0.20...0.45, step: 0.01)
                        Text("\(Int(config.terminalMaxRatio4K * 100))%")
                            .frame(width: 65)
                    }
                }
                .padding(8)
            }

            GroupBox(label: Label("Spezialmodi & Recherche", systemImage: "book.pages")) {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Side-by-Side (50/50) automatisch bei Browser + Notizen/Markdown", isOn: $config.sideBySideForNotesAndBrowser)
                        .fontWeight(.medium)

                    Text("Sobald ein Browser und Notizen (Obsidian, Notes, Bear) zusammen im Space sind, teilen sie sich exakt 50/50 den Bildschirm für optimales Lesen und Schreiben.")
                        .font(.caption).foregroundColor(.secondary)
                }
                .padding(8)
            }
        }
    }

    // MARK: - Tab 3: Space Memory
    var spaceMemorySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupBox(label: Label("Nutzungsverhalten beobachten (Space-Gedächtnis)", systemImage: "brain.head.profile")) {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Nutzungsverhalten pro Space aktiv lernen", isOn: $config.enableSpaceLearning)
                        .fontWeight(.medium)

                    Text("SpaceTile merkt sich im Hintergrund, welche Fenstergrößen du in diesem Space manuell nutzt, und adaptiert zukünftige Kachel-Aktionen automatisch.")
                        .font(.caption).foregroundColor(.secondary)

                    HStack {
                        Button("Aktuelles Layout jetzt für diesen Space lernen") {
                            if let msg = SpaceObserver.shared.learnCurrentLayoutNow() {
                                memory = SpaceMemory.shared.profiles
                                showSaveNotice(msg)
                            }
                        }
                        .buttonStyle(.borderedProminent)

                        Spacer()

                        Button("Gedächtnis leeren") {
                            SpaceMemory.shared.clear()
                            memory = []
                            showSaveNotice("Gedächtnis zurückgesetzt.")
                        }
                        .foregroundColor(.red)
                    }
                    .padding(.top, 4)
                }
                .padding(8)
            }

            Text("Gelernte Space-Profile (\(memory.count)):")
                .font(.headline)

            if memory.isEmpty {
                Text("Noch keine Profile gelernt. Klicke oben auf 'Aktuelles Layout jetzt lernen' oder arbeite wie gewohnt weiter.")
                    .font(.caption).foregroundColor(.secondary)
            } else {
                ForEach(memory) { prof in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(prof.apps.joined(separator: " + "))
                                .fontWeight(.semibold)
                            Text("Auflösung: \(prof.displayResolution) • Beobachtungen: \(prof.observationsCount)")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        if let r = prof.learnedMasterRatio {
                            Text("\(Int(r * 100))% Master")
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.cyan.opacity(0.15))
                                .cornerRadius(6)
                                .foregroundColor(.cyan)
                        }
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(8)
                }
            }
        }
    }

    // MARK: - Tab 4: Aktiver Space & Master-Auswahl
    var activeSpaceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Fenster im aktuellen Space (\(currentWindows.count)):")
                    .font(.headline)
                Spacer()
                Button(action: refreshData) {
                    Label("Neu laden", systemImage: "arrow.clockwise")
                }
            }

            if currentWindows.isEmpty {
                Text("Keine relevanten Fenster im aktuellen Space gefunden.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(currentWindows.enumerated()), id: \.element.id) { index, win in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
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
                                    Text("Stack")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Text(win.title.isEmpty ? "(ohne Fenstertitel)" : win.title)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        // Make Master Button
                        if index != 0 {
                            Button("Als Master wählen") {
                                WindowManager.shared.optimize(verbose: true, forcedMasterID: win.id)
                                refreshData()
                                showSaveNotice("'\(win.appName)' als Master angeordnet!")
                            }
                            .buttonStyle(.bordered)
                        }

                        // Presets
                        Menu("Gewicht") {
                            Button("Standard (62%)") {
                                WindowManager.shared.optimize(verbose: true, forcedMasterID: win.id, forcedRatio: 0.62)
                                refreshData()
                            }
                            Button("Side-by-Side (50%)") {
                                WindowManager.shared.optimize(verbose: true, forcedMasterID: win.id, forcedRatio: 0.50)
                                refreshData()
                            }
                            Button("Fokus Breit (75%)") {
                                WindowManager.shared.optimize(verbose: true, forcedMasterID: win.id, forcedRatio: 0.75)
                                refreshData()
                            }
                            Button("Schmal (34% / Terminal)") {
                                WindowManager.shared.optimize(verbose: true, forcedMasterID: win.id, forcedRatio: 0.34)
                                refreshData()
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.secondary.opacity(index == 0 ? 0.12 : 0.05))
                    .cornerRadius(8)
                }
            }
        }
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
            self.showSaveNotice("Shortcut für '\(field)' aktualisiert!")

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

    func triggerOptimizeNow() {
        WindowManager.shared.optimize(verbose: true)
        refreshData()
        showSaveNotice("Fenster optimiert!")
    }

    func showSaveNotice(_ msg: String) {
        saveNotification = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            saveNotification = nil
        }
    }
}
