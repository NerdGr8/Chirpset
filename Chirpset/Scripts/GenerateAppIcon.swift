#!/usr/bin/env swift
import AppKit

// Renders the Chirpset app icon (symmetric robotic bird on a dark squircle with
// a green radial glow) at every macOS size and writes them into the appiconset.
// Run:  swift Scripts/GenerateAppIcon.swift
// Mirrors the brand toolkit `appIcon()` / `bird()` drawing.

let birdVB = CGSize(width: 120, height: 110)

func hex(_ h: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((h >> 16) & 0xFF) / 255,
            green: CGFloat((h >> 8) & 0xFF) / 255,
            blue: CGFloat(h & 0xFF) / 255, alpha: a)
}

func drawBird(_ ctx: CGContext, in rect: CGRect) {
    let s = min(rect.width / birdVB.width, rect.height / birdVB.height)
    ctx.saveGState()
    // Map SVG space (y-down, origin top-left) into the target rect (y-up CG).
    ctx.translateBy(x: rect.minX, y: rect.maxY)
    ctx.scaleBy(x: s, y: -s)

    let body = hex(0xE8A838), bodyHi = NSColor.white.withAlphaComponent(0.06)
    let wing = hex(0xC48820), beak = hex(0xD49030)
    let led = hex(0x3FD97F), ledGlow = hex(0x3FD97F)
    let eye = hex(0x0A0A0E), hi = NSColor.white.withAlphaComponent(0.85)
    let wave = hex(0x3FD97F), trace = NSColor.black.withAlphaComponent(0.10)
    let foot = hex(0xE8A838)

    func fillPoly(_ pts: [(CGFloat, CGFloat)], _ c: NSColor) {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: pts[0].0, y: pts[0].1))
        pts.dropFirst().forEach { p.addLine(to: CGPoint(x: $0.0, y: $0.1)) }
        p.closeSubpath()
        ctx.addPath(p); ctx.setFillColor(c.cgColor); ctx.fillPath()
    }
    func fillCircle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, _ c: NSColor) {
        ctx.setFillColor(c.cgColor)
        ctx.fillEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
    }
    func strokeLine(_ a: (CGFloat, CGFloat), _ b: (CGFloat, CGFloat), _ c: NSColor, _ w: CGFloat, round: Bool = false) {
        ctx.setStrokeColor(c.cgColor); ctx.setLineWidth(w)
        ctx.setLineCap(round ? .round : .butt)
        ctx.move(to: CGPoint(x: a.0, y: a.1)); ctx.addLine(to: CGPoint(x: b.0, y: b.1)); ctx.strokePath()
    }
    func strokeCurve(_ p0: (CGFloat, CGFloat), _ c1: (CGFloat, CGFloat), _ c2: (CGFloat, CGFloat), _ p1: (CGFloat, CGFloat), _ c: NSColor, _ w: CGFloat) {
        ctx.setStrokeColor(c.cgColor); ctx.setLineWidth(w); ctx.setLineCap(.round)
        ctx.move(to: CGPoint(x: p0.0, y: p0.1))
        ctx.addCurve(to: CGPoint(x: p1.0, y: p1.1), control1: CGPoint(x: c1.0, y: c1.1), control2: CGPoint(x: c2.0, y: c2.1))
        ctx.strokePath()
    }

    // Wings
    fillPoly([(34,42),(10,30),(16,42),(5,35),(18,49),(34,55)], wing.withAlphaComponent(0.6))
    fillPoly([(86,42),(110,30),(104,42),(115,35),(102,49),(86,55)], wing.withAlphaComponent(0.6))
    // Body
    let bp = CGMutablePath()
    bp.move(to: CGPoint(x: 34, y: 38))
    bp.addCurve(to: CGPoint(x: 86, y: 38), control1: CGPoint(x: 34, y: 22), control2: CGPoint(x: 86, y: 22))
    bp.addLine(to: CGPoint(x: 86, y: 78))
    bp.addCurve(to: CGPoint(x: 34, y: 78), control1: CGPoint(x: 86, y: 94), control2: CGPoint(x: 34, y: 94))
    bp.closeSubpath()
    ctx.addPath(bp); ctx.setFillColor(body.cgColor); ctx.fillPath()
    // Highlight
    let hp = CGMutablePath()
    hp.move(to: CGPoint(x: 38, y: 36))
    hp.addCurve(to: CGPoint(x: 82, y: 36), control1: CGPoint(x: 38, y: 26), control2: CGPoint(x: 82, y: 26))
    hp.addLine(to: CGPoint(x: 82, y: 54))
    hp.addCurve(to: CGPoint(x: 38, y: 54), control1: CGPoint(x: 82, y: 60), control2: CGPoint(x: 38, y: 60))
    hp.closeSubpath()
    ctx.addPath(hp); ctx.setFillColor(bodyHi.cgColor); ctx.fillPath()
    // Traces
    strokeLine((40,54),(50,54), trace, 1.2); fillCircle(50,54,1.5, trace)
    strokeLine((70,54),(80,54), trace, 1.2); fillCircle(70,54,1.5, trace)
    strokeLine((40,78),(48,78), trace, 1.2); strokeLine((72,78),(80,78), trace, 1.2)
    // Antenna + LED
    strokeLine((60,22),(60,7), body, 2.5, round: true)
    fillCircle(60,4.5,8, ledGlow.withAlphaComponent(0.12)); fillCircle(60,4.5,4.5, led)
    // Eyes
    fillCircle(48,46,6, eye); fillCircle(72,46,6, eye)
    fillCircle(49.5,44.5,2, hi); fillCircle(73.5,44.5,2, hi)
    // Beak
    fillPoly([(60,56),(66.5,64),(60,72),(53.5,64)], beak)
    // Waves
    strokeCurve((50,60),(43.5,54),(41,63),(45.5,69), wave.withAlphaComponent(0.35), 1.8)
    strokeCurve((70,60),(76.5,54),(79,63),(74.5,69), wave.withAlphaComponent(0.35), 1.8)
    strokeCurve((44,55),(35,47),(32,60),(39,72), wave.withAlphaComponent(0.15), 1.4)
    strokeCurve((76,55),(85,47),(88,60),(81,72), wave.withAlphaComponent(0.15), 1.4)
    // Feet
    strokeLine((48,92),(43,106), foot.withAlphaComponent(0.7), 2, round: true)
    strokeLine((72,92),(77,106), foot.withAlphaComponent(0.7), 2, round: true)
    strokeLine((37,106),(49,106), foot.withAlphaComponent(0.5), 1.5, round: true)
    strokeLine((71,106),(83,106), foot.withAlphaComponent(0.5), 1.5, round: true)

    ctx.restoreGState()
}

