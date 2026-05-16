import SwiftUI
import AppKit

// MARK: - Formatting

private enum CalendarFormat {
    static func time(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mma"
        f.amSymbol = "a"
        f.pmSymbol = "p"
        return f.string(from: date).lowercased()
    }

    static func until(_ minutes: Int) -> String {
        if minutes <= 0 { return "now" }
        if minutes < 60 { return "in \(minutes)m" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "in \(h)h" : "in \(h)h \(m)m"
    }
}

// MARK: - Collapsed

struct CalendarCollapsedView: View {
    @Bindable var state: CalendarState

    private var nextEvent: CalendarEvent? {
        let now = Date()
        // Prefer a live event if there is one; otherwise the next upcoming.
        return state.events.first(where: { $0.isLive(at: now) })
            ?? state.events.first(where: { $0.start > now })
    }

    var body: some View {
        HStack(spacing: 4) {
            if state.authStatus != .authorized {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.tertiary)
            } else if let event = nextEvent {
                Circle()
                    .fill(Color(cgColor: event.calendarColor))
                    .frame(width: 5, height: 5)
                Text(eventLabel(event))
                    .font(Typography.labelMedium)
                    .foregroundStyle(Palette.primary)
                    .lineLimit(1)
                    .frame(maxWidth: 110, alignment: .leading)
            } else {
                Image(systemName: "calendar")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(Palette.tertiary)
            }
        }
    }

    private func eventLabel(_ event: CalendarEvent) -> String {
        let now = Date()
        if event.isLive(at: now) {
            let title = event.title
            return title.count > 14 ? String(title.prefix(13)) + "\u{2026}" : title
        }
        return CalendarFormat.until(event.minutesUntilStart(from: now)) + " · " + event.title
    }
}

// MARK: - New event draft

/// Form values for the inline new-event editor. Lives on the view side; the
/// module converts it into an EventKit save via `createEvent`.
struct NewEventDraft: Equatable {
    var title: String
    var start: Date
    var end: Date
    var calendarID: String?
    var isAllDay: Bool
}

// MARK: - Expanded

struct CalendarExpandedView: View {
    @Bindable var state: CalendarState
    let onRequestAccess: () async -> Void
    let onResetAndRetry: () async -> Void
    let onCreate: (NewEventDraft) async -> Bool

    var body: some View {
        Group {
            switch state.authStatus {
            case .notDetermined: notDeterminedView
            case .denied:        deniedView
            case .authorized:    authorizedView
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: Auth states

    private var notDeterminedView: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.system(size: 22))
                .foregroundStyle(Palette.quaternary)
            Text("Show your day at a glance")
                .font(Typography.body)
                .foregroundStyle(Palette.primary)
            Text("Ledge stays local — events are only read for display.")
                .font(Typography.caption)
                .foregroundStyle(Palette.tertiary)
                .multilineTextAlignment(.center)
            Button {
                Task { await onRequestAccess() }
            } label: {
                Text("Connect Calendar")
                    .font(Typography.labelMedium)
                    .foregroundStyle(Palette.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(Palette.highlight)
                    )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var deniedView: some View {
        VStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.system(size: 18))
                .foregroundStyle(Palette.tertiary)
            Text("Calendar access is off")
                .font(Typography.body)
                .foregroundStyle(Palette.primary)
            Text("If Ledge isn't listed in System Settings yet, use Reset & Try Again to surface a fresh permission prompt.")
                .font(Typography.caption)
                .foregroundStyle(Palette.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            HStack(spacing: 6) {
                Button {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Text("Open System Settings")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Palette.separator))
                }
                .buttonStyle(.plain)
                Button {
                    Task { await onResetAndRetry() }
                } label: {
                    Text("Reset & Try Again")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Palette.highlight))
                }
                .buttonStyle(.plain)
                .help("Clears Ledge's cached calendar permission and re-prompts")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var authorizedView: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            if state.isCreating {
                NewEventForm(
                    calendars: state.writableCalendars,
                    defaultCalendarID: state.defaultCalendarID,
                    error: state.createError,
                    onSave: { draft in await onCreate(draft) },
                    onCancel: {
                        state.isCreating = false
                        state.createError = nil
                    }
                )
            } else if state.events.isEmpty {
                emptyAgenda
            } else {
                agenda
            }
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text("Today")
                .font(Typography.label)
                .foregroundStyle(Palette.secondary)
            Spacer()
            if !state.isCreating {
                Button {
                    state.createError = nil
                    state.isCreating = true
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "plus")
                            .font(.system(size: 8, weight: .semibold))
                        Text("New")
                            .font(Typography.glance)
                    }
                    .foregroundStyle(Palette.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Palette.highlight))
                }
                .buttonStyle(.plain)
                .help("Create a new event")
                .disabled(state.writableCalendars.isEmpty)
            }
        }
    }

    private var emptyAgenda: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 20))
                .foregroundStyle(Palette.tertiary)
            Text("No events today")
                .font(Typography.body)
                .foregroundStyle(Palette.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var agenda: some View {
        let now = state.refreshedAt
        let remaining = state.events.filter { $0.end > now }
        return ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 6) {
                ForEach(remaining) { event in
                    EventRow(event: event, now: now)
                }
            }
        }
    }
}

