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

    func didActivate()
    func willDeactivate()
}

extension LedgeModule {
    var acceptsDrops: Bool { false }
    func handleDrop(_ providers: [NSItemProvider]) -> Bool { false }
    func didActivate() {}
    func willDeactivate() {}
}
