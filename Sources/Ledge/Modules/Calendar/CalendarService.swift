import Foundation
import EventKit

/// Thin wrapper around `EKEventStore`. Owns the permission dance and event
/// fetches; emits state changes via callbacks rather than holding observable
/// state itself (the module's `CalendarState` does that).
@MainActor
final class CalendarService {
    enum AuthStatus: Equatable {
        case notDetermined
        case denied            // User said no, or wrote-only / restricted
        case authorized        // Full access granted
    }

    private let store = EKEventStore()
    private var observer: NSObjectProtocol?

    /// Fires when the underlying event database changes (event added/removed
    /// in Calendar.app, sync from server, etc.). Module wires this to a
    /// refetch.
    var onStoreChanged: (() -> Void)?

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { [weak self] _ in
            // queue:.main already ensures we're on the main thread; the Task
            // hop is just to satisfy Swift 6's actor-isolation checker.
            Task { @MainActor in self?.onStoreChanged?() }
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    var currentStatus: AuthStatus {
        let raw = EKEventStore.authorizationStatus(for: .event)
        switch raw {
        case .notDetermined: return .notDetermined
        case .fullAccess:    return .authorized
        case .authorized:    return .authorized   // legacy alias
        case .denied, .restricted, .writeOnly: return .denied
        @unknown default:    return .denied
        }
    }

    /// Request full access. Returns the resulting status. Idempotent — if
    /// already authorized this is effectively a no-op.
    func requestAccess() async -> AuthStatus {
        let preStatus = EKEventStore.authorizationStatus(for: .event)
        Log.module.info("Calendar requestAccess pre-status=\(String(describing: preStatus), privacy: .public)")
        if currentStatus == .authorized { return .authorized }
        do {
            let granted = try await store.requestFullAccessToEvents()
            let postStatus = EKEventStore.authorizationStatus(for: .event)
            Log.module.info("Calendar requestAccess granted=\(granted) post-status=\(String(describing: postStatus), privacy: .public)")
            return granted ? .authorized : .denied
        } catch {
            Log.module.error("Calendar access request failed: \(String(describing: error), privacy: .public)")
            return .denied
        }
    }

    /// Local-dev escape hatch: ad-hoc signed builds sometimes never trigger
    /// a TCC prompt (the system silently denies because there's no stable
    /// code identity to attribute the request to). This nukes the TCC entry
    /// for Ledge's calendar permission so the next requestAccess() prompts
    /// fresh. No-op for shipped builds where the prompt works normally.
    func resetTCC() async {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", "Calendar", bundleID]
        do {
            try process.run()
            process.waitUntilExit()
            Log.module.info("tccutil reset Calendar \(bundleID, privacy: .public) — exit \(process.terminationStatus)")
        } catch {
            Log.module.error("tccutil reset failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// All events between `from` and `to` across every selected calendar.
    /// Returns chronologically. Caller decides what "today" means.
    func events(from: Date, to: Date) -> [CalendarEvent] {
        guard currentStatus == .authorized else { return [] }
        let calendars = store.calendars(for: .event)
        let predicate = store.predicateForEvents(withStart: from, end: to, calendars: calendars)
        return store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .map(CalendarEvent.init(from:))
    }

    // MARK: - Write

    enum CreateError: Error {
        case notAuthorized
        case noWritableCalendar
        case saveFailed(Error)
    }

    /// Writable calendars reduced to a snapshot the UI can hold without
    /// carrying live EKCalendar references across actors.
    func writableCalendars() -> [WritableCalendar] {
        guard currentStatus == .authorized else { return [] }
        return store.calendars(for: .event)
            .filter { $0.allowsContentModifications }
            .map(WritableCalendar.init(from:))
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    /// Identifier of the user's default calendar for new events, or `nil` if
    /// none is set / no writable calendar exists.
    var defaultWritableCalendarID: String? {
        store.defaultCalendarForNewEvents?.calendarIdentifier
    }

    /// Create a new event and save it. Returns the saved snapshot.
    /// Caller is responsible for triggering a refresh — though the
    /// `.EKEventStoreChanged` observer will fire one regardless.
    func createEvent(
        title: String,
        start: Date,
        end: Date,
        calendarID: String?,
        isAllDay: Bool = false,
        notes: String? = nil
    ) throws -> CalendarEvent {
        guard currentStatus == .authorized else { throw CreateError.notAuthorized }
        let calendar: EKCalendar? = {
            if let id = calendarID, let c = store.calendar(withIdentifier: id),
               c.allowsContentModifications { return c }
            return store.defaultCalendarForNewEvents
                ?? store.calendars(for: .event).first(where: { $0.allowsContentModifications })
        }()
        guard let calendar else { throw CreateError.noWritableCalendar }

        let event = EKEvent(eventStore: store)
        event.calendar = calendar
        event.title = title
        event.startDate = start
        event.endDate = end
        event.isAllDay = isAllDay
        if let notes, !notes.isEmpty { event.notes = notes }

        do {
            try store.save(event, span: .thisEvent, commit: true)
        } catch {
            Log.module.error("Calendar createEvent failed: \(String(describing: error), privacy: .public)")
            throw CreateError.saveFailed(error)
        }
        return CalendarEvent(from: event)
    }
}

/// Lightweight snapshot of a writable EKCalendar — title + color + stable
/// identifier — so the SwiftUI layer can render a picker without holding
/// the live Core Data-backed calendar object.
struct WritableCalendar: Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let color: CGColor

    init(from cal: EKCalendar) {
        self.id = cal.calendarIdentifier
        self.title = cal.title
        self.color = cal.cgColor ?? CGColor(gray: 0.7, alpha: 1)
    }
}
