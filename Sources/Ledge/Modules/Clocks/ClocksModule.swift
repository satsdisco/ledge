import SwiftUI
import Observation

@Observable
final class ClocksTicker {
    var now: Date = Date()
}

final class ClocksModule: LedgeModule {
    static let identifier = "com.satsdisco.ledge.module.clocks"
    let displayName = "Clocks"

    let store = ClocksStore()
    let ticker = ClocksTicker()
    private var tickTimer: Timer?

    init(environment: ModuleEnvironment) {
        store.load()
        startTicking()
    }

    var collapsedView: AnyView {
        AnyView(ClocksCollapsedView(store: store, ticker: ticker))
    }

    var expandedView: AnyView {
        AnyView(ClocksExpandedView(store: store, ticker: ticker))
    }

    /// Grows vertically when the user has more than 4 clocks (which then
    /// wrap to a second row of tiles). PanelManager re-asks for this on
    /// active-module change and clock-list change (wired via store.onChange
    /// → panels.relayoutIfNeeded in RootCoordinator).
    var preferredExpandedSize: CGSize {
        let twoRows = store.entries.count > 4
        return CGSize(width: 520, height: twoRows ? 340 : 220)
    }

    private func startTicking() {
        let t = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.ticker.now = Date()
        }
        RunLoop.main.add(t, forMode: .common)
        tickTimer = t
    }

    func didActivate()    {}
    func willDeactivate() {}
}
