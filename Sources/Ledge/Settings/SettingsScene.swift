import SwiftUI
import AppKit
import KeyboardShortcuts

struct SettingsScene: View {
    let loginItem: LoginItemService
    let updater: UpdaterService
    let expansion: NotchExpansionController
    let clocksStore: ClocksStore
    let enabledStore: ModuleEnabledStore
    let modulesCatalog: [(id: String, name: String, icon: String)]

    var body: some View {
        TabView {
            GeneralPane(loginItem: loginItem, updater: updater, expansion: expansion)
                .tabItem { Label("General", systemImage: "gear") }
            ModulesPane(enabled: enabledStore, catalog: modulesCatalog)
                .tabItem { Label("Modules", systemImage: "square.grid.2x2") }
            ClocksPane(store: clocksStore)
                .tabItem { Label("Clocks", systemImage: "globe") }
            ShortcutsPane()
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
            AdvancedPane()
                .tabItem { Label("Advanced", systemImage: "wrench.and.screwdriver") }
            AboutPane()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 540, height: 420)
    }
}

// MARK: - General

private struct GeneralPane: View {
    @Bindable var loginItem: LoginItemService
    @Bindable var updater: UpdaterService
    @Bindable var expansion: NotchExpansionController

    var body: some View {
        Form {
            Section {
                Toggle("Launch Ledge at login", isOn: Binding(
                    get: { loginItem.isEnabled },
                    set: { loginItem.set($0) }
                ))
            } footer: {
                Text("Ledge runs as a menu-bar-less accessory. Close this window to send it back to the notch.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent("Toggle expand", value: "⌃⌥Space")
                LabeledContent("Right-click", value: "Module switcher · Settings · Quit")
                    .foregroundStyle(.secondary)

                Picker("Hover sensitivity", selection: $expansion.enterDelay) {
                    Text("Instant").tag(0.0)
                    Text("Default").tag(0.12)
                    Text("Relaxed").tag(0.40)
                    Text("Patient").tag(0.80)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Activation")
            } footer: {
                Text("How long the cursor must rest on the notch before the panel expands. Default opens almost immediately; Relaxed and Patient prevent accidental expansions when reaching for the menu bar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Check for updates automatically", isOn: Binding(
                    get: { updater.automaticallyChecksForUpdates },
                    set: { updater.automaticallyChecksForUpdates = $0 }
                ))
                HStack {
                    Button("Check Now\u{2026}") { updater.checkForUpdates() }
                        .disabled(!updater.canCheckForUpdates)
                    Spacer()
                    if let last = updater.lastUpdateCheckDate {
                        Text("Last checked \(last.formatted(.relative(presentation: .named)))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Updates")
            } footer: {
                Text("Updates are signed and delivered via Sparkle. The app will only install releases signed with Ledge\u{2019}s private key.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Modules

private struct ModulesPane: View {
    @Bindable var enabled: ModuleEnabledStore
    let catalog: [(id: String, name: String, icon: String)]

    var body: some View {
        Form {
            Section {
                ForEach(catalog, id: \.id) { item in
                    Toggle(isOn: Binding(
                        get: { enabled.isEnabled(item.id) },
                        set: { enabled.setEnabled(item.id, $0) }
                    )) {
                        Label {
                            Text(item.name).font(.body)
                        } icon: {
                            Image(systemName: item.icon)
                                .foregroundStyle(.tint)
                        }
                    }
                }
            } header: {
                Text("Available modules")
            } footer: {
                Text("Disabled modules disappear from the segmented header and the right-click menu. Each module's data is preserved when you re-enable it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Clocks

private struct ClocksPane: View {
    @Bindable var store: ClocksStore
    @State private var pickerZoneID: String = Self.popularZones.first ?? "UTC"
    @State private var pickerLabel: String = ""
    @State private var pickerStyle: ClockEntry.Style = .analog

    private static let popularZones: [String] = {
        let pref: [String] = [
            "UTC",
            "America/New_York", "America/Los_Angeles", "America/Chicago", "America/Denver",
            "America/Sao_Paulo", "America/Mexico_City",
            "Europe/London", "Europe/Paris", "Europe/Berlin", "Europe/Madrid", "Europe/Amsterdam",
            "Asia/Tokyo", "Asia/Shanghai", "Asia/Singapore", "Asia/Hong_Kong",
            "Asia/Kolkata", "Asia/Dubai",
            "Australia/Sydney", "Pacific/Auckland"
        ]
        let all = Set(TimeZone.knownTimeZoneIdentifiers)
        return pref.filter(all.contains)
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("World Clocks")
                        .font(.title3.weight(.semibold))
                    Text("Up to \(ClocksStore.maxEntries). The first non-local clock shows in the collapsed notch.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Button("Reset to defaults") { store.resetToDefaults() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(.bottom, 12)

            List {
                ForEach(store.entries) { entry in
                    clockRow(entry)
                        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                }
                .onMove { store.move(from: $0, to: $1) }
            }
            .frame(minHeight: 200)
            .scrollContentBackground(.hidden)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.25))
            )

            addControls.padding(.top, 12)
        }
        .padding()
    }

    private func clockRow(_ entry: ClockEntry) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(.quaternary)
                Image(systemName: entry.style == .analog ? "clock" : "textformat.123")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(entry.displayLabel).font(.system(size: 13, weight: .semibold))
                Text(entry.timeZoneIdentifier).font(.system(size: 10)).foregroundStyle(.secondary)
            }

            Spacer()

            Text(entry.offsetLabel())
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)

            Picker("", selection: Binding(
                get: { entry.style },
                set: { store.setStyle($0, for: entry) }
            )) {
                Image(systemName: "clock").tag(ClockEntry.Style.analog)
                Image(systemName: "textformat.123").tag(ClockEntry.Style.digital)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 70)

            Button {
                store.remove(entry)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red.opacity(0.65))
                    .font(.system(size: 14))
            }
            .buttonStyle(.borderless)
        }
    }

    private var addControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Add a clock")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.3)
            HStack(spacing: 8) {
                TimeZonePickerButton(
                    selection: $pickerZoneID,
                    popularZones: Self.popularZones
                )
                .frame(width: 200)

                TextField("Label (optional)", text: $pickerLabel)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)

                Picker("", selection: $pickerStyle) {
                    Image(systemName: "clock").tag(ClockEntry.Style.analog)
                    Image(systemName: "textformat.123").tag(ClockEntry.Style.digital)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 70)

                Button("Add") {
                    let label = pickerLabel.trimmingCharacters(in: .whitespaces)
                    store.add(ClockEntry(
                        timeZoneIdentifier: pickerZoneID,
                        label: label.isEmpty ? nil : label,
                        style: pickerStyle
                    ))
                    pickerLabel = ""
                }
                .keyboardShortcut(.return)
                .disabled(store.entries.count >= ClocksStore.maxEntries)
            }
        }
    }
}

// MARK: - Time zone picker

/// Button-style timezone picker. Tapping opens a popover with a search
/// field and the full list of `TimeZone.knownTimeZoneIdentifiers` (~600
/// zones), plus a "Popular" section at the top for the common ones.
private struct TimeZonePickerButton: View {
    @Binding var selection: String
    let popularZones: [String]
    @State private var open = false

    var body: some View {
        Button {
            open = true
        } label: {
            HStack(spacing: 6) {
                Text(displayCity)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                Spacer(minLength: 4)
                Text(offsetString(for: selection))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(.quaternary, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $open, arrowEdge: .bottom) {
            TimeZonePickerPopover(
                selection: $selection,
                isPresented: $open,
                popularZones: popularZones
            )
        }
    }

    private var displayCity: String {
        let tail = selection.split(separator: "/").last.map(String.init) ?? selection
        return tail.replacingOccurrences(of: "_", with: " ")
    }
}

private struct TimeZonePickerPopover: View {
    @Binding var selection: String
    @Binding var isPresented: Bool
    let popularZones: [String]
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private var allZones: [String] { TimeZone.knownTimeZoneIdentifiers.sorted() }

    private var filteredAll: [String] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return allZones }
        return allZones.filter { $0.lowercased().replacingOccurrences(of: "_", with: " ").contains(q) }
    }

    private var filteredPopular: [String] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return popularZones }
        return popularZones.filter { $0.lowercased().replacingOccurrences(of: "_", with: " ").contains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                TextField("Search any city or region", text: $query)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    if !filteredPopular.isEmpty {
                        Section {
                            ForEach(filteredPopular, id: \.self) { tz in
                                row(tz)
                            }
                        } header: {
                            sectionHeader("Popular")
                        }
                    }
                    Section {
                        ForEach(filteredAll, id: \.self) { tz in
                            row(tz)
                        }
                    } header: {
                        sectionHeader(filteredAll.count == allZones.count ? "All zones" : "\(filteredAll.count) match\(filteredAll.count == 1 ? "" : "es")")
                    }
                }
            }
        }
        .frame(width: 360, height: 420)
        .onAppear { searchFocused = true }
    }

    private func row(_ tz: String) -> some View {
        let isSelected = selection == tz
        return Button {
            selection = tz
            isPresented = false
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(displayCityName(tz))
                        .foregroundStyle(.primary)
                    Text(tz.replacingOccurrences(of: "_", with: " "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(offsetString(for: tz))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tint)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.accentColor.opacity(0.12) : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 9, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))
    }

    private func displayCityName(_ tz: String) -> String {
        let tail = tz.split(separator: "/").last.map(String.init) ?? tz
        return tail.replacingOccurrences(of: "_", with: " ")
    }
}

