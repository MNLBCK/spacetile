import Foundation

struct ShortcutConfig: Codable, Equatable {
    var modifiers: [String]
    var key: String

    var displayString: String {
        let mods = modifiers.map { m -> String in
            switch m.lowercased() {
            case "hyper", "super": return "Hyper (⌃⌥⇧⌘)"
            case "cmd", "command": return "⌘ Command"
            case "opt", "option", "alt": return "⌥ Option"
            case "ctrl", "control": return "⌃ Control"
            case "shift": return "⇧ Shift"
            default: return m.capitalized
            }
        }.joined(separator: " + ")
        return "\(mods) + \(key.uppercased())"
    }
}

struct AppConstraint: Codable, Identifiable {
    var id: String { appName }
    var appName: String
    var category: String // "terminal", "browser", "notes", "editor", "custom"
    var maxWidth: Double?
    var minWidth: Double?
    var maxRatio4K: Double?
    var preferSideBySide: Bool?
    var presetWidth: Double? // 393 (iPhone), 834 (iPad), nil
}

struct Config: Codable {
    var shortcut: ShortcutConfig
    var guiShortcut: ShortcutConfig
    var masterRatio: Double
    var gap: Double
    var margin: Double
    var singleWindowMode: String // "centered" or "maximized"
    var cycleRatios: [Double]
    var ignoredApps: [String]

    // Smart Constraints & Weights
    var enableSmartWeighting: Bool
    var terminalMaxWidth4K: Double
    var terminalMaxRatio4K: Double
    var sideBySideForNotesAndBrowser: Bool
    var appConstraints: [AppConstraint]

    // Space Learning
    var enableSpaceLearning: Bool

    static let `default` = Config(
        shortcut: ShortcutConfig(
            modifiers: ["hyper"],
            key: "space"
        ),
        guiShortcut: ShortcutConfig(
            modifiers: ["hyper"],
            key: "s"
        ),
        masterRatio: 0.62,
        gap: 10.0,
        margin: 12.0,
        singleWindowMode: "centered",
        cycleRatios: [0.62, 0.50, 0.75],
        ignoredApps: [
            "Vorssaint",
            "System Settings",
            "Systemeinstellungen",
            "Calculator",
            "Rechner",
            "1Password",
            "QuickTime Player",
            "Activity Monitor",
            "Aktivitätsanzeige"
        ],
        enableSmartWeighting: true,
        terminalMaxWidth4K: 1150.0,
        terminalMaxRatio4K: 0.34,
        sideBySideForNotesAndBrowser: true,
        appConstraints: [
            AppConstraint(appName: "iTerm2", category: "terminal", maxWidth: 1150.0, minWidth: 650.0, maxRatio4K: 0.34, preferSideBySide: false, presetWidth: nil),
            AppConstraint(appName: "Terminal", category: "terminal", maxWidth: 1150.0, minWidth: 650.0, maxRatio4K: 0.34, preferSideBySide: false, presetWidth: nil),
            AppConstraint(appName: "Ghostty", category: "terminal", maxWidth: 1150.0, minWidth: 650.0, maxRatio4K: 0.34, preferSideBySide: false, presetWidth: nil),
            AppConstraint(appName: "Alacritty", category: "terminal", maxWidth: 1150.0, minWidth: 650.0, maxRatio4K: 0.34, preferSideBySide: false, presetWidth: nil),
            AppConstraint(appName: "kitty", category: "terminal", maxWidth: 1150.0, minWidth: 650.0, maxRatio4K: 0.34, preferSideBySide: false, presetWidth: nil),
            AppConstraint(appName: "Google Chrome", category: "browser", maxWidth: nil, minWidth: 500.0, maxRatio4K: nil, preferSideBySide: true, presetWidth: nil),
            AppConstraint(appName: "Safari", category: "browser", maxWidth: nil, minWidth: 500.0, maxRatio4K: nil, preferSideBySide: true, presetWidth: nil),
            AppConstraint(appName: "Arc", category: "browser", maxWidth: nil, minWidth: 500.0, maxRatio4K: nil, preferSideBySide: true, presetWidth: nil),
            AppConstraint(appName: "Firefox", category: "browser", maxWidth: nil, minWidth: 500.0, maxRatio4K: nil, preferSideBySide: true, presetWidth: nil),
            AppConstraint(appName: "Obsidian", category: "notes", maxWidth: 1000.0, minWidth: 450.0, maxRatio4K: 0.50, preferSideBySide: true, presetWidth: nil),
            AppConstraint(appName: "Notes", category: "notes", maxWidth: 950.0, minWidth: 400.0, maxRatio4K: 0.50, preferSideBySide: true, presetWidth: nil),
            AppConstraint(appName: "Bear", category: "notes", maxWidth: 950.0, minWidth: 400.0, maxRatio4K: 0.50, preferSideBySide: true, presetWidth: nil),
            AppConstraint(appName: "Code", category: "editor", maxWidth: nil, minWidth: 700.0, maxRatio4K: nil, preferSideBySide: false, presetWidth: nil),
            AppConstraint(appName: "Xcode", category: "editor", maxWidth: nil, minWidth: 800.0, maxRatio4K: nil, preferSideBySide: false, presetWidth: nil)
        ],
        enableSpaceLearning: true
    )

    static var configURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".config/spacetile/config.json")
    }

    static func load() -> Config {
        let url = configURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            let def = Config.default
            def.save()
            return def
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            var loaded = try decoder.decode(Config.self, from: data)
            // Ensure newly added fields exist or migrate
            if loaded.appConstraints.isEmpty {
                loaded.appConstraints = Config.default.appConstraints
            }
            return loaded
        } catch {
            print("[\u{001B}[33mWARN\u{001B}[0m] Fehler beim Laden von \(url.path): \(error). Verwende Standardkonfiguration.")
            return Config.default
        }
    }

    func save() {
        let url = Config.configURL
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(self) {
            try? data.write(to: url)
        }
    }
}
