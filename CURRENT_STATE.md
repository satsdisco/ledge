# Ledge — Current State

**Updated:** 2026-04-15
**Phase:** Phase 0 complete. Ready for Phase 1 (notch panel foundation).

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
- Smoke tests in `Tests/LedgeTests/`.
- Git initialized, tagged `v0.0.1-skeleton`.

## Verified
- `swift build` green.
- `./scripts/make-app.sh` produces a launchable `.app`.
- `open build/Ledge.app` runs as accessory (no Dock icon), `⌘,` opens Settings.

## Locked decisions
- Name: **Ledge**
- MVP scope: pluggable host + File Shelf + Now Playing
- Min OS: macOS 14 Sonoma
- Stack: Swift + SwiftUI content + AppKit panel bridge
- Persistence: per-module Codable JSON in Application Support
- Risky APIs: protocol-abstracted, flag-gated, public fallback required
- **Signing:** ad-hoc (`codesign --sign -`) for Phases 0–3; Developer ID + notarization deferred to Phase 4
- **Tooling path:** SwiftPM for Phases 0–2; promote to `.xcodeproj` once full Xcode is installed (needed before Phase 3's KeyboardShortcuts + polish, certainly before Phase 4)

## Next step
**Phase 1 — Notch panel foundation.** Implement `NotchPanel`, `PanelManager`, `DisplayCoordinator`, `NotchGeometry`, Debug overlay. Target: a placeholder panel at correct notch geometry on every connected display, surviving reconfig and sleep.
