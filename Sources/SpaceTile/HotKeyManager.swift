import Cocoa
import Carbon

class HotKeyManager {
    static let shared = HotKeyManager()

    private var optimizeHotKeyRef: EventHotKeyRef?
    private var guiHotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    var onHotKeyTriggered: (() -> Void)?
    var onGUITriggered: (() -> Void)?

    func register(config: Config) -> Bool {
        unregister()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handler: EventHandlerUPP = { (_, theEvent, userData) -> OSStatus in
            guard let theEvent else { return noErr }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                theEvent,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            if status == noErr {
                if hotKeyID.id == 1 {
                    HotKeyManager.shared.onHotKeyTriggered?()
                } else if hotKeyID.id == 2 {
                    HotKeyManager.shared.onGUITriggered?()
                }
            }
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

        // 1. Register Optimize Hotkey (ID 1)
        if let key1 = KeyCodes.keyCode(for: config.shortcut.key) {
            let mod1 = KeyCodes.modifierMask(for: config.shortcut.modifiers)
            let id1 = EventHotKeyID(signature: OSType(0x53505431), id: 1)
            let res = RegisterEventHotKey(key1, mod1, id1, GetApplicationEventTarget(), 0, &optimizeHotKeyRef)
            if res == noErr {
                print("[\u{001B}[32mSpaceTile\u{001B}[0m] Shortcut 'Optimieren': [\(config.shortcut.displayString)]")
            }
        }

        // 2. Register GUI Settings Hotkey (ID 2)
        if let key2 = KeyCodes.keyCode(for: config.guiShortcut.key) {
            let mod2 = KeyCodes.modifierMask(for: config.guiShortcut.modifiers)
            let id2 = EventHotKeyID(signature: OSType(0x53505432), id: 2)
            let res = RegisterEventHotKey(key2, mod2, id2, GetApplicationEventTarget(), 0, &guiHotKeyRef)
            if res == noErr {
                print("[\u{001B}[32mSpaceTile\u{001B}[0m] Shortcut 'Einstellungen (GUI)': [\(config.guiShortcut.displayString)]")
            }
        }

        return true
    }

    func unregister() {
        if let ref = optimizeHotKeyRef {
            UnregisterEventHotKey(ref)
            optimizeHotKeyRef = nil
        }
        if let ref = guiHotKeyRef {
            UnregisterEventHotKey(ref)
            guiHotKeyRef = nil
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
