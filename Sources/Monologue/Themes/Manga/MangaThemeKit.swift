import SwiftUI

enum MangaStyle {
    static var isActive: Bool {
        UserDefaults.standard.string(forKey: "globalThemeId") == GlobalThemeId.manga.rawValue
    }

    static let ink = Color(light: Color(hex: "17151F"), dark: Color(hex: "F5F0E8"))
    static let inkSub = Color(light: Color(hex: "595260"), dark: Color(hex: "B8B0BE"))
    static let inkMuted = Color(light: Color(hex: "8A8190"), dark: Color(hex: "756D7B"))
    static let paper = Color(light: Color(hex: "FFF3D7"), dark: Color(hex: "121018"))
    static let paperWarm = Color(light: Color(hex: "FFE5B8"), dark: Color(hex: "1F1724"))
    static let paperCool = Color(light: Color(hex: "E8F1FF"), dark: Color(hex: "142033"))
    static let surface = Color(light: Color(hex: "FFF9E9"), dark: Color(hex: "1B1822"))
    static let bubbleWhite = Color(light: Color(hex: "FFFDF5"), dark: Color(hex: "231F2A"))
    static let bubblePink = Color(light: Color(hex: "FFD6E4"), dark: Color(hex: "3A1C2A"))
    static let bubbleBlue = Color(light: Color(hex: "D5EAFF"), dark: Color(hex: "192D42"))
    static let labelYellow = Color(light: Color(hex: "FFE067"), dark: Color(hex: "F0C64F"))
    static let accentPink = Color(light: Color(hex: "FF4F84"), dark: Color(hex: "FF7AA1"))
    static let decoBlue = Color(light: Color(hex: "58B9FF"), dark: Color(hex: "75C8FF"))
    static let mint = Color(light: Color(hex: "8DE4B8"), dark: Color(hex: "5CD49C"))
    static let red = Color(light: Color(hex: "F04452"), dark: Color(hex: "FF5A66"))
    static let separator = Color(light: Color(hex: "241F2B").opacity(0.18), dark: Color(hex: "F7EFE5").opacity(0.18))

    static let cardRadius: CGFloat = 14
    static let buttonRadius: CGFloat = 11
    static let strokeWidth: CGFloat = 2.2
    static let fineStrokeWidth: CGFloat = 1.4
    static let shadowOffset: CGFloat = 3

    static func titleFont(_ size: CGFloat, weight: Font.Weight = .black) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func bodyFont(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func labelFont(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func comicFont(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

struct MangaRootBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [MangaStyle.paper, MangaStyle.paperWarm.opacity(0.78), MangaStyle.paperCool.opacity(0.72)]
                    : [MangaStyle.paper, MangaStyle.surface, MangaStyle.paperWarm.opacity(0.78)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            MangaPaperGrainTexture(opacity: colorScheme == .dark ? 0.05 : 0.07)
            MangaDotsTexture(opacity: colorScheme == .dark ? 0.025 : 0.035, gap: 18)
        }
        .ignoresSafeArea()
    }
}

struct MangaPaperGrainTexture: View {
    @Environment(\.colorScheme) private var colorScheme
    var opacity: Double = 0.06

    var body: some View {
        Canvas { context, size in
            let color = (colorScheme == .dark ? Color.white : MangaStyle.ink).opacity(opacity)
            let count = max(Int((size.width * size.height) / 520), 80)

            for index in 0..<count {
                let xSeed = CGFloat((index * 37) % 997) / 997
                let ySeed = CGFloat((index * 53) % 991) / 991
                let x = xSeed * size.width
                let y = ySeed * size.height
                let side = CGFloat((index % 3) + 1) * 0.55

                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: side, height: side)),
                    with: .color(color.opacity(index % 4 == 0 ? 0.5 : 1))
                )
            }
        }
        .allowsHitTesting(false)
    }
}

struct MangaDotsTexture: View {
    @Environment(\.colorScheme) private var colorScheme
    var opacity: Double = 0.08
    var gap: CGFloat = 13

    var body: some View {
        Canvas { context, size in
            let dotRadius: CGFloat = 0.9
            let dotColor = (colorScheme == .dark ? Color.white : MangaStyle.ink).opacity(opacity)
            var y = gap / 2
            var stagger = false

            while y < size.height + gap {
                var x = stagger ? gap : gap / 2
                while x < size.width + gap {
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - dotRadius, y: y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)),
                        with: .color(dotColor)
                    )
                    x += gap
                }
                y += gap
                stagger.toggle()
            }
        }
        .allowsHitTesting(false)
    }
}

struct MangaPageGridTexture: View {
    @Environment(\.colorScheme) private var colorScheme
    var opacity: Double = 0.16

