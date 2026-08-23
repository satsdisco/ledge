import AppKit
import SwiftUI

/// Non-activating, borderless panel that sits at the notch of a single screen.
/// One instance per managed screen. Owned by `PanelManager`.
final class NotchPanel: NSPanel {
    let screenDescriptor: ScreenDescriptor

    /// Closure consulted on every `canBecomeKey` query so the panel can let
    /// keyboard focus in only when the active module asks for it (Clipboard).
    /// Ambient modules (Bitcoin, Clocks) leave this returning false so
    /// clicking inside the panel never steals focus from the user's app.
    var wantsKeyProvider: (() -> Bool)?

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
        // No system shadow. On this borderless panel the WindowServer's
        // window shadow renders a faint light hairline along the panel's
        // top edge — which sits flush against the screen bezel and reads as
        // an unwanted rim. The SwiftUI silhouette defines the visible edge.
        hasShadow = false
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isMovable = false
        isMovableByWindowBackground = false
        ignoresMouseEvents = false
        hidesOnDeactivate = false
        acceptsMouseMovedEvents = true
        animationBehavior = .none
        setFrame(contentRect, display: false)
    }

    override var canBecomeKey: Bool { wantsKeyProvider?() ?? false }
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
