import Foundation

struct NoteEntry: Codable, Identifiable, Hashable {
    let id: UUID
    /// Stable yyyy-MM-dd key in the user's calendar. The entry is tied to the
    /// day it was created on — typing past midnight keeps text in that day's
    /// entry; a fresh entry is created on the user's next visit.
    let dateKey: String
    /// Wall-clock createdAt in local time (just for display).
    let createdAt: Date
    var modifiedAt: Date
    var body: String

    static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func currentDayKey(_ date: Date = Date()) -> String {
        dayKeyFormatter.string(from: date)
    }
}
