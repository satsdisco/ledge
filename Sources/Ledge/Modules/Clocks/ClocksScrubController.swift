import Foundation
import Observation

/// Time-zone scrub state for the Clocks module.
///
/// When a user clicks a clock tile in the expanded panel, that tile becomes
/// the "source" — the controller starts at offset 0 (current real time) and
/// the user adjusts the offset via arrow keys. Every tile renders the
/// effective time (real time + offset) in its own zone, so the user sees at a
/// glance what 1pm in their zone translates to everywhere else.
///
/// State is intentionally ephemeral: it never persists, and resets to idle on
/// panel collapse / module switch.
@Observable
final class ClocksScrubController {
    /// The clock entry the user is scrubbing from. `nil` when idle.
    private(set) var sourceID: UUID?

    /// Offset from real time, in minutes. Always 0 when idle.
    private(set) var offsetMinutes: Int = 0

    var isScrubbing: Bool { sourceID != nil }

    /// Click handler. Same tile → exit. Different tile → switch source.
    func toggle(_ clockID: UUID) {
        if sourceID == clockID {
            exit()
        } else {
            sourceID = clockID
            offsetMinutes = 0
        }
    }

    func adjust(by minutes: Int) {
        guard isScrubbing else { return }
        offsetMinutes += minutes
    }

    func resetOffsetToNow() {
        guard isScrubbing else { return }
        offsetMinutes = 0
    }

    /// Set the offset so the source tile displays `sourceTime` (interpreted
    /// in whatever zone the caller picked — typically the source clock's
    /// own zone). Lets users type "3pm" in the source zone and have every
    /// other tile show the equivalent moment in its own zone.
    func setOffset(toDisplay sourceTime: Date, realNow: Date) {
        guard isScrubbing else { return }
        offsetMinutes = Int(sourceTime.timeIntervalSince(realNow) / 60)
    }

    func exit() {
        sourceID = nil
        offsetMinutes = 0
    }

    /// Compose the time tiles should display: real `now` plus any scrub offset.
    func effectiveTime(realNow: Date) -> Date {
        guard isScrubbing else { return realNow }
        return realNow.addingTimeInterval(TimeInterval(offsetMinutes) * 60)
    }

    /// Human-readable offset for the badge: "+2h 15m", "−45m", "now".
    var offsetDescription: String {
        guard isScrubbing else { return "now" }
        if offsetMinutes == 0 { return "now" }
        let sign = offsetMinutes > 0 ? "+" : "−"
        let absMin = abs(offsetMinutes)
        let hours = absMin / 60
        let mins = absMin % 60
        if hours == 0 { return "\(sign)\(mins)m" }
        if mins == 0 { return "\(sign)\(hours)h" }
        return "\(sign)\(hours)h \(mins)m"
    }
}
