import AppKit
import CoreGraphics

/// Pure, testable description of a screen's relevant geometry.
/// Decouples `NotchGeometry` from `NSScreen` for unit tests.
struct ScreenDescriptor: Equatable, Hashable {
    let displayID: CGDirectDisplayID
    let frame: CGRect
    let visibleFrame: CGRect
    let safeAreaTop: CGFloat
    let auxiliaryTopLeft: CGRect?
    let auxiliaryTopRight: CGRect?
    let localizedName: String

    /// Pixels between the top of `frame` and the top of `visibleFrame` —
    /// i.e., the menu bar height on this screen. 0 when the menu bar is
    /// hidden (e.g., fullscreen).
    var menuBarHeight: CGFloat { max(0, frame.maxY - visibleFrame.maxY) }
}

extension NSScreen {
    var descriptor: ScreenDescriptor {
        let id = (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
        return ScreenDescriptor(
            displayID: id,
            frame: frame,
            visibleFrame: visibleFrame,
            safeAreaTop: safeAreaInsets.top,
            auxiliaryTopLeft: auxiliaryTopLeftArea,
            auxiliaryTopRight: auxiliaryTopRightArea,
            localizedName: localizedName
        )
    }

    static var descriptors: [ScreenDescriptor] { screens.map(\.descriptor) }
}

enum NotchGeometry {
    /// Synthetic notch dimensions on screens without a hardware notch.
    /// 185 × 32 pt matches the real 14" MacBook Pro notch (the canonical MBP
    /// form factor; Apple has kept these physical dimensions identical from
    /// M1 Pro through M4 Pro/Max). On a typical 24 pt menu bar the synthetic
    /// notch protrudes ~8 pt below into the desktop — mirroring the way a
    /// real notch sits taller than a non-notched menu bar.
    static let syntheticWidth: CGFloat = 185
    static let syntheticHeight: CGFloat = 32

    /// Returns the notch rect for a given screen, in global (bottom-left origin) coordinates,
    /// or `nil` if the screen has no notch and synthetic mode is off.
    static func notchRect(for screen: ScreenDescriptor, synthetic: Bool) -> CGRect? {
        if screen.safeAreaTop > 0,
           let left = screen.auxiliaryTopLeft,
           let right = screen.auxiliaryTopRight {
            let x = left.maxX
            let width = right.minX - left.maxX
            let height = screen.safeAreaTop
            let y = screen.frame.maxY - height
            guard width > 0, height > 0 else { return nil }
            return CGRect(x: x, y: y, width: width, height: height)
        }

        if synthetic {
            let width = syntheticWidth
            let height = syntheticHeight
            // Round to whole pixels so the rounded-corner edges anti-alias
            // crisply (sub-pixel x on odd-width screens softens the silhouette).
            let x = (screen.frame.midX - width / 2).rounded()
            let y = screen.frame.maxY - height
            return CGRect(x: x, y: y, width: width, height: height)
        }

        return nil
    }

    /// True if the screen has a hardware notch.
    static func hasHardwareNotch(_ screen: ScreenDescriptor) -> Bool {
        screen.safeAreaTop > 0 && screen.auxiliaryTopLeft != nil && screen.auxiliaryTopRight != nil
    }

    /// The visible panel frame when collapsed. The panel covers the notch rect (those
    /// pixels are the hardware cutout and are already black) plus a "tongue" extending
    /// downward past the notch so the panel is actually visible.
    static func collapsedPanelRect(
        for screen: ScreenDescriptor,
        synthetic: Bool,
        tongue: CGFloat = 0,
        horizontalInset: CGFloat = 1
    ) -> CGRect? {
        guard let notch = notchRect(for: screen, synthetic: synthetic) else { return nil }
        // Inset horizontally by 1pt to absorb sub-pixel rounding on
        // auxiliaryTopLeftArea.maxX / auxiliaryTopRightArea.minX, which can
        // otherwise leave a hairline of panel fill outside the physical cutout.
        return CGRect(
            x: notch.minX + horizontalInset,
            y: notch.minY - tongue,
            width: notch.width - horizontalInset * 2,
            height: notch.height + tongue
        )
    }

    /// The panel frame when expanded. Grows wider and taller than the notch.
    /// Centered horizontally on the notch, pinned to the top of the screen.
    static func expandedPanelRect(
        for screen: ScreenDescriptor,
        synthetic: Bool,
        width: CGFloat = 420,
        height: CGFloat = 140
    ) -> CGRect? {
        guard let notch = notchRect(for: screen, synthetic: synthetic) else { return nil }
        let x = (notch.midX - width / 2).rounded()
        let y = screen.frame.maxY - height
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
