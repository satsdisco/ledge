import AppKit
import CoreGraphics

/// Pure, testable description of a screen's relevant geometry.
/// Decouples `NotchGeometry` from `NSScreen` for unit tests.
struct ScreenDescriptor: Equatable, Hashable {
    let displayID: CGDirectDisplayID
    let frame: CGRect
    let safeAreaTop: CGFloat
    let auxiliaryTopLeft: CGRect?
    let auxiliaryTopRight: CGRect?
    let localizedName: String
}

extension NSScreen {
    var descriptor: ScreenDescriptor {
        let id = (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
        return ScreenDescriptor(
            displayID: id,
            frame: frame,
            safeAreaTop: safeAreaInsets.top,
            auxiliaryTopLeft: auxiliaryTopLeftArea,
            auxiliaryTopRight: auxiliaryTopRightArea,
            localizedName: localizedName
        )
    }

    static var descriptors: [ScreenDescriptor] { screens.map(\.descriptor) }
}

enum NotchGeometry {
    /// Default synthetic notch dimensions used when a screen has no real notch
    /// and the user has opted in via `FeatureFlags.syntheticNotch`.
    static let syntheticSize = CGSize(width: 200, height: 32)

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
            let size = syntheticSize
            let x = screen.frame.midX - size.width / 2
            let y = screen.frame.maxY - size.height
            return CGRect(x: x, y: y, width: size.width, height: size.height)
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
        tongue: CGFloat = 8
    ) -> CGRect? {
        guard let notch = notchRect(for: screen, synthetic: synthetic) else { return nil }
        return CGRect(
            x: notch.minX,
            y: notch.minY - tongue,
            width: notch.width,
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
        let x = notch.midX - width / 2
        let y = screen.frame.maxY - height
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
