import Foundation
import Cocoa

struct ServiceInstaller {
    static let label = "com.guppi.spacetile"

    static var appURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Applications/SpaceTile.app")
    }

    static var binaryDestination: URL {
        return appURL.appendingPathComponent("Contents/MacOS/spacetile")
    }

    static var symlinkDestination: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".local/bin/spacetile")
    }

    static var plistURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static var logFileURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Library/Logs/SpaceTile/stdout.log")
    }

    static func install() {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser

        // 1. Create App Bundle Directories
        let macosDir = appURL.appendingPathComponent("Contents/MacOS")
        let resDir = appURL.appendingPathComponent("Contents/Resources")
        try? fileManager.createDirectory(at: macosDir, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: resDir, withIntermediateDirectories: true)

        // 2. Copy Executable into App Bundle
        let currentExecutable = Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0])
        do {
            if currentExecutable.standardized.path != binaryDestination.standardized.path {
                if fileManager.fileExists(atPath: binaryDestination.path) {
                    try fileManager.removeItem(at: binaryDestination)
                }
                try fileManager.copyItem(at: currentExecutable, to: binaryDestination)
                try? fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: binaryDestination.path)
            }
            print("[\u{001B}[32mOK\u{001B}[0m] App binary installed to: \(binaryDestination.path)")
        } catch {
            print("[\u{001B}[31mERROR\u{001B}[0m] Could not copy binary: \(error)")
            return
        }

        // 3. Copy Icons into Bundle Resources
        let assetPaths = [
            Bundle.main.bundleURL.appendingPathComponent("assets"),
            home.appendingPathComponent("Code/spacetile/assets"),
            Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("assets")
        ]
        for assetDir in assetPaths {
            let icns = assetDir.appendingPathComponent("AppIcon.icns")
            let png = assetDir.appendingPathComponent("AppIcon.png")
            if fileManager.fileExists(atPath: icns.path) {
                let dest = resDir.appendingPathComponent("AppIcon.icns")
                try? fileManager.removeItem(at: dest)
                try? fileManager.copyItem(at: icns, to: dest)
            }
            if fileManager.fileExists(atPath: png.path) {
                let dest = resDir.appendingPathComponent("AppIcon.png")
                try? fileManager.removeItem(at: dest)
                try? fileManager.copyItem(at: png, to: dest)
            }
        }

        // 4. Write Info.plist & PkgInfo
        let infoPlistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleName</key>
            <string>SpaceTile</string>
            <key>CFBundleDisplayName</key>
            <string>SpaceTile</string>
            <key>CFBundleIdentifier</key>
            <string>\(label)</string>
            <key>CFBundleVersion</key>
            <string>\(Config.version)</string>
            <key>CFBundleShortVersionString</key>
            <string>\(Config.version)</string>
            <key>CFBundlePackageType</key>
            <string>APPL</string>
            <key>CFBundleExecutable</key>
            <string>spacetile</string>
            <key>CFBundleIconFile</key>
            <string>AppIcon</string>
            <key>LSMinimumSystemVersion</key>
            <string>13.0</string>
            <key>NSHighResolutionCapable</key>
            <true/>
            <key>NSAppleEventsUsageDescription</key>
            <string>SpaceTile requires Accessibility permissions to tile and arrange windows.</string>
        </dict>
        </plist>
        """
        let infoPlistURL = appURL.appendingPathComponent("Contents/Info.plist")
        try? infoPlistContent.write(to: infoPlistURL, atomically: true, encoding: .utf8)
        let pkgInfoURL = appURL.appendingPathComponent("Contents/PkgInfo")
        try? "APPL????".write(to: pkgInfoURL, atomically: true, encoding: .utf8)

        // 5. Deep Sign Bundle with Stable Identifier and Explicit Designated Requirement
        // Using '--requirements' ensures that macOS TCC (Accessibility) does not invalidate
        // permissions when the binary cdhash changes across rebuilds!
        let signProcess = Process()
        signProcess.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        signProcess.arguments = [
            "-s", "-",
            "--force",
            "--deep",
            "--identifier", label,
            "--requirements", "=designated => identifier \"\(label)\"",
            appURL.path
        ]
        try? signProcess.run()
        signProcess.waitUntilExit()
        print("[\u{001B}[32mOK\u{001B}[0m] Signed SpaceTile.app with stable designated requirement '\(label)'")

        // 6. Create CLI Symlink at ~/.local/bin/spacetile
        let binDir = symlinkDestination.deletingLastPathComponent()
        try? fileManager.createDirectory(at: binDir, withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: symlinkDestination.path) {
            try? fileManager.removeItem(at: symlinkDestination)
        }
        try? fileManager.createSymbolicLink(at: symlinkDestination, withDestinationURL: binaryDestination)
        print("[\u{001B}[32mOK\u{001B}[0m] Symlinked CLI tool to: \(symlinkDestination.path)")

        // 7. Write LaunchAgent Plist
        let logDir = home.appendingPathComponent("Library/Logs/SpaceTile").path
        try? fileManager.createDirectory(atPath: logDir, withIntermediateDirectories: true)

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
        try? plistContent.write(to: plistURL, atomically: true, encoding: .utf8)
        print("[\u{001B}[32mOK\u{001B}[0m] LaunchAgent written to: \(plistURL.path)")

        // 8. Restart Daemon
        restart()
        print("[\u{001B}[32mSUCCESS\u{001B}[0m] SpaceTile.app installed and daemon active!")
    }

    static func uninstall() {
        stop()
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: plistURL.path) {
            try? fileManager.removeItem(at: plistURL)
        }
        if fileManager.fileExists(atPath: appURL.path) {
            try? fileManager.removeItem(at: appURL)
        }
        if fileManager.fileExists(atPath: symlinkDestination.path) {
            try? fileManager.removeItem(at: symlinkDestination)
        }
        print("[\u{001B}[32mOK\u{001B}[0m] Uninstalled SpaceTile service and app bundle.")
    }

    static func status() {
        let info = statusInfo()
        let appExists = FileManager.default.fileExists(atPath: appURL.path)
        let linkExists = FileManager.default.fileExists(atPath: symlinkDestination.path)
        let plistExists = FileManager.default.fileExists(atPath: plistURL.path)
        let trusted = WindowManager.canControlWindows()

        print("SpaceTile Status:")
        print(" - App Bundle:    \(appExists ? "\u{001B}[32mInstalled\u{001B}[0m (\(appURL.path))" : "\u{001B}[31mMissing\u{001B}[0m")")
        print(" - CLI Symlink:   \(linkExists ? "\u{001B}[32mActive\u{001B}[0m (\(symlinkDestination.path))" : "\u{001B}[31mMissing\u{001B}[0m")")
        print(" - LaunchAgent:   \(plistExists ? "\u{001B}[32mRegistered\u{001B}[0m" : "\u{001B}[31mMissing\u{001B}[0m")")
        if info.isRunning {
            print(" - Service:       \u{001B}[32mActive\u{001B}[0m (PID: \(info.pid ?? 0))")
        } else {
            print(" - Service:       \u{001B}[33mStopped\u{001B}[0m")
        }
        print(" - Accessibility: \(trusted ? "\u{001B}[32mGranted\u{001B}[0m" : "\u{001B}[31mNot Granted\u{001B}[0m")")
    }

    @discardableResult
    private static func runCommand(_ path: String, arguments: [String]) -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let out = String(data: data, encoding: .utf8) ?? ""
            return (process.terminationStatus, out)
        } catch {
            return (-1, "")
        }
    }

    static func start() {
        runCommand("/bin/launchctl", arguments: ["load", "-w", plistURL.path])
    }

    static func stop() {
        runCommand("/bin/launchctl", arguments: ["unload", plistURL.path])
    }

    static func restart() {
        let uid = getuid()
        let result = runCommand("/bin/launchctl", arguments: ["kickstart", "-k", "gui/\(uid)/\(label)"])
        if result.status != 0 {
            start()
        }
    }

    static func restartAndReopenSettings(targetTab: String = "daemon") {
        let bin = binaryDestination.path
        let script = "nohup /bin/sh -c 'sleep 0.8 && \"\(bin)\" gui \(targetTab)' >/dev/null 2>&1 &"
        let escaped = script.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        runCommand("/usr/bin/osascript", arguments: ["-e", "do shell script \"\(escaped)\""])

        restart()

        if !CommandLine.arguments.contains("daemon") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                NSApp.terminate(nil)
            }
        }
    }

    static func statusInfo() -> (isRunning: Bool, pid: Int?) {
        let res = runCommand("/bin/launchctl", arguments: ["list", label])
        guard res.status == 0 else { return (false, nil) }

        // Format in macOS: "PID" = 12345;
        for line in res.output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("\"PID\"") || trimmed.hasPrefix("PID") {
                let digits = trimmed.filter { $0.isNumber }
                if let pid = Int(digits) {
                    return (true, pid)
                }
            }
        }
        return (true, nil)
    }

    static func getRecentLogs(maxLines: Int = 20) -> [String] {
        guard let handle = try? FileHandle(forReadingFrom: logFileURL) else {
            return ["No logs available yet."]
        }
        defer { try? handle.close() }

        let fileSize = handle.seekToEndOfFile()
        guard fileSize > 0 else { return ["No logs available yet."] }

        let readLength = min(fileSize, 32 * 1024)
        handle.seek(toFileOffset: fileSize - readLength)
        let data = handle.readDataToEndOfFile()

        guard let content = String(data: data, encoding: .utf8) else {
            return ["No logs available yet."]
        }
        let lines = content.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return Array(lines.suffix(maxLines))
    }
}
