import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let coordinator = RootCoordinator()

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.app.info("Ledge launched")
        coordinator.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator.stop()
    }
}
