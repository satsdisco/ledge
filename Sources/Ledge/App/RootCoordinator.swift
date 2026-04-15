import Foundation

/// Top-level orchestrator. Owns the module registry, the panel manager,
/// and the display coordinator. Keep it thin: wires subsystems, forwards lifecycle.
final class RootCoordinator {
    private let registry = ModuleRegistry()
    private let panels = PanelManager()
    private lazy var displays = DisplayCoordinator { [weak self] screens in
        self?.panels.reconcile(with: screens)
    }

    func start() {
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
