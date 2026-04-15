import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let coordinator = RootCoordinator()

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.app.info("Ledge launched")
        coordinator.start()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator.stop()
    }

    /// When the Settings window (or any non-NotchPanel window) closes and no
    /// other user-facing windows remain, drop back to accessory mode so we
    /// disappear from Dock/⌘-tab again.
    @objc private func windowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSWindow,
              !(closing is NotchPanel) else { return }
        DispatchQueue.main.async {
            let anyVisibleRegular = NSApp.windows.contains { w in
                w !== closing && w.isVisible && !(w is NotchPanel)
            }
            if !anyVisibleRegular && NSApp.activationPolicy() != .accessory {
                NSApp.setActivationPolicy(.accessory)
                Log.app.debug("Activation policy -> .accessory")
            }
        }
    }
}
