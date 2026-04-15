# Ledge — Brand Identity

## One-line positioning
A native macOS utility that turns the notch into a calm, glanceable surface.

## Voice
- **Restrained.** Says less than competitors. No exclamation marks.
- **Confident.** "Ledge does X." Not "Ledge can help you X."
- **Native.** Sounds like it could ship with macOS. No marketing-speak.
- **Specific.** Names features by what they are ("File Shelf", "Now Playing"), not what they do.

Words we use: *quiet, glanceable, native, calm, drag-first, restrained, polished*.
Words we avoid: *revolutionary, AI-powered, supercharge, ultimate, productivity*.

## Palette

| Token | Hex | Use |
|---|---|---|
| **Onyx** | `#0A0A0A` | Primary surface (notch panel, app icon) |
| **Graphite** | `#1C1C1E` | Secondary surface |
| **Bone** | `#F5F5F7` | Light-mode panes |
| **Mist** | `rgba(255,255,255,0.65)` | Body text on dark |
| **Accent — Pulse** | `#FF2D55` (Apple system pink) | Reserved for *active* state only — playing track dot, drop highlight, recording |

That's it. No secondary accents, no gradients beyond a single 8% top-edge highlight. Premium = restraint.

## Typography
- **System font (SF Pro)** everywhere. No custom fonts.
- Headings: SF Pro Display, semibold.
- Body: SF Pro Text, regular.
- Numerals: SF Mono for times/prices/durations.

## App icon — design direction

The icon must work at 16px and 1024px. It needs to read as **"the notch"** without being literal-cute.

**Three concepts, ranked from safest to most distinctive:**

### Concept A — "Black Ledge" (recommended for v1)
A perfectly black squircle with a single razor-thin white horizontal line spanning the bottom third — the *ledge*. Above the line, a subtle darker recess hints at the notch silhouette but is barely visible. The whole icon reads as *a deep dark surface with a shelf*, not as *a notch app*.
- Reads at any size: at 16px it looks like a dark squircle with a horizontal accent.
- Doesn't shout the gimmick.
- Pairs with macOS first-party app icons without standing out.

### Concept B — "Notch Inversion"
A white squircle with a single matte-black notch silhouette cut out from the top center. The negative space *is* the notch. Subtle inner shadow inside the cutout for depth.
- More immediately readable as "notch app."
- Slightly more memorable.
- Risk: at 16px the notch detail can blur.

### Concept C — "Light Through" (boldest)
A solid dark squircle with a single thin warm-white horizontal beam (the ledge) that appears to be *emitting* a soft glow upward into the notch silhouette above it. Like a small architectural light.
- Most memorable.
- Risk: glow can look gimmicky if overdone. Needs a designer who knows when to stop.

**My pick:** **Concept A.** Easiest to execute, hardest to fail with, scales perfectly.

---

## Image-generation prompts

Paste one of these into ChatGPT (with image gen), Midjourney, Ideogram, or hand to a designer.

### Concept A prompt
```
A premium macOS app icon, 1024×1024 pixels, transparent background.
Apple-style squircle (continuous-curvature rounded rectangle), filling
the canvas with ~140px of margin on all sides for the standard macOS
icon shadow.

Surface: deep matte black (#0A0A0A), absolutely flat — no texture, no
noise, no gradient except a barely-perceptible 6% white-to-transparent
linear highlight at the very top edge (a 2px hairline).

Single design element: one razor-thin (3px) horizontal warm-white line
(#F5F5F7 at 90% opacity) spanning the lower third of the icon, with
soft 8px feathered ends so it reads as a "ledge" or shelf, not a hard
divider. The line sits at exactly 60% from the top.

Subtle near-imperceptible inner shadow at the top center of the icon
suggesting the silhouette of a hardware notch — visible only on close
inspection, never obvious. A 12px-radius soft black void, 200px wide,
centered horizontally, blurred at 30%.

The icon must read as cleanly at 16×16 as at 1024×1024. No text. No
emoji. No skeuomorphic effects. No drop shadow on the icon itself
(macOS adds the shadow). Premium, calm, restrained — sits naturally
next to Finder, Safari, and System Settings icons.

Style references: macOS Sonoma system app icons, Linear app icon,
Notion icon, Things 3 icon. Minimalist Swiss design ethos.
```

