import Foundation
import Carbon.HIToolbox

/// Registers a global Carbon hotkey (no Accessibility permission required).
/// Hard-coded to ⌃⌥Space for v0.4. Customization UI is a later-phase concern.
final class KeyboardShortcutCenter {
    private let hotKey: GlobalHotKey

    init(expansion: NotchExpansionController) {
        hotKey = GlobalHotKey(
            keyCode: UInt32(kVK_Space),
            modifiers: UInt32(controlKey | optionKey)
        ) { [weak expansion] in
            expansion?.toggle()
        }
        Log.app.info("Keyboard shortcut registered: ⌃⌥Space")
    }
}

/// Thin wrapper around Carbon's RegisterEventHotKey. Lives for app lifetime.
final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let callback: () -> Void
    private let hotKeyID: EventHotKeyID

    init(keyCode: UInt32, modifiers: UInt32, callback: @escaping () -> Void) {
        self.callback = callback
        // Signature 'LEDG' + id 1 makes this hotkey uniquely identifiable in our handler.
        self.hotKeyID = EventHotKeyID(signature: OSType(0x4C454447), id: 1)
        install(keyCode: keyCode, modifiers: modifiers)
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }

    private func install(keyCode: UInt32, modifiers: UInt32) {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let context = Unmanaged.passUnretained(self).toOpaque()

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }
                var firedID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &firedID
                )
                let instance = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
                if firedID.id == instance.hotKeyID.id {
                    DispatchQueue.main.async { instance.callback() }
                }
                return noErr
            },
            1,
            &eventType,
            context,
            &handlerRef
        )
        guard status == noErr else {
            Log.app.error("InstallEventHandler failed: \(status)")
            return
        }

        let regStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if regStatus != noErr {
            Log.app.error("RegisterEventHotKey failed: \(regStatus)")
        }
    }
}
