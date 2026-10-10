import SwiftUI

/// A large bat that flies in from the left edge towards the status bar, swoops across to the
/// right and disappears, in a continuous loop. Takes no touches.
struct BatFlyerView: View {
    @State private var flight = BatFlight()

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                flight.update(now: now)
                flight.draw(&context, size: size, now: now)
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

final class BatFlight {
    private let interval: Double = 10
    private let duration: Double = 7
    private var nextStart: Double?
    private var startedAt: Double?

    func update(now: Double) {
        if nextStart == nil { nextStart = now + interval }
        if startedAt == nil, let next = nextStart, now >= next {
            startedAt = now
            nextStart = now + interval
        }
        if let started = startedAt, now - started >= duration {
            startedAt = nil
        }
    }

    func draw(_ context: inout GraphicsContext, size: CGSize, now: Double) {
        guard let started = startedAt else { return }
        let progress = min(max((now - started) / duration, 0), 1)
        let w = size.width
        let h = size.height
        let batSize = min(w, h) * 0.24
        let position = point(progress, w: w, h: h)
        let ahead = point(min(progress + 0.01, 1), w: w, h: h)
        let angle = atan2(ahead.y - position.y, ahead.x - position.x)
        let flap = CGFloat(sin(now * 14) * 0.5 + 0.5)

        var c = context
        c.translateBy(x: position.x, y: position.y)
        c.rotate(by: .radians(Double(angle)))
        drawBat(&c, s: batSize, flap: flap)
    }

    /// Two curves: from the left edge up to the top near the status bar, then across and off the right.
    private func point(_ t: Double, w: CGFloat, h: CGFloat) -> CGPoint {
        let a = CGPoint(x: -w * 0.1, y: h * 0.5)
        let a1 = CGPoint(x: w * 0.05, y: h * 0.15)
        let a2 = CGPoint(x: w * 0.2, y: 40)
        let a3 = CGPoint(x: w * 0.5, y: 50)
        let b1 = CGPoint(x: w * 0.8, y: 60)
        let b2 = CGPoint(x: w * 0.95, y: h * 0.3)
        let b3 = CGPoint(x: w * 1.1, y: h * 0.25)
        if t < 0.5 {
            return cubic(a, a1, a2, a3, Double(t * 2))
        }
        return cubic(a3, b1, b2, b3, Double((t - 0.5) * 2))
    }

    private func cubic(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ t: Double) -> CGPoint {
        let u = 1 - t
        let tt = CGFloat(t)
        let uu = CGFloat(u)
        let x = uu * uu * uu * p0.x + 3 * uu * uu * tt * p1.x + 3 * uu * tt * tt * p2.x + tt * tt * tt * p3.x
        let y = uu * uu * uu * p0.y + 3 * uu * uu * tt * p1.y + 3 * uu * tt * tt * p2.y + tt * tt * tt * p3.y
        return CGPoint(x: x, y: y)
    }

    /// The bat drawn pointing right, centred on the origin; its wings flap with `flap` (0..1).
    private func drawBat(_ c: inout GraphicsContext, s: CGFloat, flap: CGFloat) {
        let ink = Color(red: 26 / 255, green: 15 / 255, blue: 46 / 255)
        let lift = 0.35 + 0.65 * flap

        c.fill(Path(ellipseIn: CGRect(x: -s * 0.12, y: -s * 0.16, width: s * 0.24, height: s * 0.32)), with: .color(ink))
        c.fill(Path(ellipseIn: CGRect(x: s * 0.01, y: -s * 0.21, width: s * 0.18, height: s * 0.18)), with: .color(ink))
        c.fill(Path(ellipseIn: CGRect(x: s * 0.12, y: -s * 0.155, width: s * 0.05, height: s * 0.05)), with: .color(Color(red: 1, green: 213 / 255, blue: 79 / 255)))

        var ears = Path()
        ears.move(to: CGPoint(x: s * 0.08, y: -s * 0.2))
        ears.addLine(to: CGPoint(x: s * 0.11, y: -s * 0.32))
        ears.addLine(to: CGPoint(x: s * 0.15, y: -s * 0.18))
        ears.closeSubpath()
        c.fill(ears, with: .color(ink))

        for side in [-1.0, 1.0] {
            let sd = CGFloat(side)
            var wing = Path()
            wing.move(to: .zero)
            wing.addQuadCurve(to: CGPoint(x: sd * s * 0.75, y: -s * 0.25 * lift), control: CGPoint(x: sd * s * 0.35, y: -s * 0.55 * lift))
            wing.addQuadCurve(to: CGPoint(x: sd * s * 0.55, y: s * 0.06), control: CGPoint(x: sd * s * 0.6, y: s * 0.02))
            wing.addQuadCurve(to: CGPoint(x: sd * s * 0.38, y: s * 0.04), control: CGPoint(x: sd * s * 0.45, y: s * 0.12))
            wing.addQuadCurve(to: CGPoint(x: sd * s * 0.12, y: s * 0.06), control: CGPoint(x: sd * s * 0.25, y: s * 0.16))
            wing.closeSubpath()
            c.fill(wing, with: .color(ink))
        }
    }
}
