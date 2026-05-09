import SwiftUI

/// Branches by lockmaster:
///   AI Judge → flat refusal screen.
///   Random Delay → 15m wait + 50-word reason.
///   Charity → confirm $ donation.
///   Friend → same as random delay (legacy v1).
struct EmergencyUnlockView: View {
    @EnvironmentObject var session: SessionEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Palette.vault.ignoresSafeArea()
            VStack(spacing: 24) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Palette.textTertiary)
                    }
                    Spacer()
                    Text("emergency unlock")
                        .font(Typography.sohne(13, weight: .semibold))
                        .tracking(1.4)
                        .foregroundColor(Palette.sosRed)
                    Spacer()
                    Color.clear.frame(width: 24, height: 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                content
                    .padding(.horizontal, 24)
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch session.current?.lockmaster ?? .aiJudge {
        case .aiJudge:
            judgeRefusal
        case .randomDelay, .friend:
            RandomDelayFlow(onConfirm: { reason in
                session.confirmRandomDelayUnlock(reason: reason)
                dismiss()
            }, onCancel: { dismiss() })
        case .charity:
            CharityConfirmFlow(
                amount: session.current?.charity?.amountDollars ?? 5,
                charityName: session.current?.charity?.charity.name ?? "",
                onConfirm: {
                    session.confirmCharityUnlock()
                    dismiss()
                },
                onCancel: { dismiss() }
            )
        }
    }

    private var judgeRefusal: some View {
        VStack(spacing: 18) {
            Image(systemName: "scale.3d")
                .font(.system(size: 48))
                .foregroundColor(Palette.brass)
            Text("the judge does not negotiate.")
                .font(Typography.sectra(22))
                .foregroundColor(Palette.cream)
                .multilineTextAlignment(.center)
            Text("you picked the lockmaster that holds, no exceptions. the timer keeps the time.")
                .font(Typography.sohne(15))
                .foregroundColor(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
            Button("understood") { dismiss() }
                .buttonStyle(BrassButtonStyle(prominent: false))
                .padding(.top, 8)
        }
        .padding(.top, 24)
    }
}

// MARK: - Random Delay flow

private struct RandomDelayFlow: View {
    var onConfirm: (String) -> Void
    var onCancel: () -> Void

    @State private var endsAt = Date().addingTimeInterval(15 * 60)
    @State private var now = Date()
    @State private var reason = ""
    @State private var ticker: Timer?

    private var remaining: TimeInterval { max(0, endsAt.timeIntervalSince(now)) }
    private var canSubmit: Bool {
        wordCount(reason) >= 50 && remaining <= 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("wait fifteen minutes.")
                .font(Typography.sectra(22))
                .foregroundColor(Palette.cream)
            Text(remaining > 0 ? formatted(remaining) : "ready. write fifty words.")
                .font(Typography.plexMono(28, weight: .medium))
                .foregroundColor(remaining > 0 ? Palette.brass : Palette.openGreen)

            ProgressView(value: 1 - remaining / (15 * 60))
                .tint(Palette.brass)

            VaultCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("reason for unlock")
                        .font(Typography.sohne(12, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(Palette.brass)
                    TextEditor(text: $reason)
                        .font(Typography.sohne(15))
                        .foregroundColor(Palette.cream)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 140)
                    HStack {
                        Text("\(wordCount(reason)) / 50 words")
                            .font(Typography.sohne(12))
                            .foregroundColor(wordCount(reason) >= 50 ? Palette.openGreen : Palette.textSecondary)
                        Spacer()
                    }
                }
            }

            Spacer(minLength: 8)

            Button {
                onConfirm(reason)
            } label: {
                Text(canSubmit ? "unlock now" : "not yet")
            }
            .buttonStyle(BrassButtonStyle())
            .disabled(!canSubmit)
            .opacity(canSubmit ? 1 : 0.5)

            Button("cancel and re-lock") { onCancel() }
                .buttonStyle(GhostButtonStyle())
                .frame(maxWidth: .infinity)
        }
        .onAppear {
            ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                now = Date()
            }
        }
        .onDisappear { ticker?.invalidate(); ticker = nil }
    }

    private func formatted(_ s: TimeInterval) -> String {
        let total = Int(s)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private func wordCount(_ s: String) -> Int {
        s.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .filter { !$0.isEmpty }
            .count
    }
}

// MARK: - Charity confirm

private struct CharityConfirmFlow: View {
    let amount: Int
    let charityName: String
    var onConfirm: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("break early?")
                .font(Typography.sectra(22))
                .foregroundColor(Palette.cream)

            VaultCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("you'll be charged")
                        .font(Typography.sohne(12, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(Palette.brass)
                    Text("$\(amount)")
                        .font(Typography.plexMono(40, weight: .medium))
                        .foregroundColor(Palette.cream)
                    Text("100% goes to \(charityName).")
                        .font(Typography.sohne(13))
                        .foregroundColor(Palette.textSecondary)
                    Text("we keep $0.")
                        .font(Typography.sohne(13))
                        .foregroundColor(Palette.openGreen)
                }
            }

            Spacer(minLength: 4)

            Button("confirm donation and unlock") { onConfirm() }
                .buttonStyle(BrassButtonStyle())

            Button("cancel — keep the lock") { onCancel() }
                .buttonStyle(GhostButtonStyle())
                .frame(maxWidth: .infinity)
        }
    }
}
