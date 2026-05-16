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

// MARK: - Expanded

struct CalendarExpandedView: View {
    @Bindable var state: CalendarState
    let onRequestAccess: () async -> Void
    let onResetAndRetry: () async -> Void

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
        if state.events.isEmpty {
            emptyAgenda
        } else {
            agenda
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
