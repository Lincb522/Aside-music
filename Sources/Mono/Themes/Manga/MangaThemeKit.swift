import SwiftUI

/// 漫画主题的兼容 Token。保留最初漫画播放主题的粉、黄、蓝色板。
enum MangaStyle {
    static var isActive: Bool {
        GlobalThemeId.persistedOrDefault == .manga
    }

    static let ink = Color(light: Color(hex: "2D2D3A"), dark: Color(hex: "E8E8EF"))
    static let inkSub = Color(light: Color(hex: "8888A0"), dark: Color(hex: "8A8A9E"))
    static let inkMuted = Color(light: Color(hex: "A5A5B5"), dark: Color(hex: "67677A"))
    static var strokeInk: Color { ink }
    static let strokeInkMuted = Color(light: Color(hex: "8888A0"), dark: Color(hex: "4A4A5B"))
    static var onStrokeInk: Color { Color(light: Color.white, dark: Color(hex: "F5F5FA")) }

    static var paper: Color { Color(light: Color(hex: "FFF8EC"), dark: Color(hex: "0B0E17")) }
    static let paperWarm = Color(light: Color(hex: "FDE8F0"), dark: Color(hex: "121828"))
    static let paperCool = Color(light: Color(hex: "E8F4FD"), dark: Color(hex: "16243A"))
    static let surface = Color(light: Color(hex: "FFF8EC"), dark: Color(hex: "171923"))
    static let bubbleWhite = Color(light: Color.white, dark: Color(hex: "1F1F2A"))
    static let bubblePink = Color(light: Color(hex: "FFE8F0"), dark: Color(hex: "2E1D25"))
    static let bubbleBlue = Color(light: Color(hex: "E8F0FF"), dark: Color(hex: "1E2530"))
    static var labelYellow: Color { Color(light: Color(hex: "FFE4B5"), dark: Color(hex: "E6BD76")) }
    static var accentPink: Color { Color(light: Color(hex: "FF8FAB"), dark: Color(hex: "D86782")) }
    static var decoBlue: Color { Color(light: Color(hex: "B8D4F0"), dark: Color(hex: "6A98BD")) }
    static var mint: Color { Color(light: Color(hex: "CEF09D"), dark: Color(hex: "6B9650")) }
    static let red = Color(light: Color(hex: "F04452"), dark: Color(hex: "D64D58"))
    static let separator = Color(light: Color(hex: "2D2D3A").opacity(0.18), dark: Color(hex: "E8E8EF").opacity(0.18))

    static let cardRadius: CGFloat = 14
    static let buttonRadius: CGFloat = 11
    static let strokeWidth: CGFloat = 2.2
    static let fineStrokeWidth: CGFloat = 1.4
    static let shadowOffset: CGFloat = 3
    /// 页面级规则线的墨色浓度
    static let ruleOpacity: Double = 0.8

    // ── 印刷字体：标题用锐利黑体，气泡用圆体 ──

    static func titleFont(_ size: CGFloat, weight: Font.Weight = .black) -> Font {
        MangaComicPalette.displayFont(size)
    }

