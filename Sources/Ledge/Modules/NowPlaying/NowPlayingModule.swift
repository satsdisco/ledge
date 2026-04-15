import SwiftUI
import Observation
import Foundation

@Observable
final class NowPlayingState {
    var track: NowPlayingTrack? = nil
    var isBusy: Bool = false
}

final class NowPlayingModule: LedgeModule {
    static let identifier = "com.satsdisco.ledge.module.nowplaying"
    let displayName = "Now Playing"

    let state = NowPlayingState()
    private let controller: MediaController
    private var pollTimer: Timer?

    init(environment: ModuleEnvironment, controller: MediaController = AppleScriptMediaController()) {
        self.controller = controller
        startPolling()
    }

    // MARK: - Views

    var collapsedView: AnyView { AnyView(NowPlayingCollapsedView(state: state)) }
    var expandedView: AnyView {
        AnyView(NowPlayingExpandedView(state: state, controller: controller))
    }

    // MARK: - Polling

    private func startPolling() {
        refresh()
        let timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func refresh() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let track = await self.controller.currentTrack()
            self.state.track = track
        }
    }

    func didActivate()    { refresh() }
    func willDeactivate() {}
}
