import SwiftUI

/// Matches the physical MacBook notch cutout outline. Top edge is flush with
/// the screen top; sides are vertical; the bottom corners curve INWARD
/// (concave fillets) where the cutout meets the menu bar. Drawing the panel
/// with this shape — rather than a plain rectangle — prevents the "grey
/// sliver" that otherwise bleeds onto the menu bar next to the physical notch.
struct NotchCutoutShape: Shape {
    /// Radius of the concave fillet where the notch walls merge into the
    /// menu bar. Apple's hardware uses roughly 8–10pt on current models.
    var filletRadius: CGFloat = 10

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = min(filletRadius, rect.width / 2, rect.height)
        let w = rect.width
        let h = rect.height

        p.move(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: w, y: 0))
        p.addLine(to: CGPoint(x: w, y: h - r))

        // Concave bottom-right: arc bulges up-and-left into the shape.
        // Center at (w, h) sits OUTSIDE the shape at the "missing" corner.
        p.addRelativeArc(
            center: CGPoint(x: w, y: h),
            radius: r,
            startAngle: .degrees(270),
            delta: .degrees(-90)
        )

        p.addLine(to: CGPoint(x: r, y: h))

        // Concave bottom-left: arc bulges up-and-right into the shape.
        p.addRelativeArc(
            center: CGPoint(x: 0, y: h),
            radius: r,
            startAngle: .degrees(0),
            delta: .degrees(-90)
        )

        p.addLine(to: CGPoint(x: 0, y: 0))
        p.closeSubpath()
        return p
    }
}