    static func bodyFont(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func labelFont(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func comicFont(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - 背景

struct MangaRootBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        let _ = settings.globalThemeRevision
        ZStack {
            ThemeCustomDiffuseBackground(
                theme: .manga,
                fallbackHexes: colorScheme == .dark ? ["121018", "142033"] : ["FFF3D7", "E8F1FF"],
                accentFallbackHexes: ["FF4F84", "FFE067"],
                opacity: colorScheme == .dark ? 0.76 : 0.95
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
            let color = (colorScheme == .dark ? MangaStyle.ink : MangaStyle.strokeInk).opacity(opacity)
            let count = max(Int((size.width * size.height) / 520), 80)

            for index in 0 ..< count {
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

/// 旧纸斑纹：大块不规则灰渍 + 散落墨点飞溅（确定性伪随机，无动画开销）
struct MangaAgedPaperTexture: View {
    @Environment(\.colorScheme) private var colorScheme
    var opacity: Double = 0.12

    var body: some View {
        Canvas { context, size in
            let stain = Color(hex: colorScheme == .dark ? "3A382F" : "8B867B")

            // 大块灰渍：多圈同心椭圆叠出边缘不均匀的旧纸痕
            let blotches: [(x: CGFloat, y: CGFloat, r: CGFloat, alpha: Double)] = [
                (0.08, 0.12, 90, 0.35), (0.86, 0.3, 120, 0.28), (0.24, 0.52, 70, 0.3),
                (0.7, 0.68, 100, 0.33), (0.12, 0.86, 85, 0.3), (0.92, 0.9, 75, 0.35),
                (0.48, 0.28, 55, 0.22), (0.55, 0.94, 60, 0.26),
            ]
            for blotch in blotches {
                let center = CGPoint(x: blotch.x * size.width, y: blotch.y * size.height)
                for ring in 0 ..< 3 {
                    let radius = blotch.r * (1 - CGFloat(ring) * 0.26)
                    let wobbleX = CGFloat((ring * 17) % 13) - 6
                    let wobbleY = CGFloat((ring * 29) % 11) - 5
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: center.x - radius + wobbleX,
                            y: center.y - radius * 0.82 + wobbleY,
                            width: radius * 2,
                            height: radius * 1.64
                        )),
                        with: .color(stain.opacity(opacity * blotch.alpha / Double(ring + 2)))
                    )
                }
            }

            // 墨点飞溅：小簇浓点
            let ink = (colorScheme == .dark ? MangaStyle.ink : MangaStyle.strokeInk)
            for index in 0 ..< 46 {
                let xSeed = CGFloat((index * 131) % 977) / 977
                let ySeed = CGFloat((index * 197) % 983) / 983
                let radius = CGFloat((index % 4)) * 0.7 + 0.8
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: xSeed * size.width,
                        y: ySeed * size.height,
                        width: radius,
                        height: radius
                    )),
                    with: .color(ink.opacity(opacity * (index % 3 == 0 ? 0.75 : 0.4)))
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
            let dotColor = (colorScheme == .dark ? MangaStyle.ink : MangaStyle.strokeInk).opacity(opacity)
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

/// 网点渐晕：从角落向外、点径递减的网点圆域
struct MangaHalftoneCorner: View {
    @Environment(\.colorScheme) private var colorScheme
    var opacity: Double = 0.08
    var extent: CGFloat = 260

    var body: some View {
        Canvas { context, size in
            let color = (colorScheme == .dark ? MangaStyle.ink : MangaStyle.strokeInk).opacity(opacity)
            let origin = CGPoint(x: size.width, y: 0)
            let gap: CGFloat = 11

            var y: CGFloat = gap / 2
            var stagger = false
            while y < extent {
                var x = size.width - (stagger ? gap : gap / 2)
                while x > size.width - extent {
                    let distance = hypot(x - origin.x, y - origin.y)
                    guard distance < extent else {
                        x -= gap
                        continue
                    }
                    let ratio = max(0, 1 - distance / extent)
                    let radius = 0.6 + ratio * 1.9
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                        with: .color(color)
                    )
                    x -= gap
                }
                y += gap
                stagger.toggle()
            }
        }
        .frame(width: extent, height: extent)
        .allowsHitTesting(false)
    }
}

struct MangaPageGridTexture: View {
    @Environment(\.colorScheme) private var colorScheme
    var opacity: Double = 0.16

    var body: some View {
        Canvas { context, size in
            let color = (colorScheme == .dark ? MangaStyle.ink : MangaStyle.strokeInk).opacity(opacity)
            let widths: [CGFloat] = [0.7, 1.1, 0.7, 1.6]

            for index in 0 ..< 5 {
                let x = size.width * CGFloat(index + 1) / 6
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x - 24 + CGFloat(index * 8), y: size.height))
                context.stroke(path, with: .color(color.opacity(index == 2 ? 0.45 : 0.28)), lineWidth: widths[index % widths.count])
            }

            for index in 0 ..< 6 {
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
            for index in 0 ..< lines {
                let endX = size.width * CGFloat(index) / CGFloat(max(lines - 1, 1))
                var path = Path()
                path.move(to: origin)
                path.addLine(to: CGPoint(x: endX, y: size.height))
                context.stroke(
                    path,
                    with: .color(MangaStyle.strokeInk.opacity(opacity * (index % 3 == 0 ? 1 : 0.55))),
                    lineWidth: index % 4 == 0 ? 1.6 : 0.7
                )
            }
        }
        .allowsHitTesting(false)
        .blendMode(.multiply)
    }
}

// MARK: - 分格面板

struct MangaCardBackground: View {
    var cornerRadius: CGFloat = MangaStyle.cardRadius
    var elevated: Bool = false
    var tint: Color? = nil
    /// 海报级焦点面板：在标准漫画分格之上再加网点纹理
    var poster: Bool = false

    var body: some View {
        let radius = min(cornerRadius, MangaStyle.cardRadius + 6)
        let shape = MangaComicPanelShape(corner: radius)
        let bold = elevated || poster

        ZStack {
            if bold {
                shape
                    .fill(MangaStyle.strokeInk)
                    .offset(x: MangaStyle.shadowOffset, y: MangaStyle.shadowOffset)
            }

            shape.fill(tint ?? (bold ? MangaStyle.bubbleWhite : MangaStyle.surface.opacity(0.62)))

            if poster {
                MangaScreentone(opacity: 0.05, gap: 9)
                    .clipShape(shape)
            }

            if bold {
                shape.stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.strokeWidth)
                shape
                    .stroke(MangaStyle.strokeInk, lineWidth: 1)
                    .padding(5)
            } else {
                shape.stroke(MangaStyle.strokeInk.opacity(0.5), lineWidth: MangaStyle.fineStrokeWidth)
            }
        }
        .themeRenderSurfaceLayer()
    }
}

enum MangaSectionMarkKind {
    case star
    case heart
    case note
}

/// 章节式区块标题：爆炸气泡角标 + 大黑体标题 + 墨块「查看全部」章贴
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
            MangaSectionMark(kind: mark, size: 30)

            MangaMisprintTitle(text: title, size: 21)
                .lineLimit(1)

            Spacer(minLength: 10)

            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: 3) {
                        Text(actionTitle)
                            .font(MangaStyle.labelFont(11, weight: .black))
                        MonoIcon(icon: .chevronRight, size: 8, color: onLabel, lineWidth: 2.2)
                    }
                    .foregroundStyle(onLabel)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        MangaComicCutCornerShape(cut: MangaStyle.buttonRadius - 2)
                            .fill(MangaStyle.labelYellow)
                    )
                    .overlay(
                        MangaComicCutCornerShape(cut: MangaStyle.buttonRadius - 2)
                            .stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.fineStrokeWidth)
                    )
                    .background(
                        MangaComicCutCornerShape(cut: MangaStyle.buttonRadius - 2)
                            .fill(MangaComicPalette.toneMid)
                            .offset(x: 1.8, y: 1.8)
                    )
                    .rotationEffect(.degrees(1.6))
                }
                .buttonStyle(MonoBouncingButtonStyle())
            }
        }
    }

    private var onLabel: Color {
        MangaComicPalette.whiteInk
    }
}