// MARK: - Row

private struct EventRow: View {
    let event: CalendarEvent
    let now: Date

    private var isLive: Bool { event.isLive(at: now) }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Color rail (calendar color stripe) — wider when live.
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color(cgColor: event.calendarColor))
                .frame(width: isLive ? 3 : 2)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(event.title)
                        .font(Typography.label)
                        .foregroundStyle(Palette.primary)
                        .lineLimit(1)
                    if isLive {
                        Text("LIVE")
                            .font(Typography.glance)
                            .foregroundStyle(Palette.accent)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                Capsule().fill(Palette.accent.opacity(0.18))
                            )
                    }
                }
                HStack(spacing: 6) {
                    Text(timeRange)
                        .font(Typography.meta)
                        .foregroundStyle(Palette.secondary)
                    if let loc = event.location {
                        Text("\u{00B7} \(loc)")
                            .font(Typography.caption)
                            .foregroundStyle(Palette.tertiary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }

            Spacer(minLength: 4)

            if let url = event.joinURL {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Image(systemName: "video.fill")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Palette.accent)
                        .frame(width: 22, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Palette.accent.opacity(0.18))
                        )
                }
                .buttonStyle(.plain)
                .help("Join meeting")
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isLive ? Palette.highlight : Palette.card.opacity(0.5))
        )
    }

    private var timeRange: String {
        if event.isAllDay { return "all day" }
        return "\(CalendarFormat.time(event.start)) – \(CalendarFormat.time(event.end))"
    }
}

// MARK: - New event form

/// Inline new-event editor. Lives in the expanded drawer; no popovers — see
/// the calendar-module gotchas memo on DatePicker(.compact) killing the panel.
private struct NewEventForm: View {
    let calendars: [WritableCalendar]
    let defaultCalendarID: String?
    let error: String?
    let onSave: (NewEventDraft) async -> Bool
    let onCancel: () -> Void

