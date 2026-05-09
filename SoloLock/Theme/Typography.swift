import SwiftUI

/// Solo Lock typography. Falls back to SF when Söhne / GT Sectra / IBM Plex Mono
/// aren't bundled — the design intent (weight + monospacing) survives the fallback.
enum Typography {
    /// Notarial agreement / hero copy. Serif when available, otherwise SF Serif.
    static func sectra(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight, design: .serif)
    }

    /// UI body / labels. Geometric sans.
    static func sohne(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight, design: .default)
    }

    /// Countdown / numerics. Tabular monospace so digits don't jitter.
    static func plexMono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}