    var body: some View {
        Canvas { context, size in
            let color = (colorScheme == .dark ? Color.white : MangaStyle.ink).opacity(opacity)
            let widths: [CGFloat] = [0.7, 1.1, 0.7, 1.6]

            for index in 0..<5 {
                let x = size.width * CGFloat(index + 1) / 6
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x - 24 + CGFloat(index * 8), y: size.height))
                context.stroke(path, with: .color(color.opacity(index == 2 ? 0.45 : 0.28)), lineWidth: widths[index % widths.count])
            }

            for index in 0..<6 {
                let y = size.height * CGFloat(index + 1) / 7
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y + CGFloat(index % 2 == 0 ? 16 : -10)))
                context.stroke(path, with: .color(color.opacity(0.18)), lineWidth: widths[(index + 1) % widths.count])
            }
        }
        .allowsHitTesting(false)
    }
}

struct MangaSpeedLineTexture: View {
    var opacity: Double = 0.12

    var body: some View {
        Canvas { context, size in
            let origin = CGPoint(x: size.width * 0.86, y: -28)
            let lines = 16
            for index in 0..<lines {
                let endX = size.width * CGFloat(index) / CGFloat(max(lines - 1, 1))
                var path = Path()
                path.move(to: origin)
                path.addLine(to: CGPoint(x: endX, y: size.height))
                context.stroke(
                    path,
                    with: .color(MangaStyle.ink.opacity(opacity * (index % 3 == 0 ? 1 : 0.55))),
                    lineWidth: index % 4 == 0 ? 1.6 : 0.7
                )
            }
        }
        .allowsHitTesting(false)
        .blendMode(.multiply)
    }
}

struct MangaCardBackground: View {
    var cornerRadius: CGFloat = MangaStyle.cardRadius
    var elevated: Bool = false
    var tint: Color? = nil

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(MangaStyle.ink)
                .offset(x: MangaStyle.shadowOffset, y: MangaStyle.shadowOffset)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(tint ?? (elevated ? MangaStyle.bubbleWhite : MangaStyle.surface))

            MangaDotsTexture(opacity: elevated ? 0.024 : 0.016, gap: 12)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(MangaStyle.ink, lineWidth: MangaStyle.strokeWidth)
        }
    }
}

enum MangaSectionMarkKind {
    case star
    case heart
}

struct MangaSectionTitle: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?
    var mark: MangaSectionMarkKind

    init(
        title: String,
        actionTitle: String? = nil,
        mark: MangaSectionMarkKind = .star,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.actionTitle = actionTitle
        self.mark = mark
        self.action = action
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            MangaSectionMark(kind: mark)

            Text(title)
                .font(MangaStyle.titleFont(18, weight: .black))
                .foregroundStyle(MangaStyle.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Rectangle()
                .fill(MangaStyle.ink.opacity(0.22))
                .frame(height: 1.4)

            if let actionTitle, let action {
                Button(action: action) {
                    MangaLabel(text: actionTitle, tint: MangaStyle.decoBlue, small: true)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct MangaSectionMark: View {
    var kind: MangaSectionMarkKind = .star
    var tint: Color = MangaStyle.labelYellow
    var size: CGFloat = 24

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                .fill(tint)
                .rotationEffect(.degrees(-8))

            Image(systemName: kind == .heart ? "heart.fill" : "star.fill")
                .font(.system(size: size * 0.48, weight: .black))
                .foregroundStyle(MangaStyle.ink)
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                .stroke(MangaStyle.ink, lineWidth: 1.35)
                .rotationEffect(.degrees(-8))
        )
        .background(
            RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                .fill(MangaStyle.ink)
                .rotationEffect(.degrees(-8))
                .offset(x: 1.8, y: 1.8)
        )
    }
}

struct MangaLabel: View {
    let text: String
    var tint: Color = MangaStyle.labelYellow
    var small: Bool = false

    var body: some View {
        Text(text)
            .font(MangaStyle.labelFont(small ? 10 : 11))
            .foregroundStyle(MangaStyle.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, small ? 9 : 11)
            .padding(.vertical, small ? 5 : 6)
            .background(Capsule().fill(tint))
            .overlay(Capsule().stroke(MangaStyle.ink, lineWidth: MangaStyle.fineStrokeWidth))
            .background(Capsule().fill(MangaStyle.ink).offset(x: 2, y: 2))
    }
}

struct MangaIconBadge: View {
    let systemName: String
    var size: CGFloat = 44
    var tint: Color = MangaStyle.decoBlue

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.38, weight: .black))
            .foregroundColor(MangaStyle.ink)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .fill(tint)
            )
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .stroke(MangaStyle.ink, lineWidth: MangaStyle.strokeWidth)
            )
            .background(
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .fill(MangaStyle.ink)
                    .offset(x: 2.5, y: 2.5)
            )
    }
}

