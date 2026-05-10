import SwiftUI
import AppKit
import KeyboardShortcuts

struct SettingsScene: View {
    let loginItem: LoginItemService
    let clocksStore: ClocksStore
    let enabledStore: ModuleEnabledStore
    let modulesCatalog: [(id: String, name: String, icon: String)]

    var body: some View {
        TabView {
            GeneralPane(loginItem: loginItem)
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

            Section("Activation") {
                LabeledContent("Toggle expand", value: "⌃⌥Space")
                LabeledContent("Right-click", value: "Module switcher · Settings · Quit")
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
                Picker("", selection: $pickerZoneID) {
                    ForEach(Self.popularZones, id: \.self) { id in
                        Text(ClockEntry.derivedLabel(for: id).capitalized).tag(id)
                    }
                }
                .labelsHidden()
                .frame(width: 180)

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
                       "\u{2318}F, type a few letters \u{2014} pinned matches float to the top. Image entries are searchable by their OCR\u{2019}d text.")
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
