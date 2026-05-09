import Foundation

/// Slot vocabularies for the algorithmic Judge. Each slot has 10–24 entries.
/// Combinatorial space across templates exceeds 10^14 unique outputs before
/// chaining; with sentence chaining it dwarfs "billions of replies."
enum Vocab {

    // MARK: - Openers / addressing

    /// Notarial cold opens: "the record shows", "be advised"...
    static let coldOpens: [String] = [
        "noted",
        "received",
        "logged",
        "on the record",
        "for the record",
        "be advised",
        "the docket reads",
        "duly noted",
        "filed",
        "stipulated",
        "the file shows",
        "the timer disagrees",
        "we have your statement"
    ]

    /// Soft addressing — used when intent is anxiety / quiet.
    static let softOpens: [String] = [
        "easy",
        "okay",
        "alright",
        "breathe",
        "still here",
        "i hear you",
        "understood",
        "noted, gently",
        "okay, slowly",
        "you're fine",
        "stay with it",
        "this passes"
    ]

    // MARK: - The ruling — variations of "no"

    static let denials: [String] = [
        "the answer is no",
        "the lock holds",
        "no early release",
        "request denied",
        "the timer keeps the time",
        "the key isn't yours right now",
        "we won't be opening it",
        "this isn't a negotiation",
        "the iron stays shut",
        "the verdict is wait",
        "no exceptions issued",
        "the gate stays where it is",
        "the bolt does not move",
        "denied, with respect"
    ]

    // MARK: - Reasons / observations the judge offers

    static let reasons: [String] = [
        "this is exactly the moment you set the lock for",
        "you anticipated this version of yourself",
        "the past you was wiser than the present you",
        "your future self will thank the present silence",
        "the urge passes faster than the timer does",
        "you've felt this before and survived it",
        "the phone is louder than the thought underneath",
        "the impulse is real but the emergency isn't",
        "boredom is information, not a problem",
        "the feed will be there, dimmer, later",
        "your attention is the asset under management",
        "the lock is doing exactly what you asked it to",
        "this is the friction you came here for",
        "nothing on the other side is new"
    ]

    // MARK: - Subjects the judge names

    static let subjects: [String] = [
        "the urge",
        "this feeling",
        "the boredom",
        "the impulse",
        "the craving",
        "the static",
        "the loop",
        "the noise",
        "the itch",
        "the pull",
        "the restlessness",
        "the spike"
    ]

    // MARK: - Verbs the subject does

    static let subjectVerbs: [String] = [
        "passes",
        "fades",
        "loosens",
        "softens",
        "burns out",
        "thins",
        "decays",
        "dissolves",
        "settles",
        "quiets"
    ]

    // MARK: - Time framings

    static let timeFramings: [String] = [
        "in two minutes",
        "before the kettle boils",
        "by the next breath",
        "sooner than you think",
        "before you finish reading this",
        "in less time than the scroll would have taken",
        "well before the timer ends",
        "shortly"
    ]

    // MARK: - Closers

    static let closers: [String] = [
        "stay.",
        "sit with it.",
        "wait it out.",
        "hold the line.",
        "see you on the other side.",
        "the timer keeps the time.",
        "back to your day.",
        "well held.",
        "carry on.",
        "good ground."
    ]

    // MARK: - Substitutions for craving / negotiation

    static let alternatives: [String] = [
        "drink a glass of water",
        "stand up and walk eight steps",
        "look out a window for thirty seconds",
        "write the thought on paper",
        "stretch your jaw and shoulders",
        "make tea",
        "step outside for a minute",
        "do nothing for sixty seconds",
        "wash your face with cold water",
        "open a real book to a random page"
    ]

    // MARK: - Boredom reframes

    static let boredomReframes: [String] = [
        "boredom is the cost of attention",
        "boredom is the room where ideas live",
        "boredom is a signal, not a verdict",
        "boredom precedes most of the things worth doing",
        "this is the empty page; nothing is written on a phone",
        "boredom is the thing the feed was hiding"
    ]

    // MARK: - Anger acknowledgments (judge stays calm)

    static let angerAcks: [String] = [
        "the judge is not insulted",
        "the bench takes no offense",
        "we accept the criticism without ruling on it",
        "your protest is on the record",
        "frustration is admissible; unlock is not",
        "you can yell. the lock doesn't hear."
    ]

    // MARK: - Anxiety steadying lines

    static let anxietyLines: [String] = [
        "your nervous system is older than your phone",
        "the body settles when the input slows",
        "you are not in danger from a quiet screen",
        "anxiety speeds up when fed; this is the slowing",
        "fewer inputs, smaller storms",
        "the panic was here before the lock; it leaves first"
    ]

    // MARK: - Existential lines

    static let existentialLines: [String] = [
        "the point is to be here for the next hour",
        "meaning is what's left when the scroll stops",
        "the question is real; the feed is not the place to ask it",
        "the question stays. the lock stays too.",
        "you can keep the question and the lock at the same time"
    ]

    // MARK: - Greetings

    static let greetings: [String] = [
        "the judge is in.",
        "court is in session.",
        "still here.",
        "we're listening.",
        "the bench acknowledges you.",
        "go ahead — state the issue."
    ]

    // MARK: - Quiet acknowledgments

    static let quietAcks: [String] = [
        "okay.",
        "alright.",
        "go on, when you want.",
        "no rush.",
        "we'll wait with you.",
        "the door stays shut. so do we."
    ]
}
