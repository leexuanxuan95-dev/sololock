import SwiftUI

/// Post-session sheet: lock opens animation, single sentence, today's stats.
struct SessionEndView: View {
    let session: Session
    @EnvironmentObject var engine: SessionEngine
    @Environment(\.dismiss) private var dismiss
    @State private var open = false

    var body: some View {
        ZStack {
            Palette.vault.ignoresSafeArea()
            VStack(spacing: 22) {
                Capsule().fill(Palette.hairline).frame(width: 36, height: 4).padding(.top, 8)

                LockGlyph(size: 110, locked: !open, brass: outcomeColor)
                    .onAppear {
                        withAnimation(.spring(response: 0.7, dampingFraction: 0.6).delay(0.2)) {
                            open = true
                        }
                    }

                Text(headline)
                    .font(Typography.sectra(24, weight: .regular))
                    .foregroundColor(Palette.cream)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                stats

                Spacer(minLength: 8)

                Button("done") {
                    Haptics.tap()
                    engine.dismissCompletedSession()
                    dismiss()
                }
                .buttonStyle(BrassButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }

    private var outcomeColor: Color {
        switch session.outcome {
        case .completed: return Palette.openGreen
        case .charityCharged: return Palette.brass
        case .emergencyUnlock, .abandoned: return Palette.sosRed
        case .running: return Palette.brass
        }
    }

    private var headline: String {
        switch session.outcome {
        case .completed:
            return "you held the line. \(durationText)."
        case .emergencyUnlock:
            return "you broke the lock at \(durationText)."
        case .charityCharged:
            return "donation made. \(durationText) held."
        case .abandoned:
            return "session ended."
        case .running:
            return ""
        }
    }

    private var durationText: String {
        let s = Int(session.heldSeconds)
        let h = s / 3600, m = (s % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    private var stats: some View {
        VaultCard {
            VStack(spacing: 12) {
                StatRow(label: "lockmaster", value: session.lockmaster.title)
                Divider().background(Palette.hairline)
                StatRow(label: "apps blocked", value: "\(session.blockedGroups.count)")
                if let c = session.charity, session.outcome == .charityCharged {
                    Divider().background(Palette.hairline)
                    StatRow(label: "donated", value: "$\(c.amountDollars) → \(c.charity.name)")
                }
            }
        }
        .padding(.horizontal, 24)
    }
}

private struct StatRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label)
                .font(Typography.sohne(12, weight: .semibold))
                .tracking(1)
                .foregroundColor(Palette.brass)
            Spacer()
            Text(value)
                .font(Typography.sohne(15))
                .foregroundColor(Palette.cream)
        }
    }
}