/// 区块角标：墨色爆炸气泡 + 反白图形，背后压一层网点灰错版
struct MangaSectionMark: View {
    var kind: MangaSectionMarkKind = .star
    var tint: Color = MangaStyle.labelYellow
    var size: CGFloat = 24
    var foreground: Color?
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        let _ = settings.globalThemeRevision
        ZStack {
            MangaBurstShape(points: 9, innerRatio: 0.78)
                .fill(MangaStyle.strokeInk)
                .rotationEffect(.degrees(-8))

            if kind == .heart {
                MangaRoundedHeartShape()
                    .fill(resolvedForeground)
                    .frame(width: size * 0.44, height: size * 0.44)
                    .rotationEffect(.degrees(-8))
            } else if kind == .note {
                Text("♪")
                    .font(.system(size: size * 0.42, weight: .black))
                    .foregroundStyle(resolvedForeground)
                    .rotationEffect(.degrees(-8))
            } else {
                MangaRoundedStarShape()
                    .fill(resolvedForeground)
                    .frame(width: size * 0.44, height: size * 0.44)
                    .rotationEffect(.degrees(-8))
            }
        }
        .frame(width: size, height: size)
        .background(
            // 网点灰错版：偏移的印刷残影
            MangaBurstShape(points: 9, innerRatio: 0.78)
                .fill(MangaComicPalette.toneLight)
                .rotationEffect(.degrees(4))
                .offset(x: 2.4, y: 2.4)
        )
    }

    private var resolvedForeground: Color {
        foreground ?? MangaStyle.onStrokeInk
    }
}

