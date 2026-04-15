import Foundation
import Observation

@Observable
final class ClocksStore {
    private(set) var entries: [ClockEntry] = []

    private let store: ModuleStore<[ClockEntry]>

    static let maxEntries = 6

    init() {
        self.store = ModuleStore<[ClockEntry]>(
            moduleIdentifier: ClocksModule.identifier,
            defaultValue: ClocksStore.defaultEntries()
        )
    }

    func load() {
        entries = store.load()
        if entries.isEmpty {
            entries = Self.defaultEntries()
            persist()
        }
        Log.module.info("Loaded \(self.entries.count) clock(s)")
    }

    func add(_ entry: ClockEntry) {
        guard entries.count < Self.maxEntries else { return }
        guard !entries.contains(where: { $0.timeZoneIdentifier == entry.timeZoneIdentifier }) else { return }
        entries.append(entry)
        persist()
    }

    func remove(_ entry: ClockEntry) {
        entries.removeAll { $0.id == entry.id }
        persist()
    }

    func move(from source: IndexSet, to destination: Int) {
        entries.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    func setStyle(_ style: ClockEntry.Style, for entry: ClockEntry) {
        guard let idx = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[idx].style = style
        persist()
    }

    func resetToDefaults() {
        entries = Self.defaultEntries()
        persist()
    }

    private func persist() { store.save(entries) }

    // MARK: - Defaults

    static func defaultEntries() -> [ClockEntry] {
        [
            ClockEntry(timeZoneIdentifier: "UTC", label: "UTC", style: .analog),
            ClockEntry(timeZoneIdentifier: "America/New_York", label: "NYC", style: .analog),
            ClockEntry(timeZoneIdentifier: "Europe/London", label: "LON", style: .analog),
            ClockEntry(timeZoneIdentifier: "Asia/Tokyo", label: "TYO", style: .analog)
        ]
    }
}
