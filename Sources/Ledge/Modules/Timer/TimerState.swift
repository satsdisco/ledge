import Foundation
import Observation

@Observable
final class TimerRunState {
    enum Phase: Equatable { case idle, running, paused, finished }
    enum Mode: String, Codable, Equatable { case timer, stopwatch, pomodoro }
    /// Which leg of a pomodoro cycle we're on. Ignored when mode != .pomodoro.
    enum PomodoroPhase: String, Codable { case work, shortBreak, longBreak }

    var mode: Mode = .timer
    var phase: Phase = .idle

    // MARK: Pomodoro state

    var pomodoroPhase: PomodoroPhase = .work
    /// How many completed work sessions in the current streak. Resets when
    /// the user manually exits pomodoro or after a long break.
    var pomodoroCompletedSessions: Int = 0
    /// Lengths in seconds — exposed so we can tweak later from Settings.
    var pomodoroWorkSeconds: Int = 25 * 60
    var pomodoroShortBreakSeconds: Int = 5 * 60
    var pomodoroLongBreakSeconds: Int = 15 * 60
    /// After how many work sessions to take a long break instead of short.
    var pomodoroLongBreakInterval: Int = 4

    // MARK: Timer (countdown) state

    /// Total seconds configured for the current cycle (for reset/progress).
    var totalSeconds: Int = 25 * 60

    /// Computed remaining seconds (ticks every 0.5s while running).
    var remainingSeconds: Int = 25 * 60

    /// Last preset user chose (persisted).
    var lastPresetSeconds: Int = 25 * 60

    // MARK: Stopwatch (count-up) state

    /// Live elapsed time for the stopwatch. Recomputed each tick from the
    /// module's accumulated + (now - startDate), so pausing and resuming
    /// stays accurate to the second without drift.
    var elapsedSeconds: Int = 0

    // MARK: - Display

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

    var formattedElapsed: String {
        let s = max(0, elapsedSeconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        let r = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, r) }
        return String(format: "%02d:%02d", m, r)
    }
}
