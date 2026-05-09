import Foundation
import Combine

/// Abstracts Family Controls / Screen Time so the rest of the app stays the
/// same on simulator (where shielding apps isn't truly possible) and on
/// device (where it is, with entitlement).
protocol Blocker {
    /// Called when user grants app-blocking authorization. Returns true if
    /// authorization is now active.
    func requestAuthorization() async -> Bool

    /// Begin shielding the selected groups. On simulator this just stores
    /// state for the in-app takeover demo.
    func startBlocking(_ groups: [BlockedAppGroup])

    /// Stop shielding everything. Idempotent.
    func stopBlocking()

    /// True while blocking is active. Published so UI can react.
    var isBlocking: Bool { get }
    /// Current shielded groups (used by the in-app takeover demo).
    var activeGroups: [BlockedAppGroup] { get }
}

/// Default blocker for simulator + initial App Store build. When you wire in
/// real ManagedSettings + DeviceActivity, conform to `Blocker` and swap.
final class StubBlocker: ObservableObject, Blocker {
    @Published private(set) var isBlocking: Bool = false
    @Published private(set) var activeGroups: [BlockedAppGroup] = []

    func requestAuthorization() async -> Bool { true }

    func startBlocking(_ groups: [BlockedAppGroup]) {
        activeGroups = groups.filter { $0.enabled }
        isBlocking = true
    }

    func stopBlocking() {
        isBlocking = false
        activeGroups = []
    }
}
