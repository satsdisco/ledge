import Foundation

/// Top-level orchestrator. Owns registry, expansion controller, active-module
/// store, login item, panel manager, and display coordinator.
final class RootCoordinator {
    let loginItem = LoginItemService()
    let updater = UpdaterService()

    private let registry = ModuleRegistry()
    private let expansion = NotchExpansionController()
    private lazy var env = ModuleEnvironment(expansion: expansion)
    private lazy var fileShelf = FileShelfModule(environment: env)
    private lazy var nowPlaying = NowPlayingModule(environment: env)
    private lazy var timer = TimerModule(environment: env)
    private lazy var clocks = ClocksModule(environment: env)
    private lazy var bitcoin = BitcoinPriceModule(environment: env)
    private lazy var clipboard = ClipboardModule(environment: env)
    private lazy var notes = NotesModule(environment: env)
    private lazy var calendar = CalendarModule(environment: env)

    private static let allModuleIDs: [String] = [
        FileShelfModule.identifier,
        NowPlayingModule.identifier,
        TimerModule.identifier,
        ClocksModule.identifier,
        BitcoinPriceModule.identifier,
        ClipboardModule.identifier,
        NotesModule.identifier,
        CalendarModule.identifier
    ]

    /// Exposed for Settings UI so it can edit the clocks list live.
    var clocksStore: ClocksStore { clocks.store }
    /// Exposed for Settings UI so the user can tune hover sensitivity.
    var notchExpansion: NotchExpansionController { expansion }
    let enabledStore = ModuleEnabledStore(allIDs: RootCoordinator.allModuleIDs)
    private lazy var active = ActiveModuleStore(
        defaultID: FileShelfModule.identifier,
        availableIDs: RootCoordinator.allModuleIDs
    )
    private lazy var panels = PanelManager(
        expansion: expansion,
        active: active,
        enabled: enabledStore,
        modules: [fileShelf, nowPlaying, timer, clocks, bitcoin, clipboard, notes, calendar]
    )

    /// Display info for Settings to render the modules list with names + icons.
    var modulesCatalog: [(id: String, name: String, icon: String)] {
        [
            (FileShelfModule.identifier,    "File Shelf",  "tray.full"),
            (NowPlayingModule.identifier,   "Now Playing", "music.note"),
            (TimerModule.identifier,        "Timer",       "timer"),
            (ClocksModule.identifier,       "Clocks",      "globe"),
            (BitcoinPriceModule.identifier, "Bitcoin",     "bitcoinsign.circle"),
            (ClipboardModule.identifier,    "Clipboard",   "doc.on.clipboard"),
            (NotesModule.identifier,        "Notes",       "square.and.pencil"),
            (CalendarModule.identifier,     "Calendar",    "calendar")
        ]
    }
    private lazy var displays = DisplayCoordinator { [weak self] screens in
        self?.panels.reconcile(with: screens)
    }
    private lazy var shortcuts = KeyboardShortcutCenter(
        expansion: expansion,
        onCaptureClipboard: { [weak self] in self?.clipboard.captureFromSystemClipboard() }
    )

    func start() {
        _ = updater  // ensure Sparkle's background scheduler is alive
        // Grow / shrink the panel when the user adds or removes a clock.
        clocks.store.onCountChange = { [weak self] in self?.panels.relayoutIfNeeded() }
        registry.register(fileShelf)
        registry.register(nowPlaying)
        registry.register(timer)
        registry.register(clocks)
        registry.register(bitcoin)
        registry.register(clipboard)
        registry.register(notes)
        registry.register(calendar)
        registry.bootstrap()
        _ = shortcuts
        displays.start()
        Log.app.debug("RootCoordinator started; \(self.registry.count) module(s) registered")
    }

    func stop() {
        displays.stop()
        panels.tearDown()
        Log.app.debug("RootCoordinator stopping")
    }
}
