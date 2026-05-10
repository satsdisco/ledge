import Foundation
import Observation

@Observable
final class ClocksStore {
    private(set) var entries: [ClockEntry] = []

    /// Set externally (RootCoordinator) so the panel re-layouts when the
    /// number of clocks crosses the 4-clock threshold and the module's
    /// preferredExpandedSize wants to change.
    var onCountChange: (() -> Void)?

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
        onCountChange?()
    }

    func remove(_ entry: ClockEntry) {
        let before = entries.count
        entries.removeAll { $0.id == entry.id }
        persist()
        if entries.count != before { onCountChange?() }
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
        let before = entries.count
        entries = Self.defaultEntries()
        persist()
        if entries.count != before { onCountChange?() }
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
