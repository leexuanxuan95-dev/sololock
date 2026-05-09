import SwiftUI

// MARK: - Backgrounds

struct VaultBackground: View {
    var body: some View {
        ZStack {
            Palette.vault.ignoresSafeArea()
            // Subtle vignette so the screen feels like the inside of an iron box.
            RadialGradient(
                colors: [Palette.vault.opacity(0), Palette.vaultDeep.opacity(0.85)],
                center: .center, startRadius: 80, endRadius: 600
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Buttons

struct BrassButtonStyle: ButtonStyle {
    var prominent: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.sohne(17, weight: .semibold))
            .foregroundColor(prominent ? Palette.vaultDeep : Palette.brass)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(prominent ? Palette.brass : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Palette.brass, lineWidth: prominent ? 0 : 1.5)
                    )
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.sohne(15, weight: .regular))
            .foregroundColor(Palette.textSecondary)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

// MARK: - Cards

struct VaultCard<Content: View>: View {
    var content: Content
    init(@ViewBuilder _ content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Palette.vaultDeep)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Palette.hairline, lineWidth: 1)
            )
    }
}

// MARK: - Heavy lock glyph

struct LockGlyph: View {
    var size: CGFloat
    var locked: Bool
    var brass: Color = Palette.brass
    var body: some View {
        ZStack {
            // Body
            RoundedRectangle(cornerRadius: size * 0.14, style: .continuous)
                .fill(brass)
                .frame(width: size * 0.78, height: size * 0.62)
                .offset(y: size * 0.12)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.14, style: .continuous)
                        .stroke(brass.opacity(0.25), lineWidth: 1)
                        .offset(y: size * 0.12)
                )
                .overlay(
                    Circle()
                        .fill(Palette.vaultDeep)
                        .frame(width: size * 0.16, height: size * 0.16)
                        .offset(y: size * 0.16)
                )
            // Shackle
            Shackle(open: !locked)
                .stroke(brass, style: StrokeStyle(lineWidth: size * 0.08, lineCap: .round))
                .frame(width: size * 0.46, height: size * 0.42)
                .offset(y: -size * 0.18)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.45), radius: 18, x: 0, y: 10)
    }

    private struct Shackle: Shape {
        var open: Bool
        func path(in rect: CGRect) -> Path {
            var p = Path()
            let r = rect.width / 2
            let bottomY = rect.maxY
            let leftX = rect.minX
            let rightX = rect.maxX
            // Left leg
            p.move(to: CGPoint(x: leftX, y: bottomY))
            p.addLine(to: CGPoint(x: leftX, y: rect.midY))
            // Arc
            p.addArc(center: CGPoint(x: rect.midX, y: rect.midY),
                     radius: r,
                     startAngle: .degrees(180),
                     endAngle: open ? .degrees(355) : .degrees(0),
                     clockwise: false)
            if !open {
                p.addLine(to: CGPoint(x: rightX, y: bottomY))
            }
            return p
        }
    }
}

// MARK: - Section header

struct SectionLabel: View {
    var text: String
    var body: some View {
        Text(text.uppercased())
            .font(Typography.sohne(11, weight: .semibold))
            .tracking(2)
            .foregroundColor(Palette.brass.opacity(0.85))
    }
}
