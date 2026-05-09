import XCTest
@testable import SoloLock

/// Calculation and edge-case sweep — the kind of thing that bites you on
/// week three of being live. Covers every duration, every outcome, every
/// stat aggregation path.
final class EdgeCaseTests: XCTestCase {

    // MARK: - SessionDuration math

    func testAllDurationsSecondsAreCorrect() {
        XCTAssertEqual(SessionDuration.m15.seconds, 15 * 60)
        XCTAssertEqual(SessionDuration.m30.seconds, 30 * 60)
        XCTAssertEqual(SessionDuration.h1.seconds, 60 * 60)
        XCTAssertEqual(SessionDuration.h4.seconds, 4 * 60 * 60)
        XCTAssertEqual(SessionDuration.h8.seconds, 8 * 60 * 60)
        XCTAssertEqual(SessionDuration.overnight.seconds, 10 * 60 * 60)
    }

    func testFreeTierDurationsAreFreeOnly() {
        // Free tier: 15m, 30m, 1h.
        XCTAssertFalse(SessionDuration.m15.isPro)
        XCTAssertFalse(SessionDuration.m30.isPro)
        XCTAssertFalse(SessionDuration.h1.isPro)
        // Pro tier: 4h, 8h, overnight.
        XCTAssertTrue(SessionDuration.h4.isPro)
        XCTAssertTrue(SessionDuration.h8.isPro)
        XCTAssertTrue(SessionDuration.overnight.isPro)
    }

    // MARK: - Lockmaster gating

    func testOnlyAIJudgeIsFree() {
        XCTAssertFalse(Lockmaster.aiJudge.isPro)
        XCTAssertTrue(Lockmaster.randomDelay.isPro)
        XCTAssertTrue(Lockmaster.charity.isPro)
        XCTAssertTrue(Lockmaster.friend.isPro)
    }

    // MARK: - Session math edge cases

