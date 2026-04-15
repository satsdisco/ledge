# ADR-0002: NSPanel (non-activating) over NSWindow

**Status:** Accepted · 2026-04-14

## Context
The notch surface must overlay other apps without stealing focus, must appear in all spaces and on top of full-screen apps, and must not show in the Dock or `⌘-tab`.

## Decision
Subclass `NSPanel`. Configure: `styleMask = [.borderless, .nonactivatingPanel, .fullSizeContentView]`, `level = .statusBar + 1`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]`, `hidesOnDeactivate = false`, `becomesKeyOnlyIfNeeded = true`.

## Alternatives
- `NSWindow` + manual non-activating tweaks: doesn't fully suppress focus stealing on click; loses palette behavior.
- Status item popover: wrong UX, anchored to menu bar position, not notch geometry.

## Consequences
- Panel never activates the app. App activation policy is `.accessory` (no Dock icon) — set explicitly in `AppDelegate`.
- Becoming key for keyboard input requires explicit `makeKeyWindow()` on user interaction (e.g., expanded settings inputs).
- Right-click menus work without focus theft.
