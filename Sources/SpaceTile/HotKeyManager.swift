import Cocoa
import Carbon

class HotKeyManager {
    static let shared = HotKeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    var onHotKeyTriggered: (() -> Void)?

    func register(config: Config) -> Bool {
        unregister()

        guard let keyCode = KeyCodes.keyCode(for: config.shortcut.key) else {
            print("[\u{001B}[31mFEHLER\u{001B}[0m] Unbekannte Taste im Shortcut: '\(config.shortcut.key)'")
            return false
        }

        let modifiers = KeyCodes.modifierMask(for: config.shortcut.modifiers)

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handler: EventHandlerUPP = { (_, theEvent, userData) -> OSStatus in
            HotKeyManager.shared.onHotKeyTriggered?()
            return noErr
        }

        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            nil,
            &eventHandler
        )

        guard installStatus == noErr else {
            print("[\u{001B}[31mFEHLER\u{001B}[0m] InstallEventHandler fehlgeschlagen: \(installStatus)")
            return false
        }

        let hotKeyID = EventHotKeyID(signature: OSType(0x5350544C), id: 1) // 'SPTL'
        let regStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard regStatus == noErr else {
            print("[\u{001B}[31mFEHLER\u{001B}[0m] RegisterEventHotKey fehlgeschlagen: \(regStatus)")
            return false
        }

        let modNames = config.shortcut.modifiers.map { $0.capitalized }.joined(separator: " + ")
        print("[\u{001B}[32mSpaceTile\u{001B}[0m] Globaler Shortcut aktiv: [\(modNames) + \(config.shortcut.key.uppercased())]")
        return true
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }

    deinit {
        unregister()
    }
}
