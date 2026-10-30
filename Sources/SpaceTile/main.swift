import Foundation

setlinebuf(stdout)
setlinebuf(stderr)

func printHelp() {
    print("""
    \u{001B}[1mSpaceTile\u{001B}[0m – Intelligenter On-Demand Fenster-Optimierer für macOS

    \u{001B}[1mBENUTZUNG:\u{001B}[0m
      spacetile [BEFEHL]

    \u{001B}[1mBEFEHLE:\u{001B}[0m
      \u{001B}[32m(ohne Arg)\u{001B}[0m, \u{001B}[32moptimize\u{001B}[0m   Optimiert die Fenster im aktuellen Space sofort einmalig
      \u{001B}[32mdaemon\u{001B}[0m               Startet den Hintergrunddienst mit globalem Tastenkürzel
      \u{001B}[32minstall\u{001B}[0m              Installiert SpaceTile als dauerhaften Hintergrund-Dienst (LaunchAgent)
      \u{001B}[32muninstall\u{001B}[0m            Entfernt den Hintergrund-Dienst
      \u{001B}[32mstatus\u{001B}[0m               Zeigt an, ob der Dienst im Hintergrund aktiv ist
      \u{001B}[32mconfig\u{001B}[0m               Zeigt die aktuelle Konfiguration und ihren Speicherort
      \u{001B}[32mhelp\u{001B}[0m                 Zeigt diese Hilfe an

    \u{001B}[1mSTANDARD-SHORTCUT IM DAEMON-MODUS:\u{001B}[0m
      ⌃ + ⌥ + ⌘ + Leertaste  (Control + Option + Command + Space)

    \u{001B}[1mTRICK:\u{001B}[0m
      Drückst du den Shortcut innerhalb von 2 Sekunden mehrmals, wechselt das
      Layout automatisch zwischen 62% Fokus, 50/50 Split und 75% Fokus!
    """)
}

let args = Array(CommandLine.arguments.dropFirst())
let command = args.first?.lowercased() ?? "optimize"

switch command {
case "optimize", "run":
    _ = WindowManager.shared.optimize(verbose: true)

case "daemon":
    Daemon.run()

case "install":
    ServiceInstaller.install()

case "uninstall":
    ServiceInstaller.uninstall()

case "status":
    ServiceInstaller.status()

case "config":
    let config = Config.load()
    print("Konfigurationsdatei: \(Config.configURL.path)")
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    if let data = try? encoder.encode(config), let str = String(data: data, encoding: .utf8) {
        print("\nAktuelle Einstellungen:\n\(str)")
    }

case "help", "--help", "-h":
    printHelp()

default:
    print("Unbekannter Befehl: \(command)\n")
    printHelp()
    exit(1)
}
