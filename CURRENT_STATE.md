# Ledge — Current State

**Updated:** 2026-04-14
**Phase:** Pre-Phase 0 (architecture approved, awaiting scaffold green-light)

## What exists
- `docs/PRODUCT_BRIEF.md`
- `docs/FEATURE_INVENTORY.md`
- `docs/MVP_RECOMMENDATION.md`
- `docs/PRD.md`
- `docs/ARCHITECTURE.md`
- `docs/DESIGN_SYSTEM.md`
- `docs/IMPLEMENTATION_PLAN.md`
- `docs/ADRs/0001..0007.md`
- `TODO.md`, `CURRENT_STATE.md`

## What does not exist yet
- Xcode project
- Any source code
- Signing config
- CI

## Locked decisions
- Name: **Ledge**
- MVP scope: pluggable host + File Shelf + Now Playing
- Distribution: Developer ID notarized, direct download (not App Store)
- Min OS: macOS 14 Sonoma
- Stack: Swift + SwiftUI content + AppKit panel bridge
- Persistence: per-module Codable JSON in Application Support
- Risky APIs: protocol-abstracted, flag-gated, public fallback required

## Signing posture
**Ad-hoc signing for Phases 0–3.** No Apple Developer Team ID required during development.
- Local builds use `codesign --sign -` (ad-hoc identity).
- Bundle id reserved as `com.satsdisco.ledge` (placeholder; can be changed later without code impact).
- Real Developer ID + notarization deferred to Phase 4 packaging.

## Tooling
- ✅ Swift toolchain present via Command Line Tools.
- ❌ Full Xcode not installed. Required before Phase 0 if we go the `.xcodeproj` route. Alternative SwiftPM path possible for Phases 0–2; see below.

## Next step
Awaiting one of:
- **Path A:** install full Xcode → scaffold `Ledge.xcodeproj`.
- **Path B:** start with `Package.swift` SwiftPM executable, install Xcode later before Phase 3.