func renderIcon(px: Int) -> Data {
    let size = CGFloat(px)
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8,
                        bytesPerRow: 0, space: cs,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    // Squircle background
    let radius = size * 0.2237
    let rrect = CGPath(roundedRect: CGRect(x: 0, y: 0, width: size, height: size),
                       cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.addPath(rrect); ctx.clip()
    ctx.setFillColor(hex(0x111118).cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
    // Green radial glow
    let glowColors = [hex(0x3FD97F, 0.16).cgColor, hex(0x3FD97F, 0).cgColor] as CFArray
    if let grad = CGGradient(colorsSpace: cs, colors: glowColors, locations: [0, 1]) {
        let center = CGPoint(x: size * 0.5, y: size * 0.62)
        ctx.drawRadialGradient(grad, startCenter: center, startRadius: 0,
                               endCenter: center, endRadius: size * 0.5,
                               options: [])
    }
    // Bird, inset 10% (tighter than macOS' usual 16% — the user wants less padding)
    let inset = size * 0.10
    let birdW = size - inset * 2
    let birdH = birdW * birdVB.height / birdVB.width
    let birdRect = CGRect(x: inset, y: (size - birdH) / 2, width: birdW, height: birdH)
    drawBird(ctx, in: birdRect)

    let image = ctx.makeImage()!
    let rep = NSBitmapImageRep(cgImage: image)
    return rep.representation(using: .png, properties: [:])!
}

let setDir = "Chirpset/Assets.xcassets/AppIcon.appiconset"
let entries: [(name: String, px: Int)] = [
    ("icon_16x16",    16),  ("icon_16x16@2x",   32),
    ("icon_32x32",    32),  ("icon_32x32@2x",   64),
    ("icon_128x128", 128),  ("icon_128x128@2x",256),
    ("icon_256x256", 256),  ("icon_256x256@2x",512),
    ("icon_512x512", 512),  ("icon_512x512@2x",1024),
]
for e in entries {
    let data = renderIcon(px: e.px)
    let path = "\(setDir)/\(e.name).png"
    try! data.write(to: URL(fileURLWithPath: path))
    print("wrote \(path) (\(e.px)px)")
}

// Rewrite Contents.json with filenames.
let contents = """
{
  "images" : [
    { "filename" : "icon_16x16.png",     "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_16x16@2x.png",  "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32x32.png",     "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_32x32@2x.png",  "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128x128.png",   "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_128x128@2x.png","idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256x256.png",   "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_256x256@2x.png","idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512x512.png",   "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_512x512@2x.png","idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
"""
try! contents.write(to: URL(fileURLWithPath: "\(setDir)/Contents.json"), atomically: true, encoding: .utf8)
print("wrote Contents.json")
