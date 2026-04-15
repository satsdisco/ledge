import AppKit
import SwiftUI

/// Owns one `NotchPanel` per eligible screen. Idempotent: safe to call
/// `reconcile(with:)` repeatedly with the current screen list.
final class PanelManager {
    private var panels: [CGDirectDisplayID: NotchPanel] = [:]

    func reconcile(with screens: [ScreenDescriptor]) {
        let eligible = screens.filter { screen in
            NotchGeometry.collapsedPanelRect(for: screen, synthetic: FeatureFlags.syntheticNotch) != nil
        }
        let eligibleIDs = Set(eligible.map(\.displayID))

        // Remove panels for screens that vanished or became ineligible.
        for (id, panel) in panels where !eligibleIDs.contains(id) {
            panel.hide()
            panels.removeValue(forKey: id)
            Log.window.info("Removed panel for displayID \(id)")
        }

        // Create or update panels for eligible screens.
        for screen in eligible {
            guard let rect = NotchGeometry.collapsedPanelRect(for: screen, synthetic: FeatureFlags.syntheticNotch) else { continue }

            if let existing = panels[screen.displayID] {
                existing.updateFrame(rect)
                continue
            }

            let panel = NotchPanel(screen: screen, contentRect: rect)
            panel.install(content: NotchPlaceholderView(screen: screen))
            panel.show()
            panels[screen.displayID] = panel
            Log.window.info("Installed panel for \(screen.localizedName, privacy: .public) (id: \(screen.displayID)) at \(String(describing: rect), privacy: .public)")
        }
    }

    func tearDown() {
        for panel in panels.values { panel.hide() }
        panels.removeAll()
    }

    // Test hook
    var managedDisplayIDs: Set<CGDirectDisplayID> { Set(panels.keys) }
}

/// Placeholder content for Phase 1 — a rounded-bottom red shape that proves
/// the panel is positioned correctly. Replaced by module content in Phase 2.
private struct NotchPlaceholderView: View {
    let screen: ScreenDescriptor

    var body: some View {
        ZStack {
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 12,
                bottomTrailingRadius: 12,
                topTrailingRadius: 0,
                style: .continuous
            )
            .fill(Color.red.opacity(0.55))

            if FeatureFlags.debugOverlay {
                DebugOverlay(screen: screen)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
