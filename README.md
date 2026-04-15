# Ledge

A native macOS notch utility. Personal-use first.

## Status
Phase 0 skeleton — accessory app boots, opens Settings, registers zero modules. See `CURRENT_STATE.md`.

## Build
```
swift build
./scripts/make-app.sh
open build/Ledge.app
```

Then `⌘,` opens Settings (no Dock icon, no menu bar app menu — `LSUIElement` is on).

## Docs
- `docs/PRODUCT_BRIEF.md`
- `docs/PRD.md`
- `docs/ARCHITECTURE.md`
- `docs/DESIGN_SYSTEM.md`
- `docs/IMPLEMENTATION_PLAN.md`
- `docs/ADRs/`
