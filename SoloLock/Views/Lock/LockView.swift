import SwiftUI

/// Full-screen running session: lock animation, countdown, optional judge chat,
/// emergency button.
struct LockView: View {
    @EnvironmentObject var session: SessionEngine

    @State private var clickShut = false
    @State private var showChat = false
    @State private var showEmergency = false
    @State private var showSimulatedTakeover = false

    var body: some View {
        ZStack {
            VaultBackground()

            VStack(spacing: 24) {
                topBar
                Spacer(minLength: 8)
                LockGlyph(size: 140, locked: clickShut)
                    .onAppear {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.55).delay(0.05)) {
                            clickShut = true
                        }
                    }
                countdown
                phaseChip
                Spacer()
                bottomActions
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .sheet(isPresented: $showChat) { judgeChatSheet }
        .sheet(isPresented: $showEmergency) {
            EmergencyUnlockView()
                .environmentObject(session)
                .presentationBackground(Palette.vault)
        }
        .fullScreenCover(isPresented: $showSimulatedTakeover) {
            LockedTakeoverView(onDismiss: { showSimulatedTakeover = false })
                .environmentObject(session)
        }
    }

    // MARK: - Pieces

    private var topBar: some View {
        HStack {
            Image(systemName: session.current?.lockmaster.glyph ?? "lock")
                .foregroundColor(Palette.brass)
            Text(session.current?.lockmaster.title ?? "")
                .font(Typography.sohne(13, weight: .semibold))
                .tracking(1.2)
                .foregroundColor(Palette.brass)
            Spacer()
            Button {
                showSimulatedTakeover = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "iphone.gen3")
                    Text("preview block").font(Typography.sohne(12))
                }
                .foregroundColor(Palette.textSecondary)
            }
        }
        .padding(.top, 8)
    }

    private var countdown: some View {
        let remaining = session.current?.remaining(at: session.now) ?? 0
        return Text(format(remaining))
            .font(Typography.plexMono(64, weight: .medium))
            .foregroundColor(Palette.cream)
            .monospacedDigit()
            .contentTransition(.numericText())
            .animation(.snappy, value: Int(remaining))
    }

    private var phaseChip: some View {
        let s = session.current
        let phase = phaseString()
        return HStack(spacing: 8) {
            Circle().fill(Palette.brass).frame(width: 6, height: 6)
            Text(phase)
                .font(Typography.sohne(13))
                .foregroundColor(Palette.textSecondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(Capsule().fill(Palette.vaultDeep).overlay(Capsule().stroke(Palette.hairline)))
        .opacity(s == nil ? 0 : 1)
    }

    private var bottomActions: some View {
        VStack(spacing: 12) {
            if session.current?.lockmaster == .aiJudge {
                Button {
                    showChat = true
                } label: {
                    HStack {
                        Image(systemName: "scale.3d")
                        Text("speak to the judge")
                    }
                }
                .buttonStyle(BrassButtonStyle(prominent: false))
            }

            EmergencyHoldButton {
                showEmergency = true
            }
        }
    }

    private var judgeChatSheet: some View {
        JudgeChatView()
            .environmentObject(session)
            .presentationDetents([.large])
            .presentationBackground(Palette.vault)
    }

    // MARK: - Helpers

    private func format(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded()))
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%02d:%02d", m, sec)
    }

    private func phaseString() -> String {
        guard let s = session.current else { return "" }
        let total = s.plannedSeconds
        let remaining = s.remaining(at: session.now)
        let pct = total > 0 ? (1 - remaining / total) : 0
        let label: String
        switch pct {
        case ..<0.10: label = "clean slate"
        case ..<0.40: label = "settling in"
        case ..<0.70: label = "midway"
        case ..<0.95: label = "long stretch"
        default:      label = "last stretch"
        }
        return "\(label) · \(formatRemainingShort(remaining)) left"
    }

    private func formatRemainingShort(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        let h = s / 3600, m = (s % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

// MARK: - Emergency long-press button

private struct EmergencyHoldButton: View {
    var onTrigger: () -> Void
    @State private var progress: Double = 0
    @State private var holding = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Palette.sosRed, lineWidth: 1)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Palette.sosRed.opacity(0.10 + progress * 0.4))
                )
            GeometryReader { g in
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Palette.sosRed.opacity(0.5))
                    .frame(width: g.size.width * progress)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(holding ? "keep holding…" : "emergency unlock — hold 5s")
            }
            .font(Typography.sohne(15, weight: .semibold))
            .foregroundColor(Palette.cream)
        }
        .frame(height: 56)
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 5, maximumDistance: 60) {
            Haptics.warning()
            holding = false
            progress = 0
            onTrigger()
        } onPressingChanged: { pressing in
            holding = pressing
            if pressing {
                withAnimation(.linear(duration: 5)) { progress = 1.0 }
            } else {
                withAnimation(.easeOut(duration: 0.2)) { progress = 0 }
            }
        }
    }
}

#Preview {
    LockView().environmentObject(SessionEngine())
}
