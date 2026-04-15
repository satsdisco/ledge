import SwiftUI

// MARK: - Collapsed

struct ClocksCollapsedView: View {
    @Bindable var store: ClocksStore
    @Bindable var ticker: ClocksTicker

    private var primary: ClockEntry? {
        let local = TimeZone.current.identifier
        return store.entries.first { $0.timeZoneIdentifier != local } ?? store.entries.first
    }

    var body: some View {
        HStack(spacing: 4) {
            if let entry = primary {
                Text(entry.displayLabel)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(0.5)
                Text(ClocksFormat.time(ticker.now, in: entry.timeZone))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))
                    .monospacedDigit()
            } else {
                Image(systemName: "globe")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
    }
}

// MARK: - Expanded

struct ClocksExpandedView: View {
    @Bindable var store: ClocksStore
    @Bindable var ticker: ClocksTicker

    var body: some View {
        Group {
            if store.entries.isEmpty {
                emptyState
            } else {
                tilesGrid
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var tilesGrid: some View {
        let count = max(1, min(store.entries.count, 4))
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(store.entries) { entry in
                ClockTileView(entry: entry, now: ticker.now)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "globe")
                .font(.system(size: 22))
                .foregroundStyle(.white.opacity(0.25))
            Text("Add clocks in Settings → Clocks")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Tile

private struct ClockTileView: View {
    let entry: ClockEntry
    let now: Date

    var body: some View {
        VStack(spacing: 4) {
            face
                .frame(width: 64, height: 64)
            VStack(spacing: 1) {
                Text(entry.displayLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .tracking(0.5)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(metaLine)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var face: some View {
        if entry.style == .analog, let tz = entry.timeZone {
            AnalogClockView(date: now, timeZone: tz, diameter: 64)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
                Text(ClocksFormat.time(now, in: entry.timeZone))
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.95))
                    .monospacedDigit()
            }
        }
    }

    private var metaLine: String {
        let date = ClocksFormat.detail(now, in: entry.timeZone)
        let off = entry.offsetLabel()
        if entry.style == .analog {
            // Analog face shows time visually; show digital + date below.
            return "\(ClocksFormat.time(now, in: entry.timeZone)) · \(off)"
        } else {
            return "\(date) · \(off)"
        }
    }
}

// MARK: - Formatting helpers

enum ClocksFormat {
    static func time(_ date: Date, in tz: TimeZone?) -> String {
        guard let tz else { return "--:--" }
        let f = DateFormatter()
        f.timeZone = tz
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    static func detail(_ date: Date, in tz: TimeZone?) -> String {
        guard let tz else { return "" }
        let f = DateFormatter()
        f.timeZone = tz
        f.dateFormat = "EEE d"
        return f.string(from: date)
    }
}
