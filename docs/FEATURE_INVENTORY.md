# Ledge — Feature Inventory

Legend: **API** = `pub` (public only) / `gray` (private but commonly used) / `risky` (private, fragile). **Cx** = complexity 1–5.

## MVP

| Feature | Value | Cx | Deps | API |
|---|---|---|---|---|
| NSPanel notch overlay (non-activating, all spaces, full-screen aux) | Foundation | 3 | AppKit | pub |
| Multi-display + reconfig handling | Works on externals, dock/undock | 3 | NSScreen | pub |
| Hover-to-expand interaction | Primary affordance | 2 | SwiftUI | pub |
| Module protocol + host | Clean v1→v2 path | 2 | — | pub |
| **File Shelf module** (drag in/out, copy path, reveal, clear) | Daily driver | 4 | NSItemProvider, security-scoped bookmarks | pub |
| **Now Playing module** (title/artist/art, play/pause/skip) | Glanceable control | 3 | MediaRemote (gray) + AppleScript fallback | gray |
| Settings (modules on/off, login item, position tuning) | Trust + control | 2 | SMAppService | pub |
| Login-at-launch | Daily presence | 1 | ServiceManagement | pub |
| Logging + crash-safe shelf restore | Don't lose parked files | 2 | os.Logger, Codable | pub |

## Strong v1

| Feature | Cx | API |
|---|---|---|
| Timer module (focus / countdown / build timer) | 3 | pub |
| Global keyboard shortcut to expand (`⌃⌥space`) | 2 | pub |
| File Shelf: pinned items + per-item expiry | 2 | pub |
| Calendar countdown (next meeting in N) | 3 | pub (EventKit) |
| Custom drag preview + drop animation polish | 2 | pub |
| Menu bar fallback for non-notch Macs | 1 | pub |
| Per-module micro-settings | 2 | pub |

## Experimental / later

| Feature | API | Note |
|---|---|---|
| Clipboard history | pub | Only if it beats Raycast for actual flow |
| Snippet launcher | pub | Same |
| Volume/brightness HUD replacement | risky | System HUD intercept fragile |
| Notifications mirror | risky | DND/announcement APIs restricted |
| Shell command runner / script hooks | pub | Powerful, scope creeps |
| Shortcuts.app intents | pub | Worth it once modules stabilize |
| AirPods / device battery | gray | IOBluetooth quirks |
| "Deploy in progress" live activity | pub | Tied to script hooks |
| Per-Space behavior tuning | gray | Spaces APIs gray |
| User-authored modules (SwiftPM drop-in) | pub | After 3+ first-party modules ship |
