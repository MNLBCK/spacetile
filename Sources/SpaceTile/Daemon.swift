import Cocoa

class Daemon {
    static func run() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let config = Config.load()

        print("-----------------------------------------------------------------")
        print("\u{001B}[1mSpaceTile Daemon\u{001B}[0m (Running in background)")
        print("Hotkeys:")
        print(" * Rearrange:      \(config.shortcut.displayString)")
        print(" * Set as Master:  \(config.masterShortcut.displayString)")
        print(" * Lock/Unlock:    \(config.lockShortcut.displayString)")
        print(" * Settings GUI:   \(config.guiShortcut.displayString)")
        print("-----------------------------------------------------------------")

        HotKeyManager.shared.onRearrangeTriggered = {
            let df = DateFormatter()
            df.dateFormat = "HH:mm:ss"
            print("[\(df.string(from: Date()))] Shortcut triggered -> Rearranging windows...")
            WindowManager.shared.optimize(verbose: true)
        }

        HotKeyManager.shared.onGUITriggered = {
            let df = DateFormatter()
            df.dateFormat = "HH:mm:ss"
            print("[\(df.string(from: Date()))] Shortcut triggered -> Opening Settings GUI...")
            SettingsWindowController.shared.show()
        }

        HotKeyManager.shared.onSetMasterTriggered = {
            let df = DateFormatter()
            df.dateFormat = "HH:mm:ss"
            print("[\(df.string(from: Date()))] Shortcut triggered -> Setting focused window as Master...")
            _ = WindowManager.shared.setFocusedAsMaster()
        }

        HotKeyManager.shared.onToggleLockTriggered = {
            let df = DateFormatter()
            df.dateFormat = "HH:mm:ss"
            print("[\(df.string(from: Date()))] Shortcut triggered -> Toggling lock for focused window...")
            _ = WindowManager.shared.toggleLockForFocusedWindow()
        }

        guard HotKeyManager.shared.register(config: config) else {
            print("[\u{001B}[31mERROR\u{001B}[0m] Could not register global shortcuts. Exiting...")
            exit(1)
        }

        SpaceObserver.shared.start()

        signal(SIGINT) { _ in
            print("\nSpaceTile Daemon terminated.")
            exit(0)
        }
        signal(SIGTERM) { _ in
            print("\nSpaceTile Daemon terminated.")
            exit(0)
        }

        app.run()
    }
}
