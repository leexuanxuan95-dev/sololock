import SwiftUI

struct SessionSetupView: View {
    let lockmaster: Lockmaster

    @EnvironmentObject var session: SessionEngine
    @EnvironmentObject var subs: SubscriptionStore
    @Environment(\.dismiss) private var dismiss

    @State private var duration: SessionDuration = .h1
    @State private var groups: [BlockedAppGroup] = BlockedAppGroup.presets
    @State private var charity: Charity = Charity.directory[0]
    @State private var charityAmount: Int = 5
    @State private var showPaywall = false

    var body: some View {
        ZStack {
            VaultBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header

                    SectionLabel(text: "session length")
                    durationGrid

                    SectionLabel(text: "intent: apps to avoid")
                    blockedAppsList
                    Text("These are the apps you commit to avoid this session. In v1 the lockmaster (AI Judge / Random Delay) is the commitment device; full iOS Screen Time shielding ships in v1.1.")
                        .font(Typography.sohne(11))
                        .foregroundColor(Palette.textTertiary)
                        .padding(.horizontal, 4)

                    if lockmaster == .charity {
                        SectionLabel(text: "if you break early")
                        charityPicker
                    }

                    handItOverButton
                        .padding(.top, 12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
                .padding(.top, 8)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        // System back button is fine; hide the tab bar so "hand it over"
        // isn't obscured at the bottom.
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .presentationBackground(Palette.vault)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("set the session")
                .font(Typography.sectra(28))
                .foregroundColor(Palette.cream)
            Text("lockmaster · \(lockmaster.title.lowercased())")
                .font(Typography.sohne(13))
                .foregroundColor(Palette.brass)
        }
        .padding(.top, 12)
    }

    private var durationGrid: some View {
        let cols = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: cols, spacing: 12) {
            ForEach(SessionDuration.allCases) { d in
                Button {
                    Haptics.tap()
                    if d.isPro && !subs.isPro {
                        showPaywall = true
                    } else {
                        duration = d
                    }
                } label: {
                    DurationCell(duration: d, selected: duration == d, locked: d.isPro && !subs.isPro)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("duration.\(d.rawValue)")
            }
        }
    }

    private var blockedAppsList: some View {
        VaultCard {
            VStack(spacing: 0) {
                ForEach($groups) { $g in
                    HStack(spacing: 14) {
                        Image(systemName: g.symbol)
                            .frame(width: 28)
                            .foregroundColor(g.enabled ? Palette.brass : Palette.textTertiary)
                        Text(g.title)
                            .font(Typography.sohne(16))
                            .foregroundColor(g.enabled ? Palette.cream : Palette.textSecondary)
                        Spacer()
                        Toggle("", isOn: $g.enabled).labelsHidden().tint(Palette.brass)
                    }
                    .padding(.vertical, 10)
                    if g.id != groups.last?.id {
                        Divider().background(Palette.hairline)
                    }
                }
            }
        }
    }

    private var charityPicker: some View {
        VaultCard {
            VStack(alignment: .leading, spacing: 14) {
                Picker("charity", selection: $charity) {
                    ForEach(Charity.directory) { c in
                        Text(c.name).tag(c)
                    }
                }
                .pickerStyle(.menu)
                .tint(Palette.brass)

                Text(charity.blurb)
                    .font(Typography.sohne(13))
                    .foregroundColor(Palette.textSecondary)

                HStack {
                    Text("$\(charityAmount) per failed session")
                        .font(Typography.plexMono(15))
                        .foregroundColor(Palette.cream)
                    Spacer()
                }
                Slider(value: Binding(
                    get: { Double(charityAmount) },
                    set: { charityAmount = Int($0) }
                ), in: 1...25, step: 1)
                .tint(Palette.brass)
                Text("100% goes to the charity. we take 0%.")
                    .font(Typography.sohne(11))
                    .foregroundColor(Palette.textTertiary)
            }
        }
    }

    private var handItOverButton: some View {
        Button {
            Haptics.lockShut()
            let commitment: CharityCommitment? = lockmaster == .charity
                ? CharityCommitment(charity: charity, amountDollars: charityAmount)
                : nil
            session.start(
                duration: duration.seconds,
                lockmaster: lockmaster,
                groups: groups,
                charity: commitment
            )
            dismiss()
        } label: {
            Text("hand it over")
        }
        .buttonStyle(BrassButtonStyle())
        .disabled(!groups.contains(where: { $0.enabled }))
        .opacity(groups.contains(where: { $0.enabled }) ? 1 : 0.5)
        .accessibilityIdentifier("setup.handItOver")
    }
}

private struct DurationCell: View {
    let duration: SessionDuration
    let selected: Bool
    let locked: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text(duration.label)
                .font(Typography.plexMono(17, weight: .medium))
                .foregroundColor(selected ? Palette.vaultDeep : Palette.cream)
            if locked {
                Text("PRO")
                    .font(Typography.sohne(9, weight: .bold))
                    .tracking(1)
                    .foregroundColor(selected ? Palette.vaultDeep : Palette.brass)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(selected ? Palette.brass : Palette.vaultDeep)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Palette.hairline, lineWidth: 1)
                )
        )
        .opacity(locked ? 0.7 : 1)
    }
}
