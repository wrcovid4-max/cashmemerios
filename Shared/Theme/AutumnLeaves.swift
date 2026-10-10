import SwiftUI


/// Falling autumn leaves across the app: they blow in from above, drift right to left,
/// land on cards, stick in the gaps between cards, and some collect in a pile along the
/// bottom while the rest blow away. Takes no touches.
struct AutumnLeavesView: View {
    /// Bounds of the cards on screen, in this view's coordinates.
    var perches: [CGRect] = []
    @State private var sim = LeafSimulation()

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                sim.perches = perches
                sim.step(now: timeline.date.timeIntervalSinceReferenceDate, size: size)
                for leaf in sim.leaves {
                    AutumnLeafShape.draw(&context, leaf)
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

enum LeafState { case falling, resting, piled, leaving }

struct Leaf {
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var angle: Double
    var spin: Double
    var colour: Color
    var sway: Double
    var state: LeafState = .falling
    var restUntil: Double = 0
    var prevBottom: CGFloat = 0
}

private let leafColours: [Color] = [
    Color(red: 0.88, green: 0.48, blue: 0.22),
    Color(red: 0.70, green: 0.23, blue: 0.12),
    Color(red: 0.88, green: 0.65, blue: 0.15),
    Color(red: 0.54, green: 0.29, blue: 0.12),
    Color(red: 0.79, green: 0.35, blue: 0.17),
]

final class LeafSimulation {
    var leaves: [Leaf] = []
    var perches: [CGRect] = []
    private var gaps: [CGRect] = []
    private var time: Double = 0
    private var last: Double = 0
    private var spawnTimer: Double = 0
    private var size: CGSize = .zero
    private let maxFalling = 1000
    private let maxPiled = 200

    func step(now: Double, size: CGSize) {
        self.size = size
        let dt = last == 0 ? 1.0 / 60.0 : min(now - last, 0.05)
        last = now
        guard size.width > 0 else { return }
        time += dt
        spawnTimer -= dt
        gaps = gapsBetween(perches)

        let falling = leaves.reduce(0) { $0 + ($1.state == .piled ? 0 : 1) }
        if spawnTimer <= 0 && falling < maxFalling {
            spawn()
            spawnTimer = Double.random(in: 0.04...0.12)
        }

        let wind = 80 + 45 * sin(time * 0.6) + 25 * sin(time * 1.7)
        var piled = leaves.reduce(0) { $0 + ($1.state == .piled ? 1 : 0) }
        for i in leaves.indices {
            update(i, dt: dt, wind: CGFloat(wind), piled: &piled)
        }
        leaves.removeAll { leaf in
            (leaf.state == .falling && leaf.x < -60) ||
                (leaf.state == .leaving && (leaf.y > size.height + 40 || leaf.x < -60))
        }
    }

    /// Gaps between two surfaces stacked one above the other, overlapping horizontally.
    private func gapsBetween(_ rects: [CGRect]) -> [CGRect] {
        var result: [CGRect] = []
        for upper in rects {
            for lower in rects where lower != upper {
                let height = lower.minY - upper.maxY
                let left = max(upper.minX, lower.minX)
                let right = min(upper.maxX, lower.maxX)
                if height >= 4 && height <= 60 && right - left > 40 {
                    result.append(CGRect(x: left, y: upper.maxY, width: right - left, height: height))
                }
            }
        }
        return result
    }

    private func update(_ i: Int, dt: Double, wind: CGFloat, piled: inout Int) {
        var leaf = leaves[i]
        let step = CGFloat(dt)
        switch leaf.state {
        case .falling:
            // The wind pushes leftwards, easing towards its current speed.
            leaf.vx += (-wind - leaf.vx) * step * 1.5
            leaf.x += leaf.vx * step + CGFloat(sin(time * 2 + leaf.sway)) * 26 * step
            leaf.y += leaf.vy * step
            leaf.angle += leaf.spin * dt
            let bottom = leaf.y + leaf.size * 0.6

            if let gap = gaps.first(where: { g in
                leaf.x >= g.minX && leaf.x <= g.maxX && leaf.prevBottom <= g.minY && bottom >= g.minY
            }), Double.random(in: 0..<1) < 0.8 {
                // Stuck in the gap between two cards, for a while.
                leaf.y = gap.midY
                leaf.state = .resting
                leaf.restUntil = time + Double.random(in: 6...10)
            } else if let landing = perches.first(where: { r in
                leaf.x >= r.minX && leaf.x <= r.maxX && leaf.prevBottom <= r.minY && bottom >= r.minY
            }), Double.random(in: 0..<1) < 0.35 {
                // Lands on top of a card, for a few seconds.
                leaf.y = landing.minY - leaf.size * 0.6
                leaf.state = .resting
                leaf.restUntil = time + Double.random(in: 3...6)
            } else if bottom >= size.height - 18 {
                if piled < maxPiled && Double.random(in: 0..<1) < 0.4 {
                    leaf.state = .piled
                    leaf.x = CGFloat.random(in: 0...size.width)
                    leaf.y = size.height - 10
                    piled += 1
                } else {
                    leaf.state = .leaving
                }
            }
            leaf.prevBottom = leaf.y + leaf.size * 0.6
        case .resting:
            leaf.x += CGFloat(sin(time * 3 + leaf.sway)) * 3 * step
            if time >= leaf.restUntil {
                leaf.state = .falling
                leaf.vy = CGFloat.random(in: 60...100)
                leaf.prevBottom = leaf.y + leaf.size * 0.6
            }
        case .leaving:
            leaf.x += leaf.vx * step
            leaf.y += leaf.vy * step
            leaf.angle += leaf.spin * dt
        case .piled:
            break
        }
        leaves[i] = leaf
    }

    private func spawn() {
        leaves.append(Leaf(
            // Anywhere across the top edge, from above the status bar.
            x: CGFloat.random(in: 0...size.width),
            y: -CGFloat.random(in: 10...80),
            // XXL leaves.
            size: CGFloat.random(in: 80...110),
            vx: -90,
            vy: CGFloat.random(in: 70...120),
            angle: Double.random(in: 0..<360),
            spin: Double.random(in: -60...60),
            colour: leafColours.randomElement() ?? .orange,
            sway: Double.random(in: 0..<6.28),
            prevBottom: 0
        ))
        leaves[leaves.count - 1].prevBottom = leaves[leaves.count - 1].y + leaves[leaves.count - 1].size * 0.6
    }
}

enum AutumnLeafShape {
    static func draw(_ context: inout GraphicsContext, _ leaf: Leaf) {
        let s = leaf.size
        var shape = Path()
        shape.move(to: CGPoint(x: 0, y: -s / 2))
        shape.addQuadCurve(to: CGPoint(x: 0, y: s / 2), control: CGPoint(x: s / 2, y: -s / 4))
        shape.addQuadCurve(to: CGPoint(x: 0, y: -s / 2), control: CGPoint(x: -s / 2, y: -s / 4))
        shape.closeSubpath()
        var vein = Path()
        vein.move(to: CGPoint(x: 0, y: -s / 2))
        vein.addLine(to: CGPoint(x: 0, y: s / 2))

        var c = context
        c.translateBy(x: leaf.x, y: leaf.y)
        c.rotate(by: .degrees(leaf.angle))
        c.fill(shape, with: .color(leaf.colour))
        c.stroke(vein, with: .color(.black.opacity(0.4)), lineWidth: 1.2)
    }
}
