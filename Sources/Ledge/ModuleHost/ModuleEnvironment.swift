import Foundation

/// Services modules are allowed to reach for. Grows deliberately.
struct ModuleEnvironment {
    let expansion: NotchExpansionController
    /// Cross-module busy-state lookup. Calendar writes it; Clocks (and any
    /// future "would I be free at X?" surfaces) read it.
    let busy: BusyIndex
}
