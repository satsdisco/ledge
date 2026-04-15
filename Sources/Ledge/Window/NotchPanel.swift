import AppKit
import SwiftUI

/// Non-activating, borderless panel that sits at the notch of a single screen.
/// One instance per managed screen. Owned by `PanelManager`.
final class NotchPanel: NSPanel {
    let screenDescriptor: ScreenDescriptor

    init(screen: ScreenDescriptor, contentRect: CGRect) {
        self.screenDescriptor = screen
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isMovable = false
        isMovableByWindowBackground = false
        ignoresMouseEvents = false
        hidesOnDeactivate = false
        animationBehavior = .none
        setFrame(contentRect, display: false)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func install(content: some View) {
        let host = NSHostingView(rootView: AnyView(content))
        host.translatesAutoresizingMaskIntoConstraints = false
        contentView = NSView(frame: .zero)
        contentView?.addSubview(host)
        if let cv = contentView {
            NSLayoutConstraint.activate([
                host.leadingAnchor.constraint(equalTo: cv.leadingAnchor),
                host.trailingAnchor.constraint(equalTo: cv.trailingAnchor),
                host.topAnchor.constraint(equalTo: cv.topAnchor),
                host.bottomAnchor.constraint(equalTo: cv.bottomAnchor)
            ])
        }
    }

    func updateFrame(_ rect: CGRect) {
        guard frame != rect else { return }
        setFrame(rect, display: true, animate: false)
    }

    func show() {
        orderFrontRegardless()
    }

    func hide() {
        orderOut(nil)
    }
}
