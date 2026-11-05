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

    var cleanDisplayString: String {
        let mods = modifiers.map { m -> String in
            switch m.lowercased() {
            case "hyper", "super": return "Hyper"
            case "cmd", "command": return "⌘ Cmd"
            case "opt", "option", "alt": return "⌥ Opt"
            case "ctrl", "control": return "⌃ Ctrl"
            case "shift": return "⇧ Shift"
            default: return m.capitalized
            }
        }.joined(separator: " + ")
        return "\(mods) + \(key.uppercased())"
    }
}

struct WindowRuleConfig: Codable, Identifiable {
    var id: String
    var pattern: String             // Title substring / pattern (e.g. "openclaw", "nvim", "dev")
    var appName: String?            // Optional app name constraint (e.g. "iTerm2", or nil for any app)
    var score: Int                  // 1 to 100 weight

    init(id: String = UUID().uuidString, pattern: String, appName: String? = nil, score: Int = 50) {
        self.id = id
        self.pattern = pattern
        self.appName = appName
        self.score = score
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
    static let version = "1.5.8"
    static let repoURL = "https://github.com/MNLBCK/spacetile"
    static let issuesURL = "https://github.com/MNLBCK/spacetile/issues/new"

    // Shortcuts
    var shortcut: ShortcutConfig       // Rearrange (Hyper+Space)
    var masterShortcut: ShortcutConfig // Set Master (Hyper+Return)
    var lockShortcut: ShortcutConfig   // Lock Window (Hyper+L)
    var floatShortcut: ShortcutConfig  // Float Window Always on Top (Hyper+F)
    var guiShortcut: ShortcutConfig    // Settings (Hyper+S)

    // Menu Bar Actions
    var menuBarDoubleClickAction: String // "rearrange", "settings", "master", "uniform"
    var menuBarSingleClickAction: String // "menu", "settings", "rearrange"

    // Layout & Spacing
    var gap: Double
    var margin: Double
    var singleWindowMode: String // "centered" or "maximized"
    var enableDualFocus: Bool    // Give second primary window prominent focus beside master

    // Animation: "instant" (recommended, zero lag) or "smooth" (multi-step interpolation)
    var animationMode: String
    var animationDuration: Double
    var animationSteps: Int
    var freezeContentDuringResize: Bool

    // Grid & Weights
    var appWeights: [AppWeightConfig]
    var windowRules: [WindowRuleConfig]
    var sideBySideForNotesAndBrowser: Bool
    var enableSpaceLearning: Bool

    var ignoredApps: [String]

    init(
        shortcut: ShortcutConfig = ShortcutConfig(modifiers: ["hyper"], key: "space"),
        masterShortcut: ShortcutConfig = ShortcutConfig(modifiers: ["hyper"], key: "return"),
        lockShortcut: ShortcutConfig = ShortcutConfig(modifiers: ["hyper"], key: "l"),
        floatShortcut: ShortcutConfig = ShortcutConfig(modifiers: ["hyper"], key: "f"),
        guiShortcut: ShortcutConfig = ShortcutConfig(modifiers: ["hyper"], key: "s"),
        menuBarDoubleClickAction: String = "rearrange",
        menuBarSingleClickAction: String = "menu",
        gap: Double = 10.0,
        margin: Double = 12.0,
        singleWindowMode: String = "centered",
        enableDualFocus: Bool = true,
        animationMode: String = "smooth",
        animationDuration: Double = 0.18,
        animationSteps: Int = 10,
        freezeContentDuringResize: Bool = true,
        appWeights: [AppWeightConfig]? = nil,
        windowRules: [WindowRuleConfig]? = nil,
        sideBySideForNotesAndBrowser: Bool = true,
        enableSpaceLearning: Bool = true,
        ignoredApps: [String]? = nil
    ) {
        self.shortcut = shortcut
        self.masterShortcut = masterShortcut
        self.lockShortcut = lockShortcut
        self.floatShortcut = floatShortcut
        self.guiShortcut = guiShortcut
        self.menuBarDoubleClickAction = menuBarDoubleClickAction
        self.menuBarSingleClickAction = menuBarSingleClickAction
        self.gap = gap
        self.margin = margin
        self.singleWindowMode = singleWindowMode
        self.enableDualFocus = enableDualFocus
        self.animationMode = animationMode
        self.animationDuration = animationDuration
        self.animationSteps = animationSteps
        self.freezeContentDuringResize = freezeContentDuringResize
        self.windowRules = windowRules ?? []
        self.sideBySideForNotesAndBrowser = sideBySideForNotesAndBrowser
        self.enableSpaceLearning = enableSpaceLearning
        self.appWeights = appWeights ?? [
            AppWeightConfig(appName: "iTerm2", score: 32, minWidth: 650, minHeight: 380, maxWidth: nil),
            AppWeightConfig(appName: "Terminal", score: 32, minWidth: 650, minHeight: 380, maxWidth: nil),
            AppWeightConfig(appName: "Ghostty", score: 32, minWidth: 650, minHeight: 380, maxWidth: nil),
            AppWeightConfig(appName: "Alacritty", score: 32, minWidth: 650, minHeight: 380, maxWidth: nil),
            AppWeightConfig(appName: "kitty", score: 32, minWidth: 650, minHeight: 380, maxWidth: nil),
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
        case shortcut, masterShortcut, lockShortcut, floatShortcut, guiShortcut
        case menuBarDoubleClickAction, menuBarSingleClickAction
        case gap, margin, singleWindowMode, enableDualFocus
        case animationMode, animationDuration, animationSteps, freezeContentDuringResize
        case appWeights, windowRules, sideBySideForNotesAndBrowser, enableSpaceLearning, ignoredApps
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let def = Config.default

        shortcut = try container.decodeIfPresent(ShortcutConfig.self, forKey: .shortcut) ?? def.shortcut
        masterShortcut = try container.decodeIfPresent(ShortcutConfig.self, forKey: .masterShortcut) ?? def.masterShortcut
        lockShortcut = try container.decodeIfPresent(ShortcutConfig.self, forKey: .lockShortcut) ?? def.lockShortcut
        floatShortcut = try container.decodeIfPresent(ShortcutConfig.self, forKey: .floatShortcut) ?? def.floatShortcut
        guiShortcut = try container.decodeIfPresent(ShortcutConfig.self, forKey: .guiShortcut) ?? def.guiShortcut

        menuBarDoubleClickAction = try container.decodeIfPresent(String.self, forKey: .menuBarDoubleClickAction) ?? "rearrange"
        menuBarSingleClickAction = try container.decodeIfPresent(String.self, forKey: .menuBarSingleClickAction) ?? "menu"

        gap = try container.decodeIfPresent(Double.self, forKey: .gap) ?? def.gap
        margin = try container.decodeIfPresent(Double.self, forKey: .margin) ?? def.margin
        singleWindowMode = try container.decodeIfPresent(String.self, forKey: .singleWindowMode) ?? def.singleWindowMode
        enableDualFocus = try container.decodeIfPresent(Bool.self, forKey: .enableDualFocus) ?? true

        animationMode = try container.decodeIfPresent(String.self, forKey: .animationMode) ?? "smooth"
        animationDuration = try container.decodeIfPresent(Double.self, forKey: .animationDuration) ?? 0.18
        animationSteps = try container.decodeIfPresent(Int.self, forKey: .animationSteps) ?? 10
        freezeContentDuringResize = try container.decodeIfPresent(Bool.self, forKey: .freezeContentDuringResize) ?? true

        appWeights = try container.decodeIfPresent([AppWeightConfig].self, forKey: .appWeights) ?? def.appWeights
        windowRules = try container.decodeIfPresent([WindowRuleConfig].self, forKey: .windowRules) ?? []
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
