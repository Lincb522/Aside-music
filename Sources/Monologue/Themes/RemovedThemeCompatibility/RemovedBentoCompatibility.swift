import SwiftUI

// MARK: - Removed Bento Compatibility

/// Bento 主题已从全局主题入口移除。
/// 这里仅保留历史分支仍引用的轻量 token/组件壳，`isActive` 永远为 false。
enum BentoStyle {
    static var isActive: Bool {
        false
    }

    // ── 底色 ──
    static var paper: Color {
        Color(light: Color(hex: "F5F1EA"), dark: Color(hex: "121211"))
    }

    static let paperWarm = Color(light: Color(hex: "EFE9DD"), dark: Color(hex: "1B1B19"))
    static let surface = Color(light: Color(hex: "FFFFFF"), dark: Color(hex: "232321"))
    static let surfaceRaised = Color(light: Color(hex: "FFFEFC"), dark: Color(hex: "2C2C29"))

    // ── 文字 ──
    static let ink = Color(light: Color(hex: "1A1A18"), dark: Color(hex: "F5F2EC"))
    static let inkSoft = Color(light: Color(hex: "5C5A56"), dark: Color(hex: "C8C4BC"))
    static let inkMuted = Color(light: Color(hex: "8E8B85"), dark: Color(hex: "8F8C86"))
    static let onAccent = Color(light: Color.white, dark: Color(hex: "121211"))

    // ── 模块色（高饱和便当配色，参考日本便当盒子的颜色 + 现代 bento UI 设计） ──
    /// 番茄红 — 主推荐 / 立即播放
    static var tomato: Color {
        Color(light: Color(hex: "E54B3B"), dark: Color(hex: "F26B5B"))
    }
    /// 抹茶绿 — 收藏 / 自然分类
    static let matcha = Color(light: Color(hex: "5E8C44"), dark: Color(hex: "7AAB60"))
    /// 樱花粉 — 新发布 / 推荐
    static let sakura = Color(light: Color(hex: "EE92A8"), dark: Color(hex: "F5A8BA"))
    /// 海蓝 — 排行榜 / 数据
    static let ocean = Color(light: Color(hex: "3D6EA8"), dark: Color(hex: "5C8FCC"))
    /// 芥末黄 — 编辑精选 / 提示
    static let mustard = Color(light: Color(hex: "DDB42E"), dark: Color(hex: "EFC74F"))
    /// 紫菜紫 — Podcast / 长内容
    static let nori = Color(light: Color(hex: "7C5BA0"), dark: Color(hex: "9B7CC0"))
    /// 鲑鱼橙 — 小标签 / 时长
    static let salmon = Color(light: Color(hex: "EB7E48"), dark: Color(hex: "F0975E"))
    /// 荞麦灰 — 中性背景模块
    static let buckwheat = Color(light: Color(hex: "D6CFBF"), dark: Color(hex: "3F3D38"))

    // ── 边框 / 分隔 ──
    static let hairline = Color(light: Color(hex: "DDD5C5"), dark: Color(hex: "3A3935"))
    static let separator = Color(light: Color(hex: "E8E1CF"), dark: Color(hex: "2D2C28"))

    // ── 形状 ──
    static let blockRadius: CGFloat = 24       // 便当格子圆角，强调容器感
    static let blockRadiusLarge: CGFloat = 28
    static let blockRadiusSmall: CGFloat = 18
    static let chipRadius: CGFloat = 14
    static let blockSpacing: CGFloat = 10      // 模块间缝隙，露出底色形成"格子感"
    static let blockPadding: CGFloat = 16

    static let red = tomato

