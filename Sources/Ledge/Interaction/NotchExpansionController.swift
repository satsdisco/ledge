import Foundation
import Observation

/// Drives the panel's collapsed <-> expanded state.
///
/// Hysteresis:
/// - Hover enter: 120ms debounce.
/// - Hover exit:  350ms debounce + a minimum-expanded-hold so rapid pointer
///   drift near the boundary doesn't thrash the panel.
/// - Drag enter: immediate (drop targets must be responsive).
@Observable
final class NotchExpansionController {
    enum Phase: Equatable { case collapsed, expanded }

    private(set) var phase: Phase = .collapsed

    /// Notified on every committed phase change. Set by PanelManager to drive
    /// the actual NSPanel frame animation.
    var onPhaseChange: ((Phase) -> Void)?

    private let enterDelay: TimeInterval
    private let exitDelay: TimeInterval
    private let minExpandedHold: TimeInterval
    private var pending: DispatchWorkItem?
    private var expandedAt: Date?

    init(
        enterDelay: TimeInterval = 0.12,
        exitDelay: TimeInterval = 0.35,
        minExpandedHold: TimeInterval = 0.40
    ) {
        self.enterDelay = enterDelay
        self.exitDelay = exitDelay
        self.minExpandedHold = minExpandedHold
    }

    // MARK: - Hover

    func hoverEntered() {
        scheduleTransition(to: .expanded, after: enterDelay)
    }

    func hoverExited() {
        let held = phase == .expanded
            ? max(0, minExpandedHold - Date().timeIntervalSince(expandedAt ?? .distantPast))
            : 0
        scheduleTransition(to: .collapsed, after: exitDelay + held)
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
        if next == .expanded { expandedAt = Date() }
        onPhaseChange?(next)
        Log.window.debug("Expansion -> \(next == .expanded ? "expanded" : "collapsed", privacy: .public)")
    }
}
