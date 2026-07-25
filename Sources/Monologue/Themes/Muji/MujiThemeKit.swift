import SwiftUI

/// 无印良品主题基座 — 「青苔手帖」文艺清新
///
/// 设计基因：
/// · 青竹绿 + 杏子暖 + 雾蓝，落在微微偏绿的清新米白纸面上；
/// · 不用发丝线、不用描边：分区靠留白、水洗色块（低透明度色浸）与针脚点缀；
/// · 衬线标题保留文艺气质，配圆体小注；圆角放大、阴影极柔，像一册手帖。
enum MujiStyle {
    static var isActive: Bool {
        GlobalThemeId.persistedOrDefault == .muji
    }

    // ── 纸与面 ──

    static var paper: Color {
        ThemeColorCustomization.backgroundBase(for: .muji, fallback: Color(light: Color(hex: "F7F6EF"), dark: Color(hex: "1C1E19")), fallbackHex: "F7F6EF")
    }

    static let surface = Color(light: Color(hex: "FDFCF6"), dark: Color(hex: "262922"))
    static let surfaceRaised = Color(light: Color(hex: "F0EFE4"), dark: Color(hex: "2F332A"))

    // ── 墨 ──

    static let ink = Color(light: Color(hex: "31352B"), dark: Color(hex: "EDEEE3"))
    static let inkSoft = Color(light: Color(hex: "6E7465"), dark: Color(hex: "A9B29D"))
    static let inkMuted = Color(light: Color(hex: "98A08D"), dark: Color(hex: "7A8370"))

    static var onTint: Color {
        // readableForegroundColor 约定:light = 亮底上用的深字,dark = 深底上用的浅字
        ThemeColorCustomization.readableForegroundColor(on: clay, light: Color(hex: "13291C"), dark: Color(hex: "FBFDF8"))
    }

    static let onImage = Color(light: Color(hex: "FDFEF9"), dark: Color(hex: "F4F8EC"))

    // ── 色：青竹绿为主，杏子 / 雾蓝 / 柔黄为辅 ──
    // 注：token 名沿用旧版（clay 即主强调色），避免调用点大改

    static var clay: Color {
        ThemeColorCustomization.accentColor(for: .muji, fallback: Color(light: Color(hex: "5C8A6A"), dark: Color(hex: "8FBF9C")), fallbackHex: "5C8A6A")
    }

    static let tea = Color(light: Color(hex: "C89B66"), dark: Color(hex: "D9B584"))
    static let indigo = Color(light: Color(hex: "6E93A3"), dark: Color(hex: "93B7C6"))
    static let straw = Color(light: Color(hex: "C9AE6B"), dark: Color(hex: "D9C285"))
    static let red = Color(light: Color(hex: "C06B5C"), dark: Color(hex: "D08A7C"))

    /// 分隔色：仅供针脚点缀使用，保持极浅
    static let separator = Color(light: Color(hex: "B9BFA9"), dark: Color(hex: "4A5142"))
    /// 旧发丝线 token：清新版整体弃用描边，此色压到近乎不可见，兼容尚未清理的旧调用点
    static let hairline = Color(light: Color(hex: "C9CDBB").opacity(0.24), dark: Color(hex: "4A5142").opacity(0.3))

    // ── 形 ──

    static let cardRadius: CGFloat = 18
    static let buttonRadius: CGFloat = 12

    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: ThemeColorCustomization.accentGradientColors(
                for: .muji,
                fallback: [clay, tea.opacity(0.92), indigo.opacity(0.8)],
                fallbackHexes: ["5C8A6A", "C89B66"]
            ),
            startPoint: ThemeColorCustomization.gradientStyle(for: .muji, role: .accent).points.start,
            endPoint: ThemeColorCustomization.gradientStyle(for: .muji, role: .accent).points.end
        )
    }

    // ── 字：衬线文题 + 圆体小注 ──

    static func titleFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func bodyFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func labelFont(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    // ── 水洗色块：清新版的容器语言 ──

    /// 低透明度色浸底色（light 稍深、dark 稍亮，保证可感知）
    static func wash(_ tint: Color, strength: Double = 1) -> Color {
        tint.opacity(0.11 * strength)
    }
}

struct MujiRootBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        let _ = settings.globalThemeRevision
        ZStack {
            MujiStyle.paper

            MujiFreshAirBackdrop()

            MujiPaperTexture(opacity: colorScheme == .dark ? 0.1 : 0.2)
        }
        .ignoresSafeArea()
    }
}

