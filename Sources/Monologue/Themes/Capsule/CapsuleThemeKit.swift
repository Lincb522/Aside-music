import SwiftUI

enum CapsuleStyle {
    static var isActive: Bool {
        GlobalThemeId.persistedOrDefault == .capsule
    }

    static var base: Color {
        ThemeColorCustomization.backgroundBase(
            for: .capsule,
            fallback: Color(light: Color(hex: "F6F8FF"), dark: Color(hex: "111725")),
            fallbackHex: "F6F8FF"
        )
    }

    static var surface: Color {
        Color(light: Color(hex: "FFFFFF").opacity(0.9), dark: Color(hex: "1B2435").opacity(0.9))
    }

    static var surfaceRaised: Color {
        Color(light: Color(hex: "FFFFFF"), dark: Color(hex: "202B3E"))
    }

    static var surfaceTint: Color {
        Color(light: Color(hex: "EEF3FF"), dark: Color(hex: "26324A"))
    }

    static var ink: Color {
        Color(light: Color(hex: "141C2B"), dark: Color(hex: "F5F7FF"))
    }

    static var inkSoft: Color {
        Color(light: Color(hex: "526070"), dark: Color(hex: "B7C1D0"))
    }

    static var inkMuted: Color {
        Color(light: Color(hex: "8A95A6"), dark: Color(hex: "7F8BA0"))
    }

    static var accent: Color {
        ThemeColorCustomization.accentColor(
            for: .capsule,
            fallback: Color(hex: "3867FF"),
            fallbackHex: "3867FF"
        )
    }

    static var blue: Color {
        accent
    }

    static var cyan: Color {
        Color(hex: "2EC8E6")
    }

    static var mint: Color {
        Color(hex: "35CFA8")
    }

    static var coral: Color {
        Color(hex: "FF7E86")
    }

    static var amber: Color {
        Color(hex: "F0AD3D")
    }

    static var violet: Color {
        Color(hex: "8476FF")
    }

    static var separator: Color {
        Color(light: Color(hex: "D7DEEA"), dark: Color(hex: "354159"))
    }

    static var hairline: Color {
        Color(light: Color.white.opacity(0.9), dark: Color.white.opacity(0.12))
    }

    static var onAccent: Color {
        ThemeColorCustomization.readableForegroundColor(on: accent, light: Color(hex: "101A2A"), dark: .white)
    }

    static var accentGradient: [Color] {
        ThemeColorCustomization.accentGradientColors(
            for: .capsule,
            fallback: [accent, cyan, violet],
            fallbackHexes: ["3867FF", "2EC8E6", "8476FF"]
        )
    }

    static let cardRadius: CGFloat = 30
    static let compactRadius: CGFloat = 22

    static func titleFont(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func bodyFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func labelFont(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

struct CapsuleRootBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            ThemeCustomDiffuseBackground(
                theme: .capsule,
                fallbackHexes: colorScheme == .dark
                    ? ["111725", "1B2440", "182E35", "221C38"]
                    : ["F6F8FF", "EAF1FF", "F8F2FF", "EDF9FF"],
                accentFallbackHexes: ["3867FF", "2EC8E6", "8476FF"],
                opacity: colorScheme == .dark ? 0.8 : 0.72
            )

            CapsuleBackdropField()
                .opacity(colorScheme == .dark ? 0.35 : 0.5)
        }
        .ignoresSafeArea()
    }
}

private struct CapsuleBackdropField: View {
    var body: some View {
        GeometryReader { proxy in
            Canvas(rendersAsynchronously: true) { context, size in
                let width = max(size.width, 1)
                let height = max(size.height, 1)
                let capsules: [(CGPoint, CGSize, Double, Color)] = [
                    (CGPoint(x: width * 0.18, y: height * 0.16), CGSize(width: width * 0.34, height: 14), -18, CapsuleStyle.blue),
                    (CGPoint(x: width * 0.82, y: height * 0.13), CGSize(width: width * 0.28, height: 10), 16, CapsuleStyle.cyan),
                    (CGPoint(x: width * 0.78, y: height * 0.42), CGSize(width: width * 0.22, height: 8), -22, CapsuleStyle.violet),
                    (CGPoint(x: width * 0.2, y: height * 0.72), CGSize(width: width * 0.26, height: 9), 20, CapsuleStyle.mint),
                    (CGPoint(x: width * 0.62, y: height * 0.88), CGSize(width: width * 0.38, height: 12), -10, CapsuleStyle.coral),
                ]

                for capsule in capsules {
                    var copy = context
                    copy.translateBy(x: capsule.0.x, y: capsule.0.y)
                    copy.rotate(by: .degrees(capsule.2))
                    let rect = CGRect(
                        x: -capsule.1.width / 2,
                        y: -capsule.1.height / 2,
                        width: capsule.1.width,
                        height: capsule.1.height
                    )
                    copy.fill(
                        Path(roundedRect: rect, cornerRadius: capsule.1.height / 2),
                        with: .color(capsule.3.opacity(0.12))
                    )
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .allowsHitTesting(false)
    }
}

struct CapsuleSurfaceBackground: View {
    var cornerRadius: CGFloat = CapsuleStyle.cardRadius
    var elevated = true
    var tint: Color = CapsuleStyle.surface

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(tint)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(CapsuleStyle.hairline.opacity(elevated ? 0.86 : 0.56), lineWidth: 1)
            )
            .shadow(color: CapsuleStyle.accent.opacity(elevated ? 0.08 : 0.03), radius: elevated ? 18 : 7, x: 0, y: elevated ? 10 : 4)
            .shadow(color: Color.black.opacity(elevated ? 0.08 : 0.035), radius: elevated ? 12 : 5, x: 0, y: elevated ? 8 : 3)
    }
}

struct CapsuleFlatRowBackground: View {
    var cornerRadius: CGFloat = 18

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(CapsuleStyle.surface.opacity(0.4))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(CapsuleStyle.separator.opacity(0.5), lineWidth: 0.8)
            )
    }
}

