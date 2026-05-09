import SwiftUI

@main
struct SoloLockApp: App {
    @StateObject private var prefs = Preferences()
    @StateObject private var session = SessionEngine()
    @StateObject private var subs = SubscriptionStore()

    init() {
        // Force dark cosmetics for the vault aesthetic — UI.md is dark-only.
        UINavigationBar.appearance().tintColor = UIColor(named: "brass")
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
