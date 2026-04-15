import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// User-customizable global hotkey to toggle the notch.
    /// Default: ⌃⌥Space.
    static let toggleLedge = Self(
        "toggleLedge",
        default: .init(.space, modifiers: [.control, .option])
    )
}

/// Registers global hotkeys via the KeyboardShortcuts library (Carbon-backed,
/// no Accessibility permission required) and persists user customizations.
final class KeyboardShortcutCenter {
    init(expansion: NotchExpansionController) {
        KeyboardShortcuts.onKeyUp(for: .toggleLedge) { [weak expansion] in
            expansion?.toggle()
        }
        Log.app.info("Keyboard shortcuts registered")
    }
}
