import SwiftUI

/// Top-level router: onboarding → main app, with the running-session sheet
/// surfacing whenever the engine has a `current` session.
struct RootView: View {
    @EnvironmentObject var prefs: Preferences
    @EnvironmentObject var session: SessionEngine

    var body: some View {
        ZStack {
            VaultBackground()
            if !prefs.hasSeenOnboarding {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        // The lock screen for an active session takes over the whole app.
        .fullScreenCover(item: Binding<Session?>(
            get: { session.current?.outcome == .running ? session.current : nil },
            set: { _ in /* engine owns current */ }
        )) { _ in
            LockView()
                .environmentObject(session)
        }
        // Session-end celebration shows when current session is finished but
        // not yet dismissed.
        .sheet(item: Binding<Session?>(
            get: { (session.current?.isFinished ?? false) ? session.current : nil },
            set: { if $0 == nil { session.dismissCompletedSession() } }
        )) { s in
            SessionEndView(session: s)
                .environmentObject(session)
                .presentationDetents([.medium, .large])
        }
    }
}
