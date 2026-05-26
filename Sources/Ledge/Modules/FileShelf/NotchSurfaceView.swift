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

    /// Corner radius of the expanded drawer — the two bottom corners on a
    /// real notch, all four on the synthetic pill. Shared by `shape` and the
    /// `rim` so they trace the same curve.
    private let expandedCornerRadius: CGFloat = 22

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
        // The surface is pure OLED black across the notch band and eases into
        // a slightly grayer black down the drawer (see `surfaceFill`). A faint
        // rim traces the sides and bottom only — never the top edge, which
        // meets the screen bezel — plus the panel's drop shadow for elevation.
        surfaceFill
            .overlay(content)
            .overlay(rim)
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

    /// The panel's background fill: pure OLED black for the top band — about
    /// the height of the physical notch — easing into a slightly grayer black
    /// down the rest of the drawer. The collapsed panel is only as tall as the
    /// notch, so the band covers it entirely and it stays pure black.
    private var surfaceFill: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let band = height > 0 ? min(notchHeight / height, 1) : 1
            shape.fill(
                LinearGradient(
                    stops: [
                        .init(color: Palette.surface, location: 0),
                        .init(color: Palette.surface, location: band),
                        .init(color: Palette.drawerBase, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    /// The edge rim. Expanded: traces the sides and bottom only — the top edge
    /// meets the screen bezel and gets no rim. Collapsed: the full hairline
    /// around the notch-cutout shape, unchanged.
    @ViewBuilder
    private var rim: some View {
        let synthetic = FeatureFlags.syntheticNotch
        let expanded = expansion.phase == .expanded
        let color = Color.white.opacity(strokeOpacity(synthetic: synthetic, expanded: expanded))
        if expanded {
            PanelRim(
                topRadius: synthetic ? expandedCornerRadius : 0,
                bottomRadius: expandedCornerRadius
            )
            .stroke(color, lineWidth: 1)
        } else {
            shape.stroke(color, lineWidth: 1)
        }
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
                return AnyShape(RoundedRectangle(cornerRadius: expandedCornerRadius, style: .continuous))
            }
        }
        switch expansion.phase {
        case .collapsed:
            return AnyShape(NotchCutoutShape(filletRadius: 10))
        case .expanded:
            return AnyShape(UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: expandedCornerRadius,
                bottomTrailingRadius: expandedCornerRadius,
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

// MARK: - Panel rim

/// An open path tracing the left edge, bottom edge, and right edge of the
/// expanded panel — but not the top. Stroked, it gives the drawer a rim on
/// the sides and bottom only; the top edge meets the screen bezel.
private struct PanelRim: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let tr = max(0, min(topRadius, rect.width / 2, rect.height / 2))
        let br = max(0, min(bottomRadius, rect.width / 2, rect.height / 2))
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + tr))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - br))
        p.addArc(
            tangent1End: CGPoint(x: rect.minX, y: rect.maxY),
            tangent2End: CGPoint(x: rect.maxX, y: rect.maxY),
            radius: br
        )
        p.addLine(to: CGPoint(x: rect.maxX - br, y: rect.maxY))
        p.addArc(
            tangent1End: CGPoint(x: rect.maxX, y: rect.maxY),
            tangent2End: CGPoint(x: rect.maxX, y: rect.minY),
            radius: br
        )
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + tr))
        return p
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
