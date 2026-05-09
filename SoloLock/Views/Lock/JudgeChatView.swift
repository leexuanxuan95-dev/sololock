import SwiftUI

/// AI Judge transcript + composer. Pure-algorithmic replies via JudgeEngine.
struct JudgeChatView: View {
    @EnvironmentObject var session: SessionEngine
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Palette.hairline)
            transcript
            composer
        }
        .background(Palette.vault.ignoresSafeArea())
    }

    private var header: some View {
        HStack {
            Image(systemName: "scale.3d")
                .foregroundColor(Palette.brass)
            Text("the judge")
                .font(Typography.sectra(20))
                .foregroundColor(Palette.cream)
            Spacer()
            Button {
                Haptics.tap()
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Palette.textTertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(session.current?.judgeTranscript ?? []) { msg in
                        ChatBubble(message: msg)
                            .id(msg.id)
                    }
                    Color.clear.frame(height: 4).id("bottom")
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
            .onChange(of: session.current?.judgeTranscript.count) { _, _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onAppear {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }

    private var composer: some View {
        HStack(spacing: 10) {
            TextField("state your case", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .focused($focused)
                .font(Typography.sohne(15))
                .foregroundColor(Palette.cream)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Palette.vaultDeep)
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.hairline))
                )
                .submitLabel(.send)
                .onSubmit { send() }
                .accessibilityIdentifier("chat.composer")

            Button {
                send()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(canSend ? Palette.brass : Palette.textTertiary)
            }
            .disabled(!canSend)
            .accessibilityIdentifier("chat.send")
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .padding(.top, 6)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func send() {
        guard canSend else { return }
        Haptics.tap()
        let text = draft
        draft = ""
        session.sendUserMessage(text)
    }
}

private struct ChatBubble: View {
    let message: ChatMessage
    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 32) }
            Text(message.text)
                .font(message.role == .judge
                      ? Typography.sectra(16, weight: .regular)
                      : Typography.sohne(15))
                .foregroundColor(message.role == .judge ? Palette.cream : Palette.vaultDeep)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(message.role == .judge ? Palette.vaultDeep : Palette.brass)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(message.role == .judge ? Palette.hairline : .clear)
                )
            if message.role == .judge { Spacer(minLength: 32) }
        }
    }
}
