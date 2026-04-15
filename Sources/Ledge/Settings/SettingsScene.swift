import SwiftUI

struct SettingsScene: View {
    var body: some View {
        TabView {
            GeneralPane()
                .tabItem { Label("General", systemImage: "gear") }
            ModulesPane()
                .tabItem { Label("Modules", systemImage: "square.grid.2x2") }
            AdvancedPane()
                .tabItem { Label("Advanced", systemImage: "wrench.and.screwdriver") }
        }
        .frame(width: 480, height: 320)
    }
}

private struct GeneralPane: View {
    var body: some View {
        Form {
            Text("Hello, Ledge.")
                .font(.title3)
            Text("Phase 0 skeleton. Modules and panel will arrive in later phases.")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

private struct ModulesPane: View {
    var body: some View {
        Form {
            Text("No modules registered yet.")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

private struct AdvancedPane: View {
    var body: some View {
        Form {
            Toggle("Use MediaRemote (gray API)",
                   isOn: .constant(FeatureFlags.mediaRemote))
                .disabled(true)
            Toggle("Show synthetic notch on non-notch displays",
                   isOn: .constant(FeatureFlags.syntheticNotch))
                .disabled(true)
            Toggle("Debug overlay",
                   isOn: .constant(FeatureFlags.debugOverlay))
                .disabled(true)
            Text("Toggles become live in Phase 3.")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
        .padding()
    }
}