/// 手绘墨涂线：标题下的粗糙双笔划底线
struct MangaScribbleUnderline: View {
    var tint: Color = MangaStyle.ink

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            var first = Path()
            first.move(to: CGPoint(x: 0, y: h * 0.42))
            first.addCurve(
                to: CGPoint(x: w, y: h * 0.3),
                control1: CGPoint(x: w * 0.32, y: h * 0.02),
                control2: CGPoint(x: w * 0.7, y: h * 0.62)
            )
            context.stroke(first, with: .color(tint), style: StrokeStyle(lineWidth: h * 0.34, lineCap: .round))

            var second = Path()
            second.move(to: CGPoint(x: w * 0.06, y: h * 0.86))
            second.addCurve(
                to: CGPoint(x: w * 0.66, y: h * 0.74),
                control1: CGPoint(x: w * 0.26, y: h * 1.05),
                control2: CGPoint(x: w * 0.48, y: h * 0.58)
            )
            context.stroke(second, with: .color(tint.opacity(0.9)), style: StrokeStyle(lineWidth: h * 0.24, lineCap: .round))
        }
        .allowsHitTesting(false)
    }
}

struct MangaRoundedHeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let x = rect.minX
        let y = rect.minY

        path.move(to: CGPoint(x: x + w * 0.5, y: y + h * 0.88))
        path.addCurve(
            to: CGPoint(x: x + w * 0.08, y: y + h * 0.34),
            control1: CGPoint(x: x + w * 0.24, y: y + h * 0.68),
            control2: CGPoint(x: x + w * 0.05, y: y + h * 0.55)
        )
        path.addCurve(
            to: CGPoint(x: x + w * 0.5, y: y + h * 0.26),
            control1: CGPoint(x: x + w * 0.08, y: y + h * 0.09),
            control2: CGPoint(x: x + w * 0.36, y: y + h * 0.08)
        )
        path.addCurve(
            to: CGPoint(x: x + w * 0.92, y: y + h * 0.34),
            control1: CGPoint(x: x + w * 0.64, y: y + h * 0.08),
            control2: CGPoint(x: x + w * 0.92, y: y + h * 0.09)
        )
        path.addCurve(
            to: CGPoint(x: x + w * 0.5, y: y + h * 0.88),
            control1: CGPoint(x: x + w * 0.95, y: y + h * 0.55),
            control2: CGPoint(x: x + w * 0.76, y: y + h * 0.68)
        )
        path.closeSubpath()
        return path
    }
}

