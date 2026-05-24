import SwiftUI

enum PureWhiteStyle {
    static var isActive: Bool {
        GlobalThemeId.persistedOrDefault == .pureWhite
    }

    static var base: Color {
        ThemeColorCustomization.backgroundBase(
            for: .pureWhite,
            fallback: Color(light: .white, dark: Color(hex: "111318")),
            fallbackHex: "FFFFFF"
        )
    }

    static var paper: Color { base }

    static var surface: Color {
        Color(light: Color(hex: "FCFCFD"), dark: Color(hex: "1A1D22"))
    }

    static var surfaceRaised: Color {
        Color(light: Color(hex: "FFFFFF"), dark: Color(hex: "20242B"))
    }

    static var surfaceTint: Color {
        Color(light: Color(hex: "F5F7FA"), dark: Color(hex: "242931"))
    }

    static var cream: Color {
        Color(light: Color(hex: "F8FAFC"), dark: Color(hex: "252B31"))
    }

    static var peach: Color {
        Color(light: Color(hex: "F1F5F9"), dark: Color(hex: "2A2F36"))
    }

    static var mint: Color {
        Color(light: Color(hex: "EFF6FF"), dark: Color(hex: "24303A"))
    }

    static var coral: Color {
        Color(light: Color(hex: "EF4444"), dark: Color(hex: "F87171"))
    }

    static var blush: Color {
        Color(light: Color(hex: "F6F7F9"), dark: Color(hex: "2B2D32"))
    }

    static var paperBlue: Color {
        Color(light: Color(hex: "E3EEFF"), dark: Color(hex: "233446"))
    }

    static var lemon: Color {
        Color(light: Color(hex: "F8FAFC"), dark: Color(hex: "2C3138"))
    }

    static var ink: Color {
        Color(light: Color(hex: "0F172A"), dark: Color(hex: "F8FAFC"))
    }

    static var strokeInk: Color {
        Color(light: Color(hex: "111827"), dark: Color(hex: "F8FAFC"))
    }

    static var inkSoft: Color {
        Color(light: Color(hex: "475569"), dark: Color(hex: "CBD5E1"))
    }

    static var inkMuted: Color {
        Color(light: Color(hex: "94A3B8"), dark: Color(hex: "94A3B8"))
    }

    static var separator: Color {
        Color(light: Color(hex: "E5E7EB"), dark: Color(hex: "334155").opacity(0.7))
    }

    static var accent: Color {
        ThemeColorCustomization.accentColor(
            for: .pureWhite,
            fallback: Color(hex: "2563EB"),
            fallbackHex: "2563EB"
        )
    }

    static var onAccent: Color {
        ThemeColorCustomization.readableForegroundColor(
            on: accent,
            light: Color(hex: "0F172A"),
            dark: .white
        )
    }

    static var accentGradient: [Color] {
        ThemeColorCustomization.accentGradientColors(
            for: .pureWhite,
            fallback: [accent, paperBlue, cream],
            fallbackHexes: ["2563EB", "3B82F6", "F8FAFC"]
        )
    }

    static let strokeWidth: CGFloat = 1.2
    static let fineStrokeWidth: CGFloat = 0.85
    static let cardRadius: CGFloat = 18
    static let compactRadius: CGFloat = 12

    static func titleFont(_ size: CGFloat, weight: Font.Weight = .black) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func bodyFont(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func labelFont(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

struct PureWhiteRootBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            PureWhiteStyle.paper
            PureWhiteBackdropGrid()
                .opacity(colorScheme == .dark ? 0.48 : 0.9)
        }
        .ignoresSafeArea()
    }
}

private struct PureWhiteBackdropGrid: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            let width = max(size.width, 1)
            let height = max(size.height, 1)
            let lineColor = PureWhiteStyle.separator.opacity(colorScheme == .dark ? 0.10 : 0.28)
            let accentColor = PureWhiteStyle.accent.opacity(colorScheme == .dark ? 0.10 : 0.08)
            let step: CGFloat = 56

            var grid = Path()
            stride(from: step, through: width, by: step).forEach { x in
                grid.move(to: CGPoint(x: x, y: 0))
                grid.addLine(to: CGPoint(x: x, y: height))
            }
            stride(from: step, through: height, by: step).forEach { y in
                grid.move(to: CGPoint(x: 0, y: y))
                grid.addLine(to: CGPoint(x: width, y: y))
            }
            context.stroke(grid, with: .color(lineColor), lineWidth: 0.7)

            var rail = Path()
            let railX = min(width * 0.18, 92)
            rail.move(to: CGPoint(x: railX, y: 0))
            rail.addLine(to: CGPoint(x: railX, y: height))
            context.stroke(rail, with: .color(accentColor), lineWidth: 1.2)

            let topY = max(height * 0.12, 64)
            let bottomY = max(height - 88, height * 0.84)
            var topRule = Path()
            topRule.move(to: CGPoint(x: 0, y: topY))
            topRule.addLine(to: CGPoint(x: width, y: topY))
            context.stroke(topRule, with: .color(lineColor), lineWidth: 0.55)

            var bottomRule = Path()
            bottomRule.move(to: CGPoint(x: 0, y: bottomY))
            bottomRule.addLine(to: CGPoint(x: width, y: bottomY))
            context.stroke(bottomRule, with: .color(lineColor.opacity(0.8)), lineWidth: 0.55)
        }
        .allowsHitTesting(false)
    }
}

