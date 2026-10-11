import SwiftUI

/// Halloween effect for iPad. Loops every 16 seconds: a thin brown wire drops from the top centre, a black
/// spider comes down on it, the wire breaks near the bottom, the spider falls and hangs upside down for a few
/// seconds, then turns over, walks away towards the bottom and disappears.
struct SpiderDropView: View {
    private let cycle: Double = 16

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle)
            Canvas { context, size in
                drawScene(&context, size: size, t: t)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func smooth(_ x: Double) -> Double {
        let c = min(max(x, 0), 1)
        return c * c * (3 - 2 * c)
    }

    private func drawScene(_ context: inout GraphicsContext, size: CGSize, t: Double) {
        let w = Double(size.width)
        let h = Double(size.height)
        let cx = w * 0.5
        let halfway = h * 0.5
        let breakY = h * 0.88
        let hangY = h * 0.96
        let brown = Color(red: 0.42, green: 0.26, blue: 0.12)

        var x = cx
        var y = 0.0
        var angle = 0.0
        var alpha = 1.0
        var walk = 0.0
        var wireAlpha = 1.0
        var showSpider = true

        if t < 0.6 {
            showSpider = false
        } else if t < 4.0 {
            y = halfway * smooth((t - 0.6) / 3.4)
            walk = t * 4
        } else if t < 6.0 {
            y = halfway + (breakY - halfway) * smooth((t - 4.0) / 2.0)
            walk = t * 4
        } else if t < 7.2 {
            // The wire snaps and the spider falls, turning upside down.
            let p = (t - 6.0) / 1.2
            y = breakY + (hangY - breakY) * p * p
            angle = Double.pi * p
            wireAlpha = max(0, 1 - (t - 6.0))
        } else if t < 10.2 {
            // Hanging upside down, legs gently moving.
            y = hangY
            angle = Double.pi
            walk = sin(t * 2) * 0.3
        } else if t < 13.5 {
            // Turns over, walks away towards the bottom and fades out.
            let p = (t - 10.2) / 3.3
            x = cx + w * 0.35 * p
            y = hangY + h * 0.06 * p
            angle = Double.pi * (1 - min(1, (t - 10.2) / 0.6))
            walk = t * 10
            alpha = 1 - max(0, (p - 0.7) / 0.3)
            wireAlpha = 0
        } else {
            showSpider = false
            wireAlpha = 0
        }

        // The thin brown wire from the top centre down to the spider.
        if wireAlpha > 0 && t >= 0.6 && t < 7.2 {
            let end = t < 6.0 ? y : breakY
            var wire = Path()
            wire.move(to: CGPoint(x: cx, y: 0))
            wire.addLine(to: CGPoint(x: cx, y: end))
            context.stroke(wire, with: .color(brown.opacity(wireAlpha)), lineWidth: 1.2)
        }

        if showSpider {
            drawSpider(&context, at: CGPoint(x: x, y: y), angle: angle, walk: walk, alpha: alpha, scale: 1.5)
        }
    }

    private func drawSpider(_ context: inout GraphicsContext, at p: CGPoint, angle: Double,
                            walk: Double, alpha: Double, scale: Double) {
        var c = context
        c.translateBy(x: p.x, y: p.y)
        c.rotate(by: .radians(angle))
        c.scaleBy(x: scale, y: scale)
        let ink = Color.black.opacity(alpha)

        // Eight legs, four per side, moving in alternating steps.
        let legs = Path { path in
            for side in [-1.0, 1.0] {
                for i in 0..<4 {
                    let phase = walk + Double(i) * 1.2 + (side > 0 ? Double.pi : 0)
                    let baseY = -6.0 + Double(i) * 3.5
                    let base = CGPoint(x: side * 3.5, y: baseY)
                    let knee = CGPoint(x: side * (11 + 2 * sin(phase)), y: baseY - 5 + 2.5 * cos(phase))
                    let foot = CGPoint(x: side * (20 + 3 * sin(phase + 0.6)), y: baseY + 6 - cos(phase))
                    path.move(to: base)
                    path.addLine(to: knee)
                    path.addLine(to: foot)
                }
            }
        }
        c.stroke(legs, with: .color(ink), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))

        // Body: abdomen and head.
        c.fill(Path(ellipseIn: CGRect(x: -7, y: -1, width: 14, height: 18)), with: .color(ink))
        c.fill(Path(ellipseIn: CGRect(x: -5, y: -10, width: 10, height: 9)), with: .color(ink))
    }
}
