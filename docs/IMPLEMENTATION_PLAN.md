# Ledge — Phased Implementation Plan

Five phases. Each ends with a usable state. No phase is allowed to leak scope into the next.

---

## Phase 0 — Repo + architecture setup

**Goal.** A buildable, signed, runnable empty accessory app with the architectural skeleton in place.

**Tasks.**
1. Create Xcode project (`Ledge.xcodeproj`), App target `Ledge`, deployment target macOS 14.
2. Configure `Info.plist`: `LSUIElement = true`, bundle id `com.satsdisco.ledge` (placeholder).
3. Set up Developer ID code signing + automatic provisioning.
4. Create folder structure per `ARCHITECTURE.md`.
5. Add SwiftLint + a minimal `.swiftlint.yml` (non-blocking warnings only).
6. Add `os.Logger` wrapper at `Services/Logging/Log.swift`.
7. Add `FeatureFlags.swift` with `mediaRemote`, `syntheticNotch`, `debugOverlay`.
8. Add `AppDelegate` setting activation policy `.accessory`, no panels yet.
9. Add empty `LedgeModule` protocol + `ModuleRegistry` skeleton.
10. Add Settings scene stub with a single "Hello, Ledge" pane.
11. Commit + tag `v0.0.1-skeleton`.

**Files created.** Project file; everything in `App/`, `Services/Logging/`, `Services/FeatureFlags.swift`, `ModuleHost/LedgeModule.swift`, `ModuleHost/ModuleRegistry.swift`, `Settings/SettingsScene.swift`.

**Risks.** Signing setup friction. Mitigation: I'll provide exact Xcode steps; you confirm Team ID once.

**Definition of done.** App builds, runs, shows nothing on screen, no Dock icon, Settings opens via `⌘,` after manual `NSApp.activate`. `Console.app` shows `app.ledge` log lines.

---

## Phase 1 — Notch window/panel foundation

**Goal.** A correctly-positioned notch panel on every connected display, surviving reconfig and sleep.

**Tasks.**
1. Implement `NotchPanel: NSPanel` with style mask, level, collection behavior per ADR-0002.
2. Implement `NotchGeometry` to compute notch rect from `NSScreen` (real + synthetic).
3. Implement `DisplayCoordinator` listening for `didChangeScreenParametersNotification` and `NSWorkspace.didWakeNotification`, debounced 150ms.
4. Implement `PanelManager` owning `[ScreenID: NotchPanel]`, idempotent rebuild on display events.
5. Wire a placeholder `Color.red.opacity(0.5)` SwiftUI view via `NSHostingView` to verify positioning.
6. Add `Debug/DebugOverlay.swift` toggleable via `⌃⌥⌘D`, rendering screen + panel state inside the panel.
7. Add unit tests: `NotchGeometryTests`, `DisplayCoordinatorTests` (with injected screen list).
8. Manual test matrix: built-in only; external notched display; non-notch external (synthetic on/off); sleep/wake; full-screen Safari; Mission Control invocation.
9. Tag `v0.1.0-panel`.

**Files.** `Window/NotchPanel.swift`, `Window/PanelManager.swift`, `Window/DisplayCoordinator.swift`, `Window/NotchGeometry.swift`, `Debug/DebugOverlay.swift`, plus tests.

**Risks.**
- Spaces/full-screen edge cases. Mitigation: explicit collection behavior + manual matrix.
- Synthetic notch on non-notch display feels wrong. Mitigation: opt-in only, off by default.

**DoD.** Panel visible at correct geometry on every screen; survives 5+ reconfigs and a sleep/wake cycle without duplicate or missing panels; debug overlay toggles and reports correctly.

---

## Phase 2 — First useful interaction (File Shelf MVP)

**Goal.** A genuinely usable File Shelf shipped as the first module. Used daily without rough edges.

**Tasks.**
1. Implement `Interaction/HoverEngine.swift`: tracks hover via `NSTrackingArea` on the panel's content view, dispatches `expand`/`collapse` with hysteresis (120ms enter, 350ms exit).
2. Implement `Interaction/DragRouter.swift`: registers `[.fileURL]` drag types on the panel; on drag-entered, expands the panel and forwards `NSItemProvider`s to the active drop-accepting module.
3. Implement `Interaction/NotchExpansionController.swift`: drives SwiftUI `matchedGeometryEffect` between collapsed (notch-sized) and expanded (panel-sized) layouts.
4. Implement `ModuleHost/ModuleStore.swift` (Codable + atomic write).
5. Implement `Modules/FileShelf/FileShelfModule.swift` conforming to `LedgeModule`.
6. Implement `Modules/FileShelf/FileShelfStore.swift` with security-scoped bookmark persistence.
7. Implement collapsed view (item count + folder icon) and expanded view (grid of items with hover actions: drag out, copy path, reveal, remove, pin).
8. Wire drag-out via `NSFilePromiseProvider` + direct `NSItemProvider` of the file URL.
9. Stale-item handling per F-4.6.
10. Right-click menu on collapsed notch → quit, settings, per-module quick toggle.
11. Snapshot tests for collapsed/expanded views (light/dark, 0/1/many items, stale).
12. Manual test: 30-minute personal use session.
13. Tag `v0.2.0-shelf`.

