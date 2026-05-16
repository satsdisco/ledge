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
                    .font(Typography.glance)
                    .foregroundStyle(Palette.secondary)
                    .tracking(0.5)
                Text(ClocksFormat.time(ticker.now, in: entry.timeZone))
                    .font(Typography.label)
                    .foregroundStyle(Palette.primary)
                    .monospacedDigit()
            } else {
                Image(systemName: "globe")
                    .font(Typography.label)
                    .foregroundStyle(Palette.quaternary)
            }
        }
    }
}

// MARK: - Expanded

struct ClocksExpandedView: View {
    @Bindable var store: ClocksStore
    @Bindable var ticker: ClocksTicker
    @Bindable var scrub: ClocksScrubController
    @Bindable var weather: WeatherStore
    @Bindable var busy: BusyIndex

    /// Two-way-bound draft that the DatePicker edits. We sync it with
    /// `scrub.offsetMinutes` via onChange so all paths (typing, +/− buttons,
    /// arrow keys) stay consistent.
    @State private var draftTime: Date = Date()
    /// Guards against the picker → offset → picker feedback loop.
    @State private var isSyncing = false

    /// Time the tiles should display. Diverges from `ticker.now` only while
    /// the user is scrubbing.
    private var effectiveTime: Date {
        scrub.effectiveTime(realNow: ticker.now)
    }

    /// The clock entry the scrub is anchored on, used to label the source
    /// and feed the DatePicker its display zone.
    private var sourceEntry: ClockEntry? {
        guard let id = scrub.sourceID else { return nil }
        return store.entries.first { $0.id == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            if store.entries.count >= 2 {
                if scrub.isScrubbing {
                    scrubBar
                } else {
                    hintBar
                }
            }
            Group {
                if store.entries.isEmpty {
                    emptyState
                } else {
                    tilesGrid
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Arrow keys drive scrub adjustments (handled only while scrubbing —
        // otherwise the keys pass through). Shift = ±1h, plain = ±15min.
        .onKeyPress(.upArrow,    phases: .down) { keyAdjust(forward: true,  press: $0) }
        .onKeyPress(.rightArrow, phases: .down) { keyAdjust(forward: true,  press: $0) }
        .onKeyPress(.downArrow,  phases: .down) { keyAdjust(forward: false, press: $0) }
        .onKeyPress(.leftArrow,  phases: .down) { keyAdjust(forward: false, press: $0) }
        .onKeyPress(.escape) { keyEscape() }
        .onKeyPress(.return) { keyEscape() }
        .onDisappear { scrub.exit() }
    }

    /// Picks a sensible default source clock — the local timezone if you
    /// have one in your list, otherwise the first entry.
    private func defaultScrubAnchor() -> UUID? {
        let local = TimeZone.current.identifier
        return (store.entries.first { $0.timeZoneIdentifier == local } ?? store.entries.first)?.id
    }

    private func keyAdjust(forward: Bool, press: KeyPress) -> KeyPress.Result {
        guard scrub.isScrubbing else { return .ignored }
        let step = press.modifiers.contains(.shift) ? 60 : 15
        scrub.adjust(by: forward ? step : -step)
        return .handled
    }

    private func keyEscape() -> KeyPress.Result {
        guard scrub.isScrubbing else { return .ignored }
        scrub.exit()
        return .handled
    }

    /// Discoverable affordance shown when not converting — explains what
    /// happens if you tap a tile, plus a one-click "Convert" entry.
    private var hintBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.arrow.2.circlepath")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Palette.tertiary)
            Text("Tap a clock to convert a time across zones")
                .font(Typography.caption)
                .foregroundStyle(Palette.tertiary)
            Spacer()
            Button {
                if let anchor = defaultScrubAnchor() {
                    scrub.toggle(anchor)
                }
            } label: {
                Text("Convert")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Palette.highlight))
            }
            .buttonStyle(.plain)
            .help("Pick a time in any zone and see it in all your others")
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 6)
    }