### Concept B prompt (alternative)
```
A premium macOS app icon, 1024×1024 pixels, transparent background.
Apple-style squircle filling the canvas with ~140px shadow margin.

Surface: warm off-white (#F5F5F7), perfectly flat. No texture.

Cut from the top center of the squircle: a precise notch silhouette,
matching the actual MacBook notch profile — straight top edge, vertical
sides, concave 10px-radius fillets where the notch meets the surface
below. Notch dimensions: 280px wide, 90px tall, centered horizontally.

Inside the cutout: pure matte black (#0A0A0A) with a soft 8px inner
shadow on the bottom curves to suggest depth — like the notch is a
recess in the surface, not just a flat hole.

No text. No additional decoration. The contrast between the warm
off-white squircle and the deep black notch carries the entire design.

Reads as cleanly at 16px as at 1024px. Sits naturally with macOS
system icons. No drop shadow on the icon itself.

Style: minimalist Apple HIG, Swiss design, Things 3 / Linear / Reeder
visual restraint.
```

### Concept C prompt (boldest)
```
A premium macOS app icon, 1024×1024 pixels, transparent background.
Apple-style squircle (continuous-curvature) filling the canvas with
~140px shadow margin.

Surface: deep matte black (#0A0A0A), perfectly flat.

Single luminous element: a 4px-thick horizontal beam in warm pearl
white (#FFE9D6 at 95% opacity), spanning the middle of the icon
horizontally, with a soft elliptical glow rising from the top edge of
the beam — radiating warm pale orange (#FFB266 at 30% opacity) for
about 200px upward, falling off smoothly to transparent. The glow is
soft, not chromatic — like dim morning light catching a windowsill.

Above the glow, almost imperceptible: a slightly darker recess hinting
at the silhouette of a hardware notch (200px wide, centered, 60px
tall, just a 4% opacity black fill).

Effect: a small architectural shelf lit by warm light from somewhere
just out of frame.

No text. No additional elements. No chromatic aberration, no rainbow
gradients, no lens flares.

Reads cleanly at 16px (just a horizontal accent on a black square).
At 1024px, the warm glow is visible and feels intentional.

Style: Apple HIG, Anthony Burrill print restraint, James Turrell
luminance.
```

## Post-processing — turning the PNG into AppIcon.icns

When you have the 1024×1024 PNG (call it `icon-1024.png`):

```bash
# In a working directory containing icon-1024.png:
mkdir AppIcon.iconset

sips -z 16 16     icon-1024.png --out AppIcon.iconset/icon_16x16.png
sips -z 32 32     icon-1024.png --out AppIcon.iconset/icon_16x16@2x.png
sips -z 32 32     icon-1024.png --out AppIcon.iconset/icon_32x32.png
sips -z 64 64     icon-1024.png --out AppIcon.iconset/icon_32x32@2x.png
sips -z 128 128   icon-1024.png --out AppIcon.iconset/icon_128x128.png
sips -z 256 256   icon-1024.png --out AppIcon.iconset/icon_128x128@2x.png
sips -z 256 256   icon-1024.png --out AppIcon.iconset/icon_256x256.png
sips -z 512 512   icon-1024.png --out AppIcon.iconset/icon_256x256@2x.png
sips -z 512 512   icon-1024.png --out AppIcon.iconset/icon_512x512.png
cp                icon-1024.png    AppIcon.iconset/icon_512x512@2x.png

iconutil -c icns AppIcon.iconset

# Drop the resulting AppIcon.icns into the repo:
cp AppIcon.icns ~/Projects/Ledge/Resources/AppIcon.icns
```

`scripts/release.sh` already auto-detects `Resources/AppIcon.icns` and bundles it on the next build. No code changes needed.

## Wordmark

Use the system font, never a logotype (yet). When written as a brand mark, "Ledge" is set in **SF Pro Display Medium**, letter-spacing **−0.5%**, no special treatment. The icon is the brand mark; the wordmark is just the name.

## Marketing surfaces

| Surface | What it should feel like |
|---|---|
| Landing page hero | A single screenshot of the expanded notch on a real desktop. No ad copy above the fold. |
| Screenshots | Always real screenshots, never mockups. Always on macOS Sonoma+ wallpaper, never marketing gradients. |
| Demo video | 30 seconds, no music, no voiceover, no captions. Cursor moves naturally. |
| Tweet / post | One sentence + one screenshot. Never a thread. |
| Press email | Three sentences max + two screenshots + DMG link. |

## Anti-checklist

- ✗ Rainbow gradients anywhere
- ✗ Glassmorphism (every other utility uses it; we don't)
- ✗ Logos that try to be clever (no notch-shaped letters, no "L" reading as a shelf)
- ✗ Marketing screenshots with fake notification badges
- ✗ "Powered by AI" anywhere
- ✗ Rotating 3D anything
