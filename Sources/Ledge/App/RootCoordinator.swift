import Foundation

/// Top-level orchestrator. Owns registry, expansion controller, active-module
/// store, login item, panel manager, and display coordinator.
final class RootCoordinator {
    let loginItem = LoginItemService()

    private let registry = ModuleRegistry()
    private let expansion = NotchExpansionController()
    private lazy var env = ModuleEnvironment(expansion: expansion)
    private lazy var fileShelf = FileShelfModule(environment: env)
    private lazy var nowPlaying = NowPlayingModule(environment: env)
    private lazy var active = ActiveModuleStore(
        defaultID: FileShelfModule.identifier,
        availableIDs: [FileShelfModule.identifier, NowPlayingModule.identifier]
    )
    private lazy var panels = PanelManager(
        expansion: expansion,
        active: active,
        modules: [fileShelf, nowPlaying]
    )
    private lazy var displays = DisplayCoordinator { [weak self] screens in
        self?.panels.reconcile(with: screens)
    }

    func start() {
        registry.register(fileShelf)
        registry.register(nowPlaying)
        registry.bootstrap()
        displays.start()
        Log.app.debug("RootCoordinator started; \(self.registry.count) module(s) registered")
    }

    func stop() {
        displays.stop()
        panels.tearDown()
        Log.app.debug("RootCoordinator stopping")
    }
}
