import SwiftUI

struct SettingsScene: View {
    let loginItem: LoginItemService
    let clocksStore: ClocksStore

    var body: some View {
        TabView {
            GeneralPane(loginItem: loginItem)
                .tabItem { Label("General", systemImage: "gear") }
            ModulesPane()
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
        .frame(width: 520, height: 380)
    }
}

private struct GeneralPane: View {
    @Bindable var loginItem: LoginItemService

    var body: some View {
        Form {
            Toggle("Launch Ledge at login", isOn: Binding(
                get: { loginItem.isEnabled },
                set: { loginItem.set($0) }
            ))
            Text("Ledge runs as a menu-bar-less accessory. Close the Settings window to send it back to the notch.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

private struct ModulesPane: View {
    var body: some View {
        Form {
            Section("Active modules") {
                HStack { Image(systemName: "tray.full"); Text("File Shelf"); Spacer(); Text("On").foregroundStyle(.secondary) }
                HStack { Image(systemName: "music.note"); Text("Now Playing"); Spacer(); Text("On").foregroundStyle(.secondary) }
                HStack { Image(systemName: "timer"); Text("Timer"); Spacer(); Text("On").foregroundStyle(.secondary) }
                HStack { Image(systemName: "globe"); Text("Clocks"); Spacer(); Text("On").foregroundStyle(.secondary) }
            }
            Text("Per-module disable arrives in a later release. Switch the visible module from the expanded panel.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
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
                Text("World Clocks")
                    .font(.title3.weight(.semibold))
                Spacer()
                Menu {
                    Button("Reset to defaults") { store.resetToDefaults() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            Text("Up to \(ClocksStore.maxEntries) clocks. The first non-local one shows in the collapsed notch.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 12)

            List {
                ForEach(store.entries) { entry in
                    clockRow(entry)
                        .listRowInsets(EdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6))
                }
                .onMove { store.move(from: $0, to: $1) }
            }
            .frame(minHeight: 180)
            .scrollContentBackground(.hidden)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .separatorColor).opacity(0.15))
            )

            addControls
                .padding(.top, 12)
        }
        .padding()
    }

    private func clockRow(_ entry: ClockEntry) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.quaternary)
                Image(systemName: entry.style == .analog ? "clock" : "textformat.123")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(entry.displayLabel)
                    .font(.system(size: 13, weight: .semibold))
                Text(entry.timeZoneIdentifier)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(entry.offsetLabel())
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)

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
            }
            .buttonStyle(.borderless)
        }
    }

    private var addControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Add clock")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Picker("", selection: $pickerZoneID) {
                    ForEach(Self.popularZones, id: \.self) { id in
                        Text(ClockEntry.derivedLabel(for: id).capitalized)
                            .tag(id)
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
                .disabled(store.entries.count >= ClocksStore.maxEntries)
            }
        }
    }
}

private struct ShortcutsPane: View {
    var body: some View {
        Form {
            LabeledContent("Toggle Ledge") {
                Text("⌃⌥Space")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Text("Customizable bindings arrive once Ledge moves to an Xcode project (the shortcut recorder library depends on macro plugins only Xcode ships).")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

private struct AdvancedPane: View {
    var body: some View {
        Form {
            Toggle("Show synthetic notch on non-notch displays",
                   isOn: flagBinding("syntheticNotch"))
            Toggle("Debug overlay",
                   isOn: flagBinding("debugOverlay"))
            Text("Takes effect on next launch.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Divider()
            Button("Open log directory") {
                NSWorkspace.shared.open(FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!.appendingPathComponent("Logs"))
            }
        }
        .padding()
    }

    private func flagBinding(_ key: String) -> Binding<Bool> {
        let full = "ledge.flag.\(key)"
        return Binding(
            get: { UserDefaults.standard.bool(forKey: full) },
            set: { UserDefaults.standard.set($0, forKey: full) }
        )
    }
}

private struct AboutPane: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Ledge").font(.system(size: 22, weight: .semibold))
            Text("A native macOS notch utility.")
                .foregroundStyle(.secondary)
            Text("v0.6.0")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
