import SwiftUI
import UniformTypeIdentifiers

/// The SwiftUI root installed into each NotchPanel. Composes whichever module
/// is currently active, with hover + drop + shape, driven by the shared
/// `NotchExpansionController`. Multi-module switching happens in the expanded
/// header via a segmented control.
struct NotchSurfaceView: View {
    @Bindable var expansion: NotchExpansionController
    @Bindable var active: ActiveModuleStore
    let modules: [LedgeModule]

    @State private var dropTargeted = false

    private var activeModule: LedgeModule? {
        modules.first { type(of: $0).identifier == active.activeID } ?? modules.first
    }

    var body: some View {
        shape
            .fill(.black.opacity(0.88))
            .overlay(content)
            .overlay(
                shape.stroke(.white.opacity(dropTargeted ? 0.35 : 0.06), lineWidth: 1)
            )
            .animation(.interpolatingSpring(stiffness: 320, damping: 28), value: expansion.phase)
            .animation(.interpolatingSpring(stiffness: 220, damping: 30), value: active.activeID)
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
    }

    private func activeDropModule() -> LedgeModule? {
        if let current = activeModule, current.acceptsDrops { return current }
        // If active module doesn't take drops but another does, route to that.
        if let drop = modules.first(where: { $0.acceptsDrops }) {
            active.activeID = type(of: drop).identifier
            return drop
        }
        return nil
    }

    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: expansion.phase == .expanded ? 18 : 12,
            bottomTrailingRadius: expansion.phase == .expanded ? 18 : 12,
            topTrailingRadius: 0,
            style: .continuous
        )
    }

    @ViewBuilder
    private var content: some View {
        switch expansion.phase {
        case .collapsed:
            if let module = activeModule {
                module.collapsedView
                    .padding(.horizontal, 6)
                    .padding(.bottom, 4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .transition(.opacity)
            }
        case .expanded:
            VStack(spacing: 0) {
                if modules.count > 1 {
                    moduleSwitcher
                }
                if let module = activeModule {
                    module.expandedView
                        .id(active.activeID)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .transition(.opacity)
        }
    }

    private var moduleSwitcher: some View {
        HStack(spacing: 4) {
            ForEach(modules, id: \.objectIdentifier) { module in
                let isActive = active.activeID == type(of: module).identifier
                Button {
                    active.activeID = type(of: module).identifier
                } label: {
                    Text(module.displayName)
                        .font(.system(size: 10, weight: isActive ? .semibold : .medium))
                        .foregroundStyle(.white.opacity(isActive ? 0.95 : 0.45))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isActive ? .white.opacity(0.10) : .clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 6)
    }
}

private extension LedgeModule {
    var objectIdentifier: ObjectIdentifier { ObjectIdentifier(self) }
}
