import AppKit

/// Observes display-topology changes and sleep/wake, and invokes `onChange`
/// with the current set of screens (debounced 150ms to survive reconfig storms).
final class DisplayCoordinator {
    private let onChange: ([ScreenDescriptor]) -> Void
    private var pendingWork: DispatchWorkItem?
    private let debounceInterval: TimeInterval

    init(debounce: TimeInterval = 0.15, onChange: @escaping ([ScreenDescriptor]) -> Void) {
        self.debounceInterval = debounce
        self.onChange = onChange
    }

    func start() {
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(screensChanged),
                       name: NSApplication.didChangeScreenParametersNotification,
                       object: nil)

        let wnc = NSWorkspace.shared.notificationCenter
        wnc.addObserver(self, selector: #selector(didWake),
                        name: NSWorkspace.didWakeNotification, object: nil)

        schedule(reason: "initial")
    }

    func stop() {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        pendingWork?.cancel()
    }

    @objc private func screensChanged() { schedule(reason: "didChangeScreenParameters") }
    @objc private func didWake()       { schedule(reason: "didWake") }

    private func schedule(reason: String) {
        pendingWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let descriptors = NSScreen.descriptors
            Log.display.info("Display refresh (\(reason, privacy: .public)): \(descriptors.count) screen(s)")
            self.onChange(descriptors)
        }
        pendingWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }
}
