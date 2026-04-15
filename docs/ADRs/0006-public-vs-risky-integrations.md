# ADR-0006: Risky integrations behind protocols + feature flags + public fallback

**Status:** Accepted · 2026-04-14

## Context
Some genuinely valuable features (Now Playing, future system-HUD work, AirPods battery) sit on private/gray frameworks (`MediaRemote`, `IOBluetooth` quirks). They can break on macOS upgrades and bar App Store distribution.

## Decision
Every gray/private capability is:
1. Defined by a **public protocol** in the module (e.g., `MediaController`).
2. Implemented twice when feasible: a **gray implementation** (`MediaRemoteController`) and a **public fallback** (`AppleScriptMediaController`).
3. Selected at launch by a **capability probe** (`canAttach()`) and a **feature flag** (`FeatureFlags.mediaRemote`).
4. Wrapped in a `do/catch` with logged degradation; a failed gray path silently falls back, never crashes.
5. Documented in the module's README with the exact private symbols used and a "what breaks if Apple removes this" note.

## Alternatives
- Use only public APIs: degrades Now Playing UX significantly (AppleScript is slow, app-scoped).
- Use only private APIs: fragile, App Store ineligible, single point of failure on OS upgrades.

## Consequences
- App Store path stays *possible* later by toggling all gray flags off — feature degradation is acceptable, broken UI is not.
- Each new gray dependency requires an ADR amendment listing the symbol and the fallback plan.
- Test matrix grows: every gray-backed module must pass tests with both implementations selected.
