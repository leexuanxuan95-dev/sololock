import SwiftUI

/// Solo Lock palette — vault gray, lock brass, open green, SOS red, cream.
/// Defined in Assets.xcassets so Live Activity / Watch can share the same names.
enum Palette {
    static let vault     = Color("vault")
    static let vaultDeep = Color("vaultDeep")
    static let brass     = Color("brass")
    static let openGreen = Color("openGreen")
    static let sosRed    = Color("sosRed")
    static let cream     = Color("cream")

    static let textPrimary   = cream
    static let textSecondary = cream.opacity(0.62)
    static let textTertiary  = cream.opacity(0.38)
    static let hairline      = cream.opacity(0.10)
}
