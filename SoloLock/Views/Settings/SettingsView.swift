import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var subs: SubscriptionStore
    @EnvironmentObject var prefs: Preferences
    @State private var showPaywall = false

    var body: some View {
        ZStack {
            VaultBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    SectionLabel(text: "subscription")
                    proCard

                    SectionLabel(text: "about")
                    aboutCard

                    SectionLabel(text: "reset")
                    resetCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .presentationBackground(Palette.vault)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("settings")
                .font(Typography.sectra(32))
                .foregroundColor(Palette.cream)
        }
        .padding(.top, 32)
    }

    private var proCard: some View {
        VaultCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(subs.isPro ? "Solo Lock Pro" : "Free Tier")
                        .font(Typography.sectra(20))
                        .foregroundColor(Palette.cream)
                    Spacer()
                    if subs.isPro {
                        Text("ACTIVE")
                            .font(Typography.sohne(10, weight: .bold))
                            .tracking(1.4)
                            .foregroundColor(Palette.openGreen)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 4).stroke(Palette.openGreen))
                    }
                }
                Text(subs.isPro
                     ? "all lockmasters, unlimited sessions, 4h+ durations."
                     : "free tier: 1 session/day, max 1h, AI judge only.")
                    .font(Typography.sohne(13))
                    .foregroundColor(Palette.textSecondary)
                if !subs.isPro {
                    Button("see plans") { showPaywall = true }
                        .buttonStyle(BrassButtonStyle(prominent: false))
                        .padding(.top, 4)
                }
                Button("restore purchases") {
                    Task { await subs.restore() }
                }
                .buttonStyle(GhostButtonStyle())
            }
        }
    }

    private var aboutCard: some View {
        VaultCard {
            VStack(alignment: .leading, spacing: 12) {
                row("version", value: "1.0.0")
                Divider().background(Palette.hairline)
                row("anti-features", value: "no streaks, no shame, no social.")
                Divider().background(Palette.hairline)
                row("AI judge", value: "100% on-device. no cloud.")
            }
        }
    }

    private var resetCard: some View {
        VaultCard {
            Button {
                prefs.hasSeenOnboarding = false
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("replay onboarding")
                    Spacer()
                }
                .foregroundColor(Palette.cream)
                .font(Typography.sohne(15))
            }
        }
    }

    private func row(_ label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label.uppercased())
                .font(Typography.sohne(11, weight: .semibold))
                .tracking(1.4)
                .foregroundColor(Palette.brass)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(Typography.sohne(14))
                .foregroundColor(Palette.cream)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
