import Foundation

/// What the user is trying to do when they message the judge.
/// Classified by lightweight keyword signals — no ML, no network.
enum JudgeIntent: String, CaseIterable, Codable {
    case urgent          // "emergency", "have to", "important"
    case boredom         // "bored", "nothing to do", "killing time"
    case socialPressure  // "friend texting", "group chat", "missing out"
    case craving         // "just one scroll", "5 minutes", "quick check"
    case anxiety         // "anxious", "worried", "stressed", "panic"
    case anger           // "stupid", "this app", "you're", profanity
    case negotiation     // "deal", "let me", "i promise", "exception"
    case existential     // "why am i", "what's the point", "meaning"
    case quiet           // empty / one-word / "ok"
    case greeting        // "hi", "hello", "hey"
    case fallback
}

/// Pure-rule classifier. Public so unit tests can probe edge cases.
struct JudgeClassifier {
    static func classify(_ raw: String) -> JudgeIntent {
        let s = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty || s.count <= 2 || ["ok", "k", "yes", "no", "yeah", "nah", "fine"].contains(s) {
            return .quiet
        }
        if matches(s, any: ["hi", "hello", "hey", "yo", "sup"]) && s.count <= 14 { return .greeting }
        if matches(s, any: ["emergency", "urgent", "have to", "need to", "must", "important", "asap"]) { return .urgent }
        if matches(s, any: ["bored", "boring", "nothing to do", "killing time", "kill time", "boredom"]) { return .boredom }
        if matches(s, any: ["friend", "group chat", "girlfriend", "boyfriend", "missing out", "fomo", "everyone is"]) { return .socialPressure }
        if matches(s, any: ["just one", "five minutes", "5 minutes", "quick check", "quick look", "just a sec", "one scroll", "one peek", "five min"]) { return .craving }
        if matches(s, any: ["anxious", "anxiety", "worried", "worry", "stressed", "stress", "panic", "scared", "afraid"]) { return .anxiety }
        if matches(s, any: ["stupid", "dumb", "hate", "shut up", "fuck", "shit", "asshole", "garbage"]) { return .anger }
        if matches(s, any: ["deal", "let me", "i promise", "i swear", "exception", "trade", "make an exception", "compromise", "negotiate"]) { return .negotiation }
        if matches(s, any: ["why am i", "what's the point", "meaning", "what is the point", "no point", "exist", "purpose"]) { return .existential }
        return .fallback
    }

    /// Word-boundary substring match. Avoids "hi" matching inside "this" or
    /// "nothing", which would otherwise misclassify common phrases as greetings.
    private static func matches(_ s: String, any phrases: [String]) -> Bool {
        for p in phrases {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: p))\\b"
            if s.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }
}
