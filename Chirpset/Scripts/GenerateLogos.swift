#!/usr/bin/env swift
import AppKit

// Generates brand images for the README into assets/:
//   logo.png              — the bird mark with a green glow (transparent)
//   wordmark-dark.png     — bird + "Chirpset" wordmark, light text (dark backgrounds)
//   wordmark-light.png    — bird + "Chirpset" wordmark, dark text (light backgrounds)
//   icon.png              — the app icon (bird on a dark squircle)
// Run from the repo root:  swift Chirpset/Scripts/GenerateLogos.swift

let birdVB = CGSize(width: 120, height: 110)

func hex(_ h: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((h >> 16) & 0xFF)/255, green: CGFloat((h >> 8) & 0xFF)/255,
            blue: CGFloat(h & 0xFF)/255, alpha: a)
}

func drawBird(_ ctx: CGContext, in rect: CGRect, glow: Bool) {
    let s = min(rect.width / birdVB.width, rect.height / birdVB.height)
    ctx.saveGState()
    ctx.translateBy(x: rect.minX, y: rect.maxY)
    ctx.scaleBy(x: s, y: -s)

    let body = hex(0xE8A838), bodyHi = NSColor.white.withAlphaComponent(0.06)
    let wing = hex(0xC48820), beak = hex(0xD49030)
    let led = hex(0x3FD97F), ledGlow = hex(0x3FD97F)
    let eye = hex(0x0A0A0E), hi = NSColor.white.withAlphaComponent(0.85)
    let wave = hex(0x3FD97F), trace = NSColor.black.withAlphaComponent(0.10)
    let foot = hex(0xE8A838)

    func poly(_ p: [(CGFloat, CGFloat)], _ c: NSColor) {
        ctx.beginPath(); ctx.move(to: CGPoint(x: p[0].0, y: p[0].1))
        p.dropFirst().forEach { ctx.addLine(to: CGPoint(x: $0.0, y: $0.1)) }
        ctx.closePath(); ctx.setFillColor(c.cgColor); ctx.fillPath()
    }
    func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, _ c: NSColor) {
        ctx.setFillColor(c.cgColor)
        ctx.fillEllipse(in: CGRect(x: cx-r, y: cy-r, width: r*2, height: r*2))
    }
    func line(_ a: (CGFloat, CGFloat), _ b: (CGFloat, CGFloat), _ c: NSColor, _ w: CGFloat, round: Bool = false) {
        ctx.setStrokeColor(c.cgColor); ctx.setLineWidth(w); ctx.setLineCap(round ? .round : .butt)
        ctx.move(to: CGPoint(x: a.0, y: a.1)); ctx.addLine(to: CGPoint(x: b.0, y: b.1)); ctx.strokePath()
    }
    func curve(_ p0: (CGFloat, CGFloat), _ c1: (CGFloat, CGFloat), _ c2: (CGFloat, CGFloat), _ p1: (CGFloat, CGFloat), _ c: NSColor, _ w: CGFloat) {
        ctx.setStrokeColor(c.cgColor); ctx.setLineWidth(w); ctx.setLineCap(.round)
        ctx.move(to: CGPoint(x: p0.0, y: p0.1))
        ctx.addCurve(to: CGPoint(x: p1.0, y: p1.1), control1: CGPoint(x: c1.0, y: c1.1), control2: CGPoint(x: c2.0, y: c2.1))
        ctx.strokePath()
    }

    if glow { circle(60, 50, 46, ledGlow.withAlphaComponent(0.10)) }
    poly([(34,42),(10,30),(16,42),(5,35),(18,49),(34,55)], wing.withAlphaComponent(0.6))
    poly([(86,42),(110,30),(104,42),(115,35),(102,49),(86,55)], wing.withAlphaComponent(0.6))
    ctx.beginPath(); ctx.move(to: CGPoint(x: 34, y: 38))
    ctx.addCurve(to: CGPoint(x: 86, y: 38), control1: CGPoint(x: 34, y: 22), control2: CGPoint(x: 86, y: 22))
    ctx.addLine(to: CGPoint(x: 86, y: 78))
    ctx.addCurve(to: CGPoint(x: 34, y: 78), control1: CGPoint(x: 86, y: 94), control2: CGPoint(x: 34, y: 94))
    ctx.closePath(); ctx.setFillColor(body.cgColor); ctx.fillPath()
    ctx.beginPath(); ctx.move(to: CGPoint(x: 38, y: 36))
    ctx.addCurve(to: CGPoint(x: 82, y: 36), control1: CGPoint(x: 38, y: 26), control2: CGPoint(x: 82, y: 26))
    ctx.addLine(to: CGPoint(x: 82, y: 54))
    ctx.addCurve(to: CGPoint(x: 38, y: 54), control1: CGPoint(x: 82, y: 60), control2: CGPoint(x: 38, y: 60))
    ctx.closePath(); ctx.setFillColor(bodyHi.cgColor); ctx.fillPath()
    line((40,54),(50,54), trace, 1.2); circle(50,54,1.5, trace)
    line((70,54),(80,54), trace, 1.2); circle(70,54,1.5, trace)
    line((40,78),(48,78), trace, 1.2); line((72,78),(80,78), trace, 1.2)
    line((60,22),(60,7), body, 2.5, round: true)
    circle(60,4.5,8, ledGlow.withAlphaComponent(0.12)); circle(60,4.5,4.5, led)
    circle(48,46,6, eye); circle(72,46,6, eye)
    circle(49.5,44.5,2, hi); circle(73.5,44.5,2, hi)
    poly([(60,56),(66.5,64),(60,72),(53.5,64)], beak)
    curve((50,60),(43.5,54),(41,63),(45.5,69), wave.withAlphaComponent(0.35), 1.8)
    curve((70,60),(76.5,54),(79,63),(74.5,69), wave.withAlphaComponent(0.35), 1.8)
    curve((44,55),(35,47),(32,60),(39,72), wave.withAlphaComponent(0.15), 1.4)
    curve((76,55),(85,47),(88,60),(81,72), wave.withAlphaComponent(0.15), 1.4)
    line((48,92),(43,106), foot.withAlphaComponent(0.7), 2, round: true)
    line((72,92),(77,106), foot.withAlphaComponent(0.7), 2, round: true)
    line((37,106),(49,106), foot.withAlphaComponent(0.5), 1.5, round: true)
    line((71,106),(83,106), foot.withAlphaComponent(0.5), 1.5, round: true)
    ctx.restoreGState()
}

