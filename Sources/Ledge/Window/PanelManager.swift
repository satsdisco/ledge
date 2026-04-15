import AppKit
import SwiftUI

/// Owns one `NotchPanel` per eligible screen. Idempotent: safe to call
/// `reconcile(with:)` repeatedly with the current screen list.
/// Listens to `NotchExpansionController` to animate panel frames.
final class PanelManager {
    private var panels: [CGDirectDisplayID: NotchPanel] = [:]
    private let expansion: NotchExpansionController
    private let active: ActiveModuleStore
    private let modules: [LedgeModule]

    init(expansion: NotchExpansionController, active: ActiveModuleStore, modules: [LedgeModule]) {
        self.expansion = expansion
        self.active = active
        self.modules = modules
        expansion.onPhaseChange = { [weak self] phase in
            self?.animate(to: phase)
        }
    }

    func reconcile(with screens: [ScreenDescriptor]) {
        let eligible = screens.filter {
            NotchGeometry.notchRect(for: $0, synthetic: FeatureFlags.syntheticNotch) != nil
        }
        let eligibleIDs = Set(eligible.map(\.displayID))

        for (id, panel) in panels where !eligibleIDs.contains(id) {
            panel.hide()
            panels.removeValue(forKey: id)
            Log.window.info("Removed panel for displayID \(id)")
        }

        for screen in eligible {
            guard let rect = currentRect(for: screen) else { continue }

            if let existing = panels[screen.displayID] {
                existing.updateFrame(rect)
                continue
            }

            let panel = NotchPanel(screen: screen, contentRect: rect)
            panel.install(content: NotchSurfaceView(
                expansion: expansion,
                active: active,
                modules: modules
            ))
            panel.show()
            panels[screen.displayID] = panel
            Log.window.info("Installed panel for \(screen.localizedName, privacy: .public) (id: \(screen.displayID)) at \(String(describing: rect), privacy: .public)")
        }
    }

    func tearDown() {
        for panel in panels.values { panel.hide() }
        panels.removeAll()
    }

    // MARK: - Private

    private func currentRect(for screen: ScreenDescriptor) -> CGRect? {
        switch expansion.phase {
        case .collapsed:
            return NotchGeometry.collapsedPanelRect(for: screen, synthetic: FeatureFlags.syntheticNotch)
        case .expanded:
            return NotchGeometry.expandedPanelRect(for: screen, synthetic: FeatureFlags.syntheticNotch)
        }
    }

    private func animate(to phase: NotchExpansionController.Phase) {
        for panel in panels.values {
            guard let rect = currentRect(for: panel.screenDescriptor) else { continue }
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.22
                ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1.0, 0.36, 1.0)
                ctx.allowsImplicitAnimation = true
                panel.animator().setFrame(rect, display: true)
            }
        }
    }

    var managedDisplayIDs: Set<CGDirectDisplayID> { Set(panels.keys) }
}
