import Foundation
import Cocoa

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

    static var logFileURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Library/Logs/SpaceTile/stdout.log")
    }

    static func install() {
        let fileManager = FileManager.default
        let currentExecutable = Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0])

        let binDir = binaryDestination.deletingLastPathComponent()
        try? fileManager.createDirectory(at: binDir, withIntermediateDirectories: true)

        do {
            if currentExecutable.standardized.path != binaryDestination.standardized.path {
                if fileManager.fileExists(atPath: binaryDestination.path) {
                    try fileManager.removeItem(at: binaryDestination)
                }
                try fileManager.copyItem(at: currentExecutable, to: binaryDestination)
                print("[\u{001B}[32mOK\u{001B}[0m] Installed binary to: \(binaryDestination.path)")
            }
        } catch {
            print("[\u{001B}[31mERROR\u{001B}[0m] Could not copy binary: \(error)")
            return
        }

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
            print("[\u{001B}[32mOK\u{001B}[0m] LaunchAgent written to: \(plistURL.path)")
        } catch {
            print("[\u{001B}[31mERROR\u{001B}[0m] Could not write plist: \(error)")
            return
        }

        restart()
        print("[\u{001B}[32mSUCCESS\u{001B}[0m] SpaceTile Daemon is running and registered for login auto-start!")
    }

    static func uninstall() {
        stop()
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: plistURL.path) {
            try? fileManager.removeItem(at: plistURL)
        }
        if fileManager.fileExists(atPath: binaryDestination.path) {
            try? fileManager.removeItem(at: binaryDestination)
        }
        print("[\u{001B}[32mOK\u{001B}[0m] Uninstalled SpaceTile service.")
    }

    static func status() {
        let info = statusInfo()
        print("SpaceTile Status:")
        print(" - Binary: \(FileManager.default.fileExists(atPath: binaryDestination.path) ? "Installed" : "Not installed")")
        print(" - LaunchAgent: \(FileManager.default.fileExists(atPath: plistURL.path) ? "Registered" : "Missing")")
        if info.isRunning {
            print(" - Service: \u{001B}[32mActive\u{001B}[0m (PID: \(info.pid ?? 0))")
        } else {
            print(" - Service: \u{001B}[33mStopped\u{001B}[0m")
        }
    }

    static func start() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["load", "-w", plistURL.path]
        try? process.run()
        process.waitUntilExit()
    }

    static func stop() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["unload", plistURL.path]
        try? process.run()
        process.waitUntilExit()
    }

    static func restart() {
        let uid = getuid()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["kickstart", "-k", "gui/\(uid)/\(label)"]
        try? process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            // Fallback to reload if not already loaded
            start()
        }
    }

    static func restartAndReopenSettings(targetTab: String = "daemon") {
        let bin = binaryDestination.path
        let script = "nohup /bin/sh -c 'sleep 0.8 && \"\(bin)\" gui \(targetTab)' >/dev/null 2>&1 &"
        let escaped = script.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let osaProcess = Process()
        osaProcess.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        osaProcess.arguments = ["-e", "do shell script \"\(escaped)\""]
        try? osaProcess.run()
        osaProcess.waitUntilExit()

        restart()

        if !CommandLine.arguments.contains("daemon") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                NSApp.terminate(nil)
            }
        }
    }

    static func statusInfo() -> (isRunning: Bool, pid: Int?) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["list"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return (false, nil) }

        for line in output.components(separatedBy: "\n") {
            if line.contains(label) {
                let parts = line.split(whereSeparator: { $0.isWhitespace })
                if let first = parts.first, let pid = Int(first) {
                    return (true, pid)
                }
                return (true, nil)
            }
        }
        return (false, nil)
    }

    static func getRecentLogs(maxLines: Int = 20) -> [String] {
        guard let data = try? Data(contentsOf: logFileURL),
              let content = String(data: data, encoding: .utf8) else {
            return ["No logs available yet."]
        }
        let lines = content.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return Array(lines.suffix(maxLines))
    }
}