struct PureWhiteSurfaceBackground: View {
    var cornerRadius: CGFloat = PureWhiteStyle.cardRadius
    var elevated = true
    var tint: Color = PureWhiteStyle.surfaceRaised

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        ZStack {
            if elevated {
                shape
                    .fill(PureWhiteStyle.surfaceTint.opacity(colorScheme == .dark ? 0.34 : 0.62))
                    .offset(x: 0, y: 3)
            }

            shape
                .fill(tint)
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.08 : 0.9),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(shape)
                )
                .overlay(
                    shape.stroke(
                        PureWhiteStyle.separator.opacity(colorScheme == .dark ? 0.72 : 1),
                        lineWidth: elevated ? PureWhiteStyle.strokeWidth : PureWhiteStyle.fineStrokeWidth
                    )
                )
                .overlay(alignment: .topLeading) {
                    if elevated {
                        Capsule(style: .continuous)
                            .fill(PureWhiteStyle.accent.opacity(colorScheme == .dark ? 0.56 : 0.82))
                            .frame(width: max(18, cornerRadius * 0.9), height: 3)
                            .padding(.top, 12)
                            .padding(.leading, 12)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if elevated {
                        Capsule(style: .continuous)
                            .fill(PureWhiteStyle.separator.opacity(0.82))
                            .frame(width: 22, height: 2)
                            .padding(.trailing, 12)
                            .padding(.bottom, 12)
                    }
                }
                .shadow(
                    color: PureWhiteStyle.strokeInk.opacity(elevated ? (colorScheme == .dark ? 0.18 : 0.12) : 0.06),
                    radius: 0,
                    x: 0,
                    y: elevated ? 3 : 1
                )
        }
    }
}

struct PureWhitePageHeader<Accessory: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let icon: MonologueIcon.IconType
    let accessory: Accessory

    init(
        eyebrow: String,
        title: String,
        subtitle: String = "",
        icon: MonologueIcon.IconType = .sparkle,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.accessory = accessory()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            PureWhiteIconBadge(icon: icon, tint: PureWhiteStyle.accent, size: 46)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    PureWhiteHeaderChip(text: eyebrow.uppercased())
                    Spacer(minLength: 0)
                }

                Text(title)
                    .font(PureWhiteStyle.titleFont(26, weight: .black))
                    .foregroundStyle(PureWhiteStyle.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(PureWhiteStyle.bodyFont(13, weight: .semibold))
                        .foregroundStyle(PureWhiteStyle.inkSoft)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                }

                PureWhiteHeaderRule()
            }

            Spacer(minLength: 0)

            accessory
        }
        .padding(.horizontal, DeviceLayout.settingsHeaderHorizontalPadding)
        .padding(.top, 14)
        .padding(.bottom, 6)
        .iPadContentWidth(700)
    }
}

extension PureWhitePageHeader where Accessory == EmptyView {
    init(
        eyebrow: String,
        title: String,
        subtitle: String = "",
        icon: MonologueIcon.IconType = .sparkle
    ) {
        self.init(eyebrow: eyebrow, title: title, subtitle: subtitle, icon: icon) {
            EmptyView()
        }
    }
}

private struct PureWhiteHeaderChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(PureWhiteStyle.labelFont(10, weight: .black))
            .foregroundStyle(PureWhiteStyle.inkSoft)
            .tracking(1.1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(PureWhiteStyle.surfaceRaised)
                    .overlay(Capsule(style: .continuous).stroke(PureWhiteStyle.separator, lineWidth: 1))
            )
    }
}

private struct PureWhiteHeaderRule: View {
    var body: some View {
        HStack(spacing: 6) {
            Capsule(style: .continuous)
                .fill(PureWhiteStyle.accent)
                .frame(width: 30, height: 3)
            Capsule(style: .continuous)
                .fill(PureWhiteStyle.separator)
                .frame(width: 18, height: 3)
        }
        .padding(.top, 2)
    }
}

struct PureWhiteIconBadge: View {
    let icon: MonologueIcon.IconType
    var tint: Color = PureWhiteStyle.accent
    var size: CGFloat = 48

    var body: some View {
        let radius = max(12, size * 0.26)

        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(PureWhiteStyle.surfaceRaised)
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(PureWhiteStyle.separator, lineWidth: max(1, size * 0.034))
                )
                .overlay(alignment: .topLeading) {
                    Capsule(style: .continuous)
                        .fill(tint.opacity(0.86))
                        .frame(width: max(14, size * 0.34), height: max(3, size * 0.06))
                        .padding(size * 0.12)
                }

            MonologueIcon(
                icon: icon,
                size: size * 0.36,
                color: PureWhiteStyle.ink,
                lineWidth: max(1.4, size * 0.04)
            )
        }
        .frame(width: size, height: size)
        .shadow(color: PureWhiteStyle.strokeInk.opacity(0.10), radius: 0, x: 0, y: 2)
    }
}
