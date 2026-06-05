import SwiftUI

/// The Chirpset symmetric robotic bird — front-facing, bilateral.
/// Ported from the brand toolkit SVG (viewBox 0 0 120 110, centred at x=60).
struct BirdMark: View {
    var size: CGFloat
    var wings: Bool = true
    var feet: Bool = true
    var traces: Bool = true
    var outerWaves: Bool = true
    var glow: Bool = false
    var tint: Color? = nil   // when set, draws monochrome in this color

    private let vb = CGSize(width: 120, height: 110)

    var body: some View {
        Canvas { ctx, canvasSize in
            let s = min(canvasSize.width / vb.width, canvasSize.height / vb.height)
            ctx.scaleBy(x: s, y: s)

            let body     = tint ?? Color(hex: 0xE8A838)
            let bodyHi   = tint ?? Color.white.opacity(0.06)
            let wing     = tint ?? Color(hex: 0xC48820)
            let beak     = tint ?? Color(hex: 0xD49030)
            let led      = tint ?? Color(hex: 0x3FD97F)
            let ledGlow  = tint ?? Color(hex: 0x3FD97F)
            let eye      = tint ?? Color(hex: 0x0A0A0E)
            let hi       = tint ?? Color.white.opacity(0.85)
            let wave     = tint ?? Color(hex: 0x3FD97F)
            let trace    = tint ?? Color.black.opacity(0.10)
            let foot     = tint ?? Color(hex: 0xE8A838)

            // Glow
            if glow {
                ctx.fill(circle(cx: 60, cy: 50, r: 42), with: .color(ledGlow.opacity(0.08)))
            }

            // Wings — mirrored angular shapes
            if wings {
                ctx.fill(poly([(34,42),(10,30),(16,42),(5,35),(18,49),(34,55)]), with: .color(wing.opacity(0.6)))
                ctx.fill(poly([(86,42),(110,30),(104,42),(115,35),(102,49),(86,55)]), with: .color(wing.opacity(0.6)))
            }

            // Body — egg / shield
            var bodyPath = Path()
            bodyPath.move(to: CGPoint(x: 34, y: 38))
            bodyPath.addCurve(to: CGPoint(x: 86, y: 38), control1: CGPoint(x: 34, y: 22), control2: CGPoint(x: 86, y: 22))
            bodyPath.addLine(to: CGPoint(x: 86, y: 78))
            bodyPath.addCurve(to: CGPoint(x: 34, y: 78), control1: CGPoint(x: 86, y: 94), control2: CGPoint(x: 34, y: 94))
            bodyPath.closeSubpath()
            ctx.fill(bodyPath, with: .color(body))

            // Body highlight
            var hiPath = Path()
            hiPath.move(to: CGPoint(x: 38, y: 36))
            hiPath.addCurve(to: CGPoint(x: 82, y: 36), control1: CGPoint(x: 38, y: 26), control2: CGPoint(x: 82, y: 26))
            hiPath.addLine(to: CGPoint(x: 82, y: 54))
            hiPath.addCurve(to: CGPoint(x: 38, y: 54), control1: CGPoint(x: 82, y: 60), control2: CGPoint(x: 38, y: 60))
            hiPath.closeSubpath()
            ctx.fill(hiPath, with: .color(bodyHi))

            // Circuit traces
            if traces {
                stroke(ctx, line: [(40,54),(50,54)], color: trace, width: 1.2)
                ctx.fill(circle(cx: 50, cy: 54, r: 1.5), with: .color(trace))
                stroke(ctx, line: [(70,54),(80,54)], color: trace, width: 1.2)
                ctx.fill(circle(cx: 70, cy: 54, r: 1.5), with: .color(trace))
                stroke(ctx, line: [(40,78),(48,78)], color: trace, width: 1.2)
                stroke(ctx, line: [(72,78),(80,78)], color: trace, width: 1.2)
            }

            // Antenna + LED
            stroke(ctx, line: [(60,22),(60,7)], color: body, width: 2.5, cap: .round)
            ctx.fill(circle(cx: 60, cy: 4.5, r: 8), with: .color(ledGlow.opacity(0.12)))
            ctx.fill(circle(cx: 60, cy: 4.5, r: 4.5), with: .color(led))

            // Eyes
            ctx.fill(circle(cx: 48, cy: 46, r: 6), with: .color(eye))
            ctx.fill(circle(cx: 72, cy: 46, r: 6), with: .color(eye))
            ctx.fill(circle(cx: 49.5, cy: 44.5, r: 2), with: .color(hi))
            ctx.fill(circle(cx: 73.5, cy: 44.5, r: 2), with: .color(hi))

            // Beak — diamond
            ctx.fill(poly([(60,56),(66.5,64),(60,72),(53.5,64)]), with: .color(beak))

            // Inner sound waves
            stroke(ctx, curve: ((50,60),(43.5,54),(41,63),(45.5,69)), color: wave.opacity(0.35), width: 1.8)
            stroke(ctx, curve: ((70,60),(76.5,54),(79,63),(74.5,69)), color: wave.opacity(0.35), width: 1.8)

            // Outer sound waves
            if outerWaves {
                stroke(ctx, curve: ((44,55),(35,47),(32,60),(39,72)), color: wave.opacity(0.15), width: 1.4)
                stroke(ctx, curve: ((76,55),(85,47),(88,60),(81,72)), color: wave.opacity(0.15), width: 1.4)
            }

            // Feet
            if feet {
                stroke(ctx, line: [(48,92),(43,106)], color: foot.opacity(0.7), width: 2, cap: .round)
                stroke(ctx, line: [(72,92),(77,106)], color: foot.opacity(0.7), width: 2, cap: .round)
                stroke(ctx, line: [(37,106),(49,106)], color: foot.opacity(0.5), width: 1.5, cap: .round)
                stroke(ctx, line: [(71,106),(83,106)], color: foot.opacity(0.5), width: 1.5, cap: .round)
            }
        }
        .frame(width: size, height: size * vb.height / vb.width)
    }

    // MARK: - Drawing helpers

    private func circle(cx: CGFloat, cy: CGFloat, r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
    }

    private func poly(_ pts: [(CGFloat, CGFloat)]) -> Path {
        var p = Path()
        guard let first = pts.first else { return p }
        p.move(to: CGPoint(x: first.0, y: first.1))
        for pt in pts.dropFirst() { p.addLine(to: CGPoint(x: pt.0, y: pt.1)) }
        p.closeSubpath()
        return p
    }

    private func stroke(_ ctx: GraphicsContext, line pts: [(CGFloat, CGFloat)],
                        color: Color, width: CGFloat, cap: CGLineCap = .butt) {
        var p = Path()
        guard let first = pts.first else { return }
        p.move(to: CGPoint(x: first.0, y: first.1))
        for pt in pts.dropFirst() { p.addLine(to: CGPoint(x: pt.0, y: pt.1)) }
        ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: cap))
    }

    private func stroke(_ ctx: GraphicsContext,
                        curve c: ((CGFloat, CGFloat), (CGFloat, CGFloat), (CGFloat, CGFloat), (CGFloat, CGFloat)),
                        color: Color, width: CGFloat) {
        var p = Path()
        p.move(to: CGPoint(x: c.0.0, y: c.0.1))
        p.addCurve(to: CGPoint(x: c.3.0, y: c.3.1),
                   control1: CGPoint(x: c.1.0, y: c.1.1),
                   control2: CGPoint(x: c.2.0, y: c.2.1))
        ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue:  Double(hex & 0xFF) / 255.0,
            opacity: 1.0
        )
    }
}
