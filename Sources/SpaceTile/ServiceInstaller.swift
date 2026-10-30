import Foundation

struct ServiceInstaller {
    static let label = "com.guppi.spacetile"

    static var plistURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static var binaryDestination: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".local/bin/spacetile")
    }

    static func install() {
        let fileManager = FileManager.default
        let currentExecutable = Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0])

        // Ensure ~/.local/bin exists
        let binDir = binaryDestination.deletingLastPathComponent()
        try? fileManager.createDirectory(at: binDir, withIntermediateDirectories: true)

        // Copy executable if not already in place
        do {
            if currentExecutable.standardized.path != binaryDestination.standardized.path {
                if fileManager.fileExists(atPath: binaryDestination.path) {
                    try fileManager.removeItem(at: binaryDestination)
                }
                try fileManager.copyItem(at: currentExecutable, to: binaryDestination)
                print("[\u{001B}[32mOK\u{001B}[0m] Binary installiert nach: \(binaryDestination.path)")
            }
        } catch {
            print("[\u{001B}[31mFEHLER\u{001B}[0m] Konnte Binary nicht kopieren: \(error)")
            return
        }

        // Generate LaunchAgent Plist
        let home = fileManager.homeDirectoryForCurrentUser.path
        let logDir = "\(home)/Library/Logs/SpaceTile"
        try? fileManager.createDirectory(atPath: logDir, withIntermediateDirectories: true, attributes: nil)

        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(label)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(binaryDestination.path)</string>
                <string>daemon</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <true/>
            <key>StandardOutPath</key>
            <string>\(logDir)/stdout.log</string>
            <key>StandardErrorPath</key>
            <string>\(logDir)/stderr.log</string>
            <key>ProcessType</key>
            <string>Interactive</string>
        </dict>
        </plist>
        """

        let agentDir = plistURL.deletingLastPathComponent()
        try? fileManager.createDirectory(at: agentDir, withIntermediateDirectories: true)

        do {
            try plistContent.write(to: plistURL, atomically: true, encoding: .utf8)
            print("[\u{001B}[32mOK\u{001B}[0m] LaunchAgent erstellt unter: \(plistURL.path)")
        } catch {
            print("[\u{001B}[31mFEHLER\u{001B}[0m] Konnte Plist nicht schreiben: \(error)")
            return
        }

        // Unload existing service if already running
        let unloadProc = Process()
        unloadProc.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        unloadProc.arguments = ["unload", plistURL.path]
        try? unloadProc.run()
        unloadProc.waitUntilExit()

        // Load via launchctl
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["load", "-w", plistURL.path]
        try? process.run()
        process.waitUntilExit()

        print("[\u{001B}[32mERFOLG\u{001B}[0m] SpaceTile Daemon wurde gestartet und startet künftig automatisch beim Mac-Start!")
        print("Tipp: Logs findest du unter: ~/Library/Logs/SpaceTile/stdout.log")
    }

    static func uninstall() {
        let fileManager = FileManager.default

        // Unload
        if fileManager.fileExists(atPath: plistURL.path) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            process.arguments = ["unload", plistURL.path]
            try? process.run()
            process.waitUntilExit()

            try? fileManager.removeItem(at: plistURL)
            print("[\u{001B}[32mOK\u{001B}[0m] LaunchAgent entfernt.")
        }

        if fileManager.fileExists(atPath: binaryDestination.path) {
            try? fileManager.removeItem(at: binaryDestination)
            print("[\u{001B}[32mOK\u{001B}[0m] Binary entfernt: \(binaryDestination.path)")
        }

        print("[\u{001B}[32mERFOLG\u{001B}[0m] SpaceTile Daemon wurde sauber deinstalliert.")
    }

    static func status() {
        let fileManager = FileManager.default
        let plistExists = fileManager.fileExists(atPath: plistURL.path)
        let binExists = fileManager.fileExists(atPath: binaryDestination.path)

        print("SpaceTile Status:")
        print(" - Binary: \(binExists ? "Installiert (\(binaryDestination.path))" : "Nicht installiert")")
        print(" - LaunchAgent Plist: \(plistExists ? "Vorhanden" : "Nicht vorhanden")")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["list"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8), output.contains(label) {
            print(" - Dienst-Status: \u{001B}[32mAktiv (läuft im Hintergrund)\u{001B}[0m")
        } else {
            print(" - Dienst-Status: \u{001B}[33mInaktiv / Nicht geladen\u{001B}[0m")
        }
    }
}