    // ── 字体 ──
    static func displayFont(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func titleFont(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func bodyFont(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func labelFont(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    // ── 渐变（保留以兼容协议） ──
    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [tomato, salmon],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - 根背景

struct BentoRootBackdrop: View {
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        let _ = settings.globalThemeRevision
        BentoStyle.paper
            .ignoresSafeArea()
    }
}

// MARK: - 便当格子（核心容器）

/// Bento Block —— 便当格子的基础容器
/// 特点：大圆角 + 实色填充 + 内边距 + 可选的彩色色带顶饰
struct BentoBlock<Content: View>: View {
    let fill: Color
    let foreground: Color
    let radius: CGFloat
    let padding: CGFloat
    let stroked: Bool
    let content: Content

    init(
        fill: Color = BentoStyle.surface,
        foreground: Color = BentoStyle.ink,
        radius: CGFloat = BentoStyle.blockRadius,
        padding: CGFloat = BentoStyle.blockPadding,
        stroked: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.fill = fill
        self.foreground = foreground
        self.radius = radius
        self.padding = padding
        self.stroked = stroked
        self.content = content()
    }

    var body: some View {
        content
            .foregroundStyle(foreground)
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(BentoStyle.hairline.opacity(stroked ? 0.55 : 0), lineWidth: 0.6)
            )
    }
}

// MARK: - 模块标题（块内顶部小标签）

struct BentoBlockHeader: View {
    let eyebrow: String?
    let title: String
    var titleColor: Color = BentoStyle.ink
    var eyebrowColor: Color = BentoStyle.inkMuted
    var tightSpacing: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: tightSpacing ? 2 : 6) {
            if let eyebrow {
                Text(eyebrow.uppercased())
                    .font(BentoStyle.labelFont(10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(eyebrowColor)
            }
            Text(title)
                .font(BentoStyle.titleFont(20, weight: .heavy))
                .foregroundStyle(titleColor)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
    }
}

// MARK: - 页面外标题（区段大标题，块外）

struct BentoSectionTitle: View {
    let title: String
    var detail: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BentoStyle.titleFont(22, weight: .heavy))
                    .foregroundStyle(BentoStyle.ink)
                    .tracking(-0.2)

                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(BentoStyle.labelFont(12, weight: .medium))
                        .foregroundStyle(BentoStyle.inkMuted)
                }
            }

            Spacer(minLength: 6)

            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: 4) {
                        Text(actionTitle)
                            .font(BentoStyle.labelFont(12, weight: .bold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(BentoStyle.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(BentoStyle.surface, in: Capsule())
                    .overlay(Capsule().stroke(BentoStyle.hairline.opacity(0.55), lineWidth: 0.7))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - 大页头（首页顶部）

struct BentoPageHeader<Accessory: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    @ViewBuilder let accessory: Accessory

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(eyebrow.uppercased())
                    .font(BentoStyle.labelFont(11, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(BentoStyle.tomato)

                Text(title)
                    .font(BentoStyle.displayFont(34, weight: .black))
                    .tracking(-0.5)
                    .foregroundStyle(BentoStyle.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(BentoStyle.bodyFont(13, weight: .medium))
                        .foregroundStyle(BentoStyle.inkSoft)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            accessory
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 6)
        .padding(.bottom, 14)
        .monologuePageHeaderCollapse()
    }
}

extension BentoPageHeader where Accessory == EmptyView {
    init(eyebrow: String, title: String, subtitle: String) {
        self.init(eyebrow: eyebrow, title: title, subtitle: subtitle) {
            EmptyView()
        }
    }
}

// MARK: - 圆形图标 Badge（在彩色模块内部突出显示）

struct BentoIconBadge: View {
    let icon: MonologueIcon.IconType
    var foreground: Color = BentoStyle.ink
    var size: CGFloat = 32

    var body: some View {
        ZStack {
            Circle()
                .fill(foreground.opacity(0.14))
                .frame(width: size, height: size)
            MonologueIcon(icon: icon, size: size * 0.5, color: foreground, lineWidth: 1.6)
        }
    }
}

// MARK: - 模块顶部小标签（block 内）

struct BentoTag: View {
    let text: String
    var color: Color = BentoStyle.ink
    var background: Color? = nil

    var body: some View {
        Text(text.uppercased())
            .font(BentoStyle.labelFont(10, weight: .bold))
            .tracking(1.0)
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 4.5)
            .background(
                Capsule(style: .continuous)
                    .fill(background ?? color.opacity(0.18))
            )
    }
}

// MARK: - 操作按钮（便当风：圆胶囊 + 强对比）

struct BentoPillButton: View {
    let title: String
    var icon: MonologueIcon.IconType? = nil
    var fill: Color = BentoStyle.ink
    var foreground: Color = .white
    var compact: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 6) {
                if let icon {
                    MonologueIcon(icon: icon, size: compact ? 12 : 14, color: foreground, lineWidth: 1.6)
                }
                Text(title)
                    .font(BentoStyle.labelFont(compact ? 12 : 13, weight: .bold))
                    .foregroundStyle(foreground)
                    .lineLimit(1)
            }
            .padding(.horizontal, compact ? 11 : 14)
            .padding(.vertical, compact ? 7 : 9)
            .background(fill, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 数据指标 Tile（用于 stats 区）

struct BentoStatTile: View {
    let value: String
    let label: String
    var tint: Color = BentoStyle.tomato

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(BentoStyle.displayFont(28, weight: .black))
                .tracking(-0.6)
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(label)
                .font(BentoStyle.labelFont(11, weight: .semibold))
                .foregroundStyle(BentoStyle.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - "正在播放"指示器（节拍块）

struct BentoPlayingIndicator: View {
    var color: Color = BentoStyle.ink
    var isAnimating: Bool = true

    var body: some View {
        // 不播放时暂停 timeline 推进
        TimelineView(AppFrameRate.animationTimeline(maximumFramesPerSecond: 30, paused: !isAnimating)) { timeline in
            HStack(alignment: .bottom, spacing: 2.5) {
                ForEach(0 ..< 3, id: \.self) { index in
                    Capsule()
                        .fill(color.opacity(isAnimating ? 0.95 : 0.5))
                        .frame(width: 3.2, height: barHeight(index, at: timeline.date))
                }
            }
            .frame(width: 24, height: 18)
        }
        .allowsHitTesting(false)
    }

    private func barHeight(_ index: Int, at date: Date) -> CGFloat {
        guard isAnimating else {
            return [CGFloat(8), 12, 6][index]
        }
        let phase = date.timeIntervalSinceReferenceDate * 3.6 + Double(index) * 0.95
        let wave = (sin(phase) + 1) * 0.5
        return 5 + CGFloat(wave) * 11
    }
}

// MARK: - 分隔线（块内细线）

struct BentoDivider: View {
    var color: Color = BentoStyle.hairline
    var body: some View {
        Rectangle()
            .fill(color.opacity(0.6))
            .frame(height: 0.6)
    }
}

// MARK: - 按下交互兼容壳

struct BentoPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - 页面整体外壳

struct BentoPageSurface<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            BentoRootBackdrop()
            content
        }
        .tint(BentoStyle.tomato)
    }
}

// MARK: - View 便捷扩展

extension View {
    @ViewBuilder
    func bentoSurfaceIfNeeded() -> some View {
        if BentoStyle.isActive {
            BentoPageSurface { self }
        } else {
            self
        }
    }

    /// 快速包装一个便当格子背景
    func bentoBlock(
        fill: Color = BentoStyle.surface,
        radius: CGFloat = BentoStyle.blockRadius,
        padding: CGFloat = BentoStyle.blockPadding,
        stroked: Bool = false
    ) -> some View {
        BentoBlock(fill: fill, radius: radius, padding: padding, stroked: stroked) {
            self
        }
    }
}
