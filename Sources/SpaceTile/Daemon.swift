import Cocoa

class Daemon {
    static func run() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory) // Läuft unsichtbar im Hintergrund, kein Dock-Icon

        let config = Config.load()

        print("-----------------------------------------------------------------")
        print("\u{001B}[1mSpaceTile Daemon\u{001B}[0m (Hintergrunddienst aktiv)")
        print("Optimiert deine Fenster auf Knopfdruck:")
        print(" * 1 Fenster: Zentrierter Fokus")
        print(" * 2 Fenster: Master (\(Int(config.masterRatio * 100))%) + Stack")
        print(" * 3+ Fenster: Master + Vertikaler Stack")
        print(" * Zweimal schnell drücken: Wechselt zwischen 62% / 50% / 75%")
        print("-----------------------------------------------------------------")

        HotKeyManager.shared.onHotKeyTriggered = {
            let df = DateFormatter()
            df.dateFormat = "HH:mm:ss"
            print("[\(df.string(from: Date()))] Shortcut ausgelöst -> Optimiere Fenster...")
            WindowManager.shared.optimize(verbose: true)
        }

        guard HotKeyManager.shared.register(config: config) else {
            print("[\u{001B}[31mFEHLER\u{001B}[0m] Konnte Shortcut nicht registrieren. Beende...")
            exit(1)
        }

        // Handle termination signals cleanly
        signal(SIGINT) { _ in
            print("\nSpaceTile Daemon beendet.")
            exit(0)
        }
        signal(SIGTERM) { _ in
            print("\nSpaceTile Daemon beendet.")
            exit(0)
        }

        app.run()
    }
}
