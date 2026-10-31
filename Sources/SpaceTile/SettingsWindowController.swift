import Cocoa
import SwiftUI

class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    func show() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            NSApp.setActivationPolicy(.regular)

            if let win = self.window {
                win.orderFrontRegardless()
                win.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }

            let contentView = SettingsView()
            let hostingController = NSHostingController(rootView: contentView)

            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 840, height: 590),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            win.center()
            win.title = "SpaceTile Settings"
            win.contentViewController = hostingController
            win.isReleasedWhenClosed = false
            win.level = .floating // Stays on top when invoked
            win.delegate = self

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
        if CommandLine.arguments.contains("daemon") {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
