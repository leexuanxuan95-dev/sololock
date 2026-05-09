import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var prefs: Preferences
    @State private var step = 0
    @State private var lockOpen = false

    private let lines = [
        "your phone is loud.",
        "you can't lock yourself.",
        "let's give the key to someone — anyone."
    ]

    var body: some View {
        VStack(spacing: 36) {
            Spacer()

            LockGlyph(size: 160, locked: !lockOpen)
                .scaleEffect(step == 0 ? 1.0 : 0.96)
                .animation(.spring(response: 0.7, dampingFraction: 0.6), value: step)
                .onAppear {
                    // Lock + key animate apart on entry.
                    withAnimation(.easeOut(duration: 1.0).delay(0.4)) { lockOpen = true }
                    withAnimation(.easeIn(duration: 0.6).delay(2.0)) { lockOpen = false }
                }

            VStack(spacing: 18) {
                ForEach(0..<lines.count, id: \.self) { i in
                    Text(lines[i])
                        .font(Typography.sectra(22, weight: .regular))
                        .foregroundColor(i <= step ? Palette.cream : Palette.textTertiary)
                        .multilineTextAlignment(.center)
                        .opacity(i <= step ? 1 : 0.0)
                        .animation(.easeOut(duration: 0.5).delay(Double(i) * 0.4), value: step)
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                Button("pick your lockmaster") {
                    Haptics.tap()
                    prefs.hasSeenOnboarding = true
                }
                .buttonStyle(BrassButtonStyle())
                .padding(.horizontal, 24)

                Text("works on this device · no account required")
                    .font(Typography.sohne(12))
                    .foregroundColor(Palette.textTertiary)
            }
            .padding(.bottom, 36)
        }
        .onAppear {
            // Reveal lines one at a time.
            for i in 0..<lines.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6 + Double(i) * 0.7) {
                    withAnimation { step = i }
                }
            }
        }
    }
}

#Preview {
    ZStack { VaultBackground(); OnboardingView().environmentObject(Preferences()) }
}
