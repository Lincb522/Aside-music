import SwiftUI

enum MujiStyle {
    static var isActive: Bool {
        UserDefaults.standard.string(forKey: "globalThemeId") == GlobalThemeId.muji.rawValue
    }

    static let paper = Color(light: Color(hex: "F7F1E8"), dark: Color(hex: "171410"))
    static let paperWarm = Color(light: Color(hex: "EFE5D6"), dark: Color(hex: "211B15"))
    static let surface = Color(light: Color(hex: "FFFDF8"), dark: Color(hex: "221D18"))
    static let surfaceRaised = Color(light: Color(hex: "FCF7EF"), dark: Color(hex: "2A241E"))
    static let ink = Color(light: Color(hex: "302B26"), dark: Color(hex: "EEE5D8"))
    static let inkSoft = Color(light: Color(hex: "6F665C"), dark: Color(hex: "B7AA9B"))
    static let inkMuted = Color(light: Color(hex: "9A8F83"), dark: Color(hex: "80766B"))
    static let clay = Color(hex: "B56B4B")
    static let tea = Color(hex: "78846B")
    static let indigo = Color(hex: "56677A")
    static let straw = Color(hex: "D8B56D")
    static let red = Color(hex: "B94E3D")
    static let separator = Color(light: Color(hex: "DED3C4"), dark: Color(hex: "3A3129"))
    static let hairline = Color(light: Color(hex: "CDBFAC"), dark: Color(hex: "51463B"))

    static let cardRadius: CGFloat = 12
    static let buttonRadius: CGFloat = 9

    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [clay, straw.opacity(0.92), tea.opacity(0.82)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
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
    var body: some View {
        ZStack {
            MujiStyle.paper

            LinearGradient(
                colors: [
                    MujiStyle.paperWarm.opacity(0.62),
                    MujiStyle.paper.opacity(0.2),
                    MujiStyle.tea.opacity(0.08),
                    MujiStyle.indigo.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            MujiPaperTexture(opacity: 0.34)
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

            for index in 0..<18 {
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
    var cornerRadius: CGFloat = MujiStyle.cardRadius
    var elevated: Bool = false

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(elevated ? MujiStyle.surface : MujiStyle.surfaceRaised)
            .overlay(MujiPaperTexture(opacity: 0.12).clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(MujiStyle.hairline.opacity(elevated ? 0.72 : 0.54), lineWidth: 0.65)
            )
            .shadow(color: Color.black.opacity(elevated ? 0.075 : 0.045), radius: elevated ? 14 : 8, x: 0, y: elevated ? 7 : 3)
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
    let accessory: Accessory

    init(
        eyebrow: String,
        title: String,
        subtitle: String,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory()
    }

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
                ForEach(0..<3, id: \.self) { index in
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
            MonologueIcon(icon: icon, size: 13, color: selected ? MujiStyle.paper : tint, lineWidth: 1.5)
            Text(title)
                .font(MujiStyle.labelFont(12, weight: .semibold))
                .foregroundStyle(selected ? MujiStyle.paper : MujiStyle.ink)
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
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

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
