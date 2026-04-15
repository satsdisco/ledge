import SwiftUI

// MARK: - Collapsed

struct TimerCollapsedView: View {
    @Bindable var state: TimerRunState

    var body: some View {
        HStack(spacing: 4) {
            switch state.phase {
            case .running:
                Circle()
                    .fill(.green)
                    .frame(width: 5, height: 5)
                Text(state.formatted)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))
            case .paused:
                Image(systemName: "pause.fill")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                Text(state.formatted)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
            case .finished:
                Image(systemName: "bell.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.yellow)
                Text("done")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            case .idle:
                Image(systemName: "timer")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
    }
}

// MARK: - Expanded

struct TimerExpandedView: View {
    @Bindable var state: TimerRunState
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
            presetsRow
            timeDisplay
            actionsRow
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var presetsRow: some View {
        HStack(spacing: 6) {
            ForEach(presets, id: \.seconds) { preset in
                let isActive = state.lastPresetSeconds == preset.seconds
                Button {
                    onSetPreset(preset.seconds)
                } label: {
                    Text(preset.label)
                        .font(.system(size: 10, weight: isActive ? .semibold : .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(isActive ? 0.95 : 0.55))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isActive ? .white.opacity(0.10) : .clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var timeDisplay: some View {
        Text(state.formatted)
            .font(.system(size: 28, weight: .semibold, design: .monospaced))
            .foregroundStyle(state.phase == .finished ? .yellow : .white.opacity(0.95))
            .monospacedDigit()
    }

    private var actionsRow: some View {
        HStack(spacing: 14) {
            primaryButton
            resetButton
        }
    }

    private var primaryButton: some View {
        Button {
            switch state.phase {
            case .running:                 onPause()
            case .paused, .idle, .finished: onStart()
            }
        } label: {
            Image(systemName: state.phase == .running ? "pause.fill" : "play.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.95))
                .frame(width: 28, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.white.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
    }

    private var resetButton: some View {
        Button(action: onReset) {
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 24, height: 22)
        }
        .buttonStyle(.plain)
    }
}