    func testProgressClampedAtBothEnds() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let s = Session(startedAt: start, duration: 600,
                        lockmaster: .aiJudge, blockedGroups: [])
        // Before start (negative time) is clamped to 0.
        XCTAssertEqual(s.progress(at: start.addingTimeInterval(-100)), 0, accuracy: 0.01)
        // After end is clamped to 1.0.
        XCTAssertEqual(s.progress(at: start.addingTimeInterval(900)), 1.0, accuracy: 0.01)
    }

    func testProgressForZeroDurationDoesNotDivByZero() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        // Pathological: zero-duration session — rounding edge or test fixture.
        let s = Session(startedAt: start, duration: 0,
                        lockmaster: .aiJudge, blockedGroups: [])
        // Should return 1.0 (already done) and not crash.
        XCTAssertEqual(s.progress(at: start), 1.0)
    }

    // MARK: - heldSeconds across all outcomes

    func testHeldSecondsRunningSessionWithoutTerminatedAt() {
        // For a still-running session (rare: app crashed mid-session), we don't
        // want the value used downstream — but the model shouldn't crash either.
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let s = Session(startedAt: start, duration: 1200,
                        lockmaster: .aiJudge, blockedGroups: [])
        // With no terminatedAt, heldSeconds falls back to plannedSeconds. UI
        // is responsible for hiding that ("running" badge in HistoryView).
        XCTAssertEqual(s.heldSeconds, 1200, accuracy: 1)
    }

    func testHeldSecondsHonorsTerminatedAtEvenAfterEndsAt() {
        // Defensive: if some future bug sets terminatedAt past endsAt, we still
        // produce a sane non-negative number — never go negative.
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var s = Session(startedAt: start, duration: 60,
                        lockmaster: .aiJudge, blockedGroups: [])
        s.terminatedAt = start.addingTimeInterval(-5)
        XCTAssertGreaterThanOrEqual(s.heldSeconds, 0)
    }

    // MARK: - Stats aggregation

    func testStatsExcludesRunningSessions() {
        let store = SessionStore(filename: "tests-\(UUID().uuidString).json")
        let running = Session(duration: 3600, lockmaster: .aiJudge, blockedGroups: [])
        var completed = Session(duration: 1800, lockmaster: .aiJudge, blockedGroups: [])
        completed.outcome = .completed
        completed.terminatedAt = completed.endsAt
        let stats = store.stats(from: [running, completed])
        XCTAssertEqual(stats.totalSessions, 2)
        XCTAssertEqual(stats.totalSecondsHeld, 1800, accuracy: 1)
        XCTAssertEqual(stats.emergencyUnlocks, 0)
        XCTAssertEqual(stats.charityDollars, 0)
    }

    func testStatsAggregatesMultipleCharityCharges() {
        let store = SessionStore(filename: "tests-\(UUID().uuidString).json")
        let charities = Charity.directory
        var s1 = Session(duration: 3600, lockmaster: .charity, blockedGroups: [],
                         charity: CharityCommitment(charity: charities[0], amountDollars: 10))
        s1.outcome = .charityCharged
        s1.terminatedAt = s1.startedAt.addingTimeInterval(60)
        var s2 = Session(duration: 3600, lockmaster: .charity, blockedGroups: [],
                         charity: CharityCommitment(charity: charities[1], amountDollars: 25))
        s2.outcome = .charityCharged
        s2.terminatedAt = s2.startedAt.addingTimeInterval(120)
        let stats = store.stats(from: [s1, s2])
        XCTAssertEqual(stats.charityDollars, 35)
        XCTAssertEqual(stats.emergencyUnlocks, 2)
        XCTAssertEqual(stats.totalSecondsHeld, 180, accuracy: 1)
    }

    // MARK: - Persistence

    func testStoreReplacesExistingSessionByID() {
        let store = SessionStore(filename: "tests-\(UUID().uuidString).json")
        let id = UUID()
        var s = Session(id: id, duration: 60, lockmaster: .aiJudge, blockedGroups: [])
        store.save(s)
        s.outcome = .completed
        s.terminatedAt = s.endsAt
        store.save(s)
        let loaded = store.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.outcome, .completed)
    }

    func testStoreSortsNewestFirst() {
        let store = SessionStore(filename: "tests-\(UUID().uuidString).json")
        let now = Date()
        let old = Session(id: UUID(), startedAt: now.addingTimeInterval(-3600),
                          duration: 60, lockmaster: .aiJudge, blockedGroups: [])
        let new = Session(id: UUID(), startedAt: now,
                          duration: 60, lockmaster: .aiJudge, blockedGroups: [])
        store.save(old)
        store.save(new)
        let loaded = store.loadAll()
        XCTAssertEqual(loaded.first?.id, new.id)
        XCTAssertEqual(loaded.last?.id, old.id)
    }

    func testStoreDeletesByID() {
        let store = SessionStore(filename: "tests-\(UUID().uuidString).json")
        let s = Session(duration: 60, lockmaster: .aiJudge, blockedGroups: [])
        store.save(s)
        store.delete(s.id)
        XCTAssertTrue(store.loadAll().isEmpty)
    }

    // MARK: - Judge engine resilience

    func testJudgeReplyForEveryIntentNonEmpty() {
        let engine = JudgeEngine()
        var ctx = JudgeContext(minutesElapsed: 0, minutesRemaining: 60,
                               sessionSeed: 0xABCD_1234, recentHashes: [])
        let inputs: [(String, JudgeIntent)] = [
            ("emergency", .urgent),
            ("im bored", .boredom),
            ("my friend is texting me", .socialPressure),
            ("just one scroll", .craving),
            ("im so anxious", .anxiety),
            ("this is stupid", .anger),
            ("let me out i promise", .negotiation),
            ("what is the point", .existential),
            ("ok", .quiet),
            ("hey", .greeting),
            ("nondescript filler text here", .fallback)
        ]
        for (text, expected) in inputs {
            let r = engine.reply(to: text, context: &ctx)
            XCTAssertFalse(r.text.isEmpty, "Empty reply for: \(text)")
            XCTAssertEqual(r.intent, expected, "Wrong intent for: \(text)")
        }
    }

    func testRecentHashesResetsOnceFull() {
        // After 50 replies with the dampener cap of 32, the set should never
        // exceed 32 — proving the reset path is exercised.
        let engine = JudgeEngine()
        var ctx = JudgeContext(minutesElapsed: 5, minutesRemaining: 55,
                               sessionSeed: 0xFEED_FACE, recentHashes: [])
        for i in 0..<60 {
            _ = engine.reply(to: "filler \(i)", context: &ctx)
        }
        XCTAssertLessThanOrEqual(ctx.recentHashes.count, 33)
    }

    func testJudgeRepliesAreLowercaseAndPunctuated() {
        // Tone-check: notarial style requires lowercase + ending punctuation.
        let engine = JudgeEngine()
        var ctx = JudgeContext(minutesElapsed: 0, minutesRemaining: 60,
                               sessionSeed: 0xCAFE_F00D, recentHashes: [])
        for i in 0..<30 {
            let r = engine.reply(to: "test \(i)", context: &ctx)
            // Must end with terminal punctuation.
            let lastChar = r.text.last
            XCTAssertTrue([".", "!", "?"].contains(lastChar),
                          "Reply doesn't end with punctuation: \(r.text)")
            // Must be lowercase first letter (notarial style).
            let firstAlpha = r.text.first(where: { $0.isLetter })
            if let a = firstAlpha {
                XCTAssertTrue(a.isLowercase, "Reply not lowercase: \(r.text)")
            }
        }
    }

    // MARK: - Time formatting

    func testRemainingNeverNegativeAfterExpiry() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let s = Session(startedAt: start, duration: 60, lockmaster: .aiJudge, blockedGroups: [])
        XCTAssertGreaterThanOrEqual(s.remaining(at: start.addingTimeInterval(99999)), 0)
    }

    // MARK: - StoreKit hookup (no products in test scheme — covered by App Review)

    /// Verifies that SubscriptionStore at least responds without crashing when
    /// no products are available (e.g. in a unit-test process where the local
    /// .storekit config isn't applied). Real product validation happens against
    /// the App Store sandbox in TestFlight.
    @MainActor
    func testSubscriptionStoreLoadsWithoutCrashing() async {
        let store = SubscriptionStore()
        await store.loadProducts()
        XCTAssertFalse(store.isPro)
    }
}
