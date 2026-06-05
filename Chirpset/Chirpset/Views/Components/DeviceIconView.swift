import SwiftUI

/// A small chip-style glyph for a board family, drawn to echo the prototype's
/// SVG device icons (IC body with pin legs + traces).
struct DeviceIconView: View {
    let kind: BoardIconKind
    var size: CGFloat = 18

    var body: some View {
        Canvas { ctx, canvasSize in
            let s = min(canvasSize.width, canvasSize.height) / 18.0
            ctx.scaleBy(x: s, y: s)
            let c = kind.accent

            switch kind {
            case .pico:
                // Wide board with many pins top & bottom
                chip(ctx, rect: CGRect(x: 2, y: 5, width: 14, height: 8), color: c, lw: 1.1)
                ctx.fill(Path(ellipseIn: CGRect(x: 4, y: 7.5, width: 3, height: 3)), with: .color(c.opacity(0.3)))
                pins(ctx, color: c, xs: stride(from: 4, through: 14, by: 2).map { $0 }, top: 5, bottom: 13, len: 2.5, lw: 0.8)
            case .avr, .samd:
                chip(ctx, rect: CGRect(x: 3, y: 3, width: 12, height: 12), color: c, lw: 1.1)
                ctx.fill(roundRect(CGRect(x: 5, y: 5, width: 4, height: 3), r: 0.5), with: .color(c.opacity(0.25)))
                sidePins(ctx, color: c, ys: [7, 11], left: 3, right: 15, len: 2.5, lw: 0.9)
            case .stm, .esp, .microbit, .teensy, .generic:
                chip(ctx, rect: CGRect(x: 3, y: 3, width: 12, height: 12), color: c, lw: 1.2)
                ctx.fill(roundRect(CGRect(x: 5.5, y: 5.5, width: 7, height: 7), r: 0.8), with: .color(c.opacity(0.3)))
                pins(ctx, color: c, xs: [6, 9, 12], top: 3, bottom: 15, len: 2.5, lw: 1)
                sidePins(ctx, color: c, ys: [6, 9, 12], left: 3, right: 15, len: 2.5, lw: 1)
            }
        }
        .frame(width: size, height: size)
    }

    private func chip(_ ctx: GraphicsContext, rect: CGRect, color: Color, lw: CGFloat) {
        ctx.stroke(roundRect(rect, r: 1.4), with: .color(color), lineWidth: lw)
    }

    private func roundRect(_ r: CGRect, r radius: CGFloat) -> Path {
        Path(roundedRect: r, cornerRadius: radius)
    }

    private func pins(_ ctx: GraphicsContext, color: Color, xs: [CGFloat],
                      top: CGFloat, bottom: CGFloat, len: CGFloat, lw: CGFloat) {
        for x in xs {
            line(ctx, [(x, top), (x, top - len)], color, lw)
            line(ctx, [(x, bottom), (x, bottom + len)], color, lw)
        }
    }

    private func sidePins(_ ctx: GraphicsContext, color: Color, ys: [CGFloat],
                          left: CGFloat, right: CGFloat, len: CGFloat, lw: CGFloat) {
        for y in ys {
            line(ctx, [(left, y), (left - len, y)], color, lw)
            line(ctx, [(right, y), (right + len, y)], color, lw)
        }
    }

    private func line(_ ctx: GraphicsContext, _ pts: [(CGFloat, CGFloat)], _ color: Color, _ lw: CGFloat) {
        var p = Path()
        p.move(to: CGPoint(x: pts[0].0, y: pts[0].1))
        p.addLine(to: CGPoint(x: pts[1].0, y: pts[1].1))
        ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: lw, lineCap: .round))
    }
}