struct CapsulePageHeader<Accessory: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let accessory: Accessory

    init(
        eyebrow: String,
        title: String,
        subtitle: String = "",
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(eyebrow.uppercased())
                    .font(CapsuleStyle.labelFont(10))
                    .foregroundStyle(CapsuleStyle.inkMuted)
                    .tracking(1.2)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Capsule()
                        .fill(CapsuleStyle.accent)
                        .frame(width: 6, height: 24)

                    Text(title)
                        .font(CapsuleStyle.titleFont(25, weight: .bold))
                        .foregroundStyle(CapsuleStyle.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(CapsuleStyle.bodyFont(12, weight: .medium))
                        .foregroundStyle(CapsuleStyle.inkSoft)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }

            Spacer(minLength: 8)
            accessory
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .monologuePageHeaderCollapse()
    }
}

extension CapsulePageHeader where Accessory == EmptyView {
    init(eyebrow: String, title: String, subtitle: String = "") {
        self.init(eyebrow: eyebrow, title: title, subtitle: subtitle) {
            EmptyView()
        }
    }
}

struct CapsuleIconBadge: View {
    let icon: MonologueIcon.IconType
    var tint: Color = CapsuleStyle.accent
    var size: CGFloat = 44

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.42, style: .continuous)
            .fill(tint.opacity(0.14))
            .frame(width: size, height: size)
            .overlay(
                MonologueIcon(
                    icon: icon,
                    size: size * 0.42,
                    color: ThemeColorCustomization.visibleTintColor(tint, darkFallback: CapsuleStyle.ink),
                    lineWidth: 1.7
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.42, style: .continuous)
                    .stroke(tint.opacity(0.2), lineWidth: 0.8)
            )
    }
}

struct CapsulePillLabel: View {
    let title: String
    var icon: MonologueIcon.IconType?
    var tint: Color = CapsuleStyle.accent
    var selected = false

    var body: some View {
        HStack(spacing: 7) {
            if let icon {
                MonologueIcon(
                    icon: icon,
                    size: 13,
                    color: selected ? CapsuleStyle.onAccent : tint,
                    lineWidth: 1.7
                )
            }

            Text(title)
                .font(CapsuleStyle.labelFont(12))
                .foregroundStyle(selected ? CapsuleStyle.onAccent : CapsuleStyle.inkSoft)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 13)
        .frame(height: 34)
        .background(
            Capsule()
                .fill(selected ? tint : CapsuleStyle.surfaceRaised.opacity(0.86))
                .overlay(Capsule().stroke(selected ? Color.white.opacity(0.38) : CapsuleStyle.separator.opacity(0.48), lineWidth: 0.8))
        )
    }
}

struct CapsuleActionButton<Content: View>: View {
    var tint: Color = CapsuleStyle.accent
    let action: () -> Void
    let content: Content

    init(tint: Color = CapsuleStyle.accent, action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.action = action
        self.content = content()
    }

    var body: some View {
        Button(action: action) {
            content
                .frame(minWidth: 42, minHeight: 42)
                .background(
                    CapsuleSurfaceBackground(
                        cornerRadius: 21,
                        elevated: true,
                        tint: CapsuleStyle.surfaceRaised
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 21, style: .continuous)
                        .stroke(tint.opacity(0.16), lineWidth: 1)
                )
        }
        .buttonStyle(CapsulePressStyle())
    }
}

struct CapsulePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

struct CapsuleSectionTitle<Accessory: View>: View {
    let title: String
    let tint: Color
    let accessory: Accessory

    init(title: String, tint: Color = CapsuleStyle.accent, @ViewBuilder accessory: () -> Accessory) {
        self.title = title
        self.tint = tint
        self.accessory = accessory()
    }

    var body: some View {
        HStack(spacing: 9) {
            Capsule()
                .fill(tint)
                .frame(width: 24, height: 8)

            Text(title)
                .font(CapsuleStyle.titleFont(18, weight: .bold))
                .foregroundStyle(CapsuleStyle.ink)

            Spacer(minLength: 0)
            accessory
        }
    }
}

extension CapsuleSectionTitle where Accessory == EmptyView {
    init(title: String, tint: Color = CapsuleStyle.accent) {
        self.init(title: title, tint: tint) {
            EmptyView()
        }
    }
}
