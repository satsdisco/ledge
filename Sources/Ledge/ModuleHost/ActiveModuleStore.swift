import Foundation
import Observation

/// Persists which module is currently shown in the notch. Simple UserDefaults.
@Observable
final class ActiveModuleStore {
    private let key = "ledge.activeModule"
    private let defaultID: String
    private let availableIDs: [String]

    var activeID: String {
        didSet { UserDefaults.standard.set(activeID, forKey: key) }
    }

    init(defaultID: String, availableIDs: [String]) {
        self.defaultID = defaultID
        self.availableIDs = availableIDs
        let stored = UserDefaults.standard.string(forKey: key)
        self.activeID = (stored.flatMap { availableIDs.contains($0) ? $0 : nil }) ?? defaultID
    }
}