**Files.** `Interaction/*`, `ModuleHost/ModuleStore.swift`, `Modules/FileShelf/*`, plus tests.

**Risks.**
- Security-scoped bookmark resolution failing silently. Mitigation: explicit `bookmarkDataIsStale` handling + UI surfacing.
- Drag-out producing wrong file kind in destination apps. Mitigation: use both file URL and file promise providers.

**DoD.** Drag a Safari download into the notch, switch apps, drag it into Slack — works first try, no flicker. App relaunch restores pinned items. No crashes after 24h personal use.

---

## Phase 3 — Polish, animations, settings, second module (Now Playing)

**Goal.** Second module shipped, settings UI complete, motion polished.

**Tasks.**
1. Implement `Modules/NowPlaying/MediaController.swift` protocol.
2. Implement `MediaRemoteController` (gray, behind `FeatureFlags.mediaRemote`) and `AppleScriptMediaController` (public fallback).
3. Capability probe + selection at launch; logged.
4. Collapsed view: marquee track title + tiny play state dot. Expanded view: art + metadata + transport.
5. Implement `Interaction/KeyboardShortcutCenter.swift` using the [`KeyboardShortcuts`](https://github.com/sindresorhus/KeyboardShortcuts) Swift package; default `⌃⌥space` toggles expand on the active screen.
6. Implement Settings panes: General, Modules, Displays, Shortcuts, Advanced (per F-6).
7. Implement `LoginItem` service via `SMAppService.mainApp` with toggle in General.
8. Tighten motion: validate all transitions against `Motion.swift` tokens; remove any ad-hoc animations.
9. Snapshot tests for Now Playing views (playing, paused, no-source).
10. Reduce-Motion path verified.
11. Tag `v0.3.0-polish`.

**Files.** `Modules/NowPlaying/*`, `Interaction/KeyboardShortcutCenter.swift`, `Services/LoginItem/*`, `Settings/Panes/*`.

**Risks.**
- `MediaRemote` symbol resolution at runtime (`dlopen`/`dlsym`). Mitigation: explicit framework-load helper, log + flag-off on failure, fallback engages automatically.
- Settings window opening from accessory app needs explicit `NSApp.activate(ignoringOtherApps: true)` + `openSettings`-equivalent. Mitigation: standard pattern, well-documented.

**DoD.** Both modules ship; settings persists; login item works; motion feels coherent across both modules; one week personal use without regression.

---

## Phase 4 — Packaging and personal-use hardening

**Goal.** A signed, notarized, daily-driver build.

**Tasks.**
1. Configure Hardened Runtime + entitlements (Apple Events for AppleScript fallback, security-scoped bookmarks).
2. Notarization via `xcrun notarytool` — script in `scripts/notarize.sh`.
3. Sparkle integration *deferred*; manual update only for personal use.
4. Crash log capture: enable `MetricKit` (`MXMetricManager`) → write to `~/Library/Logs/Ledge/`.
5. `make release` Makefile target: clean → archive → export → notarize → staple → DMG via `create-dmg`.
6. README in repo root with install + uninstall + log locations.
7. `CURRENT_STATE.md` + `TODO.md` updated to reflect v1 done.
8. Tag `v1.0.0`.

**Files.** Entitlements, `scripts/`, `Makefile`, `README.md`.

**Risks.**
- Notarization rejection due to gray-API symbol references. Mitigation: gray paths use `dlsym` lookups with no link-time symbol; if rejected, flag off `mediaRemote` for the released build and ship with AppleScript only.
- Hardened Runtime breaking AppleScript fallback. Mitigation: `com.apple.security.automation.apple-events` entitlement + per-app `NSAppleEventsUsageDescription`.

**DoD.** A `.dmg` you can hand to yourself, install, run for 30 days without disabling. Crash logs captured and inspectable. v1 acceptance criteria from `PRD.md §11` all green.

---

## Beyond v1
Timer module → Calendar module → keyboard-shortcut polish → menu-bar fallback → script hooks. Each as its own phase, never bundled.
