import SwiftUI
import AppKit

// MARK: - Collapsed

struct TeleprompterCollapsedView: View {
    @Bindable var state: TeleprompterState

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: state.isPlaying ? "text.viewfinder" : "text.viewfinder")
                .font(.system(size: 10, weight: state.isPlaying ? .semibold : .regular))
                .foregroundStyle(state.isPlaying ? Palette.accent : Palette.tertiary)
            if state.isPlaying {
                Circle().fill(Palette.accent).frame(width: 4, height: 4)
            }
        }
    }
}

// MARK: - Expanded

struct TeleprompterExpandedView: View {
    @Bindable var state: TeleprompterState
    let onPersist: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            if state.text.isEmpty {
                emptyState
            } else {
                scroller
            }
            controlRow
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onKeyPress(.space) { state.isPlaying.toggle(); return .handled }
        .onKeyPress(.escape) {
            state.isPlaying = false
            state.scrollOffset = 0
            return .handled
        }
    }

    // MARK: Scroller

    private var scroller: some View {
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: false) {
                Text(state.text)
                    .font(.system(size: state.fontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.primary)
                    .lineSpacing(state.fontSize * 0.4)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .padding(.top, max(0, geo.size.height / 2 - state.scrollOffset))
                    .padding(.bottom, geo.size.height)
            }
            .disabled(state.isPlaying)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.18),
                        .init(color: .black, location: 0.82),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.viewfinder")
                .font(.system(size: 22))
                .foregroundStyle(Palette.quaternary)
            Text("No script loaded")
                .font(Typography.body)
                .foregroundStyle(Palette.secondary)
            HStack(spacing: 6) {
                Button("Paste from clipboard") { pasteFromClipboard() }
                    .buttonStyle(.plain)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Palette.highlight))
                Button("Type here") { state.text = "Type your script here…\n\nUse Space to play / pause, ESC to reset." ; onPersist() }
                    .buttonStyle(.plain)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Palette.separator))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func pasteFromClipboard() {
        if let s = NSPasteboard.general.string(forType: .string), !s.isEmpty {
            state.text = s
            state.scrollOffset = 0
            onPersist()
        }
    }

    // MARK: Controls

    private var controlRow: some View {
        HStack(spacing: 10) {
            iconButton(state.isPlaying ? "pause.fill" : "play.fill", primary: true) {
                state.isPlaying.toggle()
            }
            iconButton("backward.end.fill") {
                state.scrollOffset = 0
            }

            Divider().frame(height: 14)

            // Speed
            stepper(label: speedLabel, decrement: { state.speed = max(0.25, state.speed - 0.25); onPersist() },
                                       increment: { state.speed = min(4.0, state.speed + 0.25); onPersist() })

            // Font size
            stepper(label: "\(Int(state.fontSize))pt", decrement: { state.fontSize = max(12, state.fontSize - 2); onPersist() },
                                                      increment: { state.fontSize = min(48, state.fontSize + 2); onPersist() })

            Spacer()

            if !state.text.isEmpty {
                Button {
                    state.text = ""
                    state.scrollOffset = 0
                    onPersist()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Palette.tertiary)
                        .frame(width: 22, height: 20)
                        .background(Capsule().fill(Palette.separator))
                }
                .buttonStyle(.plain)
                .help("Clear script")
            }
        }
    }

    private var speedLabel: String {
        let v = state.speed
        return v == floor(v) ? "\(Int(v))×" : String(format: "%.2g×", v)
    }

    private func iconButton(_ name: String, primary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: primary ? 13 : 10, weight: .semibold))
                .foregroundStyle(Palette.primary)
                .frame(width: primary ? 28 : 22, height: primary ? 24 : 20)
                .background(Capsule().fill(primary ? Palette.highlight : Palette.separator))
        }
        .buttonStyle(.plain)
    }

    private func stepper(label: String, decrement: @escaping () -> Void, increment: @escaping () -> Void) -> some View {
        HStack(spacing: 3) {
            Button(action: decrement) {
                Image(systemName: "minus")
                    .font(.system(size: 8, weight: .bold))
                    .frame(width: 16, height: 16)
                    .background(Capsule().fill(Palette.separator))
            }.buttonStyle(.plain)
            Text(label)
                .font(Typography.caption)
                .monospacedDigit()
                .foregroundStyle(Palette.secondary)
                .frame(minWidth: 32)
            Button(action: increment) {
                Image(systemName: "plus")
                    .font(.system(size: 8, weight: .bold))
                    .frame(width: 16, height: 16)
                    .background(Capsule().fill(Palette.separator))
            }.buttonStyle(.plain)
        }
    }
}
