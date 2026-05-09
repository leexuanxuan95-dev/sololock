import Foundation

/// A single focus session — its plan, runtime state, and post-mortem.
struct Session: Codable, Identifiable, Hashable {
    var id: UUID
    var startedAt: Date
    var endsAt: Date
    /// Wall-clock moment the session actually ended (early break or natural end).
    /// Nil while the session is still running.
    var terminatedAt: Date?
    var lockmaster: Lockmaster
    var blockedGroups: [BlockedAppGroup]
    var charity: CharityCommitment?
    var outcome: Outcome
    /// What the user typed during an emergency unlock attempt — kept private.
    var emergencyReason: String?
    /// AI Judge transcript: every challenge + reply produced during this session.
    var judgeTranscript: [ChatMessage]

    enum Outcome: String, Codable, Hashable {
        case running
        case completed
        case emergencyUnlock
        case charityCharged
        case abandoned
    }

    init(id: UUID = UUID(),
         startedAt: Date = Date(),
         duration: TimeInterval,
         lockmaster: Lockmaster,
         blockedGroups: [BlockedAppGroup],
         charity: CharityCommitment? = nil,
         outcome: Outcome = .running,
         emergencyReason: String? = nil,
         terminatedAt: Date? = nil,
         judgeTranscript: [ChatMessage] = []) {
        self.id = id
        self.startedAt = startedAt
        self.endsAt = startedAt.addingTimeInterval(duration)
        self.terminatedAt = terminatedAt
        self.lockmaster = lockmaster
        self.blockedGroups = blockedGroups
        self.charity = charity
        self.outcome = outcome
        self.emergencyReason = emergencyReason
        self.judgeTranscript = judgeTranscript
    }

    /// Seconds the user actually held the lock (start to natural end or early break).
    var heldSeconds: TimeInterval {
        let end = terminatedAt ?? endsAt
        return max(0, end.timeIntervalSince(startedAt))
    }

    /// Planned duration in seconds.
    var plannedSeconds: TimeInterval { endsAt.timeIntervalSince(startedAt) }

    /// Seconds remaining at `now`. Clamped to >= 0.
    func remaining(at now: Date = Date()) -> TimeInterval {
        max(0, endsAt.timeIntervalSince(now))
    }

    /// 0…1 progress at `now`.
    func progress(at now: Date = Date()) -> Double {
        let total = plannedSeconds
        guard total > 0 else { return 1 }
        return min(1, max(0, 1 - (remaining(at: now) / total)))
    }

    var isFinished: Bool {
        switch outcome {
        case .running: return false
        default: return true
        }
    }
}
