import Foundation

/// Top-level orchestrator. Owns module registry, expansion controller,
/// panel manager, and display coordinator. Thin: wires subsystems,
/// forwards lifecycle events.
final class RootCoordinator {
    private let registry = ModuleRegistry()
    private let expansion = NotchExpansionController()
    private lazy var env = ModuleEnvironment(expansion: expansion)
    private lazy var fileShelf = FileShelfModule(environment: env)
    private lazy var panels = PanelManager(expansion: expansion, module: fileShelf)
    private lazy var displays = DisplayCoordinator { [weak self] screens in
        self?.panels.reconcile(with: screens)
    }

    func start() {
        registry.register(fileShelf)
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
