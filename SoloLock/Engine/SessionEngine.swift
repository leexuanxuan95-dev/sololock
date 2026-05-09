import Foundation
import Combine

/// Drives a running session: countdown, judge transcript, emergency flow,
/// completion. Owned by the app for the lifetime of the process; the
/// active session lives in `current`. UI observes via @Published.
@MainActor
final class SessionEngine: ObservableObject {

    // MARK: - Public state

    @Published private(set) var current: Session?
    @Published private(set) var now: Date = Date()
    @Published var isLockedTakeoverShowing: Bool = false
    @Published var emergencyUnlockState: EmergencyState = .idle

    enum EmergencyState: Equatable {
        case idle
        /// Random Delay: timestamp at which the 15m wait completes.
        case waiting(until: Date, reason: String)
        case readyToWrite(reason: String)
        case charityConfirming
    }

    // MARK: - Dependencies

    let store: SessionStore
    let blocker: Blocker
    let judge: JudgeEngine
    private var judgeContext: JudgeContext = .init(
        minutesElapsed: 0, minutesRemaining: 0, sessionSeed: 0, recentHashes: [])

    private var timerCancellable: AnyCancellable?

    init(store: SessionStore = SessionStore(),
         blocker: Blocker = StubBlocker(),
         judge: JudgeEngine = JudgeEngine()) {
        self.store = store
        self.blocker = blocker
        self.judge = judge
        self.timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                // Timer fires on main runloop, but the closure isn't statically
                // @MainActor-isolated. This makes that explicit so strict
                // concurrency stays happy in future Swift versions.
                MainActor.assumeIsolated { self?.tick() }
            }
    }

    // MARK: - Lifecycle

    /// Begin a brand-new session from a setup form.
    func start(duration: TimeInterval,
               lockmaster: Lockmaster,
               groups: [BlockedAppGroup],
               charity: CharityCommitment?) {
        var session = Session(
            duration: duration,
            lockmaster: lockmaster,
            blockedGroups: groups.filter { $0.enabled },
            charity: charity
        )
        // Seed the judge's "voice" off the session id so each session sounds
        // a touch different even given the same user input.
        let seed = session.id.uuidString.unicodeScalars.reduce(UInt64(0xCBF29CE484222325)) { acc, u in
            (acc ^ UInt64(u.value)) &* 0x100000001B3
        }
        judgeContext = JudgeContext(
            minutesElapsed: 0,
            minutesRemaining: Int(duration / 60),
            sessionSeed: seed,
            recentHashes: []
        )

        // Opening message from judge so the chat starts populated.
        if lockmaster == .aiJudge {
            let opening = judge.openingMessage(seed: seed, plannedMinutes: Int(duration / 60))
            session.judgeTranscript.append(opening)
        }

        blocker.startBlocking(session.blockedGroups)
        current = session
        store.save(session)
        Haptics.lockShut()
    }

    /// Tick the clock and finalize when the timer expires.
    private func tick() {
        now = Date()
        guard var s = current, !s.isFinished else { return }
        if s.remaining(at: now) <= 0 {
            s.outcome = .completed
            s.terminatedAt = s.endsAt
            blocker.stopBlocking()
            store.save(s)
            current = s
            Haptics.lockOpen()
        } else {
            // Update judge context's clock so phase lines stay current.
            judgeContext.minutesElapsed = Int(s.startedAt.distance(to: now) / 60)
            judgeContext.minutesRemaining = Int(s.remaining(at: now) / 60)
        }
    }

    /// Clear the post-session screen and return user to picker.
    func dismissCompletedSession() {
        current = nil
    }

    // MARK: - Judge chat

    /// Append a user message and produce a judge reply, persisting both.
    func sendUserMessage(_ text: String) {
        guard var s = current, s.lockmaster == .aiJudge, !s.isFinished else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let userMsg = ChatMessage(role: .user, text: trimmed)
        s.judgeTranscript.append(userMsg)

        let reply = judge.reply(to: trimmed, context: &judgeContext)
        s.judgeTranscript.append(ChatMessage(role: .judge, text: reply.text))
        current = s
        store.save(s)
    }

    // MARK: - Emergency unlock

    /// Begin the emergency unlock flow. Behavior varies by lockmaster.
    func beginEmergencyUnlock() {
        guard let s = current, !s.isFinished else { return }
        Haptics.emergency()
        switch s.lockmaster {
        case .aiJudge:
            // No early unlock — surface a refusal but stay locked.
            sendUserMessage("emergency unlock attempt")
        case .randomDelay:
            emergencyUnlockState = .waiting(
                until: Date().addingTimeInterval(15 * 60),
                reason: ""
            )
        case .charity:
            emergencyUnlockState = .charityConfirming
        case .friend:
            // Friend mode is legacy — treat like random delay for v1.
            emergencyUnlockState = .waiting(
                until: Date().addingTimeInterval(15 * 60),
                reason: ""
            )
        }
    }

    /// Once 15m has elapsed and the user has typed >=50 words, finalize the
    /// random-delay unlock.
    func confirmRandomDelayUnlock(reason: String) {
        guard var s = current, !s.isFinished else { return }
        s.emergencyReason = reason
        s.outcome = .emergencyUnlock
        s.terminatedAt = Date()
        blocker.stopBlocking()
        store.save(s)
        current = s
        emergencyUnlockState = .idle
        Haptics.lockOpen()
    }

    /// Confirm charity charge (in real app this would call StoreKit / Stripe).
    func confirmCharityUnlock() {
        guard var s = current, !s.isFinished else { return }
        s.outcome = .charityCharged
        s.terminatedAt = Date()
        blocker.stopBlocking()
        store.save(s)
        current = s
        emergencyUnlockState = .idle
        Haptics.lockOpen()
    }

    func cancelEmergencyUnlock() {
        emergencyUnlockState = .idle
    }
}
