import Foundation

/// Pickable session lengths from UI.md.
enum SessionDuration: String, Codable, CaseIterable, Identifiable, Hashable {
    case m15
    case m30
    case h1
    case h4
    case h8
    case overnight

    var id: String { rawValue }

    var seconds: TimeInterval {
        switch self {
        case .m15:       return 15 * 60
        case .m30:       return 30 * 60
        case .h1:        return 60 * 60
        case .h4:        return 4 * 60 * 60
        case .h8:        return 8 * 60 * 60
        case .overnight: return 10 * 60 * 60   // ~10h, treated as until-morning
        }
    }

    var label: String {
        switch self {
        case .m15:       return "15 m"
        case .m30:       return "30 m"
        case .h1:        return "1 h"
        case .h4:        return "4 h"
        case .h8:        return "8 h"
        case .overnight: return "overnight"
        }
    }

    /// Sessions over an hour require Pro on the free tier.
    var isPro: Bool {
        switch self {
        case .m15, .m30, .h1: return false
        case .h4, .h8, .overnight: return true
        }
    }
}
