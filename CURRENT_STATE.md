# Ledge — Current State

**Updated:** 2026-04-15
**Phase:** Phase 1 complete. Ready for Phase 2 (File Shelf MVP).

## What exists
- Planning docs (all in `docs/`).
- SwiftPM executable target `Ledge`, macOS 14+.
- Accessory app entry (`LedgeApp`, `AppDelegate`) — no Dock icon, Settings-only scene.
- `RootCoordinator` wiring, `ModuleRegistry` (empty), `LedgeModule` protocol.
- `FeatureFlags` (mediaRemote, syntheticNotch, debugOverlay) with UserDefaults overrides.
- `Log` — `os.Logger` wrapper, subsystem `app.ledge`.
- `Settings/SettingsScene.swift` — three-tab stub (General, Modules, Advanced).
- `Resources/Info.plist` with `LSUIElement = true`.
- `scripts/make-app.sh` — builds + ad-hoc signs `build/Ledge.app`.
- `Window/NotchGeometry.swift` — pure geometry (notch rect + collapsed panel rect with tongue).
- `Window/NotchPanel.swift` — NSPanel subclass (non-activating, borderless, joins all spaces, mainMenu+1 level).
- `Window/DisplayCoordinator.swift` — debounced screen-change + wake listener.
- `Window/PanelManager.swift` — idempotent per-screen panel reconciliation.
- `Debug/DebugOverlay.swift` — toggleable geometry HUD.
- Test files (disabled in Package.swift pending Xcode install) in `Tests/LedgeTests/`.
- Git tags: `v0.0.1-skeleton`, `v0.1.0-panel`.

## Verified
- `swift build` green.
- `./scripts/make-app.sh` produces a launchable `.app`.
- `open build/Ledge.app` runs as accessory (no Dock icon), `⌘,` opens Settings.
- Panel installs at correct notch geometry on built-in Retina (observed: (763, 1034, 185, 73)).
- Red tongue placeholder visible hanging below the hardware notch.
- Unified Logging: `log show --predicate 'subsystem == "app.ledge"' --last 1m`.

## Locked decisions
- Name: **Ledge**
- MVP scope: pluggable host + File Shelf + Now Playing
- Min OS: macOS 14 Sonoma
- Stack: Swift + SwiftUI content + AppKit panel bridge
- Persistence: per-module Codable JSON in Application Support
- Risky APIs: protocol-abstracted, flag-gated, public fallback required
- **Signing:** ad-hoc (`codesign --sign -`) for Phases 0–3; Developer ID + notarization deferred to Phase 4
- **Tooling path:** SwiftPM for Phases 0–2; promote to `.xcodeproj` once full Xcode is installed (needed before Phase 3's KeyboardShortcuts + polish, certainly before Phase 4)

## Outstanding from Phase 1 (deferred, not blocking)
- Tests target disabled. Re-enable after Xcode install.
- Manual display matrix (external notched display, non-notch external with synthetic mode, sleep/wake, full-screen app, Mission Control) not yet run — can only test built-in display right now.

## Next step
**Phase 2 — File Shelf MVP.** `HoverEngine`, `DragRouter`, `NotchExpansionController`, `ModuleStore`, `FileShelfModule` + views + bookmark persistence, drag-out via file URL + file promise.
