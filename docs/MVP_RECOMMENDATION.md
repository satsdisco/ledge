# Ledge — MVP Recommendation

## Decision
**Pluggable host shipped with exactly two modules: File Shelf + Now Playing.**

## Why
- File Shelf alone doesn't justify always-on notch presence the rest of the day.
- Now Playing alone is crowded territory.
- Together they make the notch *always* doing something useful at a glance, and *uniquely* useful as a drag target above all windows.
- The module protocol is cheap to design now and prohibitively expensive to retrofit later.

## Explicitly NOT in MVP
Timer, calendar, notifications, clipboard, launcher, scripts, Shortcuts integration. All slated for v1+.

## Ship definition
- Notch overlay correctly positioned on built-in + external displays.
- Hover-expand and keyboard-expand both work.
- File Shelf: drag in, drag out, copy path, reveal in Finder, clear; survives relaunch via security-scoped bookmarks.
- Now Playing: current track + play/pause/skip for Apple Music + Spotify.
- Settings: enable/disable each module, launch at login.
- One week of personal use without crash, leak, or display-reconfig bug.

## Candidates evaluated

| Candidate | Daily utility | Differentiation | Risk | Verdict |
|---|---|---|---|---|
| Media + notifications | Med | Low | Notifications need risky APIs | No |
| File drop shelf | High | High | Low | Strong, but lonely alone |
| Launcher / clipboard / snippets | Low–Med | Low (Raycast wins) | Low | No |
| Timer / focus / now-playing | Med–High | Med | Low | Reasonable but broad |
| **Hybrid host + small set** | **High** | **High** | Med (protocol design) | **Pick** |
