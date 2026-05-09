import Foundation

/// Who holds the key during a session.
enum Lockmaster: String, Codable, CaseIterable, Identifiable, Hashable {
    case aiJudge       = "ai_judge"
    case randomDelay   = "random_delay"
    case charity       = "charity"
    case friend        = "friend"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .aiJudge:     return "AI Judge"
        case .randomDelay: return "Random Delay"
        case .charity:     return "Charity Lock"
        case .friend:      return "Friend"
        }
    }

    var subtitle: String {
        switch self {
        case .aiJudge:     return "no early unlock"
        case .randomDelay: return "wait 15 min + 50 words"
        case .charity:     return "break early = donation"
        case .friend:      return "invite someone (legacy)"
        }
    }

    var glyph: String {
        switch self {
        case .aiJudge:     return "scale.3d"
        case .randomDelay: return "hourglass"
        case .charity:     return "heart.text.square.fill"
        case .friend:      return "person.2.fill"
        }
    }

    /// Marketed as paid-only? UI surfaces a "Pro" chip.
    var isPro: Bool {
        switch self {
        case .aiJudge: return false
        case .randomDelay, .charity, .friend: return true
        }
    }

    var explainer: String {
        switch self {
        case .aiJudge:
            return "An algorithmic judge holds the key. It will not negotiate. The session ends when the timer ends — no exceptions, no philosophy lectures, no foot-massage emergencies."
        case .randomDelay:
            return "If you want to unlock early, you must wait fifteen minutes and then write fifty words explaining why this is so urgent. Most of the time, by minute fourteen, it isn't."
        case .charity:
            return "Pick a dollar amount. Pick a charity. Break the lock early — your card is charged, the charity gets one hundred percent, we keep zero."
        case .friend:
            return "Someone you trust holds the key. They get a notification. They can unlock you, or they can ignore you. (This is the original LOCKBOX mechanic.)"
        }
    }
}
