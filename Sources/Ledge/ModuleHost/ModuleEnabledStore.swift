import Foundation
import Observation

/// Persists which modules are enabled. Disabled modules are hidden from
/// the segmented header, the right-click menu, and the active selection.
@Observable
final class ModuleEnabledStore {
    private let key = "ledge.enabledModules"
    private(set) var enabledIDs: Set<String>

    /// Notified when the enabled set changes so UI + PanelManager can react.
    var onChange: (() -> Void)?

    init(allIDs: [String]) {
        if let stored = UserDefaults.standard.array(forKey: key) as? [String] {
            self.enabledIDs = Set(stored).intersection(allIDs)
        } else {
            // First launch: all modules enabled.
            self.enabledIDs = Set(allIDs)
        }
    }

    func isEnabled(_ id: String) -> Bool { enabledIDs.contains(id) }

    func setEnabled(_ id: String, _ enabled: Bool) {
        if enabled { enabledIDs.insert(id) } else { enabledIDs.remove(id) }
        UserDefaults.standard.set(Array(enabledIDs), forKey: key)
        onChange?()
    }
}