    /// Time-conversion bar: the source clock's name + a typeable DatePicker
    /// for setting the source's wall time, plus quick step / reset / done
    /// controls. Type "3pm" in the Dubai source → all other tiles flip to
    /// the equivalent in their zones. Step buttons remain for nudging.
    private var scrubBar: some View {
        HStack(spacing: 8) {
            if let entry = sourceEntry {
                Text(entry.displayLabel)
                    .font(Typography.label)
                    .foregroundStyle(Palette.accent)
                    .tracking(0.6)
                Image(systemName: "arrow.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Palette.tertiary)
            }

            // `.field` style edits in place — no popover means clicking
            // doesn't bounce the cursor outside the Ledge panel (which would
            // trigger our hover engine to collapse). Just hour and minute;
            // the source-zone interpretation comes from the environment.
            DatePicker("", selection: $draftTime, displayedComponents: [.hourAndMinute])
                .datePickerStyle(.field)
                .labelsHidden()
                .environment(\.timeZone, sourceEntry?.timeZone ?? .current)
                .fixedSize()

            stepButton("minus", help: "Back 15 min") { scrub.adjust(by: -15) }
            stepButton("plus",  help: "Forward 15 min") { scrub.adjust(by: 15) }

            Spacer()

            chipButton("Now",  help: "Reset to current time") { scrub.resetOffsetToNow() }
            chipButton("Done", help: "Exit comparison mode", primary: true) { scrub.exit() }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 6)
        // Sync picker ↔ controller: when user picks a new time, recompute
        // offset; when the offset changes from buttons/keys, mirror it in
        // the picker. The isSyncing flag breaks the resulting feedback loop.
        .onChange(of: draftTime) { _, new in
            guard !isSyncing else { return }
            scrub.setOffset(toDisplay: new, realNow: ticker.now)
        }
        .onChange(of: scrub.offsetMinutes) { _, _ in
            let displayed = scrub.effectiveTime(realNow: ticker.now)
            if abs(displayed.timeIntervalSince(draftTime)) >= 1 {
                isSyncing = true
                draftTime = displayed
                DispatchQueue.main.async { isSyncing = false }
            }
        }
        .onChange(of: scrub.sourceID) { _, _ in
            isSyncing = true
            draftTime = scrub.effectiveTime(realNow: ticker.now)
            DispatchQueue.main.async { isSyncing = false }
        }
    }

    private func stepButton(_ icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Palette.primary)
                .frame(width: 22, height: 20)
                .background(Capsule().fill(Palette.highlight))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func chipButton(_ label: String, help: String, primary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(primary ? Palette.primary : Palette.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Capsule().fill(primary ? Palette.highlight : Palette.separator))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var tilesGrid: some View {
        // ≤4 clocks: one row, one column per clock.
        // 5–6 clocks: 3 columns × 2 rows (5 → 3+2, 6 → 3+3) — more balanced
        // than 4+1 or 4+2.
        let count = store.entries.count
        let columnCount = count <= 4 ? max(1, count) : 3
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: columnCount)
        // Only render the busy/free chip while scrubbing — at the live time
        // the user already knows whether they're in a meeting. Pre-compute
        // once so every tile gets the same answer for a given scrub instant.
        let busyAtScrub: Bool? = scrub.isScrubbing ? busy.isBusy(at: effectiveTime) : nil
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(store.entries) { entry in
                ClockTileView(
                    entry: entry,
                    now: effectiveTime,
                    isScrubSource: scrub.sourceID == entry.id,
                    weather: weather.snapshots[entry.timeZoneIdentifier],
                    busyAtScrub: busyAtScrub,
                    onTap: { scrub.toggle(entry.id) }
                )
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "globe")
                .font(.system(size: 22))
                .foregroundStyle(Palette.quaternary)
            Text("Add clocks in Settings → Clocks")
                .font(Typography.body)
                .foregroundStyle(Palette.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Tile

private struct ClockTileView: View {
    let entry: ClockEntry
    let now: Date
    let isScrubSource: Bool
    let weather: WeatherSnapshot?
    /// nil = not scrubbing (don't render). true = user is busy at the scrubbed
    /// instant. false = user is free. Identical across tiles because the
    /// underlying moment is the same — only the wall-clock rendering differs.
    let busyAtScrub: Bool?
    let onTap: () -> Void

    private var isLocal: Bool {
        entry.timeZone?.secondsFromGMT() == TimeZone.current.secondsFromGMT()
    }

    var body: some View {
        VStack(spacing: 6) {
            face
                .frame(width: 72, height: 72)
                .overlay(sourceRing)

            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    if isLocal {
                        // Green "you are here" — kept distinct from Palette.accent
                        // (pink) so the active-state signal doesn't compete with
                        // kinetic accents like the seconds hand.
                        Circle()
                            .fill(.green.opacity(0.85))
                            .frame(width: 5, height: 5)
                    }
                    Text(entry.displayLabel)
                        .font(Typography.label)
                        .foregroundStyle(isScrubSource ? Palette.accent : Palette.primary)
                        .tracking(0.8)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Text(metaLine)
                    .font(Typography.meta)
                    .foregroundStyle(Palette.tertiary)
                    .lineLimit(1)
                if let weather {
                    HStack(spacing: 3) {
                        Image(systemName: weather.iconName)
                            .font(.system(size: 9, weight: .medium))
                        Text("\(Int(weather.temperatureCelsius.rounded()))°")
                            .font(Typography.meta)
                            .monospacedDigit()
                    }
                    .foregroundStyle(Palette.secondary)
                }
                if let busyAtScrub {
                    busyChip(busy: busyAtScrub)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .help(isScrubSource ? "Click to exit scrub" : "Click to scrub from this zone")
    }

    /// Ring drawn around the face when this tile is the scrub source.
    /// Shape matches the face: full circle for analog, rounded rect for digital.
    @ViewBuilder
    private var sourceRing: some View {
        if isScrubSource {
            if entry.style == .analog {
                Circle().strokeBorder(Palette.accent, lineWidth: 1.5)
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Palette.accent, lineWidth: 1.5)
            }
        }
    }

    @ViewBuilder
    private var face: some View {
        if entry.style == .analog, let tz = entry.timeZone {
            AnalogClockView(date: now, timeZone: tz, diameter: 72)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Palette.card)
                Text(ClocksFormat.time(now, in: entry.timeZone))
                    .font(Typography.display)
                    .foregroundStyle(Palette.primary)
                    .monospacedDigit()
                    .tracking(-0.5)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.12), value: now)
            }
        }
    }

    /// Busy = pink pill with label (loud, because a conflict is the
    /// surprising answer). Free = tiny green dot with a quiet "free" label
    /// — present so the absence of a busy pill doesn't read as "no data".
    @ViewBuilder
    private func busyChip(busy: Bool) -> some View {
        if busy {
            HStack(spacing: 3) {
                Circle()
                    .fill(Palette.accent)
                    .frame(width: 4, height: 4)
                Text("busy")
                    .font(Typography.glance)
                    .foregroundStyle(Palette.accent)
                    .tracking(0.4)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(Capsule().fill(Palette.accent.opacity(0.16)))
        } else {
            HStack(spacing: 3) {
                Circle()
                    .fill(.green.opacity(0.85))
                    .frame(width: 4, height: 4)
                Text("free")
                    .font(Typography.glance)
                    .foregroundStyle(Palette.tertiary)
                    .tracking(0.4)
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