private func offsetString(for tzID: String) -> String {
    guard let tz = TimeZone(identifier: tzID) else { return "" }
    let offset = tz.secondsFromGMT()
    let hours = offset / 3600
    let mins = abs(offset % 3600) / 60
    let sign = hours >= 0 ? "+" : ""
    if mins == 0 { return "GMT\(sign)\(hours)" }
    return String(format: "GMT%@%d:%02d", sign, hours, mins)
}

// MARK: - Shortcuts

private struct ShortcutsPane: View {
    var body: some View {
        Form {
            Section {
                KeyboardShortcuts.Recorder("Toggle Ledge", name: .toggleLedge)
                KeyboardShortcuts.Recorder("Capture clipboard", name: .captureClipboard)
            } header: {
                Text("Global shortcuts")
            } footer: {
                Text("Active anywhere. Click a recorder to rebind \u{2014} press the new combination, or double-click to clear.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                shortcutRow("\u{2191} \u{2193}", "Move selection up / down")
                shortcutRow("\u{23CE}", "Copy the selected entry & collapse the notch")
                shortcutRow("space", "Quick Look the selected entry")
                shortcutRow("\u{2318} 1\u{2013}9", "Copy the Nth visible entry")
                shortcutRow("\u{2318} F", "Focus the search field")
                shortcutRow("\u{2326}", "Remove the selected entry")
                shortcutRow("\u{238B}", "Clear search / cancel edit")
            } header: {
                Text("Inside the Clipboard panel")
            } footer: {
                Text("These keys work after you click anywhere inside the expanded notch \u{2014} that hands keyboard focus to Ledge. Hover-only stays ambient and never steals focus from your active app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                tipRow("doc.on.clipboard",
                       "Three ways to stash",
                       "Press \u{2303}\u{2325}V, click \u{201C}Capture\u{201D} in the panel, or drag any text / image / file onto the notch.")
                tipRow("rectangle.and.text.magnifyingglass",
                       "Search before you scroll",
                       "\u{2318}F, type a few letters \u{2014} pinned matches float to the top.")
                tipRow("pencil",
                       "Turn entries into snippets",
                       "Hover an entry and click the pencil (or right-click \u{2192} Edit) to rename and tweak. Pin it so it survives \u{201C}Clear\u{201D}.")
                tipRow("eye",
                       "Quick Look anything",
                       "Select a row and press space \u{2014} works for long text, full-size images, and files.")
                tipRow("lock.shield",
                       "Concealed clipboards are skipped",
                       "If 1Password / Bitwarden mark the clipboard as concealed, \u{2303}\u{2325}V will flash \u{201C}Skipped\u{201D} instead of stashing the secret.")
            } header: {
                Text("Tips")
            }
        }
        .formStyle(.grouped)
    }

    private func shortcutRow(_ key: String, _ desc: String) -> some View {
        HStack {
            Text(key)
                .font(.system(.body, design: .monospaced).weight(.semibold))
                .frame(minWidth: 70, alignment: .leading)
            Text(desc)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func tipRow(_ icon: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .frame(width: 18)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.medium))
                Text(body).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Advanced

private struct AdvancedPane: View {
    var body: some View {
        Form {
            Section("Display") {
                Toggle("Show on non-notch displays (synthetic notch)",
                       isOn: flagBinding("syntheticNotch"))
            }
            Section {
                Toggle("Debug overlay", isOn: flagBinding("debugOverlay"))
                Button("Open log directory") {
                    let logs = FileManager.default
                        .urls(for: .libraryDirectory, in: .userDomainMask).first!
                        .appendingPathComponent("Logs")
                    NSWorkspace.shared.open(logs)
                }
                Button("Open application support directory") {
                    let support = FileManager.default
                        .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                        .appendingPathComponent("Ledge")
                    NSWorkspace.shared.open(support)
                }
            } header: {
                Text("Diagnostics")
            } footer: {
                Text("Display changes take effect on next launch.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func flagBinding(_ key: String) -> Binding<Bool> {
        let full = "ledge.flag.\(key)"
        return Binding(
            get: { UserDefaults.standard.bool(forKey: full) },
            set: { UserDefaults.standard.set($0, forKey: full) }
        )
    }
}

// MARK: - About

private struct AboutPane: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }
    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 8)
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(
                        colors: [.black.opacity(0.85), Color(nsColor: .windowBackgroundColor)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                Image(systemName: "rectangle.portrait.topthird.inset.filled")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(.white.opacity(0.92))
            }
            .frame(width: 92, height: 92)
            .shadow(color: .black.opacity(0.2), radius: 8, y: 2)

            VStack(spacing: 2) {
                Text("Ledge").font(.system(size: 22, weight: .semibold))
                Text("A native macOS notch utility")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 2) {
                Text("Version \(version) (build \(build))")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Text("© 2026 satsdisco")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