struct MangaActionButton: View {
    let systemName: String
    var tint: Color = MangaStyle.bubbleWhite
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .black))
                .foregroundColor(MangaStyle.ink)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous)
                        .fill(tint)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous)
                        .stroke(MangaStyle.ink, lineWidth: MangaStyle.strokeWidth)
                )
                .background(
                    RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous)
                        .fill(MangaStyle.ink)
                        .offset(x: 2.5, y: 2.5)
                )
        }
        .buttonStyle(.plain)
    }
}

struct MangaPageHeader<Accessory: View>: View {
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
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                MangaLabel(text: eyebrow, tint: MangaStyle.labelYellow, small: true)

                Text(title)
                    .font(MangaStyle.titleFont(28, weight: .black))
                    .foregroundStyle(MangaStyle.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.76)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(MangaStyle.bodyFont(13, weight: .bold))
                        .foregroundStyle(MangaStyle.inkSub)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 12)
            accessory
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 8)
        .padding(.bottom, 12)
    }
}

extension MangaPageHeader where Accessory == EmptyView {
    init(eyebrow: String, title: String, subtitle: String) {
        self.init(eyebrow: eyebrow, title: title, subtitle: subtitle) {
            EmptyView()
        }
    }
}

struct MangaNowPlayingIndicator: View {
    var isAnimating: Bool = true

    var body: some View {
        TimelineView(.animation) { timeline in
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(barColor(index))
                        .frame(width: 3.5, height: barHeight(index, at: timeline.date))
                }
            }
            .frame(width: 32, height: 26)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(MangaStyle.bubbleWhite)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(MangaStyle.ink, lineWidth: 1.5)
            )
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(MangaStyle.ink)
                    .offset(x: 1.5, y: 1.5)
            )
        }
        .frame(width: 32, height: 26)
        .allowsHitTesting(false)
    }

    private func barColor(_ index: Int) -> Color {
        switch index {
        case 0: return MangaStyle.accentPink
        case 1: return MangaStyle.labelYellow
        case 2: return MangaStyle.decoBlue
        default: return MangaStyle.mint
        }
    }

    private func barHeight(_ index: Int, at date: Date) -> CGFloat {
        guard isAnimating else {
            return [CGFloat(9), 14, 18, 11][index]
        }
        let phase = date.timeIntervalSinceReferenceDate * 3.4 + Double(index) * 0.64
        let wave = (sin(phase) + 1) * 0.5
        return 7 + CGFloat(wave) * 13
    }
}

struct MangaListDivider: View {
    var body: some View {
        Rectangle()
            .fill(MangaStyle.ink.opacity(0.2))
            .frame(height: 1.4)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(MangaStyle.bubbleWhite.opacity(0.55))
                    .frame(height: 0.6)
                    .offset(y: 1)
            }
    }
}

struct MangaPageSurface<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            MangaRootBackdrop()
            content
        }
        .tint(MangaStyle.accentPink)
    }
}

extension View {
    @ViewBuilder
    func mangaSurfaceIfNeeded() -> some View {
        if MangaStyle.isActive {
            MangaPageSurface { self }
        } else {
            self
        }
    }

    func mangaCard(cornerRadius: CGFloat = MangaStyle.cardRadius, elevated: Bool = false) -> some View {
        background(MangaCardBackground(cornerRadius: cornerRadius, elevated: elevated))
    }

    func mangaStagger(_ appeared: Bool, order: Int) -> some View {
        self
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 14)
            .scaleEffect(appeared ? 1 : 0.97)
            .animation(
                .spring(response: 0.48, dampingFraction: 0.76).delay(Double(order) * 0.045),
                value: appeared
            )
    }
}

struct MangaMetricTile: View {
    let value: String
    let label: String
    var tint: Color = MangaStyle.decoBlue

    var body: some View {
        VStack(spacing: 5) {
            Text(value)
                .font(MangaStyle.comicFont(20, weight: .black))
                .foregroundColor(MangaStyle.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.76)

            Text(label)
                .font(MangaStyle.comicFont(10, weight: .bold))
                .foregroundColor(MangaStyle.inkSub)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(tint.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(MangaStyle.ink, lineWidth: MangaStyle.fineStrokeWidth)
        )
    }
}

struct MangaBurstMark: View {
    var tint: Color = MangaStyle.labelYellow
    var kind: MangaSectionMarkKind = .star

    var body: some View {
        MangaSectionMark(kind: kind, tint: tint)
    }
}

struct MangaBurstShape: Shape {
    let points: Int
    let innerRatio: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) * 0.5
        let inner = outer * innerRatio
        let count = max(points, 3) * 2

        for index in 0..<count {
            let radius = index.isMultiple(of: 2) ? outer : inner
            let angle = -CGFloat.pi / 2 + CGFloat(index) * CGFloat.pi * 2 / CGFloat(count)
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        path.closeSubpath()
        return path
    }
}