    @State private var title: String = ""
    @State private var start: Date = NewEventForm.defaultStart()
    @State private var durationMinutes: Int = 30
    @State private var calendarID: String?
    @State private var isAllDay: Bool = false
    @State private var saving: Bool = false
    @FocusState private var titleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title
            TextField("Event title", text: $title)
                .textFieldStyle(.plain)
                .font(Typography.body)
                .foregroundStyle(Palette.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Palette.card)
                )
                .focused($titleFocused)
                .onSubmit(attemptSave)

            // Date stepper (day-granularity)
            HStack(spacing: 6) {
                StepperPill(
                    icon: "calendar",
                    label: dateLabel,
                    onMinus: { adjustStart(days: -1) },
                    onPlus: { adjustStart(days: 1) }
                )

                if !isAllDay {
                    StepperPill(
                        icon: "clock",
                        label: timeLabel,
                        onMinus: { adjustStart(minutes: -15) },
                        onPlus: { adjustStart(minutes: 15) }
                    )
                    DurationPicker(minutes: $durationMinutes)
                }

                Spacer(minLength: 4)

                Toggle(isOn: $isAllDay) {
                    Text("All-day")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.secondary)
                }
                .toggleStyle(.checkbox)
            }

            // Calendar pulldown
            HStack(spacing: 6) {
                Image(systemName: "calendar.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.tertiary)
                Menu {
                    ForEach(calendars) { cal in
                        Button {
                            calendarID = cal.id
                        } label: {
                            Label(cal.title, systemImage: cal.id == calendarID ? "checkmark" : "")
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        if let selected = currentCalendar {
                            Circle()
                                .fill(Color(cgColor: selected.color))
                                .frame(width: 6, height: 6)
                            Text(selected.title)
                                .font(Typography.caption)
                                .foregroundStyle(Palette.primary)
                                .lineLimit(1)
                        } else {
                            Text("No calendar")
                                .font(Typography.caption)
                                .foregroundStyle(Palette.tertiary)
                        }
                        Image(systemName: "chevron.down")
                            .font(.system(size: 7, weight: .semibold))
                            .foregroundStyle(Palette.tertiary)
                    }
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()

                Spacer(minLength: 4)

                if let error {
                    Text(error)
                        .font(Typography.caption)
                        .foregroundStyle(Palette.accent)
                        .lineLimit(1)
                }
            }

            // Action row
            HStack(spacing: 6) {
                Spacer()
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(Typography.labelMedium)
                        .foregroundStyle(Palette.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Palette.separator))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)

                Button(action: attemptSave) {
                    Text(saving ? "Saving…" : "Save")
                        .font(Typography.labelMedium)
                        .foregroundStyle(canSave ? Palette.primary : Palette.tertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(canSave ? Palette.highlight : Palette.card))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave || saving)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Palette.card.opacity(0.6))
        )
        .onAppear {
            if calendarID == nil { calendarID = defaultCalendarID }
            titleFocused = true
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && calendarID != nil
    }

    private var currentCalendar: WritableCalendar? {
        calendars.first(where: { $0.id == calendarID })
    }

    private var dateLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(start) { return "Today" }
        if cal.isDateInTomorrow(start) { return "Tomorrow" }
        let f = DateFormatter()
        f.dateFormat = cal.isDate(start, equalTo: Date(), toGranularity: .year) ? "EEE, MMM d" : "MMM d, yyyy"
        return f.string(from: start)
    }

    private var timeLabel: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: start)
    }

    private func adjustStart(days: Int) {
        if let next = Calendar.current.date(byAdding: .day, value: days, to: start) {
            start = next
        }
    }

    private func adjustStart(minutes: Int) {
        if let next = Calendar.current.date(byAdding: .minute, value: minutes, to: start) {
            start = next
        }
    }

    private func attemptSave() {
        guard canSave, !saving else { return }
        saving = true
        let draft = NewEventDraft(
            title: title.trimmingCharacters(in: .whitespaces),
            start: start,
            end: isAllDay
                ? Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
                : start.addingTimeInterval(TimeInterval(durationMinutes * 60)),
            calendarID: calendarID,
            isAllDay: isAllDay
        )
        Task {
            _ = await onSave(draft)
            saving = false
        }
    }

    /// Next half-hour from now — sensible default for an "ad-hoc meeting" draft.
    private static func defaultStart() -> Date {
        let now = Date()
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        var rounded = comps
        let m = comps.minute ?? 0
        rounded.minute = m < 30 ? 30 : 0
        if m >= 30, let hour = comps.hour {
            rounded.hour = hour + 1
        }
        return cal.date(from: rounded) ?? now.addingTimeInterval(15 * 60)
    }
}

/// Inline ◀ / label / ▶ stepper. No popovers — moving date/time by clicking
/// the chevrons keeps the cursor inside the panel and avoids the hover-exit
/// collapse that DatePicker(.compact) and (sometimes) .field trigger on
/// macOS 26.
private struct StepperPill: View {
    let icon: String
    let label: String
    let onMinus: () -> Void
    let onPlus: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(Palette.tertiary)
            Button(action: onMinus) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Palette.secondary)
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(Palette.primary)
                .frame(minWidth: 64)
                .multilineTextAlignment(.center)
            Button(action: onPlus) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Palette.secondary)
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Palette.card)
        )
    }
}

/// Tiny duration picker — discrete buckets that cover ~95% of events. Avoids
/// a stepper to keep the calm-notch aesthetic.
private struct DurationPicker: View {
    @Binding var minutes: Int
    private static let options: [Int] = [15, 30, 60, 90, 120]

    var body: some View {
        Menu {
            ForEach(Self.options, id: \.self) { m in
                Button(action: { minutes = m }) {
                    Label(Self.label(m), systemImage: m == minutes ? "checkmark" : "")
                }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "clock")
                    .font(.system(size: 9))
                    .foregroundStyle(Palette.tertiary)
                Text(Self.label(minutes))
                    .font(Typography.caption)
                    .foregroundStyle(Palette.primary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(Palette.tertiary)
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private static func label(_ m: Int) -> String {
        if m < 60 { return "\(m)m" }
        let h = m / 60
        let rem = m % 60
        return rem == 0 ? "\(h)h" : "\(h)h\(rem)m"
    }
}
