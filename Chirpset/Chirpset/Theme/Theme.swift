import SwiftUI

/// Design tokens extracted from the Chirpset brand toolkit + prototype.
/// Dark-first, born from the macOS menu bar. Amber carries the bird's
/// identity; green signals scanning/status; blue is action/progress.
enum Theme {

    // MARK: Surfaces
    static let bg            = Color(oklch: (0.13, 0.005, 250))
    static let surface       = Color(oklch: (0.22, 0.006, 250))
    static let surfaceRaised = Color(oklch: (0.27, 0.006, 250))
    static let surfaceHover  = Color(oklch: (0.32, 0.006, 250))

    // MARK: Text
    static let fg          = Color(oklch: (0.93, 0.005, 250))
    static let fgSecondary = Color(oklch: (0.72, 0.008, 250))
    static let muted       = Color(oklch: (0.52, 0.010, 250))

    // MARK: Lines
    static let border      = Color(oklch: (0.35, 0.006, 250))
    static let borderLight = Color(oklch: (0.28, 0.005, 250))

    // MARK: Accents
    static let accent      = Color(oklch: (0.72, 0.19, 150)) // circuit green
    static let accentBlue  = Color(oklch: (0.62, 0.18, 260)) // flash blue
    static let accentAmber = Color(oklch: (0.75, 0.16, 85))  // amber bird
    static let accentRed   = Color(oklch: (0.62, 0.22, 25))  // error red

    // MARK: Radii
    static let radius: CGFloat = 8
    static let radiusLarge: CGFloat = 12

    // MARK: Fonts
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

extension Color {
    /// Construct a Color from approximate OKLCH (L 0–1, C, H degrees).
    /// SwiftUI has no native OKLCH initializer, so we convert OKLCH → linear sRGB.
    init(oklch: (l: Double, c: Double, h: Double)) {
        let (r, g, b) = oklchToLinearSRGB(L: oklch.l, C: oklch.c, Hdeg: oklch.h)
        self.init(.sRGBLinear, red: r, green: g, blue: b, opacity: 1.0)
    }
}

/// OKLCH → OKLab → linear sRGB. Returns clamped linear-light components.
private func oklchToLinearSRGB(L: Double, C: Double, Hdeg: Double) -> (Double, Double, Double) {
    let h = Hdeg * .pi / 180.0
    let a = C * cos(h)
    let bb = C * sin(h)

    // OKLab → LMS'
    let l_ = L + 0.3963377774 * a + 0.2158037573 * bb
    let m_ = L - 0.1055613458 * a - 0.0638541728 * bb
    let s_ = L - 0.0894841775 * a - 1.2914855480 * bb

    let l = l_ * l_ * l_
    let m = m_ * m_ * m_
    let s = s_ * s_ * s_

    // LMS → linear sRGB
    var r =  4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
    var g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
    var b = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

    r = min(max(r, 0), 1)
    g = min(max(g, 0), 1)
    b = min(max(b, 0), 1)
    return (r, g, b)
}
