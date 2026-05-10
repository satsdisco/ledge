import SwiftUI

/// Contract every notch module conforms to. Modules never touch the window
/// layer; they declare intent through this protocol and receive a
/// `ModuleEnvironment` with the services they're allowed to use.
protocol LedgeModule: AnyObject {
    static var identifier: String { get }
    var displayName: String { get }

    var collapsedView: AnyView { get }
    var expandedView: AnyView { get }

    var acceptsDrops: Bool { get }
    func handleDrop(_ providers: [NSItemProvider]) -> Bool

    /// Preferred panel size when this module is active and the notch is expanded.
    /// Modules with content-heavy expanded views (Clocks, Shelf grid) ask for more room.
    var preferredExpandedSize: CGSize { get }

    /// Modules that need text input or keyboard navigation (Clipboard) opt in.
    /// When true, the panel is allowed to become key while this module is
    /// active. Defaults to false so ambient modules never steal focus.
    var wantsKeyboardFocus: Bool { get }

    func didActivate()
    func willDeactivate()
}

extension LedgeModule {
    var acceptsDrops: Bool { false }
    func handleDrop(_ providers: [NSItemProvider]) -> Bool { false }
    var preferredExpandedSize: CGSize { CGSize(width: 420, height: 140) }
    var wantsKeyboardFocus: Bool { false }
    func didActivate() {}
    func willDeactivate() {}
}