struct MangaRoundedStarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) * 0.48
        let inner = outer * 0.56
        let points = (0 ..< 10).map { index -> CGPoint in
            let radius = index.isMultiple(of: 2) ? outer : inner
            let angle = CGFloat(index) * .pi / 5 - .pi / 2
            return CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
        }

        var path = Path()
        for index in points.indices {
            let previous = points[(index - 1 + points.count) % points.count]
            let current = points[index]
            let next = points[(index + 1) % points.count]
            let smoothing: CGFloat = index.isMultiple(of: 2) ? 0.22 : 0.28
            let start = CGPoint(
                x: current.x + (previous.x - current.x) * smoothing,
                y: current.y + (previous.y - current.y) * smoothing
            )
            let end = CGPoint(
                x: current.x + (next.x - current.x) * smoothing,
                y: current.y + (next.y - current.y) * smoothing
            )

            if index == 0 {
                path.move(to: start)
            } else {
                path.addLine(to: start)
            }
            path.addQuadCurve(to: end, control: current)
        }
        path.closeSubpath()
        return path
    }
}

/// 话数标签：墨块反白贴纸（描边 + 网点灰错版，像手工贴上去的）
struct MangaLabel: View {
    let text: String
    var tint: Color = MangaStyle.labelYellow
    var small: Bool = false
    var foreground: Color?
    /// 气泡尾巴：问候语等对话气泡式标签
    var tail: Bool = false
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        let _ = settings.globalThemeRevision
        let shape = MangaComicCutCornerShape(cut: small ? 4 : 5)

        Text(text)
            .font(MangaStyle.labelFont(small ? 10 : 11))
            .tracking(0.4)
            .foregroundStyle(resolvedForeground)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, small ? 8 : 10)
            .padding(.vertical, small ? 4 : 5)
            .frame(minHeight: small ? 22 : 26)
            .background(shape.fill(tint))
            .overlay(shape.stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.fineStrokeWidth))
            .overlay(alignment: .bottomLeading) {
                if tail {
                    MangaBubbleTailShape()
                        .fill(tint)
                        .overlay(
                            MangaBubbleTailShape()
                                .stroke(MangaStyle.strokeInk, lineWidth: 1.1)
                        )
                        .frame(width: 9, height: 8)
                        .offset(x: 9, y: 6.5)
                }
            }
            .background(
                shape
                    .fill(MangaComicPalette.toneMid)
                    .offset(x: 1.6, y: 1.6)
            )
            .compositingGroup()
    }

    private var resolvedForeground: Color {
        if let foreground { return foreground }
        if tint == MangaStyle.accentPink || tint == MangaStyle.labelYellow || tint == MangaStyle.decoBlue || tint == MangaStyle.strokeInk {
            return MangaComicPalette.whiteInk
        }
        return MangaComicPalette.ink
    }
}

/// 对话气泡尾巴三角
struct MangaBubbleTailShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct MangaIconBadge: View {
    let icon: MonoIcon.IconType
    var size: CGFloat = 44
    var tint: Color = MangaStyle.decoBlue
    var foreground: Color?
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        let _ = settings.globalThemeRevision
        MonoIcon(icon: icon, size: size * 0.42, color: resolvedForeground, lineWidth: 1.8)
            .frame(width: size, height: size)
            .background(
                MangaComicCutCornerShape(cut: size * 0.16)
                    .fill(tint)
            )
            .overlay(MangaComicCutCornerShape(cut: size * 0.16).stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.fineStrokeWidth))
    }

    private var resolvedForeground: Color {
        if let foreground { return foreground }
        if tint == MangaStyle.accentPink || tint == MangaStyle.labelYellow || tint == MangaStyle.decoBlue || tint == MangaStyle.strokeInk {
            return MangaComicPalette.whiteInk
        }
        return MangaComicPalette.ink
    }
}

struct MangaActionButton: View {
    let icon: MonoIcon.IconType
    var tint: Color = MangaStyle.bubbleWhite
    var foreground: Color = MangaStyle.strokeInk
    /// 设计图里的头部方钮带图标下小字（电台 / 搜索）
    var title: String? = nil
    var action: () -> Void

