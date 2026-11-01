import Cocoa
import SwiftUI

class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    func show(initialTab: String? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            NSApp.setActivationPolicy(.regular)
            MenuBarController.shared.setup()

            if let win = self.window {
                if let tab = initialTab {
                    NotificationCenter.default.post(name: NSNotification.Name("com.guppi.spacetile.switchTab"), object: tab)
                }
                win.orderFrontRegardless()
                win.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }

            let contentView = SettingsView(tabName: initialTab)
            let hostingController = NSHostingController(rootView: contentView)

            let winWidth: CGFloat = 940
            let winHeight: CGFloat = 740

            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: winWidth, height: winHeight),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )

            win.setFrameAutosaveName("SpaceTileSettingsWindow")
            if !win.setFrameUsingName("SpaceTileSettingsWindow") {
                // Position window to avoid blocking the center of the screen
                // where macOS system permission dialogs and alerts spawn
                if let screen = NSScreen.main ?? NSScreen.screens.first {
                    let vf = screen.visibleFrame
                    let x: CGFloat
                    if vf.width >= 2560 {
                        // On wide/4K displays: place in left third so center (system dialogs) is 100% clear
                        x = max(vf.origin.x + 80, (vf.width * 0.28) - (winWidth / 2.0))
                    } else if vf.width >= 1600 {
                        x = max(vf.origin.x + 40, (vf.width - winWidth) / 2.0 - 200)
                    } else {
                        x = max(vf.origin.x + 20, (vf.width - winWidth) / 2.0)
                    }
                    let y = vf.origin.y + (vf.height - winHeight) / 2.0
                    win.setFrameOrigin(NSPoint(x: round(x), y: round(y)))
                } else {
                    win.center()
                }
            }

            win.title = "SpaceTile Settings"
            win.contentViewController = hostingController
            win.isReleasedWhenClosed = false
            win.level = .normal // Standard level: system permission alerts appear above it, never hidden behind
            win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary] // Stays open and in place when switching spaces
            win.delegate = self

            if let icon = SettingsView.loadAppIcon() {
                NSApp.applicationIconImage = icon
            }

            self.window = win
            win.orderFrontRegardless()
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        if CommandLine.arguments.contains("daemon") {
            NSApp.setActivationPolicy(.accessory)
        } else {
            NSApp.terminate(nil)
        }
    }
}
