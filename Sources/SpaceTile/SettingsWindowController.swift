import Cocoa
import SwiftUI

class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    func show(initialTab: String? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            NSApp.setActivationPolicy(.regular)

            if let win = self.window {
                win.orderFrontRegardless()
                win.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }

            let contentView = SettingsView(tabName: initialTab)
            let hostingController = NSHostingController(rootView: contentView)

            let winWidth: CGFloat = 880
            let winHeight: CGFloat = 620

            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: winWidth, height: winHeight),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )

            // Center strictly in the geometric middle of the visible work area
            // (avoiding top macOS system alerts and menu bar dialogs)
            if let screen = NSScreen.main ?? NSScreen.screens.first {
                let vf = screen.visibleFrame
                let x = vf.origin.x + (vf.width - winWidth) / 2.0
                let y = vf.origin.y + (vf.height - winHeight) / 2.0
                win.setFrameOrigin(NSPoint(x: round(x), y: round(y)))
            } else {
                win.center()
            }

            win.title = "SpaceTile Settings"
            win.contentViewController = hostingController
            win.isReleasedWhenClosed = false
            win.level = .floating // Stays on top when invoked
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
