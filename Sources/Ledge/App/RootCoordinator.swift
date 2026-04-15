import Foundation

/// Top-level orchestrator. Owns the module registry and (in Phase 1) the panel manager.
/// Keep this thin — it wires subsystems and forwards lifecycle events.
final class RootCoordinator {
    private let registry = ModuleRegistry()

    func start() {
        registry.bootstrap()
        Log.app.debug("RootCoordinator started; \(self.registry.count) module(s) registered")
    }

    func stop() {
        Log.app.debug("RootCoordinator stopping")
    }
}
