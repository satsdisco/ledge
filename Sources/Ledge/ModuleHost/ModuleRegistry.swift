import Foundation

/// Static registry of first-party modules. Phase 0 ships empty;
/// Phase 2 registers FileShelf, Phase 3 registers NowPlaying.
final class ModuleRegistry {
    private(set) var modules: [LedgeModule] = []

    var count: Int { modules.count }

    func bootstrap() {
        // Modules are registered here once they exist.
        // register(FileShelfModule())
        // register(NowPlayingModule())
        Log.module.info("ModuleRegistry bootstrapped with \(self.modules.count) module(s)")
    }

    func register(_ module: LedgeModule) {
        modules.append(module)
        Log.module.info("Registered module: \(type(of: module).identifier, privacy: .public)")
    }

    func module(withIdentifier id: String) -> LedgeModule? {
        modules.first { type(of: $0).identifier == id }
    }
}
