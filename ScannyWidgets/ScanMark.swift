import SwiftUI

/// The app icon's motif, drawn as shapes so it scales and works in both the
/// monochrome Lock Screen and the coloured Home Screen: corner brackets around
/// a page with a few lines and a scan line through it.
struct ScanMark: View {
    /// Bracket stroke as a fraction of the mark size.
    var bracketWeight: CGFloat = 0.075

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            // Page in A4 proportions; the brackets sit a fixed distance outside it.
            let w = s * 0.37
            let h = w * 1.414
            let margin = s * 0.105
            ZStack {
                Brackets(size: CGSize(width: w + margin * 2, height: h + margin * 2), leg: s * 0.15, radius: s * 0.07)
                    .stroke(style: StrokeStyle(lineWidth: s * bracketWeight, lineCap: .round, lineJoin: .round))
                    .opacity(0.75)
                RoundedRectangle(cornerRadius: s * 0.05)
                    .strokeBorder(lineWidth: s * 0.055)
                    .frame(width: w, height: h)
                // Text lines, the last one shortest.
                VStack(alignment: .leading, spacing: s * 0.05) {
                    ForEach([0.78, 0.78, 0.5], id: \.self) { fraction in
                        Capsule().frame(width: w * 0.62 * fraction / 0.78, height: s * 0.04)
                    }
                }
                .frame(width: w * 0.62, height: h, alignment: .topLeading)
                .offset(y: s * 0.085)
                // Scan line, a little wider than the page.
                Capsule()
                    .frame(width: w * 1.3, height: s * 0.055)
                    .offset(y: s * 0.12)
            }
            .frame(width: s, height: s)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// Four corner brackets of a centred rectangle of the given size, with softly rounded corners.
private struct Brackets: Shape {
    let size: CGSize
    let leg: CGFloat
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = CGRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2,
                       width: size.width, height: size.height)
        let c = radius
        var p = Path()
        // Top left
        p.move(to: CGPoint(x: r.minX, y: r.minY + leg))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + c))
        p.addQuadCurve(to: CGPoint(x: r.minX + c, y: r.minY), control: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + leg, y: r.minY))
        // Top right
        p.move(to: CGPoint(x: r.maxX - leg, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - c, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + c), control: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + leg))
        // Bottom right
        p.move(to: CGPoint(x: r.maxX, y: r.maxY - leg))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - c))
        p.addQuadCurve(to: CGPoint(x: r.maxX - c, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX - leg, y: r.maxY))
        // Bottom left
        p.move(to: CGPoint(x: r.minX + leg, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + c, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - c), control: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY - leg))
        return p
    }
}

// MARK: - Home Screen widget art (the app icon's own elements)

/// Cutting-mat grid from the icon: a soft grid plus two diagonals, full-bleed.
struct MatGrid: View {
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
            .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 1, lineCap: .round))
        }
    }
}

/// Page, scan light and corner brackets, drawn from the same coordinates as the
/// icon's SVG layers (1024-unit canvas), cropped to the area they occupy.
struct AppIconElements: View {
    /// In Clear/Tinted mode the system paints everything one colour, so the page
    /// details are punched out as transparent gaps instead of drawn in orange.
    var knockout = false

    // The icon's content spans x 232...792, y 162...863 on the 1024 canvas.
    private let crop = CGRect(x: 232, y: 162, width: 560, height: 701)

