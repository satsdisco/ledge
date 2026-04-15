# Ledge — Product Requirements Document (v1)

## 1. Overview
Ledge is a native macOS utility that turns the MacBook notch into an interactive surface hosting a small, curated set of modules. v1 ships a pluggable host with two modules: **File Shelf** and **Now Playing**.

## 2. Goals
- Make the notch *useful* in the first 30 seconds after install.
- Establish a module architecture that supports v2+ without rewrites.
- Hit a craft bar (latency, polish, restraint) that justifies daily use.

## 3. Non-goals
Plugin marketplace; cloud sync; iOS companion; notifications mirroring; Stage Manager replacement; App Store launch in v1.

## 4. Personas
**Primary — "The Builder."** Single power user. Mac-native, keyboard-first, drag-heavy, lives in Finder/terminal/editor/browser. Tolerance for friction = zero. Will uninstall a stuttery utility within an hour.

## 5. Use cases

### UC-1: Park a download mid-task
Builder downloads a PDF in Safari, drags it onto the notch, switches to Slack, drags it from the notch into a DM. No Finder window, no temp folder, no tab loss.

### UC-2: Skip a track without leaving editor
Builder is in Xcode full-screen. Hovers the notch; Now Playing expands. Clicks skip. Notch collapses. Focus never leaves Xcode.

### UC-3: Stash and pin a working file
Builder drags `notes.md` onto the shelf and pins it. Closes the editor window. Reopens later from the shelf via "Reveal in Finder."

### UC-4: Cold reboot
Builder reboots. Ledge auto-launches. Pinned shelf items restore. Notch is present on built-in display within 1s of login.

### UC-5: Plug in external display
Builder docks. Within 200ms, an additional notch panel appears on the notched external (or a top-center synthetic anchor on non-notch externals if enabled).

## 6. Functional requirements

### F-1 Notch overlay
- F-1.1 Display a panel anchored to each enabled screen's notch (or synthetic top-center).
- F-1.2 Panel is non-activating, joins all spaces, visible in full-screen apps.
- F-1.3 Collapsed state shows compact module slot(s); expanded state shows full module UI.
- F-1.4 Panels rebuild idempotently on screen reconfig within 200ms of the system event settling.

### F-2 Interaction
- F-2.1 Hover the notch region for ≥120ms triggers expand.
- F-2.2 Mouse exit + 350ms hysteresis triggers collapse.
- F-2.3 Global keyboard shortcut (default `⌃⌥space`, configurable in v1.1) toggles expand on the active screen's panel.
- F-2.4 Dragging any item over the notch region triggers expand and routes the drag to the active drop-accepting module.

### F-3 Module host
- F-3.1 Modules conform to `LedgeModule`, are registered in `ModuleRegistry` at app launch.
- F-3.2 Modules can be enabled/disabled in Settings without restart.
- F-3.3 At most one module is "active" (visible) per panel at a time. Switching is via segmented control in expanded view.
- F-3.4 Module persistence is sandboxed per module via `ModuleStore`.

### F-4 File Shelf module
- F-4.1 Accepts file URL drops via `NSItemProvider` (kind `public.file-url`).
- F-4.2 Stores up to N items (default 12), FIFO eviction; pinned items exempt.
- F-4.3 Each item: thumbnail/icon, filename, size, source app (best-effort), pin toggle.
- F-4.4 Item actions: drag out, copy path, copy file, reveal in Finder, remove, pin.
- F-4.5 Persisted via security-scoped bookmarks; survives relaunch.
- F-4.6 If a stored item's URL becomes invalid (file moved/deleted), item is marked stale, dimmed, and removable; never crashes.

### F-5 Now Playing module
- F-5.1 Shows current track title, artist, album art, and elapsed/total time.
- F-5.2 Controls: play/pause, prev, next.
- F-5.3 Sources: Apple Music + Spotify in MVP. Generic media (Safari, Chrome, etc.) deferred.
- F-5.4 Backed by `MediaController` protocol with two implementations: `MediaRemoteController` (gray, default) and `AppleScriptMediaController` (fallback). Selection at launch via capability probe + feature flag.
- F-5.5 If no media is playing, module collapses to a minimal "—" state, never empty crash.

### F-6 Settings
- F-6.1 Sections: General, Modules, Displays, Shortcuts, Advanced.
- F-6.2 General: launch at login, appearance (auto/light/dark), expand sensitivity.
- F-6.3 Modules: per-module enable + module-specific options (e.g., shelf size).
- F-6.4 Displays: per-screen enable, synthetic-notch toggle for non-notch screens, vertical offset trim.
- F-6.5 Shortcuts: customize global expand binding.
- F-6.6 Advanced: feature flags (developer), reset state, open log directory.

## 7. Non-functional requirements
| | Target |
|---|---|
| Idle CPU | <0.5% on M-series |
| Idle memory | <60MB resident |
| Cold launch | <500ms to first paint |
| Hover→expand latency | <100ms perceived |
| Drag→expand latency | <50ms perceived |
| Crash-free sessions | 100% over 7-day personal-use trial |
| Display reconfig recovery | <200ms |

## 8. UX principles
1. The notch is yours to ignore. Never demand attention.
2. Every interaction has a keyboard equivalent.
3. Animation has a job (state change), never decoration.
4. Errors are silent, recoverable, and logged — never modal.
5. Settings are discoverable but never on the critical path.

## 9. Technical constraints
- Min macOS 14 Sonoma. Built with Xcode 15+ / Swift 5.9+.
- Distribution: Developer ID notarized, direct download. Not App Store in v1.
- All private-API code gated behind `FeatureFlags` and abstracted behind protocols.

## 10. Future events / analytics (not implemented in MVP)
Schema reserved for opt-in local-only metrics:
- `module.activated{id}`, `module.dropAccepted{id, kind}`, `panel.rebuilt{trigger, durationMs}`, `media.controllerSelected{impl}`, `shelf.itemRestored{success}`, `shortcut.invoked{id}`.
Persisted to a rolling local SQLite if user opts in. No network.

## 11. Acceptance criteria (MVP done = all true)
- [ ] Panel renders correctly on built-in M-series notch and on a notched external display.
- [ ] Hover, keyboard, and drag triggers all expand/collapse without flicker.
- [ ] File Shelf accepts drops from Finder, Safari downloads, and Mail attachments; survives app relaunch with pinned items intact.
- [ ] Now Playing controls Apple Music and Spotify with both controller implementations green-flagged.
- [ ] Settings persists across launches.
- [ ] Login item enables/disables via SMAppService cleanly.
- [ ] No crash across 24h of normal use including 3+ sleep/wake cycles and 5+ display reconfigs.

## 12. Open questions
- Q1: Should expanded panel dim the rest of the screen? (Default: no — keep restrained.)
- Q2: When two modules are enabled, does the collapsed notch show a *combined* glance (e.g., shelf count + media), or alternate based on context? (Default: combined micro-strip; revisit after personal use.)
- Q3: Behavior on non-notch external when synthetic anchor disabled — hide panel entirely, or show a discreet menu-bar fallback? (Default: hide panel; menu-bar fallback in v1.1.)
- Q4: Should drag-out from the shelf write a copy or move? (Default: respect the drag operation requested by the destination — same as Finder.)
