import SwiftUI

/// Halloween easter egg for iPad sidebar mode: a large orange ghost, smiling and laughing on a loop.
struct LaughingGhostView: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let s = min(size.width, size.height)
                let bob = CGFloat(sin(t * 3)) * s * 0.02
                let laugh = CGFloat(0.5 + 0.5 * sin(t * 8))
                let center = CGPoint(x: size.width / 2, y: size.height / 2 + bob)
                drawGhost(&context, center: center, size: s, laugh: laugh)
            }
        }
        .frame(width: 280, height: 280)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawGhost(_ context: inout GraphicsContext, center: CGPoint, size s: CGFloat, laugh: CGFloat) {
        let r = s * 0.40
        let orange = Color(red: 1, green: 122 / 255, blue: 24 / 255)
        let ink = Color(red: 26 / 255, green: 15 / 255, blue: 46 / 255)
        let domeCenter = CGPoint(x: center.x, y: center.y - s * 0.05)
        let hemY = center.y + s * 0.36

        // Body: a dome on top and a scalloped hem at the bottom.
        var body = Path()
        body.move(to: CGPoint(x: center.x - r, y: domeCenter.y))
        for deg in stride(from: 180.0, through: 360.0, by: 4.0) {
            let rad = deg * .pi / 180
            body.addLine(to: CGPoint(x: domeCenter.x + r * CGFloat(cos(rad)),
                                     y: domeCenter.y + r * CGFloat(sin(rad))))
        }
        body.addLine(to: CGPoint(x: center.x + r, y: hemY))
        let scallops = 4
        let width = 2 * r
        for i in 0..<scallops {
            let xStart = center.x + r - width * CGFloat(i) / CGFloat(scallops)
            let xEnd = center.x + r - width * CGFloat(i + 1) / CGFloat(scallops)
            body.addQuadCurve(to: CGPoint(x: xEnd, y: hemY),
                              control: CGPoint(x: (xStart + xEnd) / 2, y: hemY + s * 0.1))
        }
        body.closeSubpath()
        context.fill(body, with: .color(orange))

        // Rosy cheeks.
        let cheekY = center.y + s * 0.08
        for side in [-1.0, 1.0] {
            let cx = center.x + CGFloat(side) * r * 0.6
            let cheek = Path(ellipseIn: CGRect(x: cx - s * 0.05, y: cheekY - s * 0.03, width: s * 0.1, height: s * 0.06))
            context.fill(cheek, with: .color(Color.pink.opacity(0.45)))
        }

        // Happy closed eyes: upward arcs.
        let eyeY = center.y - s * 0.08
        for side in [-1.0, 1.0] {
            let ex = center.x + CGFloat(side) * r * 0.4
            var eye = Path()
            eye.move(to: CGPoint(x: ex - s * 0.07, y: eyeY))
            eye.addQuadCurve(to: CGPoint(x: ex + s * 0.07, y: eyeY),
                             control: CGPoint(x: ex, y: eyeY - s * 0.09))
            context.stroke(eye, with: .color(ink), style: StrokeStyle(lineWidth: s * 0.03, lineCap: .round))
        }

        // Laughing mouth: opens and closes.
        let mouthY = center.y + s * 0.12
        var mouth = Path()
        mouth.move(to: CGPoint(x: center.x - s * 0.2, y: mouthY))
        mouth.addQuadCurve(to: CGPoint(x: center.x + s * 0.2, y: mouthY),
                           control: CGPoint(x: center.x, y: mouthY + s * 0.04 + laugh * s * 0.16))
        mouth.closeSubpath()
        context.fill(mouth, with: .color(ink))
    }
}