    var body: some View {
        Canvas { ctx, size in
            let k = size.width / crop.width
            ctx.scaleBy(x: k, y: k)
            ctx.translateBy(x: -crop.minX, y: -crop.minY)

            // Page: white A4 with orange text lines.
            let page = CGRect(x: 342, y: 272, width: 340, height: 481)
            ctx.fill(Path(roundedRect: page, cornerRadius: 22), with: .color(.white))
            let orange = Color(red: 0xF0 / 255, green: 0x89 / 255, blue: 0x4A / 255)
            let lines: [(CGFloat, CGFloat, CGFloat)] = [
                (314, 388, 636), (370, 388, 604), (426, 388, 636), (482, 388, 572),
                (538, 388, 620), (594, 388, 636), (650, 388, 588), (706, 388, 492)]
            for (y, x0, x1) in lines {
                var l = Path(); l.move(to: CGPoint(x: x0, y: y)); l.addLine(to: CGPoint(x: x1, y: y))
                if knockout {
                    var c = ctx; c.blendMode = .destinationOut
                    c.stroke(l, with: .color(.black.opacity(0.85)),
                             style: StrokeStyle(lineWidth: 21, lineCap: .round))
                } else {
                    ctx.stroke(l, with: .color(orange.opacity(0.8)),
                               style: StrokeStyle(lineWidth: 21, lineCap: .round))
                }
            }

            // Scan light: bright at the line, fading downwards.
            let pane = CGRect(x: 342, y: 510, width: 340, height: 243)
            let paneShape = UnevenRoundedRectangle(bottomLeadingRadius: 22, bottomTrailingRadius: 22).path(in: pane)
            let glow = Color(red: 1.0, green: 0x8A / 255, blue: 0x3D / 255)
            var scan = Path(); scan.move(to: CGPoint(x: 330, y: 510)); scan.addLine(to: CGPoint(x: 694, y: 510))
            if knockout {
                // Lower half fades to transparent; the scan line sits in a clear channel.
                var c = ctx; c.blendMode = .destinationOut
                c.fill(paneShape, with: .linearGradient(
                    Gradient(colors: [.black.opacity(0.7), .black.opacity(0)]),
                    startPoint: CGPoint(x: 0, y: pane.minY), endPoint: CGPoint(x: 0, y: pane.maxY)))
                var gap = Path(); gap.move(to: CGPoint(x: 342, y: 510)); gap.addLine(to: CGPoint(x: 682, y: 510))
                c.stroke(gap, with: .color(.black), style: StrokeStyle(lineWidth: 40, lineCap: .butt))
                ctx.stroke(scan, with: .color(.white), style: StrokeStyle(lineWidth: 18, lineCap: .round))
            } else {
                ctx.fill(paneShape, with: .linearGradient(
                    Gradient(stops: [
                        .init(color: glow.opacity(0.95), location: 0),
                        .init(color: glow.opacity(0.6), location: 0.25),
                        .init(color: glow.opacity(0.22), location: 0.6),
                        .init(color: glow.opacity(0), location: 1)]),
                    startPoint: CGPoint(x: 0, y: pane.minY), endPoint: CGPoint(x: 0, y: pane.maxY)))
                ctx.stroke(scan, with: .color(Color(red: 0xE8 / 255, green: 0x57 / 255, blue: 0x2A / 255)),
                           style: StrokeStyle(lineWidth: 18, lineCap: .round))
            }

            // Corner brackets, 90 units outside the page, white at 75%.
            var b = Path()
            b.move(to: CGPoint(x: 252, y: 292)); b.addLine(to: CGPoint(x: 252, y: 242))
            b.addQuadCurve(to: CGPoint(x: 312, y: 182), control: CGPoint(x: 252, y: 182)); b.addLine(to: CGPoint(x: 362, y: 182))
            b.move(to: CGPoint(x: 662, y: 182)); b.addLine(to: CGPoint(x: 712, y: 182))
            b.addQuadCurve(to: CGPoint(x: 772, y: 242), control: CGPoint(x: 772, y: 182)); b.addLine(to: CGPoint(x: 772, y: 292))
            b.move(to: CGPoint(x: 252, y: 733)); b.addLine(to: CGPoint(x: 252, y: 783))
            b.addQuadCurve(to: CGPoint(x: 312, y: 843), control: CGPoint(x: 252, y: 843)); b.addLine(to: CGPoint(x: 362, y: 843))
            b.move(to: CGPoint(x: 772, y: 733)); b.addLine(to: CGPoint(x: 772, y: 783))
            b.addQuadCurve(to: CGPoint(x: 712, y: 843), control: CGPoint(x: 772, y: 843)); b.addLine(to: CGPoint(x: 662, y: 843))
            ctx.stroke(b, with: .color(.white.opacity(0.75)),
                       style: StrokeStyle(lineWidth: 46, lineCap: .round, lineJoin: .round))
        }
        .aspectRatio(crop.width / crop.height, contentMode: .fit)
    }
}
