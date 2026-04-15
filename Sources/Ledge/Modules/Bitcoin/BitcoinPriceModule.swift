import SwiftUI
import Observation
import Foundation

@Observable
final class BitcoinPriceState {
    var snapshot: BitcoinSnapshot?
    var isFetching: Bool = false
    var lastError: String?
}

final class BitcoinPriceModule: LedgeModule {
    static let identifier = "com.satsdisco.ledge.module.bitcoin"
    let displayName = "Bitcoin"

    let state = BitcoinPriceState()
    private let service = BitcoinPriceService()
    private let store: ModuleStore<BitcoinSnapshot?>
    private var pollTimer: Timer?

    init(environment: ModuleEnvironment) {
        self.store = ModuleStore<BitcoinSnapshot?>(
            moduleIdentifier: BitcoinPriceModule.identifier,
            defaultValue: nil
        )
        // Show last cached snapshot immediately so the panel isn't empty on launch.
        state.snapshot = store.load()
        startPolling()
    }

    var collapsedView: AnyView { AnyView(BitcoinCollapsedView(state: state)) }
    var expandedView: AnyView { AnyView(BitcoinExpandedView(state: state)) }

    /// Slightly taller than default so the sparkline has room to breathe.
    var preferredExpandedSize: CGSize { CGSize(width: 440, height: 170) }

    // MARK: - Polling

    private func startPolling() {
        refresh()
        let t = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.main.add(t, forMode: .common)
        pollTimer = t
    }

    private func refresh() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.state.isFetching = true
            let snap = await self.service.fetch()
            self.state.isFetching = false
            if let snap {
                self.state.snapshot = snap
                self.state.lastError = nil
                self.store.save(snap)
            } else {
                self.state.lastError = "Couldn't reach CoinGecko"
            }
        }
    }

    func didActivate()    { refresh() }
    func willDeactivate() {}
}
