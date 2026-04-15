# Ledge — System Architecture

## Layering

```
App Shell        (LedgeApp, AppDelegate, RootCoordinator)
Window Layer     (NotchPanel, PanelManager, DisplayCoordinator, NotchGeometry)
Interaction      (HoverEngine, DragRouter, KeyboardShortcutCenter, NotchExpansionController)
Module Host      (LedgeModule, ModuleRegistry, ModuleSlot, ModuleStore)
Modules          (FileShelf, NowPlaying, ...)
Services         (Persistence, Logging, Permissions, MediaController, LoginItem, FeatureFlags)
```

Strict downward dependency rule. Modules never reach into the window layer; they declare intent via the module protocol.

## Window/panel strategy
- `NSPanel` subclass: `nonactivatingPanel`, `.fullSizeContentView`, `.borderless`, `level = .statusBar + 1`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`.
- One panel per screen with a notch (or per screen if user opts in for non-notch). Owned by `PanelManager`.
- `DisplayCoordinator` listens to `NSApplication.didChangeScreenParametersNotification` and rebuilds panels idempotently. Debounced 150ms.
- Notch geometry resolved via `NSScreen.safeAreaInsets`. Synthetic notch rect fallback for non-notch screens.

## Module protocol (sketch)

```swift
protocol LedgeModule: AnyObject {
    static var identifier: String { get }
    var displayName: String { get }
    var collapsedView: AnyView { get }
    var expandedView: AnyView { get }
    var acceptsDrops: Bool { get }
    func handleDrop(_ providers: [NSItemProvider]) -> Bool
    func didActivate()
    func willDeactivate()
}
```

Modules own their state via an `ObservableObject` view-model, persist through an injected `ModuleStore` (typed Codable), never touch `NSPanel`/`NSScreen`/shortcuts directly.

## State management
- SwiftUI + `@Observable` for view state.
- Small `AppState` actor for cross-module coordination (active module, expansion state).
- Per-module Codable blobs in Application Support, atomic writes.
- No Core Data / SwiftData for MVP.

## Animation
- Single `NotchExpansionController` driving SwiftUI `matchedGeometryEffect` between collapsed and expanded layouts.
- Spring presets centralized in `Motion.swift`. No ad-hoc `.animation` calls in modules.

## Permissions
- File Shelf: security-scoped bookmarks for retained URLs.
- Now Playing: try `MediaRemote` (gray, behind `FeatureFlag.mediaRemote`); fall back to AppleScript control of Music/Spotify. Both behind `MediaController` protocol.
- No accessibility / input monitoring / screen recording in MVP. Request lazily on first use, never at launch.

## Feature flags
- Compile-time `FeatureFlags.swift` enum + runtime override via Settings (developer pane).
- All risky/private-API code gated. A flipped flag must produce graceful degraded mode, never a crash.

## Logging & debug
- `os.Logger` subsystem `app.ledge`, per-layer categories (`window`, `module.fileshelf`, `media`, ...).
- Hidden debug overlay (⌃⌥⌘D): screen list, active panels, module states.

## Test strategy
- Unit: persistence round-trips, module registry, display geometry, drag payload conversion, media controller fallback selection.
- Snapshot: collapsed/expanded module views (light/dark, compact/wide).
- Scripted "screen dance" harness simulating display reconfigs via injected `DisplayCoordinatorEnvironment`.

## Folder structure

```
Ledge/
├── App/
│   ├── LedgeApp.swift
│   ├── AppDelegate.swift
│   └── RootCoordinator.swift
├── Window/
│   ├── NotchPanel.swift
│   ├── PanelManager.swift
│   ├── DisplayCoordinator.swift
│   └── NotchGeometry.swift
├── Interaction/
│   ├── HoverEngine.swift
│   ├── DragRouter.swift
│   ├── KeyboardShortcutCenter.swift
│   └── NotchExpansionController.swift
├── ModuleHost/
│   ├── LedgeModule.swift
│   ├── ModuleRegistry.swift
│   ├── ModuleSlot.swift
│   └── ModuleStore.swift
├── Modules/
│   ├── FileShelf/
│   └── NowPlaying/
├── Services/
│   ├── Persistence/
│   ├── Logging/
│   ├── Permissions/
│   ├── LoginItem/
│   └── FeatureFlags.swift
├── DesignSystem/
│   ├── Motion.swift
│   ├── Palette.swift
│   ├── Typography.swift
│   └── Spacing.swift
├── Settings/
│   ├── SettingsScene.swift
│   └── Panes/
├── Debug/
│   └── DebugOverlay.swift
├── Resources/Assets.xcassets
└── Tests/
    ├── LedgeUnitTests/
    └── LedgeSnapshotTests/
```

## Key risks
1. **MediaRemote private.** Mitigation: protocol abstraction + AppleScript fallback + flag.
2. **Notch geometry on non-notch displays.** `safeAreaInsets` is zero. Synthetic rect; setting to disable on non-notch.
3. **Spaces / full-screen.** Panel collection behavior must include `.fullScreenAuxiliary`. Test matrix: full-screen Safari, Xcode, Mission Control.
4. **Sleep/wake panel desync.** `DisplayCoordinator` rebuilds on `NSWorkspace.didWakeNotification`.
