import SwiftUI

struct SettingsView: View {
    @State private var config: Config = Config.load()
    @State private var memory: [SpaceProfile] = SpaceMemory.shared.profiles
    @State private var saveNotification: String?
    @State private var currentWindows: [ManagedWindow] = []
    @State private var selectedTab: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header with AppIcon
            HStack(spacing: 16) {
                if let imagePath = Bundle.main.path(forResource: "AppIcon", ofType: "png") ??
                    (FileManager.default.fileExists(atPath: "/Users/guppi/Code/spacetile/assets/AppIcon.png") ? "/Users/guppi/Code/spacetile/assets/AppIcon.png" : nil),
                   let nsImage = NSImage(contentsOfFile: imagePath) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 52, height: 52)
                        .cornerRadius(12)
                        .shadow(color: .cyan.opacity(0.3), radius: 6)
                } else {
                    Image(systemName: "rectangle.3.group.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.cyan)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("SpaceTile")
                        .font(.title2.bold())
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

            Divider()

            // Tabs
            Picker("", selection: $selectedTab) {
                Text("Allgemein & Shortcuts").tag(0)
                Text("App-Gewichte (Smart Rules)").tag(1)
                Text("Space-Gedächtnis (KI)").tag(2)
                Text("Aktiver Space").tag(3)
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
        .frame(width: 760, height: 560)
        .onAppear {
            refreshData()
        }
    }

    // MARK: - Tab 1: Allgemein & Shortcuts
    var generalSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupBox(label: Label("Tastaturkürzel (Hotkeys)", systemImage: "keyboard")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Fenster optimieren")
                                .fontWeight(.medium)
                            Text("Ordnet die Fenster des aktuellen Spaces sofort intelligent an.")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(config.shortcut.displayString)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.15))
                            .cornerRadius(6)
                            .font(.system(.body, design: .monospaced))
                    }

                    Divider()

                    HStack {
                        VStack(alignment: .leading) {
                            Text("Einstellungen öffnen (GUI)")
                                .fontWeight(.medium)
                            Text("Öffnet dieses Konfigurationsfenster von überall aus.")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(config.guiShortcut.displayString)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.15))
                            .cornerRadius(6)
                            .font(.system(.body, design: .monospaced))
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

                    Picker("Einzelfenster-Modus:", selection: $config.singleWindowMode) {
                        Text("Zentrierter Fokus (75% Breite, angenehmer Rand)").tag("centered")
                        Text("Vollbildschirm / Maximiert").tag("maximized")
                    }
                    .pickerStyle(.radioGroup)
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
                    Toggle("Intelligente Fenstergewichte aktivieren (Smart Weights)", isOn: $config.enableSmartWeighting)
                        .fontWeight(.medium)

                    Text("Auf 4K-Monitoren (3840px) ist ein Terminal mit 62% (~2380px) viel zu breit. SpaceTile begrenzt Terminals automatisch auf lesbare Breiten, während Browser oder Editor den verbleibenden Platz einnehmen.")
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

            GroupBox(label: Label("Spezialmodi & Responsive Vorschau", systemImage: "book.pages")) {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Side-by-Side (50/50) automatisch bei Browser + Notizen/Markdown", isOn: $config.sideBySideForNotesAndBrowser)
                        .fontWeight(.medium)

                    Text("Wenn du eine Anleitung im Browser liest und Notizen (Obsidian, Notes, Bear) offen hast, teilen sich beide Fenster genau 50/50 die Bildschirmbreite.")
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

                    Text("SpaceTile beobachtet im Hintergrund dezent, welche Apps du zusammen nutzt und wie du sie manuell anordnest. Erkennt SpaceTile z. B. Chrome + iTerm2, merkt es sich deine bevorzugte Aufteilung.")
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

    // MARK: - Tab 4: Aktiver Space
    var activeSpaceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sichtbare Fenster auf dem aktuellen Bildschirm:")
                    .font(.headline)
                Spacer()
                Button(action: refreshData) {
                    Label("Aktualisieren", systemImage: "arrow.clockwise")
                }
            }

            if currentWindows.isEmpty {
                Text("Keine aktiven Fenster gefunden oder Bedienungshilfen fehlen.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(currentWindows, id: \.id) { win in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(win.appName)
                                    .fontWeight(.bold)
                                if win.isFocused {
                                    Text("★ Master (Fokus)")
                                        .font(.caption2.bold())
                                        .foregroundColor(.green)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 1)
                                        .background(Color.green.opacity(0.15))
                                        .cornerRadius(4)
                                }
                            }
                            Text(win.title.isEmpty ? "(ohne Titel)" : win.title)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(8)
                }
            }
        }
    }

    // MARK: - Actions
    func refreshData() {
        memory = SpaceMemory.shared.profiles
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
