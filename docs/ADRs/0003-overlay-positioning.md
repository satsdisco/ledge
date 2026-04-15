# ADR-0003: Overlay positioning via NSScreen.safeAreaInsets with synthetic fallback

**Status:** Accepted · 2026-04-14

## Context
Notch geometry must be derived per-display, must survive display reconfig, and must degrade on non-notch screens.

## Decision
Resolve notch rect from `NSScreen.safeAreaInsets.top` and `auxiliaryTopLeftArea`/`auxiliaryTopRightArea` (public on macOS 12+). Centralize in `NotchGeometry`:
- If `safeAreaInsets.top > 0` → real notch, compute rect between the two auxiliary areas.
- Else → synthetic notch: a 200×32pt rect centered at the top edge, only if user enabled "Show on non-notch displays."

`PanelManager` listens for `didChangeScreenParametersNotification` and `NSWorkspace.didWakeNotification`, debounces 150ms, and rebuilds the per-screen panel set idempotently (diff by `screen.localizedName` + `displayID`).

## Alternatives
- Hard-coded notch dimensions per Mac model: brittle, requires a model→geometry table; breaks on new hardware.
- Private `CGSGetDisplayNotch`-style calls: unnecessary risk; public API is sufficient.

## Consequences
- Works on every notched Mac out of the box.
- Synthetic mode is an explicit opt-in; no surprise UI on non-notch displays.
- Rebuild is idempotent → safe to over-fire on noisy reconfig storms.
