# Ledge — TODO

Living checklist. Mirrors `docs/IMPLEMENTATION_PLAN.md` but tracks actual progress.

## Phase 0 — Repo + architecture setup
- [ ] Create `Ledge.xcodeproj` (App target, macOS 14, SwiftUI lifecycle)
- [ ] `Info.plist`: `LSUIElement = true`
- [ ] Ad-hoc signing (`codesign --sign -`) for dev builds; Developer ID deferred to Phase 4
- [ ] Folder structure per `ARCHITECTURE.md`
- [ ] `Services/Logging/Log.swift` (`os.Logger` wrapper)
- [ ] `Services/FeatureFlags.swift`
- [ ] `App/AppDelegate.swift` with `.accessory` activation policy
- [ ] `ModuleHost/LedgeModule.swift` + `ModuleRegistry.swift` skeletons
- [ ] `Settings/SettingsScene.swift` stub
- [ ] Tag `v0.0.1-skeleton`

## Phase 1 — Notch panel foundation
- [ ] `NotchPanel`, `PanelManager`, `DisplayCoordinator`, `NotchGeometry`
- [ ] Debug overlay (`⌃⌥⌘D`)
- [ ] Geometry + coordinator unit tests
- [ ] Manual display matrix run

## Phase 2 — File Shelf MVP
- [ ] `HoverEngine`, `DragRouter`, `NotchExpansionController`
- [ ] `ModuleStore` Codable persistence
- [ ] `FileShelfModule` + views + bookmark persistence
- [ ] Drag-out via file URL + file promise
- [ ] Snapshot tests
- [ ] 30-min personal use check

## Phase 3 — Now Playing + Polish
- [ ] `MediaController` protocol + two implementations
- [ ] Capability probe & flag gating
- [ ] `KeyboardShortcutCenter` (default `⌃⌥space`)
- [ ] Settings panes complete
- [ ] `LoginItem` via `SMAppService`
- [ ] Motion audit pass
- [ ] Reduce-Motion verified

## Phase 4 — Packaging
- [ ] Hardened Runtime + entitlements
- [ ] Notarization script
- [ ] MetricKit crash capture
- [ ] `make release` target + DMG
- [ ] README + tag `v1.0.0`

## Decisions still open
- Path A (install full Xcode → `.xcodeproj`) vs Path B (SwiftPM-only for Phases 0–2)
- Bundle id (placeholder `com.satsdisco.ledge`) — confirm or change
- App icon direction (placeholder now or skip until v1?)
- Developer ID Team ID — deferred to Phase 4 packaging
