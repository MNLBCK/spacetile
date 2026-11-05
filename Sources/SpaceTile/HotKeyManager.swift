import Cocoa
import Carbon

class HotKeyManager {
    static let shared = HotKeyManager()

    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var eventHandler: EventHandlerRef?

    var onRearrangeTriggered: (() -> Void)?
    var onGUITriggered: (() -> Void)?
    var onToggleMainTriggered: (() -> Void)?
    var onSetMasterTriggered: (() -> Void)?
    var onAddMainTriggered: (() -> Void)?
    var onRemoveMainTriggered: (() -> Void)?
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
                case 1:
                    HotKeyManager.shared.onRearrangeTriggered?()
                case 2:
                    HotKeyManager.shared.onGUITriggered?()
                case 3:
                    HotKeyManager.shared.onToggleMainTriggered?()
                    HotKeyManager.shared.onSetMasterTriggered?()
                case 4:
                    HotKeyManager.shared.onToggleLockTriggered?()
                case 5:
                    HotKeyManager.shared.onToggleFloatTriggered?()
                case 6, 601, 602:
                    HotKeyManager.shared.onAddMainTriggered?()
                case 7, 701, 702:
                    HotKeyManager.shared.onRemoveMainTriggered?()
                default:
                    break
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
        // 3. Toggle Main (ID 3)
        registerSingle(config.masterShortcut, id: 3, name: "Toggle Main Window")
        // 4. Toggle Lock (ID 4)
        registerSingle(config.lockShortcut, id: 4, name: "Toggle Lock")
        // 5. Toggle Float (ID 5)
        registerSingle(config.floatShortcut, id: 5, name: "Toggle Float")

        // 6. Add to Main Windows (Hyper++, ID 6)
        registerWithLayoutFallbacks(config.addMainShortcut, baseID: 6, name: "Add to Main")

        // 7. Remove from Main Windows (Hyper+-, ID 7)
        registerWithLayoutFallbacks(config.removeMainShortcut, baseID: 7, name: "Remove from Main")

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

    private func registerWithLayoutFallbacks(_ shortcut: ShortcutConfig, baseID: UInt32, name: String) {
        let mods = KeyCodes.modifierMask(for: shortcut.modifiers)
        let key = shortcut.key.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        var keyCodesToRegister: [UInt32] = []
        if key == "+" || key == "plus" || key == "add" {
            keyCodesToRegister = [
                UInt32(kVK_ANSI_Equal),         // US layout '=' / '+'
                UInt32(kVK_ANSI_RightBracket),  // German layout '+'
                UInt32(kVK_ANSI_KeypadPlus)     // Keypad '+'
            ]
        } else if key == "-" || key == "minus" || key == "sub" {
            keyCodesToRegister = [
                UInt32(kVK_ANSI_Minus),         // US layout '-'
                UInt32(kVK_ANSI_Slash),         // German layout '-'
                UInt32(kVK_ANSI_KeypadMinus)    // Keypad '-'
            ]
        } else if let kc = KeyCodes.keyCode(for: key) {
            keyCodesToRegister = [kc]
        }

        for (idx, kc) in keyCodesToRegister.enumerated() {
            let regID = (idx == 0) ? baseID : (baseID * 100 + UInt32(idx))
            let hotKeyID = EventHotKeyID(signature: OSType(0x53505400 + regID), id: regID)
            var ref: EventHotKeyRef?
            let res = RegisterEventHotKey(kc, mods, hotKeyID, GetApplicationEventTarget(), 0, &ref)
            if res == noErr, let r = ref {
                hotKeyRefs[regID] = r
            }
        }
        print("[\u{001B}[32mSpaceTile\u{001B}[0m] '\(name)' bound to: [\(shortcut.displayString)]")
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
