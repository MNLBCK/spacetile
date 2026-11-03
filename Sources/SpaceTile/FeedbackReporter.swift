import Cocoa
import Foundation

enum FeedbackType: String, CaseIterable, Identifiable {
    case feature = "feature"
    case bug = "bug"

    var id: String { rawValue }

    var titleLabel: String {
        switch self {
        case .feature: return "Feature-Vorschlag"
        case .bug: return "Fehlerbericht (Bug Report)"
        }
    }

    var icon: String {
        switch self {
        case .feature: return "lightbulb.fill"
        case .bug: return "ladybug.fill"
        }
    }

    var githubLabel: String {
        switch self {
        case .feature: return "enhancement"
        case .bug: return "bug"
        }
    }

    var issuePrefix: String {
        switch self {
        case .feature: return "[Feature]: "
        case .bug: return "[Bug]: "
        }
    }
}

struct FeedbackReporter {

    static func stripAnsiCodes(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"\x1b\[[0-9;]*[a-zA-Z]"#, options: []) else {
            return text
        }
        let range = NSRange(location: 0, length: text.utf16.count)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
    }

    static func getSystemInfoSummary() -> String {
        var lines: [String] = []
        lines.append("- **SpaceTile Version:** v\(Config.version)")
        lines.append("- **macOS Version:** \(ProcessInfo.processInfo.operatingSystemVersionString)")

        #if arch(arm64)
        lines.append("- **Architektur:** Apple Silicon (arm64)")
        #elseif arch(x86_64)
        lines.append("- **Architektur:** Intel (x86_64)")
        #endif

        let screens = NSScreen.screens
        lines.append("- **Bildschirme (\(screens.count)):**")
        for (i, s) in screens.enumerated() {
            let res = "\(Int(s.frame.width))x\(Int(s.frame.height))"
            let scale = String(format: "%.1fx", s.backingScaleFactor)
            let vis = "\(Int(s.visibleFrame.width))x\(Int(s.visibleFrame.height))"
            lines.append("  - Monitor \(i + 1) (\(s.localizedName)): \(res) @ \(scale) (Sichtbar: \(vis))")
        }

        if let front = NSWorkspace.shared.frontmostApplication?.localizedName {
            lines.append("- **Aktive Vordergrund-App:** \(front)")
        }

        return lines.joined(separator: "\n")
    }

    static func getCleanLogs(maxLines: Int = 35) -> String {
        let rawLogs = ServiceInstaller.getRecentLogs(maxLines: maxLines)
        return rawLogs.map { stripAnsiCodes($0) }.joined(separator: "\n")
    }

    static func buildMarkdownReport(
        type: FeedbackType,
        title: String,
        description: String,
        includeSystemInfo: Bool,
        includeLogs: Bool,
        customLogs: String? = nil
    ) -> String {
        var sections: [String] = []

        if type == .feature {
            sections.append("### 💡 Beschreibung des Vorschlags\n\(description.isEmpty ? "(Keine Beschreibung angegeben)" : description)")
            sections.append("### 🎯 Welches Problem löst diese Funktion?\n<!-- Erkläre kurz den Anwendungsfall oder Workflow -->")
        } else {
            sections.append("### 🐛 Fehlerbeschreibung\n\(description.isEmpty ? "(Keine Beschreibung angegeben)" : description)")
            sections.append("### 🔁 Schritte zum Reproduzieren\n1. \n2. \n3. ")
            sections.append("### ✅ Erwartetes Verhalten\n<!-- Was hättest du stattdessen erwartet? -->")
        }

        if includeSystemInfo {
            sections.append("### 🖥️ System- & Display-Informationen\n\(getSystemInfoSummary())")
        }

        if includeLogs {
            let logs = customLogs ?? getCleanLogs()
            if !logs.isEmpty {
                sections.append("### 📋 Diagnose-Logs\n```text\n\(logs)\n```")
            }
        }

        sections.append("---\n*Erstellt via SpaceTile v\(Config.version) Feedback Reporter*")
        return sections.joined(separator: "\n\n")
    }

    static func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    static func openGitHubIssue(
        type: FeedbackType,
        title: String,
        description: String,
        includeSystemInfo: Bool = true,
        includeLogs: Bool = true
    ) -> Bool {
        let fullMarkdown = buildMarkdownReport(
            type: type,
            title: title,
            description: description,
            includeSystemInfo: includeSystemInfo,
            includeLogs: includeLogs
        )

        // Always copy the complete un-truncated report to the clipboard
        copyToClipboard(fullMarkdown)

        // Determine if URL query needs a condensed log snippet to avoid browser length limits
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let issueTitle = "\(type.issuePrefix)\(cleanTitle.isEmpty ? (type == .feature ? "Feature-Wunsch" : "Fehlerbericht") : cleanTitle)"

        var urlMarkdown = fullMarkdown
        if urlMarkdown.count > 3200 {
            // Condense logs for URL query string
            let condensedLogs = getCleanLogs(maxLines: 10)
            urlMarkdown = buildMarkdownReport(
                type: type,
                title: title,
                description: description + "\n\n*(Hinweis: Vollständige Logs wurden automatisch in die Zwischenablage kopiert – drücke ⌘V zum Einfügen)*",
                includeSystemInfo: includeSystemInfo,
                includeLogs: includeLogs,
                customLogs: condensedLogs
            )
        }

        var components = URLComponents(string: Config.issuesURL)
        components?.queryItems = [
            URLQueryItem(name: "title", value: issueTitle),
            URLQueryItem(name: "labels", value: type.githubLabel),
            URLQueryItem(name: "body", value: urlMarkdown)
        ]

        guard let url = components?.url else { return false }
        return NSWorkspace.shared.open(url)
    }
}
