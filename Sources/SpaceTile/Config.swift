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
    static let version = "1.5.0"

    // Shortcuts
    var shortcut: ShortcutConfig       // Rearrange (Hyper+Space)
    var masterShortcut: ShortcutConfig // Set Master (Hyper+Return)
    var lockShortcut: ShortcutConfig   // Lock Window (Hyper+L)
    var guiShortcut: ShortcutConfig    // Settings (Hyper+S)

    // Layout & Spacing
    var gap: Double
    var margin: Double
    var singleWindowMode: String // "centered" or "maximized"

    // Animation: "instant" (recommended, zero lag) or "smooth" (multi-step interpolation)
    var animationMode: String
    var animationDuration: Double
    var animationSteps: Int
    var freezeContentDuringResize: Bool

    // Grid & Weights
    var appWeights: [AppWeightConfig]
    var sideBySideForNotesAndBrowser: Bool
    var enableSpaceLearning: Bool

    var ignoredApps: [String]

    init(
        shortcut: ShortcutConfig = ShortcutConfig(modifiers: ["hyper"], key: "space"),
        masterShortcut: ShortcutConfig = ShortcutConfig(modifiers: ["hyper"], key: "return"),
        lockShortcut: ShortcutConfig = ShortcutConfig(modifiers: ["hyper"], key: "l"),
        guiShortcut: ShortcutConfig = ShortcutConfig(modifiers: ["hyper"], key: "s"),
        gap: Double = 10.0,
        margin: Double = 12.0,
        singleWindowMode: String = "centered",
        animationMode: String = "smooth",
        animationDuration: Double = 0.18,
        animationSteps: Int = 10,
        freezeContentDuringResize: Bool = true,
        appWeights: [AppWeightConfig]? = nil,
        sideBySideForNotesAndBrowser: Bool = true,
        enableSpaceLearning: Bool = true,
        ignoredApps: [String]? = nil
    ) {
        self.shortcut = shortcut
        self.masterShortcut = masterShortcut
        self.lockShortcut = lockShortcut
        self.guiShortcut = guiShortcut
        self.gap = gap
        self.margin = margin
        self.singleWindowMode = singleWindowMode
        self.animationMode = animationMode
        self.animationDuration = animationDuration
        self.animationSteps = animationSteps
        self.freezeContentDuringResize = freezeContentDuringResize
        self.sideBySideForNotesAndBrowser = sideBySideForNotesAndBrowser
        self.enableSpaceLearning = enableSpaceLearning
        self.appWeights = appWeights ?? [
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
        ]
        self.ignoredApps = ignoredApps ?? [
            "Vorschau",
            "Preview",
            "System Settings",
            "Systemeinstellungen",
            "Calculator",
            "Rechner",
            "1Password",
            "QuickTime Player",
            "Activity Monitor",
            "Aktivitätsanzeige"
        ]
    }

    enum CodingKeys: String, CodingKey {
        case shortcut, masterShortcut, lockShortcut, guiShortcut
        case gap, margin, singleWindowMode
        case animationMode, animationDuration, animationSteps, freezeContentDuringResize
        case appWeights, sideBySideForNotesAndBrowser, enableSpaceLearning, ignoredApps
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let def = Config.default

        shortcut = try container.decodeIfPresent(ShortcutConfig.self, forKey: .shortcut) ?? def.shortcut
        masterShortcut = try container.decodeIfPresent(ShortcutConfig.self, forKey: .masterShortcut) ?? def.masterShortcut
        lockShortcut = try container.decodeIfPresent(ShortcutConfig.self, forKey: .lockShortcut) ?? def.lockShortcut
        guiShortcut = try container.decodeIfPresent(ShortcutConfig.self, forKey: .guiShortcut) ?? def.guiShortcut

        gap = try container.decodeIfPresent(Double.self, forKey: .gap) ?? def.gap
        margin = try container.decodeIfPresent(Double.self, forKey: .margin) ?? def.margin
        singleWindowMode = try container.decodeIfPresent(String.self, forKey: .singleWindowMode) ?? def.singleWindowMode

        animationMode = try container.decodeIfPresent(String.self, forKey: .animationMode) ?? "smooth"
        animationDuration = try container.decodeIfPresent(Double.self, forKey: .animationDuration) ?? 0.18
        animationSteps = try container.decodeIfPresent(Int.self, forKey: .animationSteps) ?? 10
        freezeContentDuringResize = try container.decodeIfPresent(Bool.self, forKey: .freezeContentDuringResize) ?? true

        appWeights = try container.decodeIfPresent([AppWeightConfig].self, forKey: .appWeights) ?? def.appWeights
        sideBySideForNotesAndBrowser = try container.decodeIfPresent(Bool.self, forKey: .sideBySideForNotesAndBrowser) ?? def.sideBySideForNotesAndBrowser
        enableSpaceLearning = try container.decodeIfPresent(Bool.self, forKey: .enableSpaceLearning) ?? def.enableSpaceLearning
        ignoredApps = try container.decodeIfPresent([String].self, forKey: .ignoredApps) ?? def.ignoredApps
    }

    static let `default` = Config()

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
            print("[\u{001B}[31mConfig\u{001B}[0m] Failed to parse config.json: \(error). Using in-memory defaults without overwriting config file.")
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
            try? data.write(to: url, options: .atomic)
        }
    }
}
