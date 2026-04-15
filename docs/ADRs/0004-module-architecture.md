# ADR-0004: First-party module protocol, no third-party plugins in v1

**Status:** Accepted · 2026-04-14

## Context
We need module modularity to keep the codebase clean and to support v1+ growth, but a real plugin system (loadable bundles, sandboxing, version negotiation) is enormous scope and a security minefield.

## Decision
Define a `LedgeModule` Swift protocol and a `ModuleRegistry` that statically registers first-party modules at app launch. Modules are *internal types*, not loaded from disk. No public plugin SDK in v1.

```swift
protocol LedgeModule: AnyObject {
    static var identifier: String { get }
    var displayName: String { get }
    var collapsedView: AnyView { get }
    var expandedView: AnyView { get }
    var acceptsDrops: Bool { get }
    func handleDrop(_ providers: [NSItemProvider]) -> Bool
    func didActivate()
    func willDeactivate()
}
```

Modules receive an injected `ModuleEnvironment` with: `ModuleStore` (typed Codable persistence), `Logger`, `FeatureFlags`, `PermissionsBroker`. They never import `Window/` or `App/`.

## Alternatives
- Full plugin marketplace with signed bundles: massive scope, premature.
- No protocol, just hard-wired modules: short-term faster, locks us into rewrite at module #3.

## Consequences
- Adding a module is a single-folder PR with zero touch to host code.
- The protocol is private API; we can break and refactor it freely until we expose a public SDK.
- Future "user-authored modules" path stays open: ship the SDK as a Swift Package once protocol stabilizes after 3+ first-party modules.
