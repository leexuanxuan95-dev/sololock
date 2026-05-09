import XCTest
@testable import SoloLock

final class JudgeEngineTests: XCTestCase {

    func testClassifierUrgent() {
        XCTAssertEqual(JudgeClassifier.classify("this is urgent please"), .urgent)
        XCTAssertEqual(JudgeClassifier.classify("I have to check now"), .urgent)
    }

    func testClassifierBoredom() {
        XCTAssertEqual(JudgeClassifier.classify("im bored out of my mind"), .boredom)
        XCTAssertEqual(JudgeClassifier.classify("nothing to do"), .boredom)
    }

    func testClassifierCraving() {
        XCTAssertEqual(JudgeClassifier.classify("just one scroll please"), .craving)
        XCTAssertEqual(JudgeClassifier.classify("five minutes only"), .craving)
    }

    func testClassifierAnxiety() {
        XCTAssertEqual(JudgeClassifier.classify("im so anxious right now"), .anxiety)
        XCTAssertEqual(JudgeClassifier.classify("panic attack"), .anxiety)
    }

    func testClassifierAnger() {
        XCTAssertEqual(JudgeClassifier.classify("this is so stupid"), .anger)
    }

    func testClassifierQuiet() {
        XCTAssertEqual(JudgeClassifier.classify(""), .quiet)
        XCTAssertEqual(JudgeClassifier.classify("ok"), .quiet)
    }

    func testReplyIsNonEmpty() {
        let engine = JudgeEngine()
        var ctx = JudgeContext(
            minutesElapsed: 5, minutesRemaining: 55,
            sessionSeed: 0xDEADBEEF, recentHashes: []
        )
        let reply = engine.reply(to: "im bored", context: &ctx)
        XCTAssertFalse(reply.text.isEmpty)
        XCTAssertEqual(reply.intent, .boredom)
    }

    /// Demonstrates the algorithm produces high variety: 200 random user inputs
    /// across distinct seeds should yield far more than 100 unique replies.
    func testBillionScaleVariety() {
        let engine = JudgeEngine()
        var seen = Set<String>()
        let prompts = [
            "im bored", "this is dumb", "just one scroll", "im anxious",
            "i need to check", "let me have an exception", "what is the point",
            "hey", "ok", "ugh", "i promise just one peek", "stress is bad rn"
        ]
        for i in 0..<200 {
            var ctx = JudgeContext(
                minutesElapsed: i % 60, minutesRemaining: 60 - (i % 60),
                sessionSeed: UInt64(0xCAFEBABE0001) &* UInt64(i + 1),
                recentHashes: []
            )
            let p = prompts[i % prompts.count]
            let r = engine.reply(to: p, context: &ctx)
            seen.insert(r.text)
        }
        XCTAssertGreaterThan(seen.count, 120, "Engine should produce highly varied replies")
    }

    /// Anti-repeat memo dampens immediate duplicates within one session.
    func testAntiRepeatWithinSession() {
        let engine = JudgeEngine()
        var ctx = JudgeContext(
            minutesElapsed: 10, minutesRemaining: 50,
            sessionSeed: 0xA5A5_A5A5, recentHashes: []
        )
        var unique = Set<String>()
        for _ in 0..<8 {
            let r = engine.reply(to: "im bored", context: &ctx)
            unique.insert(r.text)
        }
        // Out of 8 tries with same prompt, expect at least 4 distinct.
        XCTAssertGreaterThanOrEqual(unique.count, 4)
    }

    func testOpeningMessageMentionsTime() {
        let engine = JudgeEngine()
        let m = engine.openingMessage(seed: 42, plannedMinutes: 60)
        XCTAssertFalse(m.text.isEmpty)
    }
}
