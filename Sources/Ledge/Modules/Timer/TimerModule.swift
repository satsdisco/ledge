import SwiftUI
import AppKit

final class TimerModule: LedgeModule {
    static let identifier = "com.satsdisco.ledge.module.timer"
    let displayName = "Timer"

    let state = TimerRunState()
    private var tickTimer: Timer?
    private var endDate: Date?

    private let presetsKey = "ledge.timer.lastPreset"

    init(environment: ModuleEnvironment) {
        let stored = UserDefaults.standard.integer(forKey: presetsKey)
        if stored > 0 {
            state.lastPresetSeconds = stored
            state.totalSeconds = stored
            state.remainingSeconds = stored
        }
    }

    var collapsedView: AnyView { AnyView(TimerCollapsedView(state: state)) }
    var expandedView: AnyView {
        AnyView(TimerExpandedView(state: state,
                                  onSetPreset: { [weak self] in self?.setPreset($0) },
                                  onStart:    { [weak self] in self?.start() },
                                  onPause:    { [weak self] in self?.pause() },
                                  onReset:    { [weak self] in self?.reset() }))
    }

    // MARK: - Intents

    func setPreset(_ seconds: Int) {
        stopTimer()
        state.lastPresetSeconds = seconds
        state.totalSeconds = seconds
        state.remainingSeconds = seconds
        state.phase = .idle
        UserDefaults.standard.set(seconds, forKey: presetsKey)
    }

    func start() {
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

    func pause() {
        guard state.phase == .running else { return }
        stopTimer()
        state.phase = .paused
    }

    func reset() {
        stopTimer()
        state.totalSeconds = state.lastPresetSeconds
        state.remainingSeconds = state.lastPresetSeconds
        state.phase = .idle
    }

    // MARK: - Ticking

    private func startTicks() {
        tickTimer?.invalidate()
        let t = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        tickTimer = t
    }

    private func stopTimer() {
        tickTimer?.invalidate()
        tickTimer = nil
        endDate = nil
    }

    private func tick() {
        guard let end = endDate else { return }
        let remaining = Int(end.timeIntervalSinceNow.rounded())
        if remaining <= 0 {
            state.remainingSeconds = 0
            state.phase = .finished
            stopTimer()
            NSSound(named: .init("Glass"))?.play()
            Log.module.info("Timer finished")
        } else {
            state.remainingSeconds = remaining
        }
    }

    func didActivate() {}
    func willDeactivate() {}
}
