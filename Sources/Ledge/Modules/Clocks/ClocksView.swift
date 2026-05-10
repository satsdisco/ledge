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
        // ≤4 clocks: one row, one column per clock.
        // 5–6 clocks: 3 columns × 2 rows (5 → 3+2, 6 → 3+3) — more balanced
        // than 4+1 or 4+2.
        let count = store.entries.count
        let columnCount = count <= 4 ? max(1, count) : 3
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: columnCount)
        return LazyVGrid(columns: columns, spacing: 12) {
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

    private var isLocal: Bool {
        entry.timeZone?.secondsFromGMT() == TimeZone.current.secondsFromGMT()
    }

    var body: some View {
        VStack(spacing: 6) {
            face
                .frame(width: 72, height: 72)

            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    if isLocal {
                        Circle()
                            .fill(.green.opacity(0.85))
                            .frame(width: 5, height: 5)
                    }
                    Text(entry.displayLabel)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .tracking(1.2)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Text(metaLine)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.40))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var face: some View {
        if entry.style == .analog, let tz = entry.timeZone {
            AnalogClockView(date: now, timeZone: tz, diameter: 72)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(0.06))
                Text(ClocksFormat.time(now, in: entry.timeZone))
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.97))
                    .monospacedDigit()
                    .tracking(-0.5)
            }
        }
    }

    private var metaLine: String {
        let date = ClocksFormat.detail(now, in: entry.timeZone)
        let off = entry.offsetLabel()
        if entry.style == .analog {
            // Analog face shows time visually; show digital + date below.
            return "\(ClocksFormat.time(now, in: entry.timeZone))  ·  \(off)"
        } else {
            return "\(date)  ·  \(off)"
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
