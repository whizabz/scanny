import SwiftUI

/// The app icon's geometry on its 1024-unit canvas, shared by the Home Screen
/// art and the Lock Screen mark: an upright page in perspective (far edge
/// narrower), corner brackets parallel to its edges, and a scan line.
private enum IconGeometry {
    static let tl = CGPoint(x: 362, y: 272), tr = CGPoint(x: 662, y: 272)
    static let br = CGPoint(x: 722, y: 752), bl = CGPoint(x: 302, y: 752)

    /// Point on the page: u across (0 left ... 1 right), v down (0 top ... 1 bottom).
    static func point(_ u: CGFloat, _ v: CGFloat) -> CGPoint {
        let left = CGPoint(x: tl.x + (bl.x - tl.x) * v, y: tl.y + (bl.y - tl.y) * v)
        let right = CGPoint(x: tr.x + (br.x - tr.x) * v, y: tr.y + (br.y - tr.y) * v)
        return CGPoint(x: left.x + (right.x - left.x) * u, y: left.y + (right.y - left.y) * u)
    }

    static func line(_ u0: CGFloat, _ u1: CGFloat, at v: CGFloat) -> Path {
        var p = Path()
        p.move(to: point(u0, v)); p.addLine(to: point(u1, v))
        return p
    }

    static var page: Path {
        Path { p in p.addLines([tl, tr, br, bl]); p.closeSubpath() }
    }

    /// The part of the page below the scan line.
    static var lowerHalf: Path {
        Path { p in p.addLines([point(0, 0.5), point(1, 0.5), br, bl]); p.closeSubpath() }
    }

    /// Bracket corners: the page outline pushed 72 units outward, arms 62 long.
    static var brackets: Path {
        let corners = [CGPoint(x: 298.4, y: 200), CGPoint(x: 725.6, y: 200),
                       CGPoint(x: 803.6, y: 824), CGPoint(x: 220.4, y: 824)]
        var p = Path()
        for (i, c) in corners.enumerated() {
            func arm(toward other: CGPoint) -> CGPoint {
                let dx = other.x - c.x, dy = other.y - c.y, n = (dx * dx + dy * dy).squareRoot()
                return CGPoint(x: c.x + dx / n * 62, y: c.y + dy / n * 62)
            }
            p.move(to: arm(toward: corners[(i + 3) % 4]))
            p.addLine(to: c)
            p.addLine(to: arm(toward: corners[(i + 1) % 4]))
        }
        return p
    }

    /// Where the drawing sits on the canvas, brackets included.
    static let content = CGRect(x: 207, y: 187, width: 610, height: 650)
}

/// The app icon's motif as a single-colour mark for the Lock Screen, where the
/// system tints everything: page outline, a few text lines, the scan line and
/// the corner brackets, sized up so they read at a glance.
struct ScanMark: View {
    /// Bracket stroke as a fraction of the mark size.
    var bracketWeight: CGFloat = 0.045

    var body: some View {
        Canvas { ctx, size in
            // Square crop around the drawing, centred.
            let side = IconGeometry.content.height
            let k = min(size.width, size.height) / side
            ctx.translateBy(x: size.width / 2, y: size.height / 2)
            ctx.scaleBy(x: k, y: k)
            ctx.translateBy(x: -IconGeometry.content.midX, y: -IconGeometry.content.midY)

            var faded = ctx
            faded.opacity = 0.75
            faded.stroke(IconGeometry.brackets, with: .foreground,
                       style: StrokeStyle(lineWidth: side * bracketWeight, lineCap: .round, lineJoin: .round))
            ctx.stroke(IconGeometry.page, with: .foreground,
                       style: StrokeStyle(lineWidth: 40, lineJoin: .round))
            for (v, end) in [(0.17, 0.82), (0.29, 0.82), (0.41, 0.55)] as [(CGFloat, CGFloat)] {
                ctx.stroke(IconGeometry.line(0.18, end, at: v), with: .foreground,
                           style: StrokeStyle(lineWidth: 34, lineCap: .round))
            }
            ctx.stroke(IconGeometry.line(-0.12, 1.12, at: 0.62), with: .foreground,
                       style: StrokeStyle(lineWidth: 44, lineCap: .round))
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Home Screen widget art (the app icon's own elements)

/// Cutting-mat grid from the icon: a soft grid plus two diagonals, full-bleed.
struct MatGrid: View {
    var opacity: Double = 0.08

    var body: some View {
        GeometryReader { geo in
            Path { p in
                let step = geo.size.width / 8
                var x = step
                while x < geo.size.width {
                    p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: geo.size.height))
                    x += step
                }
                var y = step
                while y < geo.size.height {
                    p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: geo.size.width, y: y))
                    y += step
                }
                p.move(to: CGPoint(x: 0, y: geo.size.height)); p.addLine(to: CGPoint(x: geo.size.width, y: 0))
                p.move(to: .zero); p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
            }
            .stroke(Color.white.opacity(opacity), style: StrokeStyle(lineWidth: 1, lineCap: .round))
        }
    }
}

