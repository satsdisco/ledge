# Ledge — Design System

## Visual tone
Quiet. Dense without clutter. Closer to Finder's Quick Look or the Spotlight bar than to a consumer widget. The notch panel feels like part of the chrome — never an app window.

## Material
- Background: `NSVisualEffectView` material `.hudWindow` underneath, layered with a dark translucent fill (`black @ 70%` light / `black @ 80%` dark) so the panel reads as an extension of the notch.
- Corner radius: matches the notch's hardware radius (12pt) on the bottom; flush 0 at the top against the bezel.
- 1px inner highlight at the top edge of the expanded panel for definition. No outer shadow when collapsed; subtle 0/8/24/black@30% shadow when expanded.

## Typography
- System font (`SF Pro` via `.system`) only.
- Scale:
  - Caption: 11pt regular, tracking +0.2 — secondary metadata.
  - Body: 12pt regular — default.
  - Emphasis: 12pt medium — track titles, filenames.
  - Numerals: 13pt monospaced (`.system(.body, design: .monospaced)`) for timers and durations.
- Line height = 1.25× font size. No custom fonts ever.

## Color
Two ramps only.

**Neutral (always)**
| Token | Light | Dark |
|---|---|---|
| `surface` | `#1C1C1E @ 70%` | `#0A0A0A @ 80%` |
| `text.primary` | `white @ 95%` | `white @ 95%` |
| `text.secondary` | `white @ 60%` | `white @ 55%` |
| `text.tertiary` | `white @ 35%` | `white @ 30%` |
| `divider` | `white @ 8%` | `white @ 6%` |

**Accent (per module, restrained)**
- File Shelf: system blue, used only on drop-target glow and pin badge.
- Now Playing: system pink, used only on the play-state dot.

Avoid color for state where motion or weight will do.

## Spacing
4pt grid. Tokens: `xs=4 sm=8 md=12 lg=16 xl=24`. Panel internal padding: `md` horizontal, `sm` vertical when collapsed; `lg/md` when expanded.

## Iconography
SF Symbols only, weight `.medium`, scale `.small` for inline, `.medium` for action buttons. No third-party icon sets.

## Motion
Centralized in `DesignSystem/Motion.swift`. Three springs, that's it.

| Token | Use | Spec |
|---|---|---|
| `Motion.express` | hover-expand, drag-expand | `interpolatingSpring(stiffness: 320, damping: 28)` |
| `Motion.calm` | content swap inside panel | `interpolatingSpring(stiffness: 220, damping: 30)` |
| `Motion.snap` | dismiss, micro-feedback | `interpolatingSpring(stiffness: 480, damping: 32)` |

Rules:
- Expand/collapse uses `matchedGeometryEffect` between collapsed and expanded layouts. No cross-fade.
- Never animate opacity alone; always pair with scale or position. Bare opacity reads as a glitch.
- Total expand duration ≤220ms perceived. If it feels longer, it is.
- Reduce Motion: respect `accessibilityReduceMotion`; collapse to a 120ms ease-out crossfade.

## Interaction guidelines
- Hover targets ≥ the visible notch rect, expanded by 4pt on each side for forgiveness.
- Click targets ≥ 28×28pt inside the expanded panel.
- Drag targets visually pulse on `dropEntered` (1.02× scale, 80ms `Motion.snap`), never on hover.
- Cursor never changes (no pointer hand) — the panel is system-chrome-like.
- Right-click on collapsed notch: settings + per-module quick toggles.

## States
- **Empty:** modules render a one-line gray hint in `text.tertiary`. No illustrations, no CTAs.
- **Loading:** never block. If data is unavailable, show last-known state with a 2pt indeterminate bar at the bottom edge.
- **Error:** silent in UI; logged. Only surface if the user explicitly opens the module's expanded view, then a single-line tertiary message + retry affordance.
- **Stale (e.g., shelf item missing):** dim to 40% opacity + remove affordance on hover. Never auto-purge without user action.

## Dark/Light
Auto follows system. The panel surface is dark in both modes (it sits inside the bezel; a light panel would look broken). Settings window follows system normally.

## Accessibility
- Full keyboard navigation in expanded panel (`tab`/`shift-tab`, `enter`, `esc` collapses).
- All controls have `accessibilityLabel`s.
- Honor `increaseContrast` (raise text opacity to 100% / 80%) and `differentiateWithoutColor` (use SF Symbol weight + dot indicators instead of color for state).

## Anti-patterns
- No gradients beyond a single 8% top-edge highlight.
- No emoji in UI.
- No pulsing/breathing idle animations.
- No badges with numbers ≥ 99+.
- No marketing copy anywhere.
