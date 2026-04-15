# ADR-0001: SwiftUI for content, AppKit for window/panel plumbing

**Status:** Accepted · 2026-04-14

## Context
The notch surface needs floating-panel behavior (non-activating, joins all spaces, full-screen auxiliary) that SwiftUI's `WindowGroup` and `Window` scenes do not expose. Module content, on the other hand, is small, declarative, and benefits from SwiftUI's animation primitives (`matchedGeometryEffect`, springs, `@Observable`).

## Decision
Use **AppKit (`NSPanel` subclass)** for the host window. Embed a SwiftUI `NSHostingView` for all content. Settings is a SwiftUI `Scene`. No `WindowGroup` for the notch surface.

## Alternatives considered
1. **Pure SwiftUI `Window` + `.windowLevel(.floating)`** — insufficient control over `collectionBehavior`, can't set non-activating, no clean way to track per-screen panels.
2. **Pure AppKit views** — gives up SwiftUI animation ergonomics for no real gain.
3. **Catalyst** — wrong platform model; degraded macOS feel.

## Consequences
- One AppKit bridge layer (`NotchPanel`, `PanelManager`) is the only place that touches `NSWindow`/`NSScreen` APIs.
- Modules stay 100% SwiftUI and trivially testable.
- We pay a small bridge cost on app launch and per-screen rebuild; negligible.
- If SwiftUI gains true panel scenes in a future macOS, the bridge can be replaced without touching modules.
