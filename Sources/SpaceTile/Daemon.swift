import Cocoa

class Daemon {
    static func run() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory) // Läuft unsichtbar im Hintergrund

        let config = Config.load()

        print("-----------------------------------------------------------------")
        print("\u{001B}[1mSpaceTile Daemon\u{001B}[0m (Hintergrunddienst aktiv)")
        print("Tastaturkürzel:")
        print(" * Fenster optimieren:       \(config.shortcut.displayString)")
        print(" * Einstellungen öffnen:     \(config.guiShortcut.displayString)")
        print("-----------------------------------------------------------------")

        HotKeyManager.shared.onHotKeyTriggered = {
            let df = DateFormatter()
            df.dateFormat = "HH:mm:ss"
            print("[\(df.string(from: Date()))] Shortcut ausgelöst -> Optimiere Fenster...")
            WindowManager.shared.optimize(verbose: true)
        }

        HotKeyManager.shared.onGUITriggered = {
            let df = DateFormatter()
            df.dateFormat = "HH:mm:ss"
            print("[\(df.string(from: Date()))] Shortcut ausgelöst -> Öffne Einstellungen GUI...")
            SettingsWindowController.shared.show()
        }

        guard HotKeyManager.shared.register(config: config) else {
            print("[\u{001B}[31mFEHLER\u{001B}[0m] Konnte Shortcut nicht registrieren. Beende...")
            exit(1)
        }

        // Start background space behavior observer
        SpaceObserver.shared.start()

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
