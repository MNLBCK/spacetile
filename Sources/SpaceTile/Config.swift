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

struct AppWeightConfig: Codable, Identifiable {
    var id: String { appName }
    var appName: String
    var score: Int // 1 to 100 weight
    var minWidth: Double
    var minHeight: Double
    var maxWidth: Double?
}

struct Config: Codable {
    // Shortcuts
    var shortcut: ShortcutConfig       // Rearrange (Hyper+Space)
    var masterShortcut: ShortcutConfig // Set Master (Hyper+Return)
    var lockShortcut: ShortcutConfig   // Lock Window (Hyper+L)
    var guiShortcut: ShortcutConfig    // Settings (Hyper+S)

    // Layout & Spacing
    var gap: Double
    var margin: Double
    var singleWindowMode: String // "centered" or "maximized"

    // Animation: "instant" (recommended, zero lag) or "smooth" (4-step glide)
    var animationMode: String
    var animationDuration: Double

    // Grid & Weights
    var appWeights: [AppWeightConfig]
    var sideBySideForNotesAndBrowser: Bool
    var enableSpaceLearning: Bool

    var ignoredApps: [String]

    static let `default` = Config(
        shortcut: ShortcutConfig(modifiers: ["hyper"], key: "space"),
        masterShortcut: ShortcutConfig(modifiers: ["hyper"], key: "return"),
        lockShortcut: ShortcutConfig(modifiers: ["hyper"], key: "l"),
        guiShortcut: ShortcutConfig(modifiers: ["hyper"], key: "s"),
        gap: 10.0,
        margin: 12.0,
        singleWindowMode: "centered",
        animationMode: "instant",
        animationDuration: 0.12,
        appWeights: [
            AppWeightConfig(appName: "iTerm2", score: 32, minWidth: 650, minHeight: 380, maxWidth: 1024),
            AppWeightConfig(appName: "Terminal", score: 32, minWidth: 650, minHeight: 380, maxWidth: 1024),
            AppWeightConfig(appName: "Ghostty", score: 32, minWidth: 650, minHeight: 380, maxWidth: 1024),
            AppWeightConfig(appName: "Alacritty", score: 32, minWidth: 650, minHeight: 380, maxWidth: 1024),
            AppWeightConfig(appName: "kitty", score: 32, minWidth: 650, minHeight: 380, maxWidth: 1024),
            AppWeightConfig(appName: "Google Chrome", score: 72, minWidth: 500, minHeight: 400, maxWidth: nil),
            AppWeightConfig(appName: "Safari", score: 70, minWidth: 500, minHeight: 400, maxWidth: nil),
            AppWeightConfig(appName: "Arc", score: 70, minWidth: 500, minHeight: 400, maxWidth: nil),
            AppWeightConfig(appName: "Firefox", score: 70, minWidth: 500, minHeight: 400, maxWidth: nil),
            AppWeightConfig(appName: "Obsidian", score: 50, minWidth: 450, minHeight: 350, maxWidth: 1050),
            AppWeightConfig(appName: "Notes", score: 48, minWidth: 400, minHeight: 350, maxWidth: 1000),
            AppWeightConfig(appName: "Bear", score: 48, minWidth: 400, minHeight: 350, maxWidth: 1000),
            AppWeightConfig(appName: "Code", score: 75, minWidth: 700, minHeight: 450, maxWidth: nil),
            AppWeightConfig(appName: "Xcode", score: 78, minWidth: 800, minHeight: 500, maxWidth: nil)
        ],
        sideBySideForNotesAndBrowser: true,
        enableSpaceLearning: true,
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
        ]
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
            return try decoder.decode(Config.self, from: data)
        } catch {
            let def = Config.default
            def.save()
            return def
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
