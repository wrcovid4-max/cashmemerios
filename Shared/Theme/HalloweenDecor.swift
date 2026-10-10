import SwiftUI

/// Halloween decorations for every screen: spider webs in the top corners and pumpkins
/// in the bottom corners. Drawn as a fixed layer that takes no touches.
struct HalloweenDecor: View {
    var body: some View {
        Canvas { context, size in
            let unit = min(size.width, size.height)
            let webRadius = unit * 0.22
            let web = Color.primary.opacity(0.22)

            // Each corner's web fans into the screen: start angle and a quarter-turn sweep.
            drawWeb(&context, corner: CGPoint(x: 0, y: 0), startDegrees: 0, radius: webRadius, colour: web)
            drawWeb(&context, corner: CGPoint(x: size.width, y: 0), startDegrees: 90, radius: webRadius, colour: web)
            drawWeb(&context, corner: CGPoint(x: 0, y: size.height), startDegrees: 270, radius: webRadius, colour: web)
            drawWeb(&context, corner: CGPoint(x: size.width, y: size.height), startDegrees: 180, radius: webRadius, colour: web)

            // Scale with the screen, but never beyond a set size (keeps them small on iPad).
            let pumpkinSize = min(unit * 0.15, 56)
            let inset = unit * 0.1
            drawPumpkin(&context, centre: CGPoint(x: inset, y: size.height - inset), size: pumpkinSize)
            drawPumpkin(&context, centre: CGPoint(x: size.width - inset, y: size.height - inset), size: pumpkinSize)
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    private func drawWeb(_ context: inout GraphicsContext, corner: CGPoint, startDegrees: Double,
                         radius: CGFloat, colour: Color) {
        let spokes = 8
        for i in 0...spokes {
            let angle = (startDegrees + Double(i) * 90 / Double(spokes)) * .pi / 180
            var spoke = Path()
            spoke.move(to: corner)
            spoke.addLine(to: CGPoint(x: corner.x + radius * CGFloat(cos(angle)),
                                      y: corner.y + radius * CGFloat(sin(angle))))
            context.stroke(spoke, with: .color(colour), lineWidth: 1.2)
        }
        let rings = 6
        for ring in 1...rings {
            let r = radius * CGFloat(ring) / CGFloat(rings)
            var arc = Path()
            for step in 0...18 {
                let angle = (startDegrees + Double(step) * 5) * .pi / 180
                let point = CGPoint(x: corner.x + r * CGFloat(cos(angle)),
                                    y: corner.y + r * CGFloat(sin(angle)))
                if step == 0 { arc.move(to: point) } else { arc.addLine(to: point) }
            }
            context.stroke(arc, with: .color(colour), lineWidth: 1.1)
        }
    }

    private func drawPumpkin(_ context: inout GraphicsContext, centre: CGPoint, size: CGFloat) {
        let k = size / 108
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: centre.x - 54 * k + x * k, y: centre.y - 54 * k + y * k)
        }
        var body = Path()
        body.move(to: p(54, 40))
        body.addCurve(to: p(86, 68), control1: p(74, 40), control2: p(86, 54))
        body.addCurve(to: p(54, 96), control1: p(86, 86), control2: p(72, 96))
        body.addCurve(to: p(22, 68), control1: p(36, 96), control2: p(22, 86))
        body.addCurve(to: p(54, 40), control1: p(22, 54), control2: p(34, 40))
        body.closeSubpath()
        context.fill(body, with: .color(Color(red: 1, green: 122 / 255, blue: 24 / 255).opacity(0.9)))

        var stem = Path()
        stem.move(to: p(50, 36))
        stem.addLine(to: p(58, 36))
        stem.addLine(to: p(57, 26))
        stem.addLine(to: p(51, 26))
        stem.closeSubpath()
        context.fill(stem, with: .color(Color(red: 59 / 255, green: 110 / 255, blue: 34 / 255)))

        let face = Color(red: 26 / 255, green: 15 / 255, blue: 46 / 255).opacity(0.9)
        var eyes = Path()
        eyes.move(to: p(36, 56)); eyes.addLine(to: p(50, 56)); eyes.addLine(to: p(43, 68)); eyes.closeSubpath()
        eyes.move(to: p(58, 56)); eyes.addLine(to: p(72, 56)); eyes.addLine(to: p(65, 68)); eyes.closeSubpath()
        var mouth = Path()
        mouth.move(to: p(34, 76)); mouth.addLine(to: p(74, 76)); mouth.addLine(to: p(68, 84))
        mouth.addLine(to: p(62, 76)); mouth.addLine(to: p(54, 85)); mouth.addLine(to: p(46, 76))
        mouth.addLine(to: p(40, 84)); mouth.closeSubpath()
        context.fill(eyes, with: .color(face))
        context.fill(mouth, with: .color(face))
    }
}
