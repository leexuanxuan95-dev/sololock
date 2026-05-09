import Foundation

/// User preferences that persist across launches. Backed by UserDefaults
/// because everything here is small and rarely changing.
final class Preferences: ObservableObject {
    @Published var hasSeenOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasSeenOnboarding, forKey: K.onboarding) }
    }
    @Published var preferredLockmaster: Lockmaster {
        didSet { UserDefaults.standard.set(preferredLockmaster.rawValue, forKey: K.lockmaster) }
    }

    private enum K {
        static let onboarding = "sololock.onboarding"
        static let lockmaster = "sololock.lockmaster"
    }

    init() {
        self.hasSeenOnboarding = UserDefaults.standard.bool(forKey: K.onboarding)
        if let raw = UserDefaults.standard.string(forKey: K.lockmaster),
           let lm = Lockmaster(rawValue: raw) {
            self.preferredLockmaster = lm
        } else {
            self.preferredLockmaster = .aiJudge
        }
    }
}
