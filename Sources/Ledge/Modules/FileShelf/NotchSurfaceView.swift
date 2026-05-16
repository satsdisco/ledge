import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// The SwiftUI root installed into each NotchPanel. Composes whichever module
/// is currently active, plus a combined "glance strip" in collapsed state.
struct NotchSurfaceView: View {
    @Bindable var expansion: NotchExpansionController
    @Bindable var active: ActiveModuleStore
    @Bindable var enabled: ModuleEnabledStore
    let modules: [LedgeModule]
    /// Height of the physical notch cutout on this screen. Used to push
    /// expanded content below the cutout region so it isn't hidden.
    let notchHeight: CGFloat

    /// Modules visible after the user's enable/disable choices.
    private var visibleModules: [LedgeModule] {
        modules.filter { enabled.isEnabled(type(of: $0).identifier) }
    }

    @State private var dropTargeted = false
    @Environment(\.openSettings) private var openSettingsScene

    private var activeModule: LedgeModule? {
        let pool = visibleModules.isEmpty ? modules : visibleModules
        return pool.first { type(of: $0).identifier == active.activeID } ?? pool.first
    }

    var body: some View {
        let synthetic = FeatureFlags.syntheticNotch
        let expanded = expansion.phase == .expanded
        // Pure black surface — matches the iconic notch identity. The "liquid
        // glass" feel is delivered by a thin specular highlight along the top
        // edge (in expanded state only, where it reads as a surface gleam
        // rather than a notch reflection) plus the panel's drop shadow for
        // elevation.
        shape
            .fill(Palette.surface)
            .overlay(specularHighlight.opacity(expanded ? 1 : 0))
            .overlay(content)
            .overlay(
                shape.stroke(
                    .white.opacity(strokeOpacity(synthetic: synthetic, expanded: expanded)),
                    lineWidth: 1
                )
            )
            .animation(Motion.express, value: expansion.phase)
            .animation(Motion.calm, value: active.activeID)
            .contentShape(Rectangle())
            .onHover { hovering in
                hovering ? expansion.hoverEntered() : expansion.hoverExited()
            }
            .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { providers in
                expansion.dragEntered()
                guard let module = activeDropModule() else { return false }
                let accepted = module.handleDrop(providers)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    expansion.collapse()
                }
                return accepted
            }
            .onChange(of: dropTargeted) { _, targeted in
                if targeted { expansion.dragEntered() } else { expansion.dragExited() }
            }
            .contextMenu { contextMenu }
    }

    // MARK: - Style helpers

    private func strokeOpacity(synthetic: Bool, expanded: Bool) -> Double {
        if dropTargeted { return 0.35 }
        if expanded { return 0.08 }    // faint rim — defines the drawer edge against wallpaper
        if synthetic { return 0 }       // clean pill, no rim
        return 0.06                     // real-notch collapsed: faint hairline
    }

    /// Soft white-to-clear gradient pinned to the top edge of the shape.
    /// Reads as a specular gleam — the dark-glass equivalent of a highlight
    /// without making the whole surface look gray.
    private var specularHighlight: some View {
        shape
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.08), Color.white.opacity(0)],
                    startPoint: .top,
                    endPoint: .center
                )
            )
            .blendMode(.plusLighter)
    }

    // MARK: - Shape

    /// Real notch: collapsed uses the hardware-matching cutout shape (concave
    /// bottom fillets meet the screen bezel), expanded keeps a flat top
    /// (hidden behind the bezel) with rounded bottom corners.
    ///
    /// Synthetic notch (no hardware to align with): use a clean pill /
    /// rounded rectangle so the panel reads as an intentional UI element
    /// against the wallpaper instead of a notch-shaped silhouette hanging
    /// in empty space.
    private var shape: AnyShape {
        if FeatureFlags.syntheticNotch {
            switch expansion.phase {
            case .collapsed:
                // True pill: corner radius = half the notch height, so the
                // shape's left and right ends are perfect semicircles.
                return AnyShape(RoundedRectangle(cornerRadius: notchHeight / 2, style: .continuous))
            case .expanded:
                return AnyShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
        switch expansion.phase {
        case .collapsed:
            return AnyShape(NotchCutoutShape(filletRadius: 10))
        case .expanded:
            return AnyShape(UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 22,
                bottomTrailingRadius: 22,
                topTrailingRadius: 0,
                style: .continuous
            ))
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch expansion.phase {
        case .collapsed:
            // Flush with the notch — no visible glance content by default.
            // Users who want an always-on strip will get a toggle later.
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .expanded:
            VStack(spacing: 0) {
                if visibleModules.count > 1 {
                    moduleSwitcher
                }
                if let module = activeModule {
                    module.expandedView
                        .id(active.activeID)
                        .transition(.opacity)
                }
            }
            // Push content below the physical notch cutout so nothing gets
            // obscured by the hardware bezel.
            .padding(.top, notchHeight)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .transition(.opacity)
        }
    }

    /// Uniform stacked-tab switcher: every module shows its icon AND its
    /// label, with the active tab highlighted by a pill background. Matches
    /// the iOS tab-bar pattern so it's instantly readable — the user never
    /// has to hover to learn what each icon means.
    private var moduleSwitcher: some View {
        HStack(spacing: 2) {
            ForEach(visibleModules, id: \.objectIdentifier) { module in
                let isActive = active.activeID == type(of: module).identifier
                Button {
                    active.activeID = type(of: module).identifier
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: module.iconName)
                            .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                            .frame(height: 14)
                        Text(module.displayName)
                            .font(.system(size: 9, weight: isActive ? .semibold : .medium))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .foregroundStyle(isActive ? Palette.primary : Palette.tertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(isActive ? Palette.highlight : .clear)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .animation(Motion.calm, value: isActive)
            }
        }
        .padding(.top, 4)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Right-click menu

    @ViewBuilder
    private var contextMenu: some View {
        ForEach(visibleModules, id: \.objectIdentifier) { module in
            let isActive = active.activeID == type(of: module).identifier
            Button(isActive ? "✓ \(module.displayName)" : module.displayName) {
                active.activeID = type(of: module).identifier
                expansion.expand()
            }
        }
        Divider()
        Button("Settings…") {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            openSettingsScene()
        }
        Divider()
        Button("Quit Ledge") { NSApp.terminate(nil) }
    }

    // MARK: - Drop routing

    private func activeDropModule() -> LedgeModule? {
        if let current = activeModule, current.acceptsDrops { return current }
        if let drop = modules.first(where: { $0.acceptsDrops }) {
            active.activeID = type(of: drop).identifier
            return drop
        }
        return nil
    }
}

// MARK: - Combined collapsed strip

private struct CombinedCollapsedStrip: View {
    let modules: [LedgeModule]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(modules.enumerated()), id: \.offset) { index, module in
                if index > 0 {
                    Rectangle()
                        .fill(.white.opacity(0.12))
                        .frame(width: 1, height: 10)
                }
                module.collapsedView
            }
        }
    }
}

private extension LedgeModule {
    var objectIdentifier: ObjectIdentifier { ObjectIdentifier(self) }
}
