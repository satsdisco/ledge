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
    /// Width of the synthetic notch — picked to match the visual weight of a
    /// real 14"/16" MacBook notch (~200pt regardless of screen width).
    static let syntheticWidth: CGFloat = 200

    /// Fallback synthetic notch height when the screen has no menu bar
    /// (e.g., menu bar autohidden, fullscreen app). Matches the standard
    /// macOS menu bar on non-notched displays.
    static let syntheticHeightFallback: CGFloat = 24

    /// Synthetic notch height for a given screen. Tracks the actual menu bar
    /// height so the panel sits flush within the menu bar rather than
    /// overhanging onto the desktop.
    static func syntheticHeight(for screen: ScreenDescriptor) -> CGFloat {
        let menu = screen.menuBarHeight
        return menu > 0 ? menu : syntheticHeightFallback
    }

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
            let height = syntheticHeight(for: screen)
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
