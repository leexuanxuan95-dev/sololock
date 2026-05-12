import SwiftUI

struct LockmasterPickerView: View {
    @EnvironmentObject var prefs: Preferences
    @EnvironmentObject var subs: SubscriptionStore
    @State private var explainer: Lockmaster?
    @State private var goToSetup: Lockmaster?
    @State private var showPaywall = false

    var body: some View {
        ZStack {
            VaultBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    if !subs.isPro {
                        goProBanner
                    }
                    ForEach(Lockmaster.allCases.filter { $0.availableInV1 }) { lm in
                        Button {
                            Haptics.tap()
                            // Apple Review 2.1(b): IAPs must be discoverable.
                            // Tapping a Pro card while non-Pro routes through
                            // the paywall first, then opens the explainer.
                            if lm.isPro && !subs.isPro {
                                showPaywall = true
                            } else {
                                explainer = lm
                            }
                        } label: {
                            LockmasterCard(lockmaster: lm, isPro: lm.isPro && !subs.isPro)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("picker.\(lm.rawValue)")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .sheet(item: $explainer) { lm in
            LockmasterExplainerSheet(lockmaster: lm) {
                explainer = nil
                goToSetup = lm
            }
            .presentationDetents([.medium, .large])
            .presentationBackground(Palette.vault)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .presentationBackground(Palette.vault)
        }
        .navigationDestination(item: $goToSetup) { lm in
            SessionSetupView(lockmaster: lm)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("solo lock")
                .font(Typography.sectra(36, weight: .regular))
                .foregroundColor(Palette.cream)
            Text("set a goal. lock yourself in. no friend required.")
                .font(Typography.sohne(15))
                .foregroundColor(Palette.textSecondary)
        }
        .padding(.top, 32)
        .padding(.bottom, 8)
    }

    /// Prominent paywall entry point. Apple App Review couldn't locate the
    /// IAPs on submission 2 — making the path explicit on the Home screen
    /// addresses Guideline 2.1(b) "IAPs not found in binary".
    private var goProBanner: some View {
        Button {
            Haptics.tap()
            showPaywall = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .foregroundColor(Palette.vaultDeep)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Go Pro")
                        .font(Typography.sohne(15, weight: .semibold))
                        .foregroundColor(Palette.vaultDeep)
                    Text("see plans — $4.99/mo · $24.99/yr · $59 lifetime")
                        .font(Typography.sohne(12))
                        .foregroundColor(Palette.vaultDeep.opacity(0.7))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(Palette.vaultDeep.opacity(0.6))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Palette.brass)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("picker.goPro")
    }
}

private struct LockmasterCard: View {
    let lockmaster: Lockmaster
    let isPro: Bool

    var body: some View {
        VaultCard {
            HStack(spacing: 16) {
                Image(systemName: lockmaster.glyph)
                    .font(.system(size: 28, weight: .regular))
                    .foregroundColor(Palette.brass)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Palette.vault))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(lockmaster.title)
                            .font(Typography.sectra(20, weight: .regular))
                            .foregroundColor(Palette.cream)
                        if isPro { ProBadge() }
                    }
                    Text(lockmaster.subtitle)
                        .font(Typography.sohne(13))
                        .foregroundColor(Palette.textSecondary)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(Palette.textTertiary)
            }
        }
    }
}

struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(Typography.sohne(10, weight: .bold))
            .tracking(1.4)
            .foregroundColor(Palette.vaultDeep)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 4).fill(Palette.brass))
    }
}

private struct LockmasterExplainerSheet: View {
    let lockmaster: Lockmaster
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            Palette.vault.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Image(systemName: lockmaster.glyph)
                        .font(.system(size: 32))
                        .foregroundColor(Palette.brass)
                    Text(lockmaster.title)
                        .font(Typography.sectra(28))
                        .foregroundColor(Palette.cream)
                    Spacer()
                }
                Text(lockmaster.explainer)
                    .font(Typography.sectra(17, weight: .regular))
                    .foregroundColor(Palette.textPrimary)
                    .lineSpacing(4)

                Spacer()

                Button("continue") { onContinue() }
                    .buttonStyle(BrassButtonStyle())
                    .accessibilityIdentifier("explainer.continue")
            }
            .padding(24)
        }
    }
}
