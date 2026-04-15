import Foundation

/// Per-module typed Codable persistence. Writes atomically via
/// `FileManager.replaceItem`. Root at
/// `~/Library/Application Support/Ledge/modules/<identifier>/state.json`.
final class ModuleStore<Value: Codable> {
    private let url: URL
    private let identifier: String
    private let defaultValue: Value

    init(moduleIdentifier: String, defaultValue: Value) {
        self.identifier = moduleIdentifier
        self.defaultValue = defaultValue
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Ledge/modules/\(moduleIdentifier)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.url = dir.appendingPathComponent("state.json")
    }

    func load() -> Value {
        guard let data = try? Data(contentsOf: url) else { return defaultValue }
        do {
            return try JSONDecoder().decode(Value.self, from: data)
        } catch {
            Log.module.error("Decode failed for \(self.identifier, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return defaultValue
        }
    }

    func save(_ value: Value) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(value)
            try atomicWrite(data)
        } catch {
            Log.module.error("Save failed for \(self.identifier, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func atomicWrite(_ data: Data) throws {
        let tmp = url.appendingPathExtension("tmp-\(UUID().uuidString)")
        try data.write(to: tmp, options: .atomic)
        if FileManager.default.fileExists(atPath: url.path) {
            _ = try FileManager.default.replaceItemAt(url, withItemAt: tmp)
        } else {
            try FileManager.default.moveItem(at: tmp, to: url)
        }
    }
}
