import Foundation

struct ShelfItem: Codable, Identifiable, Hashable {
    let id: UUID
    var bookmark: Data
    var displayName: String
    var byteSize: Int64
    var addedAt: Date
    var isPinned: Bool

    /// Computed at load; not persisted.
    var isStale: Bool = false

    /// Resolved URL at load; not persisted.
    var resolvedURL: URL?

    enum CodingKeys: String, CodingKey {
        case id, bookmark, displayName, byteSize, addedAt, isPinned
    }
}
