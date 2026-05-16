import SwiftUI
import Observation

@Observable
final class TeleprompterState {
    var text: String = ""
    var fontSize: CGFloat = 22
    /// Lines per second the script scrolls at.
    var speed: Double = 1.0
    var isPlaying: Bool = false
    /// Vertical scroll offset in points. Driven by the tick timer when
    /// `isPlaying` is true.
    var scrollOffset: CGFloat = 0
    /// Mirror horizontally for teleprompter rigs (beam splitter reads text
    /// reversed). Toggle from the controls row.
    var mirrored: Bool = false
}

final class TeleprompterModule: LedgeModule {
    static let identifier = "com.satsdisco.ledge.module.teleprompter"
    let displayName = "Teleprompter"
    let iconName = "text.viewfinder"

    let state = TeleprompterState()
    private let store: ModuleStore<TeleprompterPersisted>
    private var tickTimer: Timer?

    init(environment: ModuleEnvironment) {
        self.store = ModuleStore<TeleprompterPersisted>(
            moduleIdentifier: TeleprompterModule.identifier,
            defaultValue: TeleprompterPersisted()
        )
        let saved = store.load()
        state.text = saved.text
        state.fontSize = saved.fontSize
        state.speed = saved.speed
        state.mirrored = saved.mirrored
        startTicking()
    }

    var collapsedView: AnyView { AnyView(TeleprompterCollapsedView(state: state)) }
    var expandedView: AnyView {
        AnyView(TeleprompterExpandedView(state: state, onPersist: { [weak self] in self?.persist() }))
    }

    /// Taller than default — the whole point is having room for a few lines
    /// of scrollable text plus a controls row.
    var preferredExpandedSize: CGSize { CGSize(width: 540, height: 280) }

    /// Need keyboard focus so space-to-toggle / arrow-to-nudge work without
    /// clicking the panel first.
    var wantsKeyboardFocus: Bool { true }

    private func startTicking() {
        // 60-ish updates per second. The view advances `scrollOffset` by
        // (fontSize * lineHeightFactor * speed / fps) on each tick.
        let t = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        tickTimer = t
    }

    private func tick() {
        guard state.isPlaying else { return }
        // 28pt per line ~ font size × line spacing; advance one line per
        // (1/speed) seconds.
        let perTick = state.fontSize * 1.4 * state.speed / 30.0
        state.scrollOffset += perTick
    }

    private func persist() {
        store.save(TeleprompterPersisted(
            text: state.text,
            fontSize: state.fontSize,
            speed: state.speed,
            mirrored: state.mirrored
        ))
    }

    func didActivate() {}
    func willDeactivate() { persist() }
}

/// JSON-encoded persistence shape. State that's intentionally not persisted:
/// `isPlaying` and `scrollOffset` — both should reset each time the panel
/// reopens.
private struct TeleprompterPersisted: Codable {
    var text: String = ""
    var fontSize: CGFloat = 22
    var speed: Double = 1.0
    var mirrored: Bool = false
}
