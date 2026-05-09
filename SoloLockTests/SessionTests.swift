import XCTest
@testable import SoloLock

final class SessionTests: XCTestCase {

    func testHeldSecondsForCompletedSession() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var s = Session(startedAt: start, duration: 3600,
                        lockmaster: .aiJudge, blockedGroups: [])
        s.outcome = .completed
        s.terminatedAt = s.endsAt
        XCTAssertEqual(s.heldSeconds, 3600, accuracy: 1)
    }

    func testHeldSecondsForEarlyBreak() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var s = Session(startedAt: start, duration: 3600,
                        lockmaster: .charity, blockedGroups: [])
        s.outcome = .charityCharged
        s.terminatedAt = start.addingTimeInterval(900) // broke at 15m
        XCTAssertEqual(s.heldSeconds, 900, accuracy: 1)
    }

    func testProgressMonotonic() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let s = Session(startedAt: start, duration: 600,
                        lockmaster: .aiJudge, blockedGroups: [])
        let p0 = s.progress(at: start)
        let p1 = s.progress(at: start.addingTimeInterval(300))
        let p2 = s.progress(at: start.addingTimeInterval(600))
        XCTAssertEqual(p0, 0, accuracy: 0.01)
        XCTAssertEqual(p1, 0.5, accuracy: 0.01)
        XCTAssertEqual(p2, 1.0, accuracy: 0.01)
    }

    func testRemainingClampedToZero() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let s = Session(startedAt: start, duration: 60,
                        lockmaster: .aiJudge, blockedGroups: [])
        XCTAssertEqual(s.remaining(at: start.addingTimeInterval(120)), 0)
    }

    func testStoreRoundTrip() {
        let store = SessionStore(filename: "tests-\(UUID().uuidString).json")
        let s = Session(duration: 60, lockmaster: .aiJudge, blockedGroups: [])
        store.save(s)
        let loaded = store.loadAll()
        XCTAssertEqual(loaded.first?.id, s.id)
    }

    func testStatsAggregation() {
        let store = SessionStore(filename: "tests-\(UUID().uuidString).json")
        var completed = Session(duration: 60, lockmaster: .aiJudge, blockedGroups: [])
        completed.outcome = .completed
        completed.terminatedAt = completed.endsAt

        var charged = Session(duration: 3600, lockmaster: .charity, blockedGroups: [],
                              charity: CharityCommitment(charity: Charity.directory[0], amountDollars: 5))
        charged.outcome = .charityCharged
        charged.terminatedAt = charged.startedAt.addingTimeInterval(1800)

        let stats = store.stats(from: [completed, charged])
        XCTAssertEqual(stats.totalSessions, 2)
        XCTAssertEqual(stats.charityDollars, 5)
        XCTAssertEqual(stats.emergencyUnlocks, 1)
        XCTAssertEqual(stats.totalSecondsHeld, 60 + 1800, accuracy: 1)
    }
}
