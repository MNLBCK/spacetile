import SwiftUI
import AppKit

struct FeedbackSheetView: View {
    @Binding var isPresented: Bool
    @State var selectedType: FeedbackType = .feature
    @State private var titleText: String = ""
    @State private var descriptionText: String = ""
    @State private var includeSystemInfo: Bool = true
    @State private var includeLogs: Bool = true
    @State private var showLogPreview: Bool = false
    @State private var recentLogsText: String = ""
    @State private var statusNotice: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "bubble.left.and.exclamationmark.bubble.right.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.cyan)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Feedback & GitHub Issue")
                        .font(.headline.bold())
                    Text("Reiche Vorschläge oder Fehlerberichte direkt auf GitHub ein.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.8))

            Divider()

            // Form Content
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 14) {
                    // Type Picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Art des Anliegens:")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)

                        Picker("", selection: $selectedType) {
                            Label("Funktion vorschlagen", systemImage: "lightbulb.fill")
                                .tag(FeedbackType.feature)
                            Label("Fehler melden (Bug Report)", systemImage: "ladybug.fill")
                                .tag(FeedbackType.bug)
                        }
                        .pickerStyle(.segmented)
                    }

                    // Title Field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Titel:")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)

                        TextField(selectedType == .feature ? "z.B. Tastenkürzel für 50/50 Split..." : "z.B. Fenster springt nach Neustart nicht ins Raster...", text: $titleText)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Description Field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Beschreibung:")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)

                        TextEditor(text: $descriptionText)
                            .font(.system(size: 13))
                            .frame(height: 100)
                            .padding(4)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.12), lineWidth: 1))
                    }

                    // Diagnostics Section (especially relevant for bugs)
                    GroupBox(label: Label("Diagnose-Informationen", systemImage: "stethoscope")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("System- & Bildschirm-Infos anhängen", isOn: $includeSystemInfo)
                                .font(.subheadline)

                            if includeSystemInfo {
                                Text(FeedbackReporter.getSystemInfoSummary())
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.secondary.opacity(0.06))
                                    .cornerRadius(6)
                            }

                            Divider()

                            Toggle("Aktuelle SpaceTile-Logs anhängen", isOn: $includeLogs)
                                .font(.subheadline)

                            if includeLogs {
                                HStack {
                                    Text("\(recentLogsText.components(separatedBy: "\n").count) Logzeilen geladen")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)

                                    Spacer()

                                    Button(showLogPreview ? "Vorschau ausblenden" : "Logs anzeigen") {
                                        showLogPreview.toggle()
                                    }
                                    .buttonStyle(.plain)
                                    .font(.caption2)
                                    .foregroundColor(.cyan)
                                }

                                if showLogPreview {
                                    ScrollView(.vertical, showsIndicators: true) {
                                        Text(recentLogsText)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.green.opacity(0.9))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(6)
                                    }
                                    .frame(height: 110)
                                    .background(Color.black.opacity(0.9))
                                    .cornerRadius(6)
                                }
                            }
                        }
                        .padding(6)
                    }
                }
                .padding(16)
            }
            .frame(height: 380)

            Divider()

            // Footer / Actions
            HStack(spacing: 12) {
                if let msg = statusNotice {
                    Text(msg)
                        .font(.caption.bold())
                        .foregroundColor(.green)
                }

                Spacer()

                Button("In Zwischenablage kopieren") {
                    let markdown = FeedbackReporter.buildMarkdownReport(
                        type: selectedType,
                        title: titleText,
                        description: descriptionText,
                        includeSystemInfo: includeSystemInfo,
                        includeLogs: includeLogs
                    )
                    FeedbackReporter.copyToClipboard(markdown)
                    statusNotice = "✓ In Zwischenablage kopiert!"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        statusNotice = nil
                    }
                }
                .buttonStyle(.bordered)

                Button(action: submitToGitHub) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.right.square.fill")
                        Text("Auf GitHub öffnen ↗")
                    }
                    .padding(.horizontal, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
            }
            .padding(14)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        }
        .frame(width: 580, height: 500)
        .onAppear {
            recentLogsText = FeedbackReporter.getCleanLogs(maxLines: 35)
            if selectedType == .feature {
                includeLogs = false
            }
        }
        .onChange(of: selectedType) { newType in
            if newType == .bug {
                includeLogs = true
                includeSystemInfo = true
            }
        }
    }

    private func submitToGitHub() {
        let success = FeedbackReporter.openGitHubIssue(
            type: selectedType,
            title: titleText,
            description: descriptionText,
            includeSystemInfo: includeSystemInfo,
            includeLogs: includeLogs
        )

        if success {
            statusNotice = "✓ Issue-Vorlage geöffnet & Bericht kopiert!"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                isPresented = false
            }
        } else {
            statusNotice = "Fehler beim Öffnen des Browsers."
        }
    }
}
