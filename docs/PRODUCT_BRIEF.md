# Ledge — Product Brief

## Vision
Turn the MacBook notch into a calm, glanceable, drag-friendly surface that earns its pixels every day. Not a toy; an interaction layer that feels native to macOS.

## Target user
One technical Mac power user: keyboard-first, automation-heavy, lives in Finder, terminal, browser, editor. Values restraint, latency, craft.

## Core jobs to be done
1. Park files temporarily while moving between Finder, browser uploads, Slack, editor.
2. Glance at and control media without raising the menu bar or switching apps.
3. Hold a transient timer/countdown (build, focus block, meeting) where eyes already go.
4. Get out of the way the rest of the time.

## Non-goals (MVP)
Plugin marketplace, cloud sync, iOS companion, notifications mirror, Stage Manager replacement, App Store launch.

## Differentiators
- **Drag-first**, not glance-first: the notch is a target, not a billboard.
- **Module discipline**: 2 modules done excellently > 12 done shallowly.
- **Developer-aware defaults**: timers tied to processes/scripts, file shelf understands paths.
- **Restraint**: no rainbow animations, no gamification, no upsell.

## Principles
1. Native-first (Swift + SwiftUI + AppKit bridge).
2. Latency is a feature — every interaction <100ms perceived.
3. Invisible by default, useful on demand.
4. Drag, hover, and keyboard equivalents for everything.
5. Fail quietly; never block the user.
6. Local-only state; no telemetry without consent.

## MVP success criteria
- File shelf used ≥5×/workday for two consecutive weeks unprompted.
- Stays installed and launched-at-login for 30 days without disable.
- Idle: <60MB RAM, <0.5% CPU, no measurable thermal impact.
- Zero crashes across sleep/wake, display reconfig, full-screen toggles for one week.
- Notch overlay positions correctly on all detected displays within 200ms of connect.
