import Foundation
import Observation
import AppKit

@Observable
final class FileShelfStore {
    static let maxItems = 12

    private(set) var items: [ShelfItem] = []

    private let store = ModuleStore<[ShelfItem]>(
        moduleIdentifier: FileShelfModule.identifier,
        defaultValue: []
    )

    func load() {
        let raw = store.load()
        items = raw.map { resolve($0) }
        Log.shelf.info("Loaded \(self.items.count) shelf item(s)")
    }

    // MARK: - Intake

    func accept(urls: [URL]) {
        guard !urls.isEmpty else { return }
        for url in urls {
            if let item = makeItem(for: url) {
                insert(item)
            }
        }
        persist()
    }

    private func makeItem(for url: URL) -> ShelfItem? {
        do {
            let bookmark = try url.bookmarkData(
                options: [.minimalBookmark],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .nameKey])
            return ShelfItem(
                id: UUID(),
                bookmark: bookmark,
                displayName: values.name ?? url.lastPathComponent,
                byteSize: Int64(values.fileSize ?? 0),
                addedAt: Date(),
                isPinned: false,
                isStale: false,
                resolvedURL: url
            )
        } catch {
            Log.shelf.error("Bookmark failed for \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func insert(_ item: ShelfItem) {
        // Dedup by resolved path if we already have it.
        if let incoming = item.resolvedURL,
           let existingIndex = items.firstIndex(where: { $0.resolvedURL == incoming }) {
            var existing = items.remove(at: existingIndex)
            existing.addedAt = Date()
            items.insert(existing, at: 0)
            return
        }
        items.insert(item, at: 0)
        evictIfNeeded()
    }

    private func evictIfNeeded() {
        let unpinned = items.enumerated().filter { !$0.element.isPinned }
        let overflow = unpinned.count - Self.maxItems
        guard overflow > 0 else { return }
        // Evict oldest unpinned first.
        let toRemove = Array(unpinned.sorted { $0.element.addedAt < $1.element.addedAt }.prefix(overflow))
        let removeIndices = Set(toRemove.map(\.offset))
        items = items.enumerated().compactMap { removeIndices.contains($0.offset) ? nil : $0.element }
    }

    // MARK: - Actions

    func togglePin(_ item: ShelfItem) {
        guard let idx = items.firstIndex(of: item) else { return }
        items[idx].isPinned.toggle()
        persist()
    }

    func remove(_ item: ShelfItem) {
        items.removeAll { $0.id == item.id }
        persist()
    }

    func clearUnpinned() {
        items.removeAll { !$0.isPinned }
        persist()
    }

    func revealInFinder(_ item: ShelfItem) {
        guard let url = item.resolvedURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func copyPath(_ item: ShelfItem) {
        guard let url = item.resolvedURL else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(url.path, forType: .string)
    }

    // MARK: - Persistence

    private func persist() {
        store.save(items)
    }

    private func resolve(_ raw: ShelfItem) -> ShelfItem {
        var copy = raw
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: raw.bookmark,
                options: [.withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            copy.resolvedURL = FileManager.default.fileExists(atPath: url.path) ? url : nil
            copy.isStale = isStale || copy.resolvedURL == nil
        } catch {
            copy.resolvedURL = nil
            copy.isStale = true
        }
        return copy
    }
}
