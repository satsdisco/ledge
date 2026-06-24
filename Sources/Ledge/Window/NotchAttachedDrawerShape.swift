import SwiftUI

/// Expanded real-notch surface. The top center remains the same width as the
/// physical cutout, then eases into the wider drawer below the menu-bar area.
struct NotchAttachedDrawerShape: Shape {
    var notchWidth: CGFloat
    var notchHeight: CGFloat
    var shoulderRadius: CGFloat = 10
    var bottomRadius: CGFloat = 22

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let neckWidth = min(max(notchWidth, notchHeight * 2), w)
        let neckLeft = (w - neckWidth) / 2
        let neckRight = (w + neckWidth) / 2
        let joinY = min(max(notchHeight, 1), h)
        let shoulder = min(shoulderRadius, neckLeft, w - neckRight, joinY)
        let bottom = min(bottomRadius, w / 2, max(0, h - joinY))

        p.move(to: CGPoint(x: neckLeft, y: 0))
        p.addLine(to: CGPoint(x: neckRight, y: 0))
        p.addLine(to: CGPoint(x: neckRight, y: joinY - shoulder))
        p.addQuadCurve(
            to: CGPoint(x: neckRight + shoulder, y: joinY),
            control: CGPoint(x: neckRight, y: joinY)
        )
        p.addLine(to: CGPoint(x: w, y: joinY))
        p.addLine(to: CGPoint(x: w, y: h - bottom))
        p.addQuadCurve(
            to: CGPoint(x: w - bottom, y: h),
            control: CGPoint(x: w, y: h)
        )
        p.addLine(to: CGPoint(x: bottom, y: h))
        p.addQuadCurve(
            to: CGPoint(x: 0, y: h - bottom),
            control: CGPoint(x: 0, y: h)
        )
        p.addLine(to: CGPoint(x: 0, y: joinY))
        p.addLine(to: CGPoint(x: neckLeft - shoulder, y: joinY))
        p.addQuadCurve(
            to: CGPoint(x: neckLeft, y: joinY - shoulder),
            control: CGPoint(x: neckLeft, y: joinY)
        )
        p.addLine(to: CGPoint(x: neckLeft, y: 0))
        p.closeSubpath()
        return p
    }
}
