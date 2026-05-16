import SwiftUI
import AppKit

final class TimerModule: LedgeModule {
    static let identifier = "com.satsdisco.ledge.module.timer"
    let displayName = "Timer"
    let iconName = "timer"

    let state = TimerRunState()
    private var tickTimer: Timer?

    // Countdown bookkeeping
    private var endDate: Date?

    // Stopwatch bookkeeping — recompute elapsed each tick from these so
    // pausing and resuming stays accurate to the second.
    private var swStartDate: Date?
    private var swAccumulated: TimeInterval = 0

    private let presetsKey = "ledge.timer.lastPreset"
    private let modeKey = "ledge.timer.mode"

    init(environment: ModuleEnvironment) {
        let stored = UserDefaults.standard.integer(forKey: presetsKey)
        if stored > 0 {
            state.lastPresetSeconds = stored
            state.totalSeconds = stored
            state.remainingSeconds = stored
        }
        if let raw = UserDefaults.standard.string(forKey: modeKey),
           let mode = TimerRunState.Mode(rawValue: raw) {
            state.mode = mode
        }
    }

    var collapsedView: AnyView { AnyView(TimerCollapsedView(state: state)) }
    var expandedView: AnyView {
        AnyView(TimerExpandedView(
            state: state,
            onSetMode: { [weak self] in self?.setMode($0) },
            onSetPreset: { [weak self] in self?.setPreset($0) },
            onStart:    { [weak self] in self?.start() },
            onPause:    { [weak self] in self?.pause() },
            onReset:    { [weak self] in self?.reset() }
        ))
    }

    /// Bumped from 180 to accommodate the mode toggle row added on top of
    /// the original (presets + countdown + actions) layout. Without the
    /// extra height, content overflows into the notch tongue at the top.
    var preferredExpandedSize: CGSize { CGSize(width: 540, height: 240) }

    // MARK: - Mode

    func setMode(_ newMode: TimerRunState.Mode) {
        guard state.mode != newMode else { return }
        // Switching mode resets whatever is running so we never have both
        // ticking at once or stale display values.
        stopTicks()
        state.mode = newMode
        state.phase = .idle
        switch newMode {
        case .timer:
            state.totalSeconds = state.lastPresetSeconds
            state.remainingSeconds = state.lastPresetSeconds
        case .stopwatch:
            state.elapsedSeconds = 0
            swStartDate = nil
            swAccumulated = 0
        case .pomodoro:
            state.pomodoroPhase = .work
            state.pomodoroCompletedSessions = 0
            state.totalSeconds = state.pomodoroWorkSeconds
            state.remainingSeconds = state.pomodoroWorkSeconds
        }
        UserDefaults.standard.set(newMode.rawValue, forKey: modeKey)
    }

    /// Length in seconds for the upcoming pomodoro phase.
    private func durationForCurrentPomodoroPhase() -> Int {
        switch state.pomodoroPhase {
        case .work:       return state.pomodoroWorkSeconds
        case .shortBreak: return state.pomodoroShortBreakSeconds
        case .longBreak:  return state.pomodoroLongBreakSeconds
        }
    }

    /// On finish: tick the cycle forward. Work → short or long break →
    /// back to work. Long break every Nth session.
    private func advancePomodoroPhase() {
        switch state.pomodoroPhase {
        case .work:
            state.pomodoroCompletedSessions += 1
            state.pomodoroPhase =
                (state.pomodoroCompletedSessions % state.pomodoroLongBreakInterval == 0)
                ? .longBreak : .shortBreak
        case .shortBreak, .longBreak:
            state.pomodoroPhase = .work
        }
        let duration = durationForCurrentPomodoroPhase()
        state.totalSeconds = duration
        state.remainingSeconds = duration
        state.phase = .idle
    }

    // MARK: - Intents (mode-aware)

