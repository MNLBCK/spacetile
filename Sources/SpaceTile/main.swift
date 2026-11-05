import Cocoa

setlinebuf(stdout)
setlinebuf(stderr)

func printHelp() {
    print("""
    \u{001B}[1mSpaceTile\u{001B}[0m – Intelligenter On-Demand Fenster-Optimierer für macOS

    \u{001B}[1mBENUTZUNG:\u{001B}[0m
      spacetile [BEFEHL]

    \u{001B}[1mBEFEHLE:\u{001B}[0m
      \u{001B}[32m(ohne Arg)\u{001B}[0m, \u{001B}[32moptimize\u{001B}[0m   Optimiert die Fenster im aktuellen Space sofort einmalig
      \u{001B}[32mgui\u{001B}[0m, \u{001B}[32msettings\u{001B}[0m        Öffnet die grafische Benutzeroberfläche (GUI)
      \u{001B}[32mlearn\u{001B}[0m                Speichert das aktuelle Fensterlayout für dieses App-Set im Space-Gedächtnis
      \u{001B}[32mdaemon\u{001B}[0m               Startet den Hintergrunddienst mit globalen Shortcuts
      \u{001B}[32minstall\u{001B}[0m              Installiert SpaceTile als dauerhaften Hintergrund-Dienst (LaunchAgent)
      \u{001B}[32muninstall\u{001B}[0m            Entfernt den Hintergrund-Dienst
      \u{001B}[32mstatus\u{001B}[0m               Zeigt an, ob der Dienst im Hintergrund aktiv ist
      \u{001B}[32mfeedback\u{001B}[0m, \u{001B}[32mbug\u{001B}[0m       Erstellt einen Vorschlag oder Fehlerbericht mit Logs auf GitHub
      \u{001B}[32mconfig\u{001B}[0m               Zeigt die aktuelle Konfiguration
      \u{001B}[32mhelp\u{001B}[0m                 Zeigt diese Hilfe an

    \u{001B}[1mSTANDARD-SHORTCUTS:\u{001B}[0m
      Hyper + Leertaste  (⌃⌥⇧⌘ + Space)  ➔ Fenster optimieren
      Hyper + Return     (⌃⌥⇧⌘ + Enter)  ➔ Als Master-Fenster setzen (Doppeltipp: Master aufheben)
      Hyper + L          (⌃⌥⇧⌘ + L)      ➔ Fensterposition sperren (Lock)
      Hyper + F          (⌃⌥⇧⌘ + F)      ➔ Floating Fenster (Always on Top, ignoriert beim Tiling)
      Hyper + S          (⌃⌥⇧⌘ + S)      ➔ Einstellungen GUI öffnen
    """)
}

let args = Array(CommandLine.arguments.dropFirst())
let command = args.first?.lowercased() ?? "optimize"

switch command {
case "optimize", "run":
    _ = WindowManager.shared.optimize(verbose: true)

case "master":
    _ = WindowManager.shared.setFocusedAsMaster()

case "clear-master", "reset-master":
    WindowManager.shared.clearMasterWindow()

case "focus":
    _ = WindowManager.shared.setFocusedAsSecondaryFocus()

case "clear-focus", "reset-focus":
    WindowManager.shared.clearSecondaryFocusWindow()

case "lock":
    _ = WindowManager.shared.toggleLockForFocusedWindow()

case "float":
    _ = WindowManager.shared.toggleFloatForFocusedWindow()

case "gui", "settings":
    let targetTab = args.count > 1 ? args[1] : nil
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)
    SettingsWindowController.shared.show(initialTab: targetTab)
    app.run()

case "learn":
    if let msg = SpaceObserver.shared.learnCurrentLayoutNow() {
        print("[\u{001B}[32mSpaceTile\u{001B}[0m] \(msg)")
    } else {
        print("[\u{001B}[31mSpaceTile\u{001B}[0m] Konnte aktuelles Layout nicht erfassen.")
    }

case "daemon":
    Daemon.run()

case "restart":
    ServiceInstaller.restart()

case "install":
    ServiceInstaller.install()

case "uninstall":
    ServiceInstaller.uninstall()

case "status":
    ServiceInstaller.status()

case "feedback", "issue", "bug":
    let isBug = (command == "bug")
    let title = args.dropFirst().joined(separator: " ")
    print("[\u{001B}[32mSpaceTile\u{001B}[0m] Erstelle GitHub \(isBug ? "Fehlerbericht" : "Vorschlag") mit Diagnose-Logs...")
    let success = FeedbackReporter.openGitHubIssue(
        type: isBug ? .bug : .feature,
        title: title,
        description: "",
        includeSystemInfo: true,
        includeLogs: isBug
    )
    if success {
        print("[\u{001B}[32mOK\u{001B}[0m] GitHub Issue-Maske im Browser geöffnet und Diagnose-Bericht in die Zwischenablage kopiert!")
    } else {
        print("[\u{001B}[31mERROR\u{001B}[0m] Browser konnte nicht geöffnet werden.")
    }

case "config":
    if args.contains("--gui") {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        SettingsWindowController.shared.show()
        app.run()
    } else {
        let config = Config.load()
        print("Konfigurationsdatei: \(Config.configURL.path)")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(config), let str = String(data: data, encoding: .utf8) {
            print("\nAktuelle Einstellungen:\n\(str)")
        }
    }

case "help", "--help", "-h":
    printHelp()

default:
    print("Unbekannter Befehl: \(command)\n")
    printHelp()
    exit(1)
}
