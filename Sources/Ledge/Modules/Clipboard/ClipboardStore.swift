import Foundation
import Observation
import AppKit

@Observable
final class ClipboardStore {
    static let maxItems = 50

    /// Result of a capture attempt, surfaced to the UI for feedback flashes.
    enum CaptureResult {
        case captured
        case skippedConcealed
        case empty
    }

    private(set) var items: [ClipboardItem] = []
    var searchQuery: String = ""

    /// Currently-selected item id, used by keyboard navigation. Nil means
    /// "no selection". Set automatically when the visible list changes.
    var selectedID: UUID?

    /// Set externally (by ClipboardModule). Invoked after a successful copy
    /// so the panel can collapse so the user can immediately ⌘V.
    var onAfterCopy: (() -> Void)?

    /// Filtered + sorted view used by the expanded list. Pinned first, then
    /// most-recent. Filter matches preview/title/text/filename.
    var visibleItems: [ClipboardItem] {
        let q = searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        let filtered: [ClipboardItem]
        if q.isEmpty {
            filtered = items
        } else {
            filtered = items.filter { item in
                if item.preview.lowercased().contains(q) { return true }
                if let t = item.title?.lowercased(), t.contains(q) { return true }
                if let t = item.text?.lowercased(), t.contains(q) { return true }
                if let n = item.displayName?.lowercased(), n.contains(q) { return true }
                if let o = item.ocrText?.lowercased(), o.contains(q) { return true }
                return false
            }
        }
        return filtered.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned && !rhs.isPinned }
            return lhs.addedAt > rhs.addedAt
        }
    }

    private let store = ModuleStore<[ClipboardItem]>(
        moduleIdentifier: ClipboardModule.identifier,
        defaultValue: []
    )

    private let imagesDir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Ledge/modules/\(ClipboardModule.identifier)/images", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// nspasteboard.org community convention. Apps that copy secrets (1Password,
    /// Bitwarden, Keychain Access) declare these types so clipboard managers
    /// can opt out. We honor it even though our capture is manual — defense
    /// in depth against accidentally stashing a password with ⌃⌥V.
    private let concealedTypes: Set<NSPasteboard.PasteboardType> = [
        NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"),
        NSPasteboard.PasteboardType("org.nspasteboard.TransientType"),
        NSPasteboard.PasteboardType("Pasteboard generator type"),
        NSPasteboard.PasteboardType("de.petermaurer.TransientPasteboardType")
    ]

    func load() {
        let raw = store.load()
        items = raw.map { resolve($0) }
        Log.module.info("Clipboard loaded \(self.items.count) item(s)")
        // Backfill OCR for image entries from older builds.
        for item in items where item.kind == .image && item.ocrText == nil {
            runOCR(for: item)
        }
    }

    // MARK: - Capture from system pasteboard

    /// Reads the current `NSPasteboard.general` contents and inserts a new
    /// item. Honors concealed-clipboard hints from password managers and
    /// returns a result code so the UI can flash an explanation.
    @discardableResult
    func captureFromPasteboard() -> CaptureResult {
        let pb = NSPasteboard.general
        let types = Set(pb.types ?? [])

        if !types.isDisjoint(with: concealedTypes) {
            Log.module.info("Clipboard capture skipped: concealed type present")
            return .skippedConcealed
        }

        // 1. File URLs
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty {
            for url in urls {
                if let item = makeFileItem(for: url) {
                    insert(item)
                }
            }
            persist()
            return .captured
        }

        // 2. Image (only if no text — many apps put both, prefer text)
        let plainText = pb.string(forType: .string)
        if (plainText == nil || plainText?.isEmpty == true),
           let image = NSImage(pasteboard: pb),
           let item = makeImageItem(from: image) {
            insert(item)
            persist()
            runOCR(for: item)
            return .captured
        }

        // 3. Text — pick up rich representations alongside if present.
        if let s = plainText, !s.isEmpty {
            let rtf = pb.data(forType: .rtf)
            let html = pb.data(forType: .html)
            let item = makeTextItem(from: s, rtf: rtf, html: html)
            insert(item)
            persist()
            return .captured
        }

        return .empty
    }

    // MARK: - Drop intake

    func acceptText(_ text: String, rtf: Data? = nil, html: Data? = nil) {
        guard !text.isEmpty else { return }
        let item = makeTextItem(from: text, rtf: rtf, html: html)
        insert(item)
        persist()
    }

    func acceptImage(_ image: NSImage) {
        guard let item = makeImageItem(from: image) else { return }
        insert(item)
        persist()
        runOCR(for: item)
    }

    /// Run Vision OCR on a freshly-inserted image entry and persist any
    /// recognized text back onto the item. Failures are silent — `ocrText`
    /// just stays nil, no UI noise.
    private func runOCR(for item: ClipboardItem) {
        guard item.kind == .image, let url = imageURL(for: item) else { return }
        ClipboardOCR.recognize(at: url) { [weak self] text in
            guard let self, let text else { return }
            guard let idx = self.items.firstIndex(where: { $0.id == item.id }) else { return }
            self.items[idx].ocrText = text
            self.persist()
            Log.module.info("Clipboard OCR captured \(text.count) chars")
        }
    }

    func acceptFile(_ url: URL) {
        guard let item = makeFileItem(for: url) else { return }
        insert(item)
        persist()
    }

    // MARK: - Item construction

    private func makeTextItem(from raw: String, rtf: Data? = nil, html: Data? = nil) -> ClipboardItem {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = trimmed.split(whereSeparator: \.isNewline).first.map(String.init) ?? trimmed
        let preview = String(firstLine.prefix(120))
        return ClipboardItem(
            id: UUID(),
            kind: .text,
            addedAt: Date(),
            isPinned: false,
            preview: preview,
            text: raw,
            rtfData: rtf,
            htmlData: html
        )
    }

    private func makeImageItem(from image: NSImage) -> ClipboardItem? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            return nil
        }
        let filename = "\(UUID().uuidString).png"
        let target = imagesDir.appendingPathComponent(filename)
        do {
            try png.write(to: target, options: .atomic)
        } catch {
            Log.module.error("Clipboard image write failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
        let w = rep.pixelsWide
        let h = rep.pixelsHigh
        return ClipboardItem(
            id: UUID(),
            kind: .image,
            addedAt: Date(),
            isPinned: false,
            preview: "Image \(w)\u{00D7}\(h)",
            imageFilename: filename,
            imageWidth: w,
            imageHeight: h
        )
    }

    private func makeFileItem(for url: URL) -> ClipboardItem? {
        do {
            let bookmark = try url.bookmarkData(
                options: [.minimalBookmark],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .nameKey])
            let name = values.name ?? url.lastPathComponent
            return ClipboardItem(
                id: UUID(),
                kind: .file,
                addedAt: Date(),
                isPinned: false,
                preview: name,
                bookmark: bookmark,
                displayName: name,
                byteSize: Int64(values.fileSize ?? 0),
                resolvedURL: url
            )
        } catch {
            Log.module.error("Clipboard bookmark failed for \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func insert(_ item: ClipboardItem) {
        if item.kind == .text, let t = item.text,
           let idx = items.firstIndex(where: { $0.kind == .text && $0.text == t }) {
            var existing = items.remove(at: idx)
            existing.addedAt = Date()
            items.insert(existing, at: 0)
            return
        }
        if item.kind == .file, let url = item.resolvedURL,
           let idx = items.firstIndex(where: { $0.kind == .file && $0.resolvedURL == url }) {
            var existing = items.remove(at: idx)
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
        let toRemove = Array(unpinned.sorted { $0.element.addedAt < $1.element.addedAt }.prefix(overflow))
        let removeOffsets = Set(toRemove.map(\.offset))
        let evicted = toRemove.map(\.element)
        items = items.enumerated().compactMap { removeOffsets.contains($0.offset) ? nil : $0.element }
        for item in evicted { deleteSidecar(item) }
    }

    // MARK: - Item actions

    /// Writes the item's payload back to `NSPasteboard.general`, ready to
    /// paste. For rich-text entries we declare RTF/HTML alongside plain so
    /// rich destinations get formatting and plain destinations fall back.
    func copyToPasteboard(_ item: ClipboardItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch item.kind {
        case .text:
            var declared: [NSPasteboard.PasteboardType] = []
            if item.rtfData != nil  { declared.append(.rtf) }
            if item.htmlData != nil { declared.append(.html) }
            declared.append(.string)
            pb.declareTypes(declared, owner: nil)
            if let rtf = item.rtfData   { pb.setData(rtf, forType: .rtf) }
            if let html = item.htmlData { pb.setData(html, forType: .html) }
            if let t = item.text        { pb.setString(t, forType: .string) }
        case .image:
            if let url = imageURL(for: item),
               let data = try? Data(contentsOf: url) {
                pb.setData(data, forType: .png)
            }
        case .file:
            if let url = item.resolvedURL {
                pb.writeObjects([url as NSURL])
            }
        }
        onAfterCopy?()
    }

    func togglePin(_ item: ClipboardItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx].isPinned.toggle()
        persist()
    }

    func remove(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        deleteSidecar(item)
        persist()
    }

    func clearUnpinned() {
        let removed = items.filter { !$0.isPinned }
        items.removeAll { !$0.isPinned }
        for item in removed { deleteSidecar(item) }
        persist()
    }

    /// Update a text entry's title and/or body. Used by inline edit. Updating
    /// the body re-derives the preview from the first line. Rich-text data is
    /// dropped on edit since the user is now authoring plain text.
    func updateTextItem(_ item: ClipboardItem, newTitle: String?, newText: String) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }), items[idx].kind == .text else { return }
        let trimmedTitle = newTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = trimmedBody.split(whereSeparator: \.isNewline).first.map(String.init) ?? trimmedBody
        items[idx].text = newText
        items[idx].title = (trimmedTitle?.isEmpty == false) ? trimmedTitle : nil
        items[idx].preview = String(firstLine.prefix(120))
        items[idx].rtfData = nil
        items[idx].htmlData = nil
        persist()
    }

    // MARK: - Selection helpers (keyboard nav)

    /// Move selection by `delta` rows in the visible list. Wraps at edges.
    func moveSelection(by delta: Int) {
        let visible = visibleItems
        guard !visible.isEmpty else { selectedID = nil; return }
        if let current = selectedID, let i = visible.firstIndex(where: { $0.id == current }) {
            let n = visible.count
            let next = ((i + delta) % n + n) % n
            selectedID = visible[next].id
        } else {
            selectedID = delta >= 0 ? visible.first?.id : visible.last?.id
        }
    }

    /// Jump to the Nth visible entry (1-indexed). Used by ⌘1–9.
    func selectNth(_ index: Int) -> ClipboardItem? {
        let visible = visibleItems
        guard index >= 1, index <= visible.count else { return nil }
        let item = visible[index - 1]
        selectedID = item.id
        return item
    }

    /// Reconcile selection after the visible set changes (filter, removal,
    /// load). If the previous selection is gone, fall back to the first row.
    func ensureSelectionValid() {
        let visible = visibleItems
        if let id = selectedID, visible.contains(where: { $0.id == id }) { return }
        selectedID = visible.first?.id
    }

    // MARK: - Image helpers

    func imageURL(for item: ClipboardItem) -> URL? {
        guard let name = item.imageFilename else { return nil }
        let url = imagesDir.appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private func deleteSidecar(_ item: ClipboardItem) {
        guard item.kind == .image, let name = item.imageFilename else { return }
        let url = imagesDir.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Persistence

    private func persist() {
        store.save(items)
    }

    private func resolve(_ raw: ClipboardItem) -> ClipboardItem {
        guard raw.kind == .file, let bookmark = raw.bookmark else { return raw }
        var copy = raw
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmark,
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
