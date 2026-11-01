import Cocoa

class Daemon {
    private static let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss"
        return df
    }()

    private static var signalSources: [DispatchSourceSignal] = []

    static func run() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        MenuBarController.shared.setup()

        var config = Config.load()

        print("-----------------------------------------------------------------")
        print("\u{001B}[1mSpaceTile Daemon\u{001B}[0m (Running in background)")
        print("Hotkeys:")
        print(" * Rearrange:      \(config.shortcut.displayString)")
        print(" * Set as Master:  \(config.masterShortcut.displayString)")
        print(" * Lock/Unlock:    \(config.lockShortcut.displayString)")
        print(" * Settings GUI:   \(config.guiShortcut.displayString)")
        print("-----------------------------------------------------------------")

        HotKeyManager.shared.onRearrangeTriggered = {
            print("[\(timeFormatter.string(from: Date()))] Shortcut triggered -> Rearranging windows...")
            WindowManager.shared.optimize(verbose: true)
        }

        HotKeyManager.shared.onGUITriggered = {
            print("[\(timeFormatter.string(from: Date()))] Shortcut triggered -> Opening Settings GUI...")
            SettingsWindowController.shared.show()
        }

        HotKeyManager.shared.onSetMasterTriggered = {
            print("[\(timeFormatter.string(from: Date()))] Shortcut triggered -> Setting focused window as Master...")
            _ = WindowManager.shared.setFocusedAsMaster()
        }

        HotKeyManager.shared.onToggleLockTriggered = {
            print("[\(timeFormatter.string(from: Date()))] Shortcut triggered -> Toggling lock for focused window...")
            _ = WindowManager.shared.toggleLockForFocusedWindow()
        }

        guard HotKeyManager.shared.register(config: config) else {
            print("[\u{001B}[31mERROR\u{001B}[0m] Could not register global shortcuts. Exiting...")
            exit(1)
        }

        // Listen for config changes from GUI or CLI to live-reload hotkeys
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.guppi.spacetile.configChanged"),
            object: nil,
            queue: .main
        ) { _ in
            let newConfig = Config.load()
            config = newConfig
            _ = HotKeyManager.shared.register(config: newConfig)
            print("[\(timeFormatter.string(from: Date()))] Config changed -> Reloaded hotkeys.")
        }

        SpaceObserver.shared.start()

        // Clean signal handling via DispatchSource (async-signal-safe)
        let signals = [SIGINT, SIGTERM]
        for sig in signals {
            signal(sig, SIG_IGN) // ignore default handler
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler {
                print("\nSpaceTile Daemon terminated cleanly.")
                exit(0)
            }
            source.resume()
            signalSources.append(source)
        }

        app.run()
    }
}