    var body: some View {
        let shape = MangaComicCutCornerShape(cut: MangaStyle.buttonRadius)

        Button(action: action) {
            VStack(spacing: 3) {
                MonoIcon(icon: icon, size: title == nil ? 18 : 16, color: foreground, lineWidth: 2)

                if let title {
                    Text(title)
                        .font(MangaStyle.labelFont(9, weight: .black))
                        .foregroundStyle(foreground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .frame(width: 48, height: 48)
            .background(shape.fill(tint))
            .overlay(shape.stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.strokeWidth))
            .background(
                shape
                    .fill(MangaStyle.strokeInk)
                    .offset(x: 2.2, y: 2.2)
            )
        }
        .buttonStyle(MonoBouncingButtonStyle())
    }
}

/// 页面标题：话数标签眉题 + 网点灰错版大标题
struct MangaPageHeader<Accessory: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    @ViewBuilder let accessory: Accessory

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                MangaLabel(text: eyebrow, tint: MangaStyle.labelYellow, small: true)

                MangaMisprintTitle(text: title, size: 28)

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
        .monoPageHeaderCollapse()
    }
}

extension MangaPageHeader where Accessory == EmptyView {
    init(eyebrow: String, title: String, subtitle: String) {
        self.init(eyebrow: eyebrow, title: title, subtitle: subtitle) {
            EmptyView()
        }
    }
}

/// 错版标题：墨字背后压一层微偏移的网点灰字，模拟套印偏移
struct MangaMisprintTitle: View {
    let text: String
    var size: CGFloat = 28
    var weight: Font.Weight = .black
    var alignment: TextAlignment = .leading
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        let _ = settings.globalThemeRevision
        ZStack(alignment: leadingAlignment) {
            Text(text)
                .font(MangaStyle.titleFont(size, weight: weight))
                .foregroundStyle(MangaComicPalette.toneLight.opacity(0.9))
                .offset(x: size * 0.07, y: size * 0.07)

            Text(text)
                .font(MangaStyle.titleFont(size, weight: weight))
                .foregroundStyle(MangaStyle.ink)
        }
        .multilineTextAlignment(alignment)
        .lineLimit(2)
        .minimumScaleFactor(0.76)
    }

    private var leadingAlignment: Alignment {
        switch alignment {
        case .center: return .center
        case .trailing: return .trailing
        default: return .leading
        }
    }
}

struct MangaNowPlayingIndicator: View {
    var isAnimating: Bool = true

    var body: some View {
        // 不播放时暂停 timeline 推进，避免进入非激活 tab 后仍然占用主线程
        TimelineView(
            AppFrameRate.animationTimeline(
                maximumFramesPerSecond: 30,
                paused: !isAnimating
            )
        ) { timeline in
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0 ..< 4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(barColor(index))
                        .frame(width: 3.5, height: barHeight(index, at: timeline.date))
                }
            }
            .frame(width: 32, height: 26)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(MangaStyle.bubbleWhite.opacity(0.95))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(MangaStyle.strokeInk, lineWidth: 1.4)
            )
        }
        .frame(width: 32, height: 26)
        .allowsHitTesting(false)
    }

    private func barColor(_ index: Int) -> Color {
        switch index {
        case 0: return MangaStyle.ink
        case 1: return MangaComicPalette.toneMid
        case 2: return MangaStyle.ink.opacity(0.62)
        default: return MangaComicPalette.toneLight
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
            .fill(MangaStyle.strokeInk.opacity(0.24))
            .frame(height: 1.4)
    }
}

/// 印刷双规则线：粗 + 细，用于区块或栏目的上下边界
struct MangaRuleLine: View {
    var heavy: Bool = true

    var body: some View {
        if heavy {
            VStack(spacing: 2.5) {
                Rectangle()
                    .fill(MangaStyle.ink.opacity(0.78))
                    .frame(height: 2)
                Rectangle()
                    .fill(MangaStyle.ink.opacity(0.3))
                    .frame(height: 0.8)
            }
        } else {
            Rectangle()
                .fill(MangaStyle.ink.opacity(0.3))
                .frame(height: 0.8)
        }
    }
}

