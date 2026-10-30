import Foundation

struct ShortcutConfig: Codable {
    var modifiers: [String]
    var key: String
}

struct Config: Codable {
    var shortcut: ShortcutConfig
    var masterRatio: Double
    var gap: Double
    var margin: Double
    var singleWindowMode: String // "centered" or "maximized"
    var cycleRatios: [Double]
    var ignoredApps: [String]

    static let `default` = Config(
        shortcut: ShortcutConfig(
            modifiers: ["command", "option", "control"],
            key: "space"
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
