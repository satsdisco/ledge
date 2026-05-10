import Foundation
import Observation
import AppKit

@Observable
final class NotesStore {
    /// All entries, newest first. Today's entry (if any) is index 0.
    private(set) var entries: [NoteEntry] = []

    /// Convenience accessor for the editable today entry. Created on demand
    /// via `ensureTodayEntry()`.
    var todayEntry: NoteEntry? {
        entries.first { $0.dateKey == NoteEntry.currentDayKey() }
    }

    var archive: [NoteEntry] {
        let today = NoteEntry.currentDayKey()
        return entries.filter { $0.dateKey != today }
    }

    /// IDs of archive entries the user has expanded (tapped to read). Not
    /// persisted — UI-only state lives here so view updates flow through
    /// `@Observable`.
    var expandedArchiveIDs: Set<UUID> = []

    private let store = ModuleStore<[NoteEntry]>(
        moduleIdentifier: NotesModule.identifier,
        defaultValue: []
    )

    private var saveTask: Task<Void, Never>?
    private var midnightTimer: Timer?

    func load() {
        entries = store.load().sorted { $0.dateKey > $1.dateKey }
        Log.module.info("Notes loaded \(self.entries.count) entry/entries")
        ensureTodayEntry()
        scheduleMidnightRollover()
    }

    /// Make sure there's a row for today. Idempotent.
    @discardableResult
    func ensureTodayEntry() -> NoteEntry {
        let key = NoteEntry.currentDayKey()
        if let existing = entries.first(where: { $0.dateKey == key }) {
            return existing
        }
        let now = Date()
        let entry = NoteEntry(
            id: UUID(),
            dateKey: key,
            createdAt: now,
            modifiedAt: now,
            body: ""
        )
        entries.insert(entry, at: 0)
        persistImmediately()
        return entry
    }

    // MARK: - Editing

    /// Update today's body. Saves are debounced (~600ms) to avoid hitting
    /// disk on every keystroke.
    func updateTodayBody(_ newBody: String) {
        let key = NoteEntry.currentDayKey()
        if let idx = entries.firstIndex(where: { $0.dateKey == key }) {
            entries[idx].body = newBody
            entries[idx].modifiedAt = Date()
        } else {
            let entry = NoteEntry(
                id: UUID(),
                dateKey: key,
                createdAt: Date(),
                modifiedAt: Date(),
                body: newBody
            )
            entries.insert(entry, at: 0)
        }
        scheduleSave()
    }

    func toggleArchiveExpansion(_ entry: NoteEntry) {
        if expandedArchiveIDs.contains(entry.id) {
            expandedArchiveIDs.remove(entry.id)
        } else {
            expandedArchiveIDs.insert(entry.id)
        }
    }

    func remove(_ entry: NoteEntry) {
        entries.removeAll { $0.id == entry.id }
        expandedArchiveIDs.remove(entry.id)
        persistImmediately()
    }

    /// Copies an archived entry's body to the system clipboard so the user
    /// can paste it elsewhere.
    func copyToPasteboard(_ entry: NoteEntry) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(entry.body, forType: .string)
    }

    // MARK: - Persistence

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            self?.persistImmediately()
        }
    }

    private func persistImmediately() {
        saveTask?.cancel()
        saveTask = nil
        store.save(entries)
    }

    /// Schedule a wakeup ~1s after the next midnight so we materialize
    /// tomorrow's entry without the user having to relaunch. On miss
    /// (sleep, app suspended), `ensureTodayEntry()` on next activation
    /// catches up.
    private func scheduleMidnightRollover() {
        midnightTimer?.invalidate()
        let now = Date()
        let cal = Calendar.current
        guard let nextMidnight = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) else { return }
        let interval = nextMidnight.timeIntervalSince(now) + 1
        let t = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.ensureTodayEntry()
            self?.scheduleMidnightRollover()
        }
        RunLoop.main.add(t, forMode: .common)
        midnightTimer = t
    }
}
