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

    /// Wider + taller than the default so analog faces have room to breathe.
    var preferredExpandedSize: CGSize { CGSize(width: 520, height: 200) }

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
