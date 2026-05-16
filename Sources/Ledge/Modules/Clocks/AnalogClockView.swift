import SwiftUI

struct AnalogClockView: View {
    let date: Date
    let timeZone: TimeZone
    let diameter: CGFloat

    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height
            let center = CGPoint(x: w / 2, y: h / 2)
            let r = min(w, h) / 2

            // Face
            let face = Path(ellipseIn: CGRect(x: 0.5, y: 0.5, width: w - 1, height: h - 1))
            ctx.stroke(face, with: .color(Palette.tertiary), lineWidth: 1)

            // Tick marks at 12/3/6/9
            for i in 0..<4 {
                let angle = Double(i) / 4 * 2 * .pi - .pi / 2
                let outer = CGPoint(x: center.x + cos(angle) * (r - 1.5),
                                    y: center.y + sin(angle) * (r - 1.5))
                let inner = CGPoint(x: center.x + cos(angle) * (r - 3.5),
                                    y: center.y + sin(angle) * (r - 3.5))
                var tick = Path()
                tick.move(to: inner)
                tick.addLine(to: outer)
                ctx.stroke(tick, with: .color(Palette.secondary), lineWidth: 1)
            }

            // Time components in the target zone
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = timeZone
            let comps = cal.dateComponents([.hour, .minute, .second], from: date)
            let second = Double(comps.second ?? 0)
            let minute = Double(comps.minute ?? 0) + second / 60
            let hour = Double(comps.hour ?? 0) + minute / 60

            // Hour hand
            let hAngle = (hour.truncatingRemainder(dividingBy: 12) / 12) * 2 * .pi - .pi / 2
            ctx.stroke(
                handPath(from: center, angle: hAngle, length: r * 0.52),
                with: .color(Palette.primary),
                lineWidth: 1.6
            )

            // Minute hand
            let mAngle = (minute / 60) * 2 * .pi - .pi / 2
            ctx.stroke(
                handPath(from: center, angle: mAngle, length: r * 0.78),
                with: .color(Palette.primary),
                lineWidth: 1
            )

            // Second hand — accent color, kinetic.
            let sAngle = (second / 60) * 2 * .pi - .pi / 2
            ctx.stroke(
                handPath(from: center, angle: sAngle, length: r * 0.82),
                with: .color(Palette.accent.opacity(0.9)),
                lineWidth: 0.6
            )

            // Center dot
            let dot = Path(ellipseIn: CGRect(x: center.x - 1.2, y: center.y - 1.2, width: 2.4, height: 2.4))
            ctx.fill(dot, with: .color(.white))
        }
        .frame(width: diameter, height: diameter)
    }

    private func handPath(from center: CGPoint, angle: Double, length: CGFloat) -> Path {
        var p = Path()
        p.move(to: center)
        p.addLine(to: CGPoint(x: center.x + cos(angle) * length,
                              y: center.y + sin(angle) * length))
        return p
    }
}
