import SwiftUI
import AppKit

/// Whale's design system — "the ocean that embraces hundreds of rivers": calm, intelligent,
/// trustworthy, premium. The custom "Deep Ocean" palette now ships in BOTH a dark and a light
/// variant and follows the system appearance (no longer forced dark) — every token is a
/// `dynamic(light:dark:)` color that resolves itself per appearance, so views never need to read
/// `@Environment(\.colorScheme)`; they just reference `WhaleTheme.Color.*` as before.
///
/// Typography note: the brief specifies Geist/Inter, but no font files are bundled with the app
/// (and none should be fabricated) — falls back to the system font (SF Pro) at the requested
/// weights, the closest available substitute without shipping third-party font assets.
enum WhaleTheme {
    enum Color {
        // Dark "Deep Ocean" — the original brief palette: background lifted off near-black, vivid
        // cyan/blue accents, white text. Light "Deep Ocean" — a foam/sky-tinted background with
        // the same ocean hues darkened enough to stay legible on a light surface, and deep-navy
        // ink for text. Each token below pairs the two.
        static let background = SwiftUI.Color.dynamic(light: 0xEAF1F8, dark: 0x121B36)
        static let primary = SwiftUI.Color.dynamic(light: 0x2563EB, dark: 0x3B82F6)
        static let secondary = SwiftUI.Color.dynamic(light: 0x0891B2, dark: 0x2EE6F5)
        static let accent = SwiftUI.Color.dynamic(light: 0x0E7490, dark: 0x93E8FF)
        static let text = SwiftUI.Color.dynamic(light: 0x0B1A33, dark: 0xFFFFFF)
        static let muted = SwiftUI.Color.dynamic(light: 0x55657F, dark: 0xAEBBD6)

        // On the dark navy bg these are white-tinted (translucent highlights); on the light foam
        // bg that same translucency would vanish, so light uses near-white elevated cards and
        // ink-tinted borders/hovers instead.
        static let border = SwiftUI.Color.dynamic(light: 0x0B1A33, darkAlpha: 0.12, lightAlpha: 0.12, dark: 0xFFFFFF)
        static let surface = SwiftUI.Color.dynamic(light: 0xFFFFFF, darkAlpha: 0.06, lightAlpha: 1.0, dark: 0xFFFFFF)
        static let surfaceHover = SwiftUI.Color.dynamic(light: 0xEDF2F8, darkAlpha: 0.10, lightAlpha: 1.0, dark: 0xFFFFFF)
        static let surfaceSelected = secondary.opacity(0.20)

        static let gradient = LinearGradient(colors: [primary, secondary], startPoint: .leading, endPoint: .trailing)
    }

    /// Code/diff palette — now adaptive to the appearance. Dark mode keeps the deep navy editor
    /// slab with light text + pastel syntax; light mode uses a soft light slab with darker, denser
    /// syntax colors tuned for contrast (an earlier near-white slab with pastel colors read as
    /// washed out, so the light variants here are deliberately deeper greens/blues/ambers). The
    /// syntax highlighter uses THIS palette (not the general `Color.*` tokens) so each token has a
    /// purpose-picked value per appearance.
    enum Code {
        static let background = SwiftUI.Color.dynamic(light: 0xF1F4F9, dark: 0x0C1730)
        static let header = SwiftUI.Color.dynamic(light: 0x0B1A33, darkAlpha: 0.04, lightAlpha: 0.05, dark: 0xFFFFFF)
        static let border = SwiftUI.Color.dynamic(light: 0x0B1A33, darkAlpha: 0.10, lightAlpha: 0.12, dark: 0xFFFFFF)
        static let text = SwiftUI.Color.dynamic(light: 0x1F2430, dark: 0xE6EDF7)
        static let muted = SwiftUI.Color.dynamic(light: 0x6B7280, dark: 0x8A97B0)
        static let string = SwiftUI.Color.dynamic(light: 0x0A7D33, dark: 0x86EFAC)
        static let number = SwiftUI.Color.dynamic(light: 0xB45309, dark: 0x93E8FF)
        static let keyword = SwiftUI.Color.dynamic(light: 0x0550AE, dark: 0x2EE6F5)
        static let diffAddition = SwiftUI.Color.dynamic(light: 0x15803D, dark: 0x86EFAC)
        static let diffRemoval = SwiftUI.Color.dynamic(light: 0xB91C1C, dark: 0xFCA5A5)
        static let diffAdditionBackground = SwiftUI.Color(hex: 0x22C55E, opacity: 0.16)
        static let diffRemovalBackground = SwiftUI.Color(hex: 0xEF4444, opacity: 0.16)
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

    /// A color that resolves itself against the active appearance — light vs dark — so a single
    /// static token works in both modes without any view reading the environment. Backed by an
    /// `NSColor` dynamic provider, which AppKit re-evaluates whenever the appearance changes.
    static func dynamic(light: UInt32, dark: UInt32) -> SwiftUI.Color {
        dynamic(light: light, darkAlpha: 1.0, lightAlpha: 1.0, dark: dark)
    }

    static func dynamic(light: UInt32, darkAlpha: Double, lightAlpha: Double, dark: UInt32) -> SwiftUI.Color {
        SwiftUI.Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let hex = isDark ? dark : light
            let alpha = isDark ? darkAlpha : lightAlpha
            return NSColor(SwiftUI.Color(hex: hex, opacity: alpha))
        })
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
