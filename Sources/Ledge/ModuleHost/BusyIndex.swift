import Foundation
import Observation

/// Half-open `[start, end)` interval marking a window during which the user
/// is committed to something. Kept calendar-agnostic so other sources (DND,
/// Focus modes, manual blocks) could feed it later without API churn.
struct BusyInterval: Equatable, Hashable {
    let start: Date
    let end: Date

    func contains(_ moment: Date) -> Bool {
        moment >= start && moment < end
    }
}

/// Shared busy-state lookup. The Calendar module is the only writer today
/// (it publishes today's events here on every refresh); other modules read
/// it via the environment without ever touching EventKit themselves. All
/// reads/writes happen on the main thread in practice (Calendar.refresh is
/// @MainActor, SwiftUI bodies run on main) so we don't isolate it.
@Observable
final class BusyIndex {
    /// Sorted, deduplicated busy windows. Replace wholesale on refresh
    /// rather than mutating in place — keeps writers simple.
    var intervals: [BusyInterval] = []

    func isBusy(at moment: Date) -> Bool {
        intervals.contains(where: { $0.contains(moment) })
    }
}
