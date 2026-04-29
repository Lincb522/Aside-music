import SwiftUI

enum MujiStyle {
    static var isActive: Bool {
        UserDefaults.standard.string(forKey: "globalThemeId") == GlobalThemeId.muji.rawValue
    }

    static var paper: Color {
        ThemeColorCustomization.backgroundBase(for: .muji, fallback: Color(light: Color(hex: "F7F1E8"), dark: Color(hex: "29241E")), fallbackHex: "F7F1E8")
    }

    static let paperWarm = Color(light: Color(hex: "EFE5D6"), dark: Color(hex: "342D25"))
    static let surface = Color(light: Color(hex: "FFFDF8"), dark: Color(hex: "332C25"))
    static let surfaceRaised = Color(light: Color(hex: "FCF7EF"), dark: Color(hex: "40372E"))
    static let ink = Color(light: Color(hex: "302B26"), dark: Color(hex: "F5EDE1"))
    static let inkSoft = Color(light: Color(hex: "6F665C"), dark: Color(hex: "D8CBBB"))
    static let inkMuted = Color(light: Color(hex: "9A8F83"), dark: Color(hex: "B1A493"))
    static let onTint = Color(light: Color(hex: "FFF8EF"), dark: Color(hex: "211A15"))
    static let onImage = Color(light: Color(hex: "FFFDF8"), dark: Color(hex: "FFF7EA"))
    static var clay: Color {
        ThemeColorCustomization.accentColor(for: .muji, fallback: Color(light: Color(hex: "B56B4B"), dark: Color(hex: "C98261")), fallbackHex: "B56B4B")
    }

    static let tea = Color(light: Color(hex: "78846B"), dark: Color(hex: "96A382"))
    static let indigo = Color(light: Color(hex: "56677A"), dark: Color(hex: "8191A1"))
    static let straw = Color(light: Color(hex: "D8B56D"), dark: Color(hex: "E0C37D"))
    static let red = Color(light: Color(hex: "B94E3D"), dark: Color(hex: "CF6858"))
    static let separator = Color(light: Color(hex: "DED3C4"), dark: Color(hex: "6C5E50"))
    static let hairline = Color(light: Color(hex: "CDBFAC"), dark: Color(hex: "827263"))

    static let cardRadius: CGFloat = 12
    static let buttonRadius: CGFloat = 9

    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: ThemeColorCustomization.accentGradientColors(
                for: .muji,
                fallback: [clay, straw.opacity(0.92), tea.opacity(0.82)],
                fallbackHexes: ["B56B4B", "D8B56D"]
            ),
            startPoint: ThemeColorCustomization.gradientStyle(for: .muji, role: .accent).points.start,
            endPoint: ThemeColorCustomization.gradientStyle(for: .muji, role: .accent).points.end
        )
    }

    static func titleFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func bodyFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func labelFont(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

struct MujiRootBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        let _ = settings.globalThemeRevision
        ZStack {
            MujiStyle.paper

            MujiPaperTexture(opacity: colorScheme == .dark ? 0.18 : 0.34)
        }
        .ignoresSafeArea()
    }
}

struct MujiPaperTexture: View {
    var opacity: Double = 0.28

    var body: some View {
        Canvas { context, size in
            let fiber = MujiStyle.inkMuted.opacity(opacity)
            let warm = MujiStyle.straw.opacity(opacity * 0.45)

            for index in stride(from: 0, through: Int(size.height) + 24, by: 18) {
                var path = Path()
                let y = CGFloat(index)
                path.move(to: CGPoint(x: -12, y: y))
                path.addLine(to: CGPoint(x: size.width + 12, y: y + CGFloat((index % 5) - 2)))
                context.stroke(path, with: .color(fiber.opacity(index.isMultiple(of: 3) ? 0.16 : 0.08)), lineWidth: 0.45)
            }

            for index in stride(from: 0, through: Int(size.width) + 24, by: 26) {
                var path = Path()
                let x = CGFloat(index)
                path.move(to: CGPoint(x: x, y: -12))
                path.addLine(to: CGPoint(x: x + CGFloat((index % 7) - 3), y: size.height + 12))
                context.stroke(path, with: .color(fiber.opacity(0.045)), lineWidth: 0.35)
            }

            for index in 0 ..< 18 {
                let rect = CGRect(
                    x: size.width * CGFloat((index * 37) % 100) / 100,
                    y: size.height * CGFloat((index * 53) % 100) / 100,
                    width: CGFloat(28 + (index % 5) * 11),
                    height: 1
                )
                context.fill(Path(roundedRect: rect, cornerRadius: 0.5), with: .color(warm.opacity(0.06)))
            }
        }
        .allowsHitTesting(false)
    }
}

struct MujiPaperCardBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var cornerRadius: CGFloat = MujiStyle.cardRadius
    var elevated: Bool = false

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(elevated ? MujiStyle.surfaceRaised : MujiStyle.surface)
            .overlay(MujiPaperTexture(opacity: colorScheme == .dark ? 0.07 : 0.12).clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(MujiStyle.hairline.opacity(colorScheme == .dark ? (elevated ? 0.5 : 0.38) : (elevated ? 0.72 : 0.54)), lineWidth: 0.65)
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? (elevated ? 0.04 : 0.025) : (elevated ? 0.075 : 0.045)),
                radius: elevated ? 14 : 8,
                x: 0,
                y: elevated ? 7 : 3
            )
            .themeRenderSurfaceLayer(isEnabled: elevated)
    }
}

