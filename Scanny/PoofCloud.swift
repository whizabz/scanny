import SwiftUI

/// The macOS Dock "poof": a puffy white cloud pops out of nothing, its middle
/// blows out into a ring, the ring breaks into small puffs, and they drift off.
///
/// Every puff is a shaded circle. All circles get a thin grey rim first and the
/// white bodies are painted over it, so only the outside of the merged shape keeps
/// its outline, the way the Dock's cartoon cloud reads.
struct PoofCloud: View {
    static let duration: Double = 0.8

    @State private var start = Date()
    /// Pins the animation to one moment (0...1), for previews.
    var fixedProgress: Double?
    /// Size of the cloud at full swell, in points.
    var radius: CGFloat = 80

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = fixedProgress ?? min(1, timeline.date.timeIntervalSince(start) / Self.duration)
            Canvas { ctx, size in
                Self.draw(&ctx, center: CGPoint(x: size.width / 2, y: size.height / 2),
                          radius: radius, t: t)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: Puffs

    private enum Kind { case core, ring, speck }

    /// One puff, in cluster units (1 = `radius`).
    private struct Puff {
        var kind: Kind
        var angle: Double
        var dist: Double
        var r: Double
        /// When this puff has fully faded (0...1 of the animation).
        var death: Double
    }

    private static let puffs: [Puff] = {
        var seed: UInt64 = 0x5EED_C10D
        func rand() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed >> 33) / Double(1 << 31)
        }
        func rand(_ lo: Double, _ hi: Double) -> Double { lo + (hi - lo) * rand() }

        var out: [Puff] = []  // drawn in order: core puffs are appended last, on top
        var core: [Puff] = []
        // The full middle of the first frame; it blows out to open the ring.
        for i in 0..<7 {
            core.append(Puff(kind: .core, angle: Double(i) / 7 * 2 * .pi + rand(-0.3, 0.3),
                            dist: i == 0 ? 0.04 : rand(0.14, 0.24), r: rand(0.26, 0.32), death: 0.36))
        }
        // The ring. Puffs near the gaps between clusters die first, so the ring
        // breaks into separate clumps rather than shrinking evenly.
        let ringCount = 34
        let clusters = 6.0
        let clusterOffset = rand(0, 2 * .pi)
        for i in 0..<ringCount {
            let angle = Double(i) / Double(ringCount) * 2 * .pi + rand(-0.08, 0.08)
            let phase = (angle - clusterOffset) * clusters / (2 * .pi)
            let fromGap = abs(phase - phase.rounded())  // 0 at a gap, 0.5 mid-clump
            out.append(Puff(kind: .ring, angle: angle, dist: rand(0.4, 0.52),
                            r: rand(0.16, 0.24) * (0.65 + fromGap * 0.8),
                            death: 0.58 + fromGap * 0.8 + rand(-0.05, 0.05)))
        }
        // Small bits of spray flung outward.
        for _ in 0..<16 {
            out.append(Puff(kind: .speck, angle: rand(0, 2 * .pi), dist: rand(0.55, 1.0),
                            r: rand(0.025, 0.06), death: rand(0.8, 1.0)))
        }
        return out + core
    }()

    // MARK: Drawing

    private static func clamp(_ x: Double) -> Double { min(max(x, 0), 1) }
    private static func smooth(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let u = clamp((x - a) / (b - a)); return u * u * (3 - 2 * u)
    }
    private static func easeOut(_ x: Double) -> Double { 1 - pow(1 - clamp(x), 3) }

    private static func draw(_ ctx: inout GraphicsContext, center: CGPoint, radius: CGFloat, t: Double) {
        let pop = easeOut(t / 0.14)  // the cloud bursts into view
        let expand = easeOut(t)
        let swirl = 0.25 * t
        let lift = -14 * t
        let fade = 1 - smooth(0.82, 1, t)
        guard fade > 0.01, pop > 0 else { return }

        var circles: [(c: CGPoint, r: CGFloat)] = []
        for p in puffs {
            var d: Double, size: Double
            switch p.kind {
            case .core:
                // Pushed outward into the ring while it shrinks, so no dots are left in the hole.
                d = p.dist + 0.7 * smooth(0.1, p.death, t)
                size = p.r * pop * (1 - smooth(0.08, p.death, t))
            case .ring:
                d = p.dist * (0.62 + 1.25 * expand)
                size = p.r * pop * (1.35 - 0.75 * expand) * (1 - smooth(p.death - 0.3, p.death, t))
            case .speck:
                guard t > 0.12 else { continue }
                d = p.dist * (0.5 + 1.3 * easeOut((t - 0.12) / 0.88))
                size = p.r * smooth(0.12, 0.22, t) * (1 - smooth(p.death - 0.2, p.death, t))
            }
            guard size > 0.004 else { continue }
            let a = p.angle + swirl
            circles.append((CGPoint(x: center.x + CGFloat(cos(a) * d) * radius,
                                    y: center.y + lift + CGFloat(sin(a) * d) * radius * 0.92),
                            CGFloat(size) * radius))
        }

        ctx.opacity = fade
        ctx.drawLayer { layer in
            layer.addFilter(.shadow(color: .black.opacity(0.18), radius: 5, x: 1, y: 4))

            // Rim: every circle a touch larger, in grey. Bodies below cover the inner rims.
            let rim = max(0.7, radius * 0.011)
            for (c, r) in circles {
                layer.fill(Path(ellipseIn: CGRect(x: c.x - r - rim, y: c.y - r - rim,
                                                  width: (r + rim) * 2, height: (r + rim) * 2)),
                           with: .color(Color(white: 0.62)))
            }
            // Bodies, lit from the upper left: bright core, grey toward the lower rim.
            for (c, r) in circles {
                layer.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                           with: .radialGradient(
                               Gradient(colors: [.white, Color(white: 0.96), Color(white: 0.78)]),
                               center: CGPoint(x: c.x - r * 0.3, y: c.y - r * 0.35),
                               startRadius: 0, endRadius: r * 1.5))
            }

            // The curls inside the full cloud of the first frame.
            let curls = 1 - smooth(0.06, 0.24, t)
            if curls > 0.01 {
                for p in puffs where p.kind == .core && p.dist > 0 {
                    let a = p.angle + swirl
                    let d = (p.dist + 0.7 * smooth(0.1, p.death, t)) * Double(radius)
                    let c = CGPoint(x: center.x + CGFloat(cos(a) * d), y: center.y + lift + CGFloat(sin(a) * d))
                    var arc = Path()
                    arc.addArc(center: c, radius: CGFloat(p.r * pop) * radius * 0.7,
                               startAngle: .radians(a + 0.6), endAngle: .radians(a + 2.4), clockwise: false)
                    layer.stroke(arc, with: .color(Color(white: 0.64).opacity(curls)),
                                 style: StrokeStyle(lineWidth: rim, lineCap: .round))
                }
            }
        }
        ctx.opacity = 1
    }
}

#Preview("Frames") {
    HStack(spacing: 0) {
        ForEach([0.1, 0.3, 0.5, 0.7, 0.9], id: \.self) { t in
            PoofCloud(fixedProgress: t, radius: 40).frame(width: 140, height: 160)
        }
    }
    .background(Color(red: 0.12, green: 0.25, blue: 0.5))
}

#Preview("Loop") {
    struct Loop: View {
        @State private var id = 0
        var body: some View {
            PoofCloud().id(id)
                .frame(width: 320, height: 320)
                .background(Color(red: 0.12, green: 0.25, blue: 0.5))
                .onTapGesture { id += 1 }
        }
    }
    return Loop()
}
