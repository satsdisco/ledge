import SwiftUI
import Observation

@Observable
final class ClocksTicker {
    var now: Date = Date()
}

final class ClocksModule: LedgeModule {
    static let identifier = "com.satsdisco.ledge.module.clocks"
    let displayName = "Clocks"
    let iconName = "globe"

    let store = ClocksStore()
    let ticker = ClocksTicker()
    let scrub = ClocksScrubController()
    private var tickTimer: Timer?

    init(environment: ModuleEnvironment) {
        store.load()
        startTicking()
    }

    var collapsedView: AnyView {
        AnyView(ClocksCollapsedView(store: store, ticker: ticker))
    }

    var expandedView: AnyView {
        AnyView(ClocksExpandedView(store: store, ticker: ticker, scrub: scrub))
    }

    /// Opt in to keyboard focus so arrow keys can drive scrub mode. The
    /// expanded view returns `.ignored` for keys when no scrub is active,
    /// so this doesn't intercept anything else.
    var wantsKeyboardFocus: Bool { true }

    /// Grows vertically when the user has more than 4 clocks (which then
    /// wrap to a second row of tiles). PanelManager re-asks for this on
    /// active-module change and clock-list change (wired via store.onChange
    /// → panels.relayoutIfNeeded in RootCoordinator).
    var preferredExpandedSize: CGSize {
        let twoRows = store.entries.count > 4
        return CGSize(width: 540, height: twoRows ? 360 : 240)
    }

    private func startTicking() {
        let t = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.ticker.now = Date()
        }
        RunLoop.main.add(t, forMode: .common)
        tickTimer = t
    }

    func didActivate()    {}
    func willDeactivate() {
        // Drop any in-flight scrub when the user switches away.
        scrub.exit()
    }
}
