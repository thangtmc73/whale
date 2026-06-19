import SwiftUI

/// Whale's design system — "the ocean that embraces hundreds of rivers": calm, intelligent,
/// trustworthy, premium. Dark-only by design (not light/dark-adaptive) per the brief's "Premium
/// dark mode" direction — applied via `.preferredColorScheme(.dark)` at the window root.
///
/// Typography note: the brief specifies Geist/Inter, but no font files are bundled with the app
/// (and none should be fabricated) — falls back to the system font (SF Pro) at the requested
/// weights, the closest available substitute without shipping third-party font assets.
enum WhaleTheme {
    enum Color {
        // Brightened from the original brief's palette per user feedback ("more vivid colors") —
        // background lifted off near-black, accents pushed more saturated, surfaces/borders more
        // visible, selection states tinted instead of plain gray.
        static let background = SwiftUI.Color(hex: 0x121B36)
        static let primary = SwiftUI.Color(hex: 0x3B82F6)
        static let secondary = SwiftUI.Color(hex: 0x2EE6F5)
        static let accent = SwiftUI.Color(hex: 0x93E8FF)
        static let text = SwiftUI.Color(hex: 0xFFFFFF)
        static let muted = SwiftUI.Color(hex: 0xAEBBD6)
        static let border = SwiftUI.Color.white.opacity(0.12)
        static let surface = SwiftUI.Color.white.opacity(0.06)
        static let surfaceHover = SwiftUI.Color.white.opacity(0.10)
        static let surfaceSelected = secondary.opacity(0.20)

        static let gradient = LinearGradient(colors: [primary, secondary], startPoint: .leading, endPoint: .trailing)
    }

    enum Radius {
        static let small: CGFloat = 10
        static let medium: CGFloat = 16
        static let large: CGFloat = 22
        static let composer: CGFloat = 26
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }

    enum Motion {
        static let fast = SwiftUI.Animation.easeOut(duration: 0.15)
        static let normal = SwiftUI.Animation.easeInOut(duration: 0.22)
    }

    enum Typography {
        static func heading(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold) }
        static func body(_ size: CGFloat = 13) -> Font { .system(size: size, weight: .medium) }
        static func caption(_ size: CGFloat = 11) -> Font { .system(size: size, weight: .medium) }
        static func mono(_ size: CGFloat = 12) -> Font { .system(size: size, weight: .regular, design: .monospaced) }
    }
}

extension SwiftUI.Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b, opacity: opacity)
    }
}

/// "Soft depth instead of heavy shadows" — a faint colored glow rather than a hard drop shadow.
struct WhaleGlow: ViewModifier {
    var color: SwiftUI.Color
    var radius: CGFloat
    var opacity: Double

    func body(content: Content) -> some View {
        content.shadow(color: color.opacity(opacity), radius: radius)
    }
}

extension View {
    func whaleGlow(_ color: SwiftUI.Color = WhaleTheme.Color.secondary, radius: CGFloat = 20, opacity: Double = 0.15) -> some View {
        modifier(WhaleGlow(color: color, radius: radius, opacity: opacity))
    }

    /// Subtle bordered card surface used throughout (sidebar rows, composer, code blocks).
    func whaleSurface(cornerRadius: CGFloat = WhaleTheme.Radius.medium, fill: SwiftUI.Color = WhaleTheme.Color.surface) -> some View {
        self
            .background(RoundedRectangle(cornerRadius: cornerRadius).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(WhaleTheme.Color.border, lineWidth: 1))
    }
}
