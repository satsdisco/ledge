# Ledge — Path to Release

This is the punch list for taking Ledge from "works on my machine, ad-hoc signed" to a real shippable Mac app.

## Where we are
- v0.8.0 — five modules (File Shelf, Now Playing, Timer, Clocks, Bitcoin), keyboard shortcut, login item, polished Settings, hardware-cutout-shaped panel.
- ~2,400 LOC, 42 source files, clean module architecture.
- Built with SwiftPM under Command Line Tools, ad-hoc signed via `scripts/make-app.sh`.

## What's blocking real release

| Blocker | Effort | Notes |
|---|---|---|
| **No app icon** | 1h design + 30m bake | 1024px master + Iconset (16/32/128/256/512 @1x/@2x). |
| **CLT toolchain, not Xcode** | 10GB download | Required for proper signing, notarization, App Store path, and re-enabling the test target. |
| **No Apple Developer account** | $99/yr + 1d | Needed for Developer ID cert + notarization + App Store. |
| **No Developer ID code signing** | 30m once Xcode + cert in place | Replaces ad-hoc with `Developer ID Application: <Your Name> (TEAMID)`. |
| **No notarization** | 30m setup + ~5m per build | `xcrun notarytool submit ... --wait` + `xcrun stapler staple`. Required for Gatekeeper to accept downloads on macOS 10.15+. |
| **No DMG packaging** | 1h | `create-dmg` script with bundled background + drag-to-Applications affordance. |
| **No auto-update** | 4h | Sparkle 2 (https://sparkle-project.org). Self-hosted appcast + signed updates. |
| **No website** | 4–6h | Single-page landing: hero video, feature list, download, changelog, support email. |
| **No privacy policy** | 1h | Required if you ship anywhere public. Ledge is local-only — short doc. |
| **No support channel** | 0 | Email + GitHub issues is enough for v1. |

## Pre-release engineering punch list

### Tier 1 — must do
- [ ] App icon (commission designer or use Bezel/Glyphs/SF Symbols composition)
- [ ] Install full Xcode and migrate `Package.swift` → `Ledge.xcodeproj` (or keep SwiftPM and use `xcodebuild -scheme Ledge`)
- [ ] Re-enable `LedgeTests` target with swift-testing
- [ ] Hardened Runtime entitlements (`com.apple.security.automation.apple-events`, network for Bitcoin)
- [ ] `scripts/release.sh` — clean build → archive → sign → notarize → staple → DMG → checksum
- [ ] Sparkle integration with EdDSA-signed appcast
- [ ] First-launch onboarding (one-card overlay: "Hover the notch to expand. ⌃⌥Space to toggle. Right-click for options.")
- [ ] Per-module crash isolation: wrap module init in do/catch; log + skip rather than crash the host

### Tier 2 — should do
- [ ] Customizable global hotkey (re-evaluate `KeyboardShortcuts` package once on Xcode; the `#Preview` macro will resolve)
- [ ] Per-module quick toggles in collapsed glance strip (opt-in)
- [ ] File Shelf: drag to reorder, per-item expiry timer, accept dragged URLs from non-file sources (text snippets path)
- [ ] Now Playing: scrub bar, marquee long titles, support generic media via `MPNowPlayingInfoCenter` if Apple ever opens read access
- [ ] Timer: custom duration input, multiple concurrent timers, repeat option
- [ ] Clocks: digital seconds, search-as-you-type zone picker, per-clock accent color
- [ ] Bitcoin: currency selector (USD/EUR/GBP/sats), price alerts on threshold crossings
- [ ] MetricKit crash + signpost capture → local log + opt-in upload

### Tier 3 — nice to have
- [ ] Module SDK as a Swift Package so motivated users can write their own
- [ ] Shortcuts.app integration (start timer, query BTC, etc.)
- [ ] Translations (start with es / de / ja / pt-BR)
- [ ] iCloud sync of Settings (modules enabled, clocks list)

## Distribution choices

You have three paths. They're not mutually exclusive — most ship-able indie macOS apps do **A + B**.

### A. Direct download (Developer ID + notarization)
- Pro: full feature set, Sparkle auto-update, no App Store rev share, ship updates same-day.
- Con: $99/yr cert, you handle hosting + payments.
- **Recommended for v1.** Cheapest, fastest, most flexibility.

### B. Mac App Store
- Pro: discoverability, automatic updates, App Store payment + receipts.
- Con: 15–30% rev share, sandboxing requirements (security-scoped bookmarks already done — good), no private APIs (we're already public-only — good), review delays.
- **Eligible after a few cleanups:** AppleScript usage description ✓, security-scoped bookmarks ✓, no private APIs ✓. Add receipt validation if you ever charge.
- **Recommended for v1.1+.**

### C. Setapp / third-party stores
- Pro: existing audience, monthly stipend.
- Con: smaller revenue per user, exclusivity terms.
- **Skip for v1.**

## Pricing model — three options

| Model | Pros | Cons | Verdict for Ledge |
|---|---|---|---|
| **Free + open source** | Maximum reach, community contribution | Zero revenue, ongoing maintenance burden | Honest if you don't want a business |
| **Free trial → one-time license ($15–25)** | Clean. Indie-friendly. Loyal users. | Marketing required. | **Recommended.** |
| **Subscription ($3–5/mo)** | Recurring rev for ongoing dev | Annoys users for utilities, churn battle | Save for v2 if feature surface grows |

The $15–25 one-time price slot is exactly where utilities like Alcove ($10), Boring.notch ($5), TopNotchBar (free) sit. Position Ledge premium-of-the-bunch — extensible architecture, Bitcoin, clocks, polish — at $19 with a 14-day trial.

## Marketing — minimum viable

1. **Domain + landing page** — `getledge.app` or similar (`ledge.app` likely taken). Use Cloudflare Pages or Vercel.
2. **Three screenshots** — collapsed (almost invisible), expanded with album art, expanded with Bitcoin sparkline. PNG + WebP.
3. **30s screen recording** — drag a file in, switch to Now Playing, expand Bitcoin. No music, no voiceover; let the polish speak.
4. **Launch posts** — Hacker News (Show HN), r/macapps, Indie Hackers, Twitter/X. Don't blast all at once; stagger 24h apart.
5. **Press list** — MacStories, Sixcolors, The Verge tech, AppAddict (German), Macworld. Email each personally.

## Privacy posture
Ledge is local-first. Network calls today:
1. CoinGecko `/simple/price` and `/coins/bitcoin/market_chart` for Bitcoin module.
2. (Optional future) Sparkle appcast XML pull.

Nothing else. No telemetry, no analytics, no auth, no cloud sync. **Privacy policy can fit on one page.** Make this a marketing point.

## Suggested release calendar

| Week | Milestone |
|---|---|
| 1 | Install Xcode, design app icon, set up Apple Developer account |
| 2 | Migrate to Xcode project, Hardened Runtime, signing, notarization scripted |
| 3 | Sparkle integration, first-launch onboarding, crash isolation |
| 4 | Landing page + screenshots + recording, privacy policy |
| 5 | TestFlight-style soft launch to ~20 Mac power users you trust, fix what breaks |
| 6 | Public launch (HN + r/macapps + Twitter same morning) |

Six weeks from today is achievable without rushing. None of it is novel work — it's all well-documented Apple-developer plumbing.

## Concrete next action

The single thing standing between you and *all* of the above is **install full Xcode**. Once that exists, every blocker becomes a normal day's work. Ad-hoc signed dev builds will keep working in parallel for personal use during the transition.

After Xcode: app icon. Even a placeholder you commission on Fiverr for $40 is enough to start signing real builds.