    func setPreset(_ seconds: Int) {
        // Only meaningful for timer mode; harmless to call in stopwatch.
        stopTicks()
        state.lastPresetSeconds = seconds
        state.totalSeconds = seconds
        state.remainingSeconds = seconds
        state.phase = .idle
        UserDefaults.standard.set(seconds, forKey: presetsKey)
    }

    func start() {
        switch state.mode {
        case .timer, .pomodoro: startTimer()
        case .stopwatch:        startStopwatch()
        }
    }

    func pause() {
        guard state.phase == .running else { return }
        switch state.mode {
        case .timer, .pomodoro:
            stopTicks()
        case .stopwatch:
            if let started = swStartDate {
                swAccumulated += Date().timeIntervalSince(started)
                swStartDate = nil
                state.elapsedSeconds = Int(swAccumulated)
            }
            stopTicks()
        }
        state.phase = .paused
    }

    func reset() {
        stopTicks()
        switch state.mode {
        case .timer:
            state.totalSeconds = state.lastPresetSeconds
            state.remainingSeconds = state.lastPresetSeconds
        case .stopwatch:
            swStartDate = nil
            swAccumulated = 0
            state.elapsedSeconds = 0
        case .pomodoro:
            state.pomodoroPhase = .work
            state.pomodoroCompletedSessions = 0
            state.totalSeconds = state.pomodoroWorkSeconds
            state.remainingSeconds = state.pomodoroWorkSeconds
        }
        state.phase = .idle
    }

    // MARK: - Timer (countdown)

    private func startTimer() {
        // For pomodoro, the seed duration comes from the current phase
        // (work / short break / long break) rather than the user's manual
        // preset. Otherwise, behaves identically to the countdown path.
        let seed: Int = {
            switch state.mode {
            case .pomodoro: return durationForCurrentPomodoroPhase()
            default:        return state.lastPresetSeconds
            }
        }()
        switch state.phase {
        case .idle, .finished:
            state.totalSeconds = seed
            state.remainingSeconds = seed
            endDate = Date().addingTimeInterval(TimeInterval(seed))
        case .paused:
            endDate = Date().addingTimeInterval(TimeInterval(state.remainingSeconds))
        case .running:
            return
        }
        state.phase = .running
        startTicks()
        Log.module.info("Timer started: \(self.state.remainingSeconds)s")
    }

    private func tickTimer_() {
        guard let end = endDate else { return }
        let remaining = Int(end.timeIntervalSinceNow.rounded())
        if remaining <= 0 {
            state.remainingSeconds = 0
            stopTicks()
            NSSound(named: .init("Glass"))?.play()
            if state.mode == .pomodoro {
                advancePomodoroPhase()
                Log.module.info("Pomodoro phase \(self.state.pomodoroPhase.rawValue, privacy: .public) complete; cycle \(self.state.pomodoroCompletedSessions)")
                // Auto-roll into the next phase so the user doesn't have to
                // hit play again between work and break.
                startTimer()
            } else {
                state.phase = .finished
                Log.module.info("Timer finished")
            }
        } else {
            state.remainingSeconds = remaining
        }
    }

    // MARK: - Stopwatch (count-up)

    private func startStopwatch() {
        switch state.phase {
        case .idle, .finished:
            swStartDate = Date()
            swAccumulated = 0
            state.elapsedSeconds = 0
        case .paused:
            swStartDate = Date()
        case .running:
            return
        }
        state.phase = .running
        startTicks()
        Log.module.info("Stopwatch started")
    }

    private func tickStopwatch() {
        guard let started = swStartDate else { return }
        let total = swAccumulated + Date().timeIntervalSince(started)
        state.elapsedSeconds = Int(total)
    }

    // MARK: - Shared ticking

    private func startTicks() {
        tickTimer?.invalidate()
        let t = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            switch self.state.mode {
            case .timer, .pomodoro: self.tickTimer_()
            case .stopwatch:        self.tickStopwatch()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        tickTimer = t
    }

    private func stopTicks() {
        tickTimer?.invalidate()
        tickTimer = nil
        endDate = nil
    }

    func didActivate() {}
    func willDeactivate() {}
}
