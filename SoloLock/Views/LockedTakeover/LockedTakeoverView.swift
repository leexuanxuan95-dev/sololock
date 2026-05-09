import SwiftUI

/// Demonstrates what the user sees on a real device when they try to open a
/// blocked app during a session. On simulator we surface this manually via
/// the "preview block" button on the LockView since Family Controls cannot
/// genuinely intercept other apps in the simulator.
struct LockedTakeoverView: View {
    @EnvironmentObject var session: SessionEngine
    var onDismiss: () -> Void

    @State private var quoteIdx = 0
    private let quotes: [(String, String)] = [
        ("the things you own end up owning you.", "—chuck palahniuk"),
        ("we don't decide what's important; what we attend to does.", "—james clear"),
        ("the chief task in life is simply this: to identify and separate matters so that I can say clearly which are externals not under my control.", "—epictetus"),
        ("you do not rise to the level of your goals; you fall to the level of your systems.", "—james clear"),
        ("there is nothing more pleasant than to take time off from many things.", "—seneca"),
        ("what you do every day matters more than what you do once in a while.", "—gretchen rubin"),
        ("you are what you give your attention to.", "—naval"),
        ("the deep life is the good life.", "—cal newport")
    ]
    @State private var rotateTimer: Timer?

    var body: some View {
        ZStack {
            Palette.vaultDeep.ignoresSafeArea()
            VStack(spacing: 28) {
                HStack {
                    Button(action: { onDismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Palette.textTertiary)
                            .font(.system(size: 24))
                    }
                    Spacer()
                    Text("simulated block")
                        .font(Typography.sohne(11, weight: .semibold))
                        .tracking(1.4)
                        .foregroundColor(Palette.brass)
                    Spacer()
                    Color.clear.frame(width: 24, height: 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Spacer()

                LockGlyph(size: 130, locked: true)
                    .padding(.bottom, 8)

                Text(remainingString())
                    .font(Typography.plexMono(48, weight: .medium))
                    .foregroundColor(Palette.cream)

                VStack(spacing: 8) {
                    Text(quotes[quoteIdx].0)
                        .font(Typography.sectra(18, weight: .regular))
                        .foregroundColor(Palette.cream)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .transition(.opacity)
                    Text(quotes[quoteIdx].1)
                        .font(Typography.sohne(12))
                        .foregroundColor(Palette.brass)
                }
                .id("quote-\(quoteIdx)")

                Spacer()

                Text("come back when the timer ends.")
                    .font(Typography.sohne(13))
                    .foregroundColor(Palette.textSecondary)
                    .padding(.bottom, 28)
            }
        }
        .onAppear {
            rotateTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.5)) {
                    quoteIdx = (quoteIdx + 1) % quotes.count
                }
            }
        }
        .onDisappear {
            rotateTimer?.invalidate()
            rotateTimer = nil
        }
    }

    private func remainingString() -> String {
        let r = session.current?.remaining(at: session.now) ?? 0
        let s = max(0, Int(r))
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%02d:%02d", m, sec)
    }
}
