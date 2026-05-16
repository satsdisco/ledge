import SwiftUI

// MARK: - Collapsed

struct TimerCollapsedView: View {
    @Bindable var state: TimerRunState

    var body: some View {
        HStack(spacing: 4) {
            switch state.mode {
            case .timer: timerCollapsed
            case .stopwatch: stopwatchCollapsed
            }
        }
    }

    @ViewBuilder
    private var timerCollapsed: some View {
        switch state.phase {
        case .running:
            // Green "go" for active timer — distinct from kinetic accent (pink)
            // and pinned-state blue. Status colors keep their own vocabulary.
            Circle()
                .fill(.green)
                .frame(width: 5, height: 5)
            Text(state.formatted)
                .font(Typography.labelMedium)
                .monospacedDigit()
                .foregroundStyle(Palette.primary)
        case .paused:
            Image(systemName: "pause.fill")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Palette.secondary)
            Text(state.formatted)
                .font(Typography.labelMedium)
                .monospacedDigit()
                .foregroundStyle(Palette.secondary)
        case .finished:
            // Yellow attention for "ding, your timer is up" — status, not accent.
            Image(systemName: "bell.fill")
                .font(.system(size: 10))
                .foregroundStyle(.yellow)
            Text("done")
                .font(Typography.labelMedium)
                .foregroundStyle(Palette.primary)
        case .idle:
            Image(systemName: "timer")
                .font(.system(size: 10))
                .foregroundStyle(Palette.quaternary)
        }
    }

    @ViewBuilder
    private var stopwatchCollapsed: some View {
        switch state.phase {
        case .running:
            Circle()
                .fill(.green)
                .frame(width: 5, height: 5)
            Text(state.formattedElapsed)
                .font(Typography.labelMedium)
                .monospacedDigit()
                .foregroundStyle(Palette.primary)
        case .paused:
            Image(systemName: "pause.fill")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Palette.secondary)
            Text(state.formattedElapsed)
                .font(Typography.labelMedium)
                .monospacedDigit()
                .foregroundStyle(Palette.secondary)
        case .idle, .finished:
            Image(systemName: "stopwatch")
                .font(.system(size: 10))
                .foregroundStyle(Palette.quaternary)
        }
    }
}

// MARK: - Expanded

struct TimerExpandedView: View {
    @Bindable var state: TimerRunState
    let onSetMode: (TimerRunState.Mode) -> Void
    let onSetPreset: (Int) -> Void
    let onStart: () -> Void
    let onPause: () -> Void
    let onReset: () -> Void

    private let presets: [(label: String, seconds: Int)] = [
        ("5m", 5 * 60),
        ("10m", 10 * 60),
        ("25m", 25 * 60),
        ("60m", 60 * 60)
    ]

    var body: some View {
        VStack(spacing: 8) {
            modeToggle
            if state.mode == .timer {
                presetsRow
            }
            Spacer(minLength: 0)
            timeDisplay
            actionsRow
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Mode toggle

    private var modeToggle: some View {
        HStack(spacing: 0) {
            modeButton(.timer,     label: "Timer",     icon: "timer")
            modeButton(.stopwatch, label: "Stopwatch", icon: "stopwatch")
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Palette.card)
        )
    }

    private func modeButton(_ mode: TimerRunState.Mode, label: String, icon: String) -> some View {
        let isActive = state.mode == mode
        return Button { onSetMode(mode) } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .medium))
                Text(label)
                    .font(Typography.labelMedium)
            }
            .foregroundStyle(isActive ? Palette.primary : Palette.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isActive ? Palette.highlight : .clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Timer presets

    private var presetsRow: some View {
        HStack(spacing: 6) {
            ForEach(presets, id: \.seconds) { preset in
                let isActive = state.lastPresetSeconds == preset.seconds
                Button {
                    onSetPreset(preset.seconds)
                } label: {
                    Text(preset.label)
                        .font(isActive ? Typography.label : Typography.labelMedium)
                        .monospacedDigit()
                        .foregroundStyle(isActive ? Palette.primary : Palette.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isActive ? Palette.highlight : .clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Display

    private var timeDisplay: some View {
        Text(displayString)
            .font(Typography.hero)
            .foregroundStyle(displayTint)
            .monospacedDigit()
            .contentTransition(.numericText())
            .animation(.easeOut(duration: 0.18), value: displayString)
    }

    private var displayString: String {
        switch state.mode {
        case .timer:    return state.formatted
        case .stopwatch: return state.formattedElapsed
        }
    }

    private var displayTint: Color {
        if state.mode == .timer && state.phase == .finished { return .yellow }
        return Palette.primary
    }

    // MARK: Actions

    private var actionsRow: some View {
        HStack(spacing: 14) {
            primaryButton
            resetButton
        }
    }

    private var primaryButton: some View {
        Button {
            switch state.phase {
            case .running:                  onPause()
            case .paused, .idle, .finished: onStart()
            }
        } label: {
            Image(systemName: state.phase == .running ? "pause.fill" : "play.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.primary)
                .frame(width: 28, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Palette.highlight)
                )
        }
        .buttonStyle(.plain)
    }

    private var resetButton: some View {
        Button(action: onReset) {
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Palette.secondary)
                .frame(width: 24, height: 22)
        }
        .buttonStyle(.plain)
    }
}
