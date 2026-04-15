import Foundation
import Observation

@Observable
final class TimerRunState {
    enum Phase: Equatable { case idle, running, paused, finished }

    var phase: Phase = .idle

    /// Total seconds configured for the current cycle (for reset/progress).
    var totalSeconds: Int = 25 * 60

    /// Computed remaining seconds (ticks every 0.5s while running).
    var remainingSeconds: Int = 25 * 60

    /// Last preset user chose (persisted).
    var lastPresetSeconds: Int = 25 * 60

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return 1.0 - Double(remainingSeconds) / Double(totalSeconds)
    }

    var formatted: String {
        let s = max(0, remainingSeconds)
        let m = s / 60
        let r = s % 60
        return String(format: "%02d:%02d", m, r)
    }
}
