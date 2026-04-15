import Foundation
import Observation

/// Drives the panel's collapsed <-> expanded state. Single instance shared
/// across all panels in Phase 2 (per-panel controllers are a Phase 3 concern).
///
/// Hover-to-expand uses 120ms debounce on enter, 350ms on exit.
/// Drag-entered expands immediately, no debounce.
@Observable
final class NotchExpansionController {
    enum Phase: Equatable { case collapsed, expanded }

    private(set) var phase: Phase = .collapsed

    /// Notified on every committed phase change. Set by PanelManager to drive
    /// the actual NSPanel frame animation.
    var onPhaseChange: ((Phase) -> Void)?

    private let enterDelay: TimeInterval
    private let exitDelay: TimeInterval
    private var pending: DispatchWorkItem?

    init(enterDelay: TimeInterval = 0.12, exitDelay: TimeInterval = 0.35) {
        self.enterDelay = enterDelay
        self.exitDelay = exitDelay
    }

    // MARK: - Hover

    func hoverEntered() {
        scheduleTransition(to: .expanded, after: enterDelay)
    }

    func hoverExited() {
        scheduleTransition(to: .collapsed, after: exitDelay)
    }

    // MARK: - Drag

    func dragEntered() {
        pending?.cancel()
        commit(.expanded)
    }

    func dragExited() {
        scheduleTransition(to: .collapsed, after: exitDelay)
    }

    // MARK: - Explicit

    func expand()   { pending?.cancel(); commit(.expanded) }
    func collapse() { pending?.cancel(); commit(.collapsed) }
    func toggle()   { phase == .collapsed ? expand() : collapse() }

    // MARK: - Private

    private func scheduleTransition(to target: Phase, after delay: TimeInterval) {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.commit(target)
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func commit(_ next: Phase) {
        guard phase != next else { return }
        phase = next
        onPhaseChange?(next)
        Log.window.debug("Expansion -> \(next == .expanded ? "expanded" : "collapsed", privacy: .public)")
    }
}
