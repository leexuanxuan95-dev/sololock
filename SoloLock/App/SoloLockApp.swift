import SwiftUI

@main
struct SoloLockApp: App {
    @StateObject private var prefs: Preferences
    @StateObject private var session: SessionEngine
    @StateObject private var subs = SubscriptionStore()

    init() {
        // Force dark cosmetics for the vault aesthetic — UI.md is dark-only.
        UINavigationBar.appearance().tintColor = UIColor(named: "brass")

        // UI-test launch arguments. Wipes app state and skips onboarding so
        // UI tests start at a deterministic location.
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--ui-test-reset") {
            UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
            // Wipe sessions.json
            if let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                try? FileManager.default.removeItem(at: dir.appendingPathComponent("sessions.json"))
            }
        }
        let p = Preferences()
        if args.contains("--ui-test-skip-onboarding") {
            p.hasSeenOnboarding = true
        }
        _prefs = StateObject(wrappedValue: p)
        _session = StateObject(wrappedValue: SessionEngine())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(prefs)
                .environmentObject(session)
                .environmentObject(subs)
                .preferredColorScheme(.dark)
                .task { await subs.loadProducts() }
        }
    }
}
