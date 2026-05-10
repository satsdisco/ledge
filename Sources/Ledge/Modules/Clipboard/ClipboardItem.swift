import Foundation

enum ClipboardKind: String, Codable {
    case text
    case image
    case file
}

struct ClipboardItem: Codable, Identifiable, Hashable {
    let id: UUID
    var kind: ClipboardKind
    var addedAt: Date
    var isPinned: Bool

    /// One-line preview shown in the expanded list. For text, the first line
    /// truncated to ~120 chars. For images, dimensions. For files, the filename.
    var preview: String

    // Text payload. `text` is always plain UTF-8 (set for kind=.text).
    // `rtfData` and `htmlData` are optional richer representations captured
    // alongside, so we can paste back formatting where the destination accepts
    // it and fall back to plain text everywhere else.
    var text: String?
    var rtfData: Data?
    var htmlData: Data?

    /// Optional title set by the user when editing a snippet. When non-nil,
    /// shown in place of the auto-generated preview.
    var title: String?

    // Image payload. PNG data is written to
    // `<module-dir>/images/<imageFilename>` and referenced by name.
    var imageFilename: String?
    var imageWidth: Int?
    var imageHeight: Int?
    /// Text recognized via Vision after capture. `nil` until OCR finishes
    /// (or if OCR found nothing). Indexed in search.
    var ocrText: String?

    // File payload. Minimal bookmark, like FileShelf.
    var bookmark: Data?
    var displayName: String?
    var byteSize: Int64?

    // Computed at load; not persisted.
    var resolvedURL: URL?
    var isStale: Bool = false

    var hasRichText: Bool { rtfData != nil || htmlData != nil }
    var displayTitle: String { title ?? preview }

    enum CodingKeys: String, CodingKey {
        case id, kind, addedAt, isPinned, preview, title
        case text, rtfData, htmlData
        case imageFilename, imageWidth, imageHeight, ocrText
        case bookmark, displayName, byteSize
    }
}
