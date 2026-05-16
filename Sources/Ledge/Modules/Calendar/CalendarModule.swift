import SwiftUI
import AppKit
import Observation

@Observable
@MainActor
final class CalendarState {
    var authStatus: CalendarService.AuthStatus = .notDetermined
    /// Today's events (00:00 → 23:59) in chronological order.
    var events: [CalendarEvent] = []
    /// `Date()` at last refresh — used for "X min until" calculations.
    var refreshedAt: Date = Date()
    /// Whether the inline new-event form is showing in the expanded view.
    var isCreating: Bool = false
    /// Writable calendars available for new events. Empty until auth.
    var writableCalendars: [WritableCalendar] = []
    /// Suggested calendar ID for a fresh new-event form. `nil` if the user
    /// has no default-for-new-events configured and no writable calendar.
    var defaultCalendarID: String?
    /// Set after a failed save so the form can show the error inline. Cleared
    /// when the user edits a field or dismisses the form.
    var createError: String?
}

final class CalendarModule: LedgeModule {
    static let identifier = "com.satsdisco.ledge.module.calendar"
    let displayName = "Calendar"
    let iconName = "calendar"

    @MainActor let state = CalendarState()
    @MainActor private let service = CalendarService()
    private let busy: BusyIndex
    private var pollTimer: Timer?

    /// Calendar is an ambient module by default, but it needs the panel to
    /// become key while the inline new-event form is open so TextField and
    /// Menu can receive input. Without this, typing into the title field
    /// silently does nothing and the calendar pulldown won't open.
    var wantsKeyboardFocus: Bool {
        MainActor.assumeIsolated { state.isCreating }
    }

    init(environment: ModuleEnvironment) {
        self.busy = environment.busy
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.state.authStatus = self.service.currentStatus
            self.service.onStoreChanged = { [weak self] in self?.refresh() }
            if self.state.authStatus == .authorized {
                self.refresh()
            }
            self.startPolling()
        }
    }

    var collapsedView: AnyView { AnyView(CalendarCollapsedView(state: state)) }
    var expandedView: AnyView {
        AnyView(CalendarExpandedView(
            state: state,
            onRequestAccess: { [weak self] in await self?.requestAccess() },
            onResetAndRetry: { [weak self] in await self?.resetAndRetry() },
            onCreate: { [weak self] draft in await self?.createEvent(draft) ?? false }
        ))
    }

    /// Bigger drawer to fit a couple of agenda rows comfortably.
    var preferredExpandedSize: CGSize { CGSize(width: 540, height: 220) }

    // MARK: - Refresh

    @MainActor
    func requestAccess() async {
        // Ledge runs as LSUIElement (.accessory). Some macOS permission
        // prompts won't render unless the requesting app is a regular
        // foreground app, so we briefly promote ourselves while the
        // EventKit request is in flight. The notch panel stays put either
        // way — only the activation policy changes.
        let savedPolicy = NSApp.activationPolicy()
        if savedPolicy != .regular {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
        let status = await service.requestAccess()
        if savedPolicy != .regular {
            NSApp.setActivationPolicy(savedPolicy)
        }
        state.authStatus = status
        if status == .authorized { refresh() }
    }

    /// Nuke any cached TCC entry for Ledge's calendar permission, then
    /// re-request. Surfaces a fresh prompt when a previous request got
    /// silently denied (common on ad-hoc signed dev builds).
    @MainActor
    func resetAndRetry() async {
        await service.resetTCC()
        // After reset the status is .notDetermined again; request fresh.
        state.authStatus = service.currentStatus
        await requestAccess()
    }

    @MainActor
    private func refresh() {
        guard service.currentStatus == .authorized else {
            state.authStatus = service.currentStatus
            return
        }
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? Date().addingTimeInterval(86_400)
        state.events = service.events(from: start, to: end)
        state.refreshedAt = Date()
        if state.writableCalendars.isEmpty {
            state.writableCalendars = service.writableCalendars()
            state.defaultCalendarID = service.defaultWritableCalendarID
                ?? state.writableCalendars.first?.id
        }
        // Skip all-day events: they shouldn't shade a 3pm scheduling lookup
        // as "busy" — the user almost always means timed overlap.
        busy.intervals = state.events
            .filter { !$0.isAllDay }
            .map { BusyInterval(start: $0.start, end: $0.end) }
    }

    /// Save a new event. Returns true on success so the view can dismiss the
    /// form; false leaves the form up with `state.createError` populated.
    @MainActor
    func createEvent(_ draft: NewEventDraft) async -> Bool {
        do {
            _ = try service.createEvent(
                title: draft.title,
                start: draft.start,
                end: draft.end,
                calendarID: draft.calendarID,
                isAllDay: draft.isAllDay,
                notes: nil
            )
            state.createError = nil
            state.isCreating = false
            refresh()
            return true
        } catch CalendarService.CreateError.noWritableCalendar {
            state.createError = "No writable calendar available."
            return false
        } catch CalendarService.CreateError.notAuthorized {
            state.createError = "Calendar access was revoked."
            return false
        } catch {
            state.createError = "Couldn't save event."
            return false
        }
    }

    private func startPolling() {
        // Refresh every 5 min in addition to .EKEventStoreChanged so the
        // "X min until" countdown stays roughly accurate.
        let t = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        RunLoop.main.add(t, forMode: .common)
        pollTimer = t
    }

    func didActivate() {
        Task { @MainActor in refresh() }
    }
    func willDeactivate() {}
}
