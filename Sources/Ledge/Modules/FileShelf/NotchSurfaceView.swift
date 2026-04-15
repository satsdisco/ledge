import SwiftUI
import UniformTypeIdentifiers

/// The SwiftUI root installed into each NotchPanel. Composes the active module's
/// collapsed/expanded views with hover + drop + shape, all driven by the
/// shared `NotchExpansionController`.
struct NotchSurfaceView: View {
    @Bindable var expansion: NotchExpansionController
    let module: FileShelfModule

    @State private var dropTargeted = false

    var body: some View {
        shape
            .fill(.black.opacity(0.88))
            .overlay(content)
            .overlay(
                shape.stroke(.white.opacity(dropTargeted ? 0.35 : 0.06), lineWidth: 1)
            )
            .animation(.interpolatingSpring(stiffness: 320, damping: 28), value: expansion.phase)
            .onHover { hovering in
                hovering ? expansion.hoverEntered() : expansion.hoverExited()
            }
            .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { providers in
                expansion.dragEntered()
                let accepted = module.handleDrop(providers)
                // Collapse shortly after drop so panel returns to rest.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    expansion.collapse()
                }
                return accepted
            }
            .onChange(of: dropTargeted) { _, targeted in
                if targeted { expansion.dragEntered() } else { expansion.dragExited() }
            }
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
            module.collapsedView
                .padding(.horizontal, 6)
                .padding(.bottom, 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .transition(.opacity)
        case .expanded:
            module.expandedView
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .transition(.opacity)
        }
    }
}