struct MujiSectionTitle: View {
    let title: String
    var detail: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .bottom, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(MujiStyle.titleFont(18, weight: .medium))
                    .foregroundStyle(MujiStyle.ink)
                    .tracking(0.6)

                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(MujiStyle.labelFont(11))
                        .foregroundStyle(MujiStyle.inkMuted)
                }
            }

            Rectangle()
                .fill(MujiStyle.separator)
                .frame(height: 0.6)
                .padding(.bottom, 7)

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(MujiStyle.labelFont(10, weight: .semibold))
                        .foregroundStyle(MujiStyle.inkSoft)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(MujiStyle.surface, in: Capsule())
                        .overlay(Capsule().stroke(MujiStyle.hairline.opacity(0.44), lineWidth: 0.6))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 1)
            }
        }
    }
}

struct MujiPageHeader<Accessory: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    @ViewBuilder let accessory: Accessory

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(eyebrow.uppercased())
                    .font(MujiStyle.labelFont(10, weight: .semibold))
                    .foregroundStyle(MujiStyle.clay)
                    .tracking(1.2)

                Text(title)
                    .font(MujiStyle.titleFont(30, weight: .regular))
                    .foregroundStyle(MujiStyle.ink)
                    .tracking(0.3)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(MujiStyle.labelFont(12, weight: .regular))
                        .foregroundStyle(MujiStyle.inkSoft)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 10)

            accessory
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 8)
        .padding(.bottom, 12)
    }
}

extension MujiPageHeader where Accessory == EmptyView {
    init(eyebrow: String, title: String, subtitle: String) {
        self.init(eyebrow: eyebrow, title: title, subtitle: subtitle) {
            EmptyView()
        }
    }
}

struct MujiIconBadge: View {
    let icon: MonologueIcon.IconType
    var tint: Color = MujiStyle.clay
    var size: CGFloat = 46

    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(tint.opacity(0.11))
            .frame(width: size, height: size)
            .overlay(
                MonologueIcon(icon: icon, size: size * 0.42, color: tint, lineWidth: 1.4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(tint.opacity(0.28), lineWidth: 0.6)
            )
    }
}

struct MujiMetricTile: View {
    let value: String
    let label: String
    var tint: Color = MujiStyle.clay

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(MujiStyle.titleFont(22, weight: .medium))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(MujiStyle.labelFont(10, weight: .medium))
                .foregroundStyle(MujiStyle.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(MujiStyle.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(MujiStyle.hairline.opacity(0.42), lineWidth: 0.6)
        )
    }
}

struct MujiNowPlayingIndicator: View {
    var isAnimating: Bool = true

    var body: some View {
        TimelineView(.animation) { timeline in
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0 ..< 3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1.4, style: .continuous)
                        .fill(barColor(index).opacity(isAnimating ? 0.86 : 0.5))
                        .frame(width: 3, height: barHeight(index, at: timeline.date))
                }
            }
            .frame(width: 28, height: 24)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(MujiStyle.surface.opacity(0.93))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(MujiStyle.hairline.opacity(0.5), lineWidth: 0.6)
            )
            .shadow(color: MujiStyle.clay.opacity(0.12), radius: 6, x: 0, y: 3)
        }
        .frame(width: 28, height: 24)
        .allowsHitTesting(false)
    }

    private func barColor(_ index: Int) -> Color {
        switch index {
        case 0: return MujiStyle.clay
        case 1: return MujiStyle.tea
        default: return MujiStyle.indigo
        }
    }

    private func barHeight(_ index: Int, at date: Date) -> CGFloat {
        guard isAnimating else {
            return [CGFloat(10), 15, 8][index]
        }

        let phase = date.timeIntervalSinceReferenceDate * 3.2 + Double(index) * 0.8
        let wave = (sin(phase) + 1) * 0.5
        return 7 + CGFloat(wave) * 11
    }
}

struct MujiActionPill: View {
    let title: String
    let icon: MonologueIcon.IconType
    var selected: Bool = false
    var tint: Color = MujiStyle.clay

    var body: some View {
        HStack(spacing: 7) {
            MonologueIcon(icon: icon, size: 13, color: selected ? MujiStyle.onTint : tint, lineWidth: 1.5)
            Text(title)
                .font(MujiStyle.labelFont(12, weight: .semibold))
                .foregroundStyle(selected ? MujiStyle.onTint : MujiStyle.ink)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(selected ? tint : MujiStyle.surface.opacity(0.78), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(selected ? tint.opacity(0.0) : MujiStyle.hairline.opacity(0.48), lineWidth: 0.6)
        )
    }
}

struct MujiListDivider: View {
    var body: some View {
        Rectangle()
            .fill(MujiStyle.separator.opacity(0.72))
            .frame(height: 0.6)
    }
}

struct MujiPill: View {
    let text: String
    var tint: Color = MujiStyle.clay

    var body: some View {
        Text(text)
            .font(MujiStyle.labelFont(10, weight: .semibold))
            .foregroundStyle(tint)
            .tracking(0.8)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(tint.opacity(0.09), in: Capsule())
            .overlay(Capsule().stroke(tint.opacity(0.28), lineWidth: 0.6))
    }
}

struct MujiPageSurface<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            MujiRootBackdrop()
            content
        }
        .tint(MujiStyle.clay)
    }
}

extension View {
    @ViewBuilder
    func mujiSurfaceIfNeeded() -> some View {
        if MujiStyle.isActive {
            MujiPageSurface { self }
        } else {
            self
        }
    }

    func mujiCard(cornerRadius: CGFloat = MujiStyle.cardRadius, elevated: Bool = false) -> some View {
        background(MujiPaperCardBackground(cornerRadius: cornerRadius, elevated: elevated))
    }
}
