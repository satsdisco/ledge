import Foundation
import EventKit

/// Snapshot of a single EventKit event reduced to the fields Ledge actually
/// renders. Decoupling from `EKEvent` keeps the rest of the module testable
/// and avoids passing live Core Data-backed objects across actors.
struct CalendarEvent: Identifiable, Equatable, Hashable {
    let id: String              // EKEvent.eventIdentifier
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let location: String?
    let calendarColor: CGColor
    let calendarTitle: String
    /// First URL found in the event's URL field, notes, or location. Lets
    /// the user one-click into a Zoom/Meet/Teams link from the panel.
    let joinURL: URL?

    init(from event: EKEvent) {
        self.id = event.eventIdentifier ?? UUID().uuidString
        self.title = event.title ?? "(no title)"
        self.start = event.startDate
        self.end = event.endDate
        self.isAllDay = event.isAllDay
        self.location = event.location?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.calendarColor = event.calendar?.cgColor ?? CGColor(gray: 0.7, alpha: 1)
        self.calendarTitle = event.calendar?.title ?? ""
        self.joinURL = Self.firstURL(in: event)
    }

    /// Used by previews/tests.
    init(id: String, title: String, start: Date, end: Date, isAllDay: Bool = false,
         location: String? = nil, calendarColor: CGColor = CGColor(gray: 0.7, alpha: 1),
         calendarTitle: String = "", joinURL: URL? = nil) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.location = location
        self.calendarColor = calendarColor
        self.calendarTitle = calendarTitle
        self.joinURL = joinURL
    }

    /// True if the event is happening *right now*.
    func isLive(at moment: Date) -> Bool {
        moment >= start && moment < end
    }

    /// Minutes until the event begins (negative if already started).
    func minutesUntilStart(from moment: Date) -> Int {
        Int(start.timeIntervalSince(moment) / 60)
    }

    private static func firstURL(in event: EKEvent) -> URL? {
        if let url = event.url { return url }
        let haystack = (event.notes ?? "") + "\n" + (event.location ?? "")
        guard !haystack.isEmpty,
              let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        else { return nil }
        let range = NSRange(location: 0, length: (haystack as NSString).length)
        return detector.firstMatch(in: haystack, range: range)?.url
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