/// 清新空气感底色：角落两团极淡的水彩色晕（青竹 + 杏子），像纸上洇开的颜料
struct MujiFreshAirBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let alpha = colorScheme == .dark ? 0.10 : 0.16

            ZStack {
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [MujiStyle.clay.opacity(alpha), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: size.width * 0.62
                        )
                    )
                    .frame(width: size.width * 1.24, height: size.width * 0.9)
                    .position(x: size.width * 0.12, y: -size.width * 0.08)

                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [MujiStyle.tea.opacity(alpha * 0.8), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: size.width * 0.56
                        )
                    )
                    .frame(width: size.width * 1.12, height: size.width * 0.84)
                    .position(x: size.width * 0.96, y: size.height * 1.02)
            }
        }
        .allowsHitTesting(false)
    }
}

/// 纸面肌理：稀疏的细点颗粒，安静的手帖底噪
struct MujiPaperTexture: View {
    var opacity: Double = 0.2

    /// 低电量模式下省掉纹理
    private var isLowPowerMode: Bool {
        ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    var body: some View {
        Canvas { context, size in
            if isLowPowerMode { return }

            let grain = MujiStyle.inkMuted.opacity(opacity)

            // 伪随机散点颗粒
            var seed: UInt64 = 0x9E3779B97F4A7C15
            func next() -> CGFloat {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                return CGFloat((seed >> 33) % 1000) / 1000
            }

            let count = Int(size.width * size.height / 5200)
            for _ in 0 ..< count {
                let x = next() * size.width
                let y = next() * size.height
                let d = 0.7 + next() * 0.9
                let rect = CGRect(x: x, y: y, width: d, height: d)
                context.fill(Path(ellipseIn: rect), with: .color(grain.opacity(0.16 + Double(next()) * 0.2)))
            }
        }
        .allowsHitTesting(false)
    }
}

/// 纸面卡片底：柔和水洗面，无描边，阴影极轻
struct MujiPaperCardBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var cornerRadius: CGFloat = MujiStyle.cardRadius
    var elevated: Bool = false

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(elevated ? MujiStyle.surface : MujiStyle.surfaceRaised.opacity(colorScheme == .dark ? 0.9 : 0.75))
            .shadow(
                color: MujiStyle.ink.opacity(colorScheme == .dark ? 0.0 : (elevated ? 0.06 : 0.03)),
                radius: elevated ? 14 : 8,
                x: 0,
                y: elevated ? 6 : 3
            )
            .themeRenderSurfaceLayer(isEnabled: elevated)
    }
}

/// 针脚线：手帖里的缝线点缀，替代一切发丝分隔线
struct MujiStitchLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

/// 分组标题：双色圆点标记 + 衬线标题 + 水洗胶囊动作
struct MujiSectionTitle: View {
    let title: String
    var detail: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    MujiDotMark()

                    Text(title)
                        .font(MujiStyle.titleFont(19, weight: .medium))
                        .foregroundStyle(MujiStyle.ink)
                        .tracking(0.6)
                }

                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(MujiStyle.labelFont(10.5))
                        .foregroundStyle(MujiStyle.inkMuted)
                        .tracking(0.8)
                        .padding(.leading, 22)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: 4) {
                        Text(actionTitle)
                            .font(MujiStyle.labelFont(10.5, weight: .semibold))
                            .tracking(0.6)

                        MonologueIcon(icon: .chevronRight, size: 8, color: MujiStyle.clay, lineWidth: 1.6)
                    }
                    .foregroundStyle(MujiStyle.clay)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(MujiStyle.wash(MujiStyle.clay), in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// 双色圆点标记：青竹实点 + 杏子小点，手帖里的段落记号
struct MujiDotMark: View {
    var tint: Color = MujiStyle.clay
    var companion: Color = MujiStyle.tea

    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)

            Circle()
                .fill(companion.opacity(0.85))
                .frame(width: 4, height: 4)
        }
    }
}

/// 页面头部：清新刊头 —— 圆点眉题 + 衬线大标题 + 柔和引言
struct MujiPageHeader<Accessory: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    @ViewBuilder let accessory: Accessory

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                MujiDotMark()

                Text(eyebrow.uppercased())
                    .font(MujiStyle.labelFont(10, weight: .semibold))
                    .foregroundStyle(MujiStyle.clay)
                    .tracking(2.2)
                    .fixedSize()
            }

            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(title)
                        .font(MujiStyle.titleFont(30, weight: .medium))
                        .foregroundStyle(MujiStyle.ink)
                        .tracking(0.3)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)

                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(MujiStyle.bodyFont(12.5))
                            .foregroundStyle(MujiStyle.inkSoft)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 10)

                accessory
            }
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 8)
        .padding(.bottom, 12)
        .monologuePageHeaderCollapse()
    }
}

