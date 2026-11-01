import Cocoa
import Carbon

class HotKeyManager {
    static let shared = HotKeyManager()

    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var eventHandler: EventHandlerRef?

    var onRearrangeTriggered: (() -> Void)?
    var onGUITriggered: (() -> Void)?
    var onSetMasterTriggered: (() -> Void)?
    var onToggleLockTriggered: (() -> Void)?
    var onToggleFloatTriggered: (() -> Void)?

    func register(config: Config) -> Bool {
        unregister()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handler: EventHandlerUPP = { (_, theEvent, _) -> OSStatus in
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
                switch hotKeyID.id {
                case 1: HotKeyManager.shared.onRearrangeTriggered?()
                case 2: HotKeyManager.shared.onGUITriggered?()
                case 3: HotKeyManager.shared.onSetMasterTriggered?()
                case 4: HotKeyManager.shared.onToggleLockTriggered?()
                case 5: HotKeyManager.shared.onToggleFloatTriggered?()
                default: break
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
            print("[\u{001B}[31mERROR\u{001B}[0m] InstallEventHandler failed: \(installStatus)")
            return false
        }

        // 1. Rearrange (ID 1)
        registerSingle(config.shortcut, id: 1, name: "Rearrange")
        // 2. GUI (ID 2)
        registerSingle(config.guiShortcut, id: 2, name: "Settings GUI")
        // 3. Set Master (ID 3)
        registerSingle(config.masterShortcut, id: 3, name: "Set as Master")
        // 4. Toggle Lock (ID 4)
        registerSingle(config.lockShortcut, id: 4, name: "Toggle Lock")
        // 5. Toggle Float (ID 5)
        registerSingle(config.floatShortcut, id: 5, name: "Toggle Float")

        return true
    }

    private func registerSingle(_ shortcut: ShortcutConfig, id: UInt32, name: String) {
        guard let key = KeyCodes.keyCode(for: shortcut.key) else {
            print("[\u{001B}[33mWARN\u{001B}[0m] Unknown key '\(shortcut.key)' for '\(name)'")
            return
        }
        let mods = KeyCodes.modifierMask(for: shortcut.modifiers)
        let hotKeyID = EventHotKeyID(signature: OSType(0x53505400 + id), id: id)
        var ref: EventHotKeyRef?
        let res = RegisterEventHotKey(key, mods, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        if res == noErr, let r = ref {
            hotKeyRefs[id] = r
            print("[\u{001B}[32mSpaceTile\u{001B}[0m] '\(name)' bound to: [\(shortcut.displayString)]")
        } else {
            print("[\u{001B}[31mERROR\u{001B}[0m] Could not bind '\(name)': error \(res)")
        }
    }

    func unregister() {
        for (_, ref) in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()

        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }

    deinit {
        unregister()
    }
}