/// Page, scan light and corner brackets, drawn from the same coordinates as the
/// icon's SVG layers (1024-unit canvas), cropped to the area they occupy.
struct AppIconElements: View {
    /// In Clear/Tinted mode the system paints everything one colour, so the page
    /// details are punched out as transparent gaps instead of drawn in orange.
    var knockout = false

    private var crop: CGRect { IconGeometry.content }

    var body: some View {
        Canvas { ctx, size in
            let k = size.width / crop.width
            ctx.scaleBy(x: k, y: k)
            ctx.translateBy(x: -crop.minX, y: -crop.minY)

            // Page: white, its corners softened by a white outline, with orange text lines.
            let page = IconGeometry.page
            ctx.fill(page, with: .color(.white))
            ctx.stroke(page, with: .color(.white), style: StrokeStyle(lineWidth: 20, lineJoin: .round))
            let orange = Color(red: 0xF0 / 255, green: 0x89 / 255, blue: 0x4A / 255)
            let ends: [CGFloat] = [0.86, 0.74, 0.86, 0.62, 0.8, 0.86, 0.48]
            for (i, end) in ends.enumerated() {
                let l = IconGeometry.line(0.14, end, at: 0.12 + 0.76 * CGFloat(i) / CGFloat(ends.count - 1))
                if knockout {
                    var c = ctx; c.blendMode = .destinationOut
                    c.stroke(l, with: .color(.black.opacity(0.85)),
                             style: StrokeStyle(lineWidth: 22, lineCap: .round))
                } else {
                    ctx.stroke(l, with: .color(orange.opacity(0.8)),
                               style: StrokeStyle(lineWidth: 22, lineCap: .round))
                }
            }

            // Scan light: bright at the line, fading down the lower half of the page.
            let lower = IconGeometry.lowerHalf
            let top = IconGeometry.point(0, 0.5).y, bottom = IconGeometry.bl.y
            let glow = Color(red: 1.0, green: 0x8A / 255, blue: 0x3D / 255)
            let scan = IconGeometry.line(-0.05, 1.05, at: 0.5)
            if knockout {
                // Lower half fades to transparent; the scan line sits in a clear channel.
                var c = ctx; c.blendMode = .destinationOut
                c.fill(lower, with: .linearGradient(
                    Gradient(colors: [.black.opacity(0.7), .black.opacity(0)]),
                    startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 0, y: bottom)))
                c.stroke(IconGeometry.line(0, 1, at: 0.5), with: .color(.black),
                         style: StrokeStyle(lineWidth: 40, lineCap: .butt))
                ctx.stroke(scan, with: .color(.white), style: StrokeStyle(lineWidth: 18, lineCap: .round))
            } else {
                ctx.fill(lower, with: .linearGradient(
                    Gradient(stops: [
                        .init(color: glow.opacity(0.85), location: 0),
                        .init(color: glow.opacity(0.45), location: 0.3),
                        .init(color: glow.opacity(0), location: 1)]),
                    startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 0, y: bottom)))
                ctx.stroke(scan, with: .color(Color(red: 0xE8 / 255, green: 0x57 / 255, blue: 0x2A / 255)),
                           style: StrokeStyle(lineWidth: 18, lineCap: .round))
            }

            // Corner brackets, parallel to the page edges, white at 75%.
            ctx.stroke(IconGeometry.brackets, with: .color(.white.opacity(0.75)),
                       style: StrokeStyle(lineWidth: 26, lineCap: .round, lineJoin: .round))
        }
        .aspectRatio(crop.width / crop.height, contentMode: .fit)
    }
}

#Preview("Lock Screen mark") {
    ScanMark().frame(width: 60, height: 60).padding().background(.black).foregroundStyle(.white)
}
