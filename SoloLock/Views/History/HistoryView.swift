import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var engine: SessionEngine
    @State private var sessions: [Session] = []
    @State private var stats: SessionStore.Stats = .init(totalSessions: 0, totalSecondsHeld: 0, charityDollars: 0, emergencyUnlocks: 0)

    var body: some View {
        ZStack {
            VaultBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    statsRow
                    SectionLabel(text: "all sessions")
                    if sessions.isEmpty {
                        emptyState
                    } else {
                        ForEach(sessions) { s in
                            SessionRow(session: s)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .onAppear { reload() }
        // Reload when a session ends so History reflects the latest immediately.
        .onChange(of: engine.current?.outcome) { _, _ in reload() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("history")
                .font(Typography.sectra(32))
                .foregroundColor(Palette.cream)
            Text("no streaks. no shaming. just the record.")
                .font(Typography.sohne(13))
                .foregroundColor(Palette.textSecondary)
        }
        .padding(.top, 32)
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatCard(value: "\(stats.totalSessions)", label: "sessions")
            StatCard(value: heldString(stats.totalSecondsHeld), label: "time held")
            StatCard(value: "$\(stats.charityDollars)", label: "to charity")
        }
    }

    private var emptyState: some View {
        VaultCard {
            VStack(spacing: 8) {
                Image(systemName: "tray")
                    .font(.system(size: 28))
                    .foregroundColor(Palette.textTertiary)
                Text("no sessions yet.")
                    .font(Typography.sohne(15))
                    .foregroundColor(Palette.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
    }

    private func reload() {
        sessions = engine.store.loadAll()
        stats = engine.store.stats(from: sessions)
    }

    private func heldString(_ s: TimeInterval) -> String {
        let total = Int(s)
        let h = total / 3600, m = (total % 3600) / 60
        if h > 0 { return "\(h)h\(m == 0 ? "" : " \(m)m")" }
        return "\(m)m"
    }
}

private struct StatCard: View {
    let value: String
    let label: String
    var body: some View {
        VaultCard {
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(Typography.plexMono(20, weight: .medium))
                    .foregroundColor(Palette.cream)
                Text(label.uppercased())
                    .font(Typography.sohne(10, weight: .semibold))
                    .tracking(1.4)
                    .foregroundColor(Palette.brass)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct SessionRow: View {
    let session: Session

    var body: some View {
        VaultCard {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: outcomeGlyph)
                    .foregroundColor(outcomeColor)
                    .font(.system(size: 18))
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(dateString)
                        .font(Typography.sohne(13, weight: .semibold))
                        .foregroundColor(Palette.cream)
                    Text("\(session.lockmaster.title) · \(durationText)")
                        .font(Typography.sohne(12))
                        .foregroundColor(Palette.textSecondary)
                    Text(outcomeText)
                        .font(Typography.sohne(11))
                        .foregroundColor(outcomeColor)
                }
                Spacer()
            }
        }
    }

    private var outcomeGlyph: String {
        switch session.outcome {
        case .completed: return "checkmark.seal.fill"
        case .emergencyUnlock, .abandoned: return "exclamationmark.triangle.fill"
        case .charityCharged: return "heart.fill"
        case .running: return "lock.fill"
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

    private var outcomeText: String {
        switch session.outcome {
        case .completed: return "held to the end."
        case .emergencyUnlock: return "broken early."
        case .charityCharged: return "donation: $\(session.charity?.amountDollars ?? 0)"
        case .abandoned: return "abandoned."
        case .running: return "still running."
        }
    }

    private var durationText: String {
        let s = Int(session.heldSeconds)
        let h = s / 3600, m = (s % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d · h:mm a"
        return f.string(from: session.startedAt)
    }
}
