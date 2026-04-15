import SwiftUI

struct SettingsScene: View {
    let loginItem: LoginItemService

    var body: some View {
        TabView {
            GeneralPane(loginItem: loginItem)
                .tabItem { Label("General", systemImage: "gear") }
            ModulesPane()
                .tabItem { Label("Modules", systemImage: "square.grid.2x2") }
            ShortcutsPane()
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
            AdvancedPane()
                .tabItem { Label("Advanced", systemImage: "wrench.and.screwdriver") }
            AboutPane()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 480, height: 320)
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
                HStack {
                    Image(systemName: "tray.full")
                    Text("File Shelf")
                    Spacer()
                    Text("On").foregroundStyle(.secondary)
                }
                HStack {
                    Image(systemName: "music.note")
                    Text("Now Playing")
                    Spacer()
                    Text("On").foregroundStyle(.secondary)
                }
            }
            Text("Per-module enable/disable arrives in a later release. Switch which module is shown in the notch from the expanded panel.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
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
            Text("v0.4.0")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
