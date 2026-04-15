# ADR-0007: Accessory app, login-item via SMAppService, no Dock or main window

**Status:** Accepted · 2026-04-14

## Context
Ledge is a background utility. It must not appear in the Dock, must not steal focus, must auto-launch at login, and must survive sleep/wake cleanly.

## Decision
- `Info.plist`: `LSUIElement = true` (accessory app, no Dock icon, no menu bar app menu).
- `NSApplication.shared.setActivationPolicy(.accessory)` set explicitly in `AppDelegate.applicationWillFinishLaunching`.
- Login item via `SMAppService.mainApp` (modern API, macOS 13+). User toggleable in Settings.
- No primary `WindowGroup`; only the AppKit panels and a SwiftUI Settings scene shown via `NSApp.activate()` + `openSettings`-style command.
- Lifecycle hooks:
  - `applicationDidFinishLaunching` → build registry, restore module state, build panels.
  - `NSWorkspace.didWakeNotification` → rebuild panels (defensive).
  - `NSWorkspace.willSleepNotification` → flush stores.
  - `NSApplication.willTerminateNotification` → flush stores + tear down panels.

## Alternatives
- Menu-bar app with `NSStatusItem` only: doesn't give us the notch surface.
- Background launch agent (`launchd` plist): heavier, less user-controllable than `SMAppService`.

## Consequences
- Cleaner system citizen: invisible until needed, recoverable across sleep.
- Settings window is the only "real" window the user ever sees; must be polished accordingly.
- No `⌘Q` from menu bar by default — provide quit affordance in Settings and via right-click on the notch panel.
