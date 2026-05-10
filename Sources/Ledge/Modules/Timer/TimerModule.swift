import SwiftUI
import AppKit

final class TimerModule: LedgeModule {
    static let identifier = "com.satsdisco.ledge.module.timer"
    let displayName = "Timer"

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
    var preferredExpandedSize: CGSize { CGSize(width: 420, height: 220) }

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
        }
        UserDefaults.standard.set(newMode.rawValue, forKey: modeKey)
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
        case .timer:    startTimer()
        case .stopwatch: startStopwatch()
        }
    }

    func pause() {
        guard state.phase == .running else { return }
        switch state.mode {
        case .timer:
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
        }
        state.phase = .idle
    }

    // MARK: - Timer (countdown)

    private func startTimer() {
        switch state.phase {
        case .idle, .finished:
            state.totalSeconds = state.lastPresetSeconds
            state.remainingSeconds = state.lastPresetSeconds
            endDate = Date().addingTimeInterval(TimeInterval(state.lastPresetSeconds))
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
            state.phase = .finished
            stopTicks()
            NSSound(named: .init("Glass"))?.play()
            Log.module.info("Timer finished")
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
            case .timer:    self.tickTimer_()
            case .stopwatch: self.tickStopwatch()
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
