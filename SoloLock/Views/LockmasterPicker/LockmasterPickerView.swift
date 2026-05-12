import SwiftUI

struct LockmasterPickerView: View {
    @EnvironmentObject var prefs: Preferences
    @EnvironmentObject var subs: SubscriptionStore
    @State private var explainer: Lockmaster?
    @State private var goToSetup: Lockmaster?

    var body: some View {
        ZStack {
            VaultBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    ForEach(Lockmaster.allCases.filter { $0.availableInV1 }) { lm in
                        Button {
                            Haptics.tap()
                            explainer = lm
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
