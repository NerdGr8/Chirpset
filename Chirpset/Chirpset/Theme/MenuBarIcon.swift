import AppKit

/// The menu bar status icon, drawn with pure AppKit (no SwiftUI/ImageRenderer).
///
/// `MenuBarExtra` evaluates its `label` inside the App's view-graph build;
/// invoking `ImageRenderer` there is re-entrant and crashes AttributeGraph.
/// Drawing straight into an `NSImage` sidesteps the graph entirely. The image is
/// a monochrome template (a bird silhouette) so it adapts to light/dark menu bars.
enum MenuBarIcon {

    static let image: NSImage = {
        let size = NSSize(width: 18, height: 16)
        let img = NSImage(size: size, flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            draw(ctx, size: size)
            return true
        }
        img.isTemplate = true
        return img
    }()

    /// Bird silhouette in the SVG's 120×110 space, scaled to fit `size`.
    private static func draw(_ ctx: CGContext, size: NSSize) {
        let vb = CGSize(width: 120, height: 110)
        let s = min(size.width / vb.width, size.height / vb.height)
        ctx.saveGState()
        // SVG space is y-down; flip into AppKit's y-up image space.
        ctx.translateBy(x: (size.width - vb.width * s) / 2, y: size.height - (size.height - vb.height * s) / 2)
        ctx.scaleBy(x: s, y: -s)
        ctx.setFillColor(NSColor.black.cgColor)
        ctx.setStrokeColor(NSColor.black.cgColor)

        func poly(_ pts: [(CGFloat, CGFloat)]) {
            ctx.beginPath()
            ctx.move(to: CGPoint(x: pts[0].0, y: pts[0].1))
            pts.dropFirst().forEach { ctx.addLine(to: CGPoint(x: $0.0, y: $0.1)) }
            ctx.closePath(); ctx.fillPath()
        }
        func line(_ a: (CGFloat, CGFloat), _ b: (CGFloat, CGFloat), _ w: CGFloat) {
            ctx.setLineWidth(w); ctx.setLineCap(.round)
            ctx.move(to: CGPoint(x: a.0, y: a.1)); ctx.addLine(to: CGPoint(x: b.0, y: b.1)); ctx.strokePath()
        }
        func dot(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, color: NSColor = .black) {
            ctx.setFillColor(color.cgColor)
            ctx.fillEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
            ctx.setFillColor(NSColor.black.cgColor)
        }

        // Wings
        poly([(34,42),(10,30),(16,42),(5,35),(18,49),(34,55)])
        poly([(86,42),(110,30),(104,42),(115,35),(102,49),(86,55)])
        // Body
        ctx.beginPath()
        ctx.move(to: CGPoint(x: 34, y: 38))
        ctx.addCurve(to: CGPoint(x: 86, y: 38), control1: CGPoint(x: 34, y: 22), control2: CGPoint(x: 86, y: 22))
        ctx.addLine(to: CGPoint(x: 86, y: 78))
        ctx.addCurve(to: CGPoint(x: 34, y: 78), control1: CGPoint(x: 86, y: 94), control2: CGPoint(x: 34, y: 94))
        ctx.closePath(); ctx.fillPath()
        // Antenna + LED tip
        line((60,22),(60,8), 2.5)
        dot(60, 5, 5)
        // Beak notch + eyes punched out (clear) for a touch of detail
        ctx.setBlendMode(.clear)
        dot(48, 46, 4.5); dot(72, 46, 4.5)
        ctx.setBlendMode(.normal)
        ctx.setFillColor(NSColor.black.cgColor)
        poly([(60,56),(66,63),(60,70),(54,63)])

        ctx.restoreGState()
    }
}
