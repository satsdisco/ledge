import SwiftUI
import AppKit

final class NotesModule: LedgeModule {
    static let identifier = "com.satsdisco.ledge.module.notes"
    let displayName = "Notes"
    let iconName = "square.and.pencil"
    var wantsKeyboardFocus: Bool { true }

    let store = NotesStore()
    private let env: ModuleEnvironment

    init(environment: ModuleEnvironment) {
        self.env = environment
        store.load()
    }

    var collapsedView: AnyView {
        AnyView(NotesCollapsedView(store: store))
    }

    var expandedView: AnyView {
        AnyView(NotesExpandedView(store: store))
    }

    /// Roomy: editor + archive list. Tallest of the modules.
    var preferredExpandedSize: CGSize { CGSize(width: 540, height: 360) }

    func didActivate() {
        // Catch up if the app was running across midnight.
        store.ensureTodayEntry()
    }

    func willDeactivate() {}
}
