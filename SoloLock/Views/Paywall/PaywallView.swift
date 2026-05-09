import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var subs: SubscriptionStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedID: String = SubscriptionStore.yearlyID
    @State private var purchasing = false
    @State private var open = false

    var body: some View {
        ZStack {
            Palette.vault.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 22) {
                    header
                    glyph
                    bullets
                    plans
                    cta
                    footer
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
        }
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Palette.textTertiary)
            }
            Spacer()
        }
        .padding(.top, 12)
    }

    private var glyph: some View {
        VStack(spacing: 16) {
            LockGlyph(size: 96, locked: !open)
                .onAppear {
                    withAnimation(.spring(response: 0.7, dampingFraction: 0.65).delay(0.2)) {
                        open = true
                    }
                }
            Text("solo lock pro")
                .font(Typography.sectra(28))
                .foregroundColor(Palette.cream)
            Text("the lock holds longer. the key feels heavier.")
                .font(Typography.sohne(14))
                .foregroundColor(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
    }

    private var bullets: some View {
        VaultCard {
            VStack(alignment: .leading, spacing: 12) {
                BulletRow(text: "all four lockmaster types")
                BulletRow(text: "unlimited sessions per day")
                BulletRow(text: "4h, 8h, overnight durations")
                BulletRow(text: "live activity + apple watch")
                BulletRow(text: "history insights")
            }
        }
    }

    private var plans: some View {
        VStack(spacing: 10) {
            if subs.products.isEmpty {
                // StoreKit hasn't loaded yet (or is offline). Show static
                // fallbacks so the paywall always renders the offering and
                // App Review screenshots aren't blank "loading…" placeholders.
                FallbackPlanRow(id: SubscriptionStore.monthlyID,
                                title: "Pro Monthly", subtitle: "All Pro features.",
                                price: "$4.99", badge: nil,
                                selected: selectedID == SubscriptionStore.monthlyID)
                    .onTapGesture { Haptics.tap(); selectedID = SubscriptionStore.monthlyID }
                FallbackPlanRow(id: SubscriptionStore.yearlyID,
                                title: "Pro Yearly", subtitle: "Billed annually. ~58% savings.",
                                price: "$24.99", badge: "BEST VALUE",
                                selected: selectedID == SubscriptionStore.yearlyID)
                    .onTapGesture { Haptics.tap(); selectedID = SubscriptionStore.yearlyID }
                FallbackPlanRow(id: SubscriptionStore.lifetimeID,
                                title: "Lifetime", subtitle: "One-time purchase.",
                                price: "$59", badge: nil,
                                selected: selectedID == SubscriptionStore.lifetimeID)
                    .onTapGesture { Haptics.tap(); selectedID = SubscriptionStore.lifetimeID }
                if let err = subs.loadError {
                    Text(err)
                        .font(Typography.sohne(11))
                        .foregroundColor(Palette.textTertiary)
                }
            } else {
                ForEach(subs.products, id: \.id) { p in
                    PlanRow(
                        product: p,
                        selected: selectedID == p.id,
                        isYearly: p.id == SubscriptionStore.yearlyID
                    )
                    .onTapGesture {
                        Haptics.tap()
                        selectedID = p.id
                    }
                }
            }
        }
    }

    private var cta: some View {
        VStack(spacing: 8) {
            Button {
                purchaseSelected()
            } label: {
                HStack {
                    if purchasing { ProgressView().tint(Palette.vaultDeep) }
                    Text(ctaTitle)
                }
            }
            .buttonStyle(BrassButtonStyle())
            .disabled(purchasing)
            Button("restore purchases") { Task { await subs.restore() } }
                .buttonStyle(GhostButtonStyle())
        }
    }

    private var ctaTitle: String {
        selectedID == SubscriptionStore.lifetimeID ? "buy lifetime" : "subscribe"
    }

    private var footer: some View {
        Text("100% of charity-lock fees go to the charity. solo lock takes 0%.")
            .font(Typography.sohne(11))
            .foregroundColor(Palette.textTertiary)
            .multilineTextAlignment(.center)
            .padding(.top, 4)
    }

    private func purchaseSelected() {
        guard let product = subs.products.first(where: { $0.id == selectedID }) else { return }
        purchasing = true
        Task {
            defer { purchasing = false }
            try? await subs.purchase(product)
            if subs.isPro { dismiss() }
        }
    }
}

private struct BulletRow: View {
    let text: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(Palette.brass)
            Text(text)
                .font(Typography.sohne(15))
                .foregroundColor(Palette.cream)
            Spacer()
        }
    }
}

/// Same layout as PlanRow but driven by hard-coded values (used while
/// StoreKit hasn't returned products yet, or when the device is offline).
private struct FallbackPlanRow: View {
    let id: String
    let title: String
    let subtitle: String
    let price: String
    let badge: String?
    let selected: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(selected ? Palette.brass : Palette.hairline, lineWidth: 1.5)
                    .frame(width: 22, height: 22)
                if selected {
                    Circle().fill(Palette.brass).frame(width: 12, height: 12)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(Typography.sohne(15, weight: .semibold))
                        .foregroundColor(Palette.cream)
                    if let badge {
                        Text(badge)
                            .font(Typography.sohne(9, weight: .bold))
                            .tracking(1.2)
                            .foregroundColor(Palette.vaultDeep)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 4).fill(Palette.brass))
                    }
                }
                Text(subtitle)
                    .font(Typography.sohne(12))
                    .foregroundColor(Palette.textSecondary)
            }
            Spacer()
            Text(price)
                .font(Typography.plexMono(15, weight: .medium))
                .foregroundColor(Palette.cream)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Palette.vaultDeep)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(selected ? Palette.brass : Palette.hairline,
                                lineWidth: selected ? 1.5 : 1)
                )
        )
        .accessibilityIdentifier("plan.\(id)")
    }
}

private struct PlanRow: View {
    let product: Product
    let selected: Bool
    let isYearly: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(selected ? Palette.brass : Palette.hairline, lineWidth: 1.5)
                    .frame(width: 22, height: 22)
                if selected {
                    Circle().fill(Palette.brass).frame(width: 12, height: 12)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(product.displayName)
                        .font(Typography.sohne(15, weight: .semibold))
                        .foregroundColor(Palette.cream)
                    if isYearly {
                        Text("BEST VALUE")
                            .font(Typography.sohne(9, weight: .bold))
                            .tracking(1.2)
                            .foregroundColor(Palette.vaultDeep)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 4).fill(Palette.brass))
                    }
                }
                Text(product.description)
                    .font(Typography.sohne(12))
                    .foregroundColor(Palette.textSecondary)
            }
            Spacer()
            Text(product.displayPrice)
                .font(Typography.plexMono(15, weight: .medium))
                .foregroundColor(Palette.cream)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Palette.vaultDeep)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(selected ? Palette.brass : Palette.hairline, lineWidth: selected ? 1.5 : 1)
                )
        )
    }
}
