import Foundation

/// Sentence templates per intent. Slots: {open}, {soft}, {deny}, {reason},
/// {subject}, {verb}, {time}, {close}, {alt}, {boredom}, {angerAck},
/// {anxiety}, {exist}, {greet}, {quiet}, {minutes}, {progress}.
///
/// Multiple templates per intent so the surface form rotates even when the
/// underlying ruling is the same.
enum JudgeTemplates {

    static func templates(for intent: JudgeIntent) -> [String] {
        switch intent {
        case .urgent: return urgent
        case .boredom: return boredom
        case .socialPressure: return socialPressure
        case .craving: return craving
        case .anxiety: return anxiety
        case .anger: return anger
        case .negotiation: return negotiation
        case .existential: return existential
        case .quiet: return quiet
        case .greeting: return greeting
        case .fallback: return fallback
        }
    }

    private static let urgent: [String] = [
        "{open}. {deny} — {reason}.",
        "{open}. real emergencies don't get typed in here. they get acted on.",
        "{open}. if it's a true emergency, your phone can still call. {deny}.",
        "if it were truly urgent, you'd be moving, not negotiating. {deny}.",
        "the lock distinguishes between urgent and uncomfortable. this is the second one.",
        "{open}. urgency is the favorite costume of the urge.",
        "{deny}. emergencies use 911, not lockmasters.",
        "we read the message. {deny}. {close}",
        "the urgency is felt; the unlock is not granted.",
        "{open}. the brain calls everything urgent at minute three. it isn't.",
        "name the emergency in one sentence. read it back. still feel urgent? wait one more minute and read it again.",
        "{deny}. the only thing on fire is your attention."
    ]

    private static let boredom: [String] = [
        "{open}. {boredom}.",
        "boredom is what you came here for. {close}",
        "{open}. {boredom}. the lock is doing the work.",
        "this is the muscle being trained. boredom in, attention out.",
        "{open}. {subject} {verb} {time}. you don't need a phone to wait it out.",
        "the boredom is the point. the boredom is the medicine.",
        "{boredom}. you can {alt} or just sit. either is fine.",
        "{open}. boredom is a draft of an idea. give it room.",
        "if the only cure for empty time is a feed, the feed is the disease.",
        "ten minutes of boredom is cheaper than two hours of regret. {close}"
    ]

    private static let socialPressure: [String] = [
        "{open}. anyone who needs you for a real reason can call. the rest can wait.",
        "the group chat survives without you. it always does.",
        "{open}. fomo is the feeling that something is happening. nothing is.",
        "{deny}. your friends are not net-better off when you're scrolling at them.",
        "the worst social cost is small. the cost of breaking a lock is bigger.",
        "if a friend is mid-crisis, they will phone. they always do.",
        "{open}. the chat will read the same in {time}.",
        "you are not behind. there is no behind to be in.",
        "social momentum is a hallucination of the feed. {close}",
        "{open}. {subject} {verb} {time} — the chat won't have moved much.",
        "the wedding photos, the hot take, the inside joke — all of it keeps."
    ]

    private static let craving: [String] = [
        "{open}. \"just one\" is the lock's least favorite sentence.",
        "five minutes is forty. you know this. {deny}.",
        "{open}. one scroll is the trailer for the next two hours.",
        "{deny}. the quick check is the slow exit.",
        "{open}. {subject} {verb} {time}. that's shorter than the scroll would be.",
        "instead of one peek, {alt}. then re-read this in two minutes.",
        "the craving is loud now. it gets quiet when ignored. {close}",
        "{open}. one peek and the lock has done nothing for you today.",
        "you didn't pay this lock to grant exceptions. {close}",
        "imagine yourself in ten minutes having scrolled. is that a better version? {deny}.",
        "{open}. the urge is honest about what it wants and lying about how long it takes."
    ]

    private static let anxiety: [String] = [
        "{soft}. {anxiety}.",
        "{soft}. the screen makes anxiety louder, not smaller.",
        "{soft}. {subject} {verb} {time}. nothing here is on fire.",
        "you are not in danger. the lock is not in danger. {close}",
        "the body needs slower input right now, not faster. that's what this is.",
        "{soft}. you can sit. you can move. you can write. you can do nothing.",
        "{anxiety}. the feed is not where panic gets resolved.",
        "{soft}. try one slow breath. then another. the lock will keep the time.",
        "{soft}. anxiety wants stimulation. the lock prescribes the opposite.",
        "you came here because you knew this would happen. you also knew it would pass."
    ]

    private static let anger: [String] = [
        "{angerAck}.",
        "{angerAck}. {deny}.",
        "{open}. {angerAck} — the lock continues.",
        "{angerAck}. the timer is unmoved.",
        "yell as needed. the bench is calm. {deny}.",
        "{angerAck}. the anger is data. the unlock is not the response.",
        "the judge cannot be insulted into opening the door.",
        "{open}. the protest is logged. the verdict stands.",
        "anger at the lock is anger at the past you who set it. forgive them; they were right."
    ]

    private static let negotiation: [String] = [
        "{open}. there is no deal to be made. the deal already happened, with the past you, before the lock.",
        "{deny}. the lockmaster doesn't take counteroffers.",
        "you've already negotiated — when you set this. that was the only round.",
        "{open}. the bench accepts no plea bargains.",
        "the only exception was already used: it was called \"don't lock yourself in.\" you declined.",
        "{deny}. promises to the future are paid in present silence.",
        "you can promise anything. the lock holds anyway.",
        "{open}. \"i swear\" is the sound the urge makes when it's losing.",
        "every clever bargain has been heard before. {close}",
        "the lock's contract has one clause and you signed it."
    ]

    private static let existential: [String] = [
        "{exist}.",
        "{exist}. {close}",
        "{open}. {exist}.",
        "the question is good. the feed is not the answer.",
        "{exist}. the lock keeps the room quiet enough to hear it.",
        "the question outlasts the timer. that's fine.",
        "you can hold the question and the silence at the same time.",
        "{open}. meaning is mostly noticing. the feed is mostly not noticing."
    ]

    private static let quiet: [String] = [
        "{quiet}",
        "{quiet} {close}",
        "{open}. {quiet}",
        "still here.",
        "we'll wait. {close}"
    ]

    private static let greeting: [String] = [
        "{greet}",
        "{greet} state the issue when ready.",
        "{greet} the timer is doing its job.",
        "{open}. {greet}",
        "{greet} {progress}"
    ]

    private static let fallback: [String] = [
        "{open}. {deny} — {reason}.",
        "{open}. {subject} {verb} {time}. {close}",
        "{open}. the lock continues. {close}",
        "{deny}. {close}",
        "the docket has it. {deny}.",
        "{open}. the timer is faster than it feels.",
        "{open}. {reason}. {close}",
        "the message is heard. the lock is not moved.",
        "{open}. nothing on the other side is new. {close}"
    ]
}