extension View {
    /// 漫画照片框：墨描边（当前项加粗），封面像贴进分格的插画
    func mangaPhotoFrame(cornerRadius: CGFloat = 4, emphasized: Bool = false) -> some View {
        clipShape(MangaComicPanelShape(corner: cornerRadius))
            .overlay(
                MangaComicPanelShape(corner: cornerRadius)
                    .stroke(
                        MangaStyle.strokeInk,
                        lineWidth: emphasized ? 2.6 : 1.8
                    )
            )
    }

    /// 带硬墨影的照片框：焦点封面（英雄卡、横幅）使用
    func mangaPosterPhotoFrame(cornerRadius: CGFloat = MangaStyle.cardRadius, emphasized: Bool = false) -> some View {
        clipShape(MangaComicPanelShape(corner: cornerRadius))
            .overlay(
                MangaComicPanelShape(corner: cornerRadius)
                    .stroke(
                        MangaStyle.strokeInk,
                        lineWidth: MangaStyle.strokeWidth
                    )
            )
            .background(
                MangaComicPanelShape(corner: cornerRadius)
                    .fill(MangaStyle.strokeInk)
                    .offset(x: MangaStyle.shadowOffset - 0.5, y: MangaStyle.shadowOffset - 0.5)
            )
    }
}

/// 四角星火花：散落在面板边缘的装饰
struct MangaSparkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) * 0.5
        let inner = outer * 0.24

        for index in 0 ..< 8 {
            let radius = index.isMultiple(of: 2) ? outer : inner
            let angle = -CGFloat.pi / 2 + CGFloat(index) * .pi / 4
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

/// 闪电装饰：头部与底栏角落的漫画符号
struct MangaLightningShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: w * 0.62, y: 0))
        path.addLine(to: CGPoint(x: w * 0.12, y: h * 0.56))
        path.addLine(to: CGPoint(x: w * 0.44, y: h * 0.56))
        path.addLine(to: CGPoint(x: w * 0.3, y: h))
        path.addLine(to: CGPoint(x: w * 0.9, y: h * 0.38))
        path.addLine(to: CGPoint(x: w * 0.54, y: h * 0.38))
        path.addLine(to: CGPoint(x: w * 0.88, y: 0))
        path.closeSubpath()
        return path
    }
}

/// 火花点缀：墨描边的四角星
struct MangaSparkDecoration: View {
    var size: CGFloat = 16
    var tint: Color = MangaStyle.bubbleWhite
    var angle: Double = 0

    var body: some View {
        ZStack {
            MangaSparkShape()
                .fill(tint)
            MangaSparkShape()
                .stroke(MangaStyle.strokeInk, lineWidth: 1.4)
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(angle))
        .allowsHitTesting(false)
    }
}

struct MangaPageSurface<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .tint(MangaStyle.accentPink)
            .background {
                MangaRootBackdrop()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
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
        opacity(1)
            .offset(y: appeared ? 0 : 8)
            .scaleEffect(appeared ? 1 : 0.985)
            .animation(
                .spring(response: 0.42, dampingFraction: 0.74).delay(Double(order) * 0.04),
                value: appeared
            )
    }
}

struct MangaMetricTile: View {
    let value: String
    let label: String
    var tint: Color = MangaStyle.ink

    var body: some View {
        // 杂志数据栏式的纯排版统计：墨块短划 + 大数字 + 小标签，无卡片
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(tint)
                .frame(width: 16, height: 4)

            Text(value)
                .font(MangaStyle.titleFont(20, weight: .black))
                .foregroundColor(MangaStyle.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.76)

            Text(label)
                .font(MangaStyle.labelFont(10, weight: .bold))
                .foregroundColor(MangaStyle.inkSub)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
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

        for index in 0 ..< count {
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
