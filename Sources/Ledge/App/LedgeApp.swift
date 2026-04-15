import SwiftUI

@main
struct LedgeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsScene(
                loginItem: appDelegate.coordinator.loginItem,
                clocksStore: appDelegate.coordinator.clocksStore,
                enabledStore: appDelegate.coordinator.enabledStore,
                modulesCatalog: appDelegate.coordinator.modulesCatalog
            )
        }
    }
}
