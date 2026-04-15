# ADR-0006: Risky integrations behind protocols + feature flags + public fallback

**Status:** Accepted · 2026-04-14 · **Amended 2026-04-15**

## Context
Some genuinely valuable features (Now Playing, future system-HUD work, AirPods battery) sit on private/gray frameworks (`MediaRemote`, `IOBluetooth` quirks). They can break on macOS upgrades and bar App Store distribution.

## 2026-04-15 amendment — MediaRemote is dead for third-party apps
Since macOS 15.4, `MRMediaRemoteGetNowPlayingInfo` returns nil for third-party processes; only system-sanctioned apps (Control Center, Dock, Siri) get now-playing data back. This was confirmed widely across the notch-app ecosystem in 2025. On macOS 26 the restriction holds.

**Implication for Ledge.** The "gray implementation" half of the MediaController abstraction no longer provides value: the probe would always fail, the fallback would always engage. We ship AppleScript-only.

**Net decision.**
- `MediaController` protocol stays — still the right seam.
- `AppleScriptMediaController` is the sole implementation for v1.
- `FeatureFlags.mediaRemote` is retained as a no-op in v1 (gated behind `#if false`-style dead code removal or left as a stub for the day Apple reopens the API). We surface no user-facing toggle for it.
- Sources reduced to the two apps AppleScript can read reliably: Apple Music and Spotify. Chrome/Safari/other media are out of scope for v1.

## Original decision (still applies to future gray capabilities)
Every gray/private capability is:
1. Defined by a **public protocol** in the module.
2. Implemented twice when feasible: gray + public fallback.
3. Selected at launch by a capability probe + feature flag.
4. Wrapped so a failed gray path silently falls back, never crashes.
5. Documented with exact private symbols used and a "what breaks if Apple removes this" note.

## Alternatives revisited
- Pure AppleScript: what we're doing. Ugly but reliable.
- Ship with broken MediaRemote and hope users don't notice: no.
- Wait for Apple to reopen the API: indefinite.
- Private MRMediaRemoteSendCommand for *writes* (play/pause) while reading stays AppleScript: considered, rejected — writes-only via private API is still App Store ineligible and adds fragility with no meaningful UX upside over AppleScript's `tell app "Spotify" to playpause`.

## Consequences
- Now Playing module depends on macOS Automation permission the first time it queries each source app. User will see a standard macOS prompt. We handle denial gracefully (module degrades to empty state, logs, does not crash).
- Non-running source apps are skipped via a `System Events (name of processes)` probe so we never auto-launch Music/Spotify.
- If Apple reopens MediaRemote later, adding a second implementation behind `MediaController` is a single-file change. The abstraction survives the amendment.