extension MujiPageHeader where Accessory == EmptyView {
    init(eyebrow: String, title: String, subtitle: String) {
        self.init(eyebrow: eyebrow, title: title, subtitle: subtitle) {
            EmptyView()
        }
    }
}

/// 图标记号：水洗圆底 + 着色图标，柔和友好
struct MujiIconBadge: View {
    let icon: MonologueIcon.IconType
    var tint: Color = MujiStyle.clay
    var size: CGFloat = 46
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        let _ = settings.globalThemeRevision
        Circle()
            .fill(MujiStyle.wash(tint, strength: 1.25))
            .frame(width: size, height: size)
            .overlay(
                MonologueIcon(icon: icon, size: size * 0.4, color: tint, lineWidth: 1.5)
            )
    }
}

/// 数据签：水洗圆角底上的衬线数字 + 小注
struct MujiMetricTile: View {
    let value: String
    let label: String
    var tint: Color = MujiStyle.clay

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value)
                .font(MujiStyle.titleFont(22, weight: .medium))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(MujiStyle.labelFont(9.5, weight: .medium))
                .foregroundStyle(MujiStyle.inkSoft)
                .tracking(1.1)
                .textCase(.uppercase)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(MujiStyle.wash(tint))
        )
    }
}

struct MujiNowPlayingIndicator: View {
    var isAnimating: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // 不播放时或减少动画偏好时暂停 timeline 推进
        TimelineView(
            AppFrameRate.animationTimeline(
                maximumFramesPerSecond: 30,
                paused: !isAnimating || reduceMotion
            )
        ) { timeline in
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0 ..< 3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1.4, style: .continuous)
                        .fill(MujiStyle.clay.opacity(isAnimating ? 0.92 : 0.6))
                        .frame(width: 3, height: reduceMotion ? staticBarHeight(index) : barHeight(index, at: timeline.date))
                }
            }
            .frame(width: 28, height: 24)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(MujiStyle.surface.opacity(0.95))
                    .shadow(color: MujiStyle.ink.opacity(0.08), radius: 5, x: 0, y: 2)
            )
        }
        .frame(width: 28, height: 24)
        .allowsHitTesting(false)
    }

    /// reduceMotion 启用时使用静态高度
    private func staticBarHeight(_ index: Int) -> CGFloat {
        [CGFloat(14), 18, 11][index]
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

/// 动作签：水洗胶囊，选中时青竹填色
struct MujiActionPill: View {
    let title: String
    let icon: MonologueIcon.IconType
    var selected: Bool = false
    var tint: Color = MujiStyle.clay
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        let _ = settings.globalThemeRevision
        HStack(spacing: 7) {
            MonologueIcon(icon: icon, size: 13, color: foreground, lineWidth: 1.5)
            Text(title)
                .font(MujiStyle.labelFont(12, weight: .semibold))
                .foregroundStyle(foreground)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(selected ? AnyShapeStyle(tint) : AnyShapeStyle(MujiStyle.wash(tint, strength: 1.1)), in: Capsule())
    }

    private var foreground: Color {
        selected
            ? ThemeColorCustomization.readableForegroundColor(on: tint, light: Color.white, dark: Color(hex: "13291C"))
            : tint
    }
}

/// 针脚分隔：一排细小缝线点，替代旧发丝分隔线
struct MujiListDivider: View {
    var body: some View {
        MujiStitchLine()
            .stroke(
                MujiStyle.separator.opacity(0.55),
                style: StrokeStyle(lineWidth: 1.7, lineCap: .round, dash: [0.1, 8])
            )
            .frame(height: 2)
            .padding(.horizontal, 1)
    }
}

/// 标签：水洗小胶囊 + small caps 文字
struct MujiPill: View {
    let text: String
    var tint: Color = MujiStyle.clay
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        let _ = settings.globalThemeRevision
        Text(text)
            .font(MujiStyle.labelFont(9.5, weight: .semibold))
            .foregroundStyle(tint)
            .tracking(1)
            .textCase(.uppercase)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(MujiStyle.wash(tint, strength: 1.15), in: Capsule())
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