func makeContext(_ w: Int, _ h: Int) -> CGContext {
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    return CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                     space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

func write(_ ctx: CGContext, to path: String) {
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
    print("wrote \(path)")
}

// MARK: logo.png — bird mark with glow
do {
    let px = 512
    let ctx = makeContext(px, px)
    let inset = CGFloat(px) * 0.08
    let bw = CGFloat(px) - inset*2
    let bh = bw * birdVB.height / birdVB.width
    drawBird(ctx, in: CGRect(x: inset, y: (CGFloat(px)-bh)/2, width: bw, height: bh), glow: true)
    write(ctx, to: "assets/logo.png")
}

// MARK: wordmark variants — bird + "Chirpset"
func wordmark(textColor: NSColor, path: String) {
    let scale: CGFloat = 3
    let birdH = 96 * scale
    let birdW = birdH * birdVB.width / birdVB.height
    let fontSize = 92 * scale
    let font = NSFont.systemFont(ofSize: fontSize, weight: .heavy)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font, .foregroundColor: textColor, .kern: -fontSize * 0.03
    ]
    let text = NSAttributedString(string: "Chirpset", attributes: attrs)
    let textSize = text.size()
    let gap = 18 * scale
    let pad = 16 * scale
    let w = Int(birdW + gap + textSize.width + pad*2)
    let h = Int(max(birdH, textSize.height) + pad*2)

    let ctx = makeContext(w, h)
    let ns = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ns

    let birdRect = CGRect(x: pad, y: (CGFloat(h)-birdH)/2, width: birdW, height: birdH)
    drawBird(ctx, in: birdRect, glow: false)
    let ty = (CGFloat(h) - textSize.height)/2
    text.draw(at: CGPoint(x: pad + birdW + gap, y: ty))

    NSGraphicsContext.restoreGraphicsState()
    write(ctx, to: path)
}
wordmark(textColor: hex(0xF0F0F6), path: "assets/wordmark-dark.png")
wordmark(textColor: hex(0x1A1A1E), path: "assets/wordmark-light.png")

// MARK: icon.png — copy the rendered app icon if present
let appIcon = "Chirpset/Chirpset/Assets.xcassets/AppIcon.appiconset/icon_256x256@2x.png"
if FileManager.default.fileExists(atPath: appIcon) {
    try? FileManager.default.removeItem(atPath: "assets/icon.png")
    try? FileManager.default.copyItem(atPath: appIcon, toPath: "assets/icon.png")
    print("copied assets/icon.png")
}
