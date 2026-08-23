import SwiftUI

// MARK: - 逐字歌词效果

/// 普通播放器逐字歌词的高亮动画风格。
/// 在「歌词外观 → 逐字效果」中选择，作用于默认歌词页、
/// 歌词播放器主题（OrganicLyricsView）与极简主题的逐字视图。
enum KaraokeWordStyle: String, CaseIterable, Identifiable {
    /// 流光：柔和光带扫过，词面微微托起（默认）
    case flow
    /// 弹跳：唱到的词从底部回弹放大
    case bounce
    /// 升起：词从下方浮现落位
    case rise
    /// 辉光：光晕跟随唱词扫过
    case glow
    /// 聚焦：由虚化渐变清晰
    case focus
    /// 波浪：沿基线轻柔摆动
    case wave
    /// 翻页：沿纵轴从侧面翻入
    case flip
    /// 滑入：高亮从左侧滑入落位
    case slide
    /// 脉冲：演唱中随进度轻微收放
    case pulse
    /// 经典：硬边卡拉OK填充
    case classic

    static let storageKey = "karaokeWordStyle"
    static let defaultStyle: KaraokeWordStyle = .flow

    var id: String { rawValue }

    var label: String {
        switch self {
        case .flow: return String(localized: "流光")
        case .bounce: return String(localized: "弹跳")
        case .rise: return String(localized: "升起")
        case .glow: return String(localized: "辉光")
        case .focus: return String(localized: "聚焦")
        case .wave: return String(localized: "波浪")
        case .flip: return String(localized: "翻页")
        case .slide: return String(localized: "滑入")
        case .pulse: return String(localized: "脉冲")
        case .classic: return String(localized: "经典")
        }
    }

    var caption: String {
        switch self {
        case .flow: return String(localized: "光带柔和扫过")
        case .bounce: return String(localized: "唱到回弹放大")
        case .rise: return String(localized: "从下方浮现")
        case .glow: return String(localized: "光晕随词流动")
        case .focus: return String(localized: "虚化渐清晰")
        case .wave: return String(localized: "沿基线轻摆")
        case .flip: return String(localized: "从侧面翻入")
        case .slide: return String(localized: "从左侧滑入")
        case .pulse: return String(localized: "双拍呼吸收放")
        case .classic: return String(localized: "硬边填充")
        }
    }

    static func resolve(_ raw: String) -> KaraokeWordStyle {
        KaraokeWordStyle(rawValue: raw) ?? .defaultStyle
    }
}

// MARK: - 进度曲线

/// 逐字动画共用的进度整形：
/// eased 用于扫光位移（去掉线性起停的机械感），pulse 用于激活瞬间的弹性强调。
enum KaraokeProgressCurve {
    /// smoothstep：两端缓入缓出
    static func eased(_ p: CGFloat) -> CGFloat {
        let t = min(max(p, 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// 激活脉冲：进行中最强、两端归零（sin 窗）
    static func pulse(_ p: CGFloat) -> CGFloat {
        let t = min(max(p, 0), 1)
        guard t > 0, t < 1 else { return 0 }
        return sin(.pi * t)
    }

    /// 双拍脉冲：一个词内形成两次清晰的收放峰值，中段保留较弱呼吸。
    static func doubleBeat(_ p: CGFloat) -> CGFloat {
        let t = min(max(p, 0), 1)
        guard t > 0, t < 1 else { return 0 }
        let envelope = sin(.pi * t)
        let beats = abs(sin(.pi * 2 * t))
        return envelope * (0.28 + 0.72 * beats)
    }

    /// 阻尼弹簧（用于「弹跳」）：快速起跳过冲，回落时越过基线再轻微余弹归位。
    /// 与 pulse 的对称 sin 窗不同，这条曲线有明确的「跳起-落地-回弹」节奏感。
    static func springSettle(_ p: CGFloat) -> CGFloat {
        let t = min(max(p, 0), 1)
        guard t > 0, t < 1 else { return 0 }
        return sin(t * .pi * 2.0) * exp(-2.6 * t)
    }
}

/// Compact progress mask shared by every per-word renderer.
///
/// The previous mask rendered a surface up to five times wider and twice as
/// tall as every glyph. With a full lyric line that produced dozens of large
/// offscreen textures per frame. Dynamic gradient stops keep the same soft
/// leading edge while staying inside the word's actual bounds.
struct KaraokeSweepMask: View {
    let progress: CGFloat
    var softEdge: CGFloat = 0.16

    var body: some View {
        let p = min(max(progress, 0), 1)
        let featherStart = min(max(p - softEdge, 0), 1)
        let featherEnd = min(max(p + 0.025, featherStart + 0.001), 1)

        LinearGradient(
            stops: [
                .init(color: .black, location: 0),
                .init(color: .black, location: featherStart),
                .init(color: .black.opacity(0.42), location: p),
                .init(color: .clear, location: featherEnd),
                .init(color: .clear, location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - 样式化逐字视图（词级）

/// 单个歌词词块的样式化渲染，供默认歌词页与极简主题复用。
/// 由外层 TimelineView 驱动逐帧刷新，body 内保持纯计算 + 轻量修饰符。
struct KaraokeStyledWordView: View {
    let text: String
    /// 词内线性进度 0...1
    let progress: CGFloat
    let font: Font
    let style: KaraokeWordStyle
    var inactiveColor: Color = .gray.opacity(0.3)
    var activeColor: Color = .monoTextPrimary
    var activeGradient: LinearGradient? = nil

    var body: some View {
        let clamped = min(max(progress, 0), 1)

        Group {
            // 一行中绝大多数词都处于“未开始”或“已完成”。这两种静态状态
            // 只画一层 Text，只有正在演唱的词保留遮罩/辉光动画。
            if clamped <= 0.0001 {
                inactiveText
            } else if clamped >= 0.9999 {
                activeText
            } else {
                animatedWord(progress: clamped)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func animatedWord(progress: CGFloat) -> some View {
        let eased = KaraokeProgressCurve.eased(progress)
        let pulse = KaraokeProgressCurve.pulse(progress)
        let doubleBeat = KaraokeProgressCurve.doubleBeat(progress)
        let spring = style == .bounce ? KaraokeProgressCurve.springSettle(progress) : 0
        let glowStrength = style == .glow ? pulse : (style == .pulse ? doubleBeat * 0.72 : 0)

        return ZStack(alignment: .leading) {
            Text(text)
                .font(font)
                .foregroundColor(inactiveColor)
                .blur(radius: style == .focus ? 2.2 * (1 - eased) : 0)
                .opacity(style == .flip ? Double(max(0.12, 1 - eased * 1.35)) : 1)

            activeText
                .mask(maskView(eased: eased))
                .scaleEffect(
                    x: style == .flip ? 0.62 + 0.38 * eased : 1,
                    y: style == .flip ? 0.9 + 0.1 * eased : 1,
                    anchor: .leading
                )
                .rotationEffect(.degrees(activeRotation(eased: eased, pulse: pulse)))
                .rotation3DEffect(
                    .degrees(style == .flip ? -105 * Double(1 - eased) : 0),
                    axis: (x: 0, y: 1, z: 0),
                    anchor: .leading,
                    perspective: 0.72
                )
                .offset(
                    x: activeLayerHorizontalOffset(eased: eased),
                    y: activeLayerVerticalOffset(eased: eased, pulse: pulse)
                )
                .opacity(activeLayerOpacity(eased: eased))
                .brightness(style == .pulse ? Double(doubleBeat * 0.14) : 0)
                .shadow(
                    color: glowStrength > 0 ? activeColor.opacity(Double(glowStrength * 0.8)) : .clear,
                    radius: glowStrength > 0 ? 11 * glowStrength : 0
                )
        }
        .scaleEffect(
            wholeScale(pulse: pulse, doubleBeat: doubleBeat, spring: spring),
            anchor: style == .bounce ? .bottom : .center
        )
        .offset(y: verticalOffset(pulse: pulse, spring: spring))
    }

    private var inactiveText: some View {
        Text(text)
            .font(font)
            .foregroundColor(inactiveColor)
            .blur(radius: style == .focus ? 2.2 : 0)
    }

    @ViewBuilder
    private var activeText: some View {
        if let gradient = activeGradient {
            Text(text)
                .font(font)
                .foregroundStyle(gradient)
        } else {
            Text(text)
                .font(font)
                .foregroundColor(activeColor)
        }
    }

    private func wholeScale(pulse: CGFloat, doubleBeat: CGFloat, spring: CGFloat) -> CGFloat {
        switch style {
        case .flow: return 1 + 0.05 * pulse
        // 弹跳：弹簧轨迹驱动缩放，正半程跳起放大、负半程落地压扁，带明确回弹
        case .bounce: return 1 + 0.22 * spring
        case .glow: return 1 + 0.03 * pulse
        case .pulse: return 1 + 0.2 * doubleBeat
        case .rise, .focus, .wave, .flip, .slide, .classic: return 1
        }
    }

    private func verticalOffset(pulse: CGFloat, spring: CGFloat) -> CGFloat {
        switch style {
        case .flow: return -1.8 * pulse
        // 弹跳：整词随弹簧上抛下落（负值向上），与缩放同步形成起跳感
        case .bounce: return -6.5 * spring
        case .rise, .glow, .focus, .wave, .flip, .slide, .pulse, .classic: return 0
        }
    }

    private func activeRotation(eased: CGFloat, pulse: CGFloat) -> Double {
        guard style == .wave else { return 0 }
        return Double(sin(eased * .pi * 2) * pulse * 3.5)
    }

    private func activeLayerHorizontalOffset(eased: CGFloat) -> CGFloat {
        switch style {
        case .flip:
            return -10 * (1 - eased)
        case .slide:
            return -14 * (1 - eased)
        default:
            return 0
        }
    }

    private func activeLayerVerticalOffset(eased: CGFloat, pulse: CGFloat) -> CGFloat {
        switch style {
        case .rise:
            return 7 * (1 - eased)
        case .wave:
            return -sin(eased * .pi * 2) * pulse * 4
        default:
            return 0
        }
    }

    private func activeLayerOpacity(eased: CGFloat) -> Double {
        switch style {
        case .flip:
            return Double(0.25 + 0.75 * eased)
        case .slide:
            return Double(0.4 + 0.6 * eased)
        case .pulse:
            return Double(0.48 + 0.52 * min(eased * 4, 1))
        default:
            return 1
        }
    }

    @ViewBuilder
    private func maskView(eased: CGFloat) -> some View {
        switch style {
        case .classic:
            // 经典硬边填充
            Rectangle()
                .scaleEffect(
                    x: min(max(progress, 0), 1),
                    y: 1,
                    anchor: .leading
                )
        case .bounce, .flip, .pulse:
            // 整词类动画快速点亮，不叠加横向扫光。
            Rectangle()
                .opacity(min(max(progress, 0) * 3.5, 1))
        default:
            KaraokeSweepMask(progress: eased)
        }
    }
}

// MARK: - 设置页动态预览

/// 「逐字效果」设置的实时预览：以选中样式循环演唱一行示例歌词。
struct KaraokeStylePreviewStrip: View {
    let style: KaraokeWordStyle
    let accent: Color
    var fontSize: CGFloat = 24

    private static let sampleWords: [String] = ["把", "晚", "风", "唱", "成", "一", "封", "信"]
    private static let cycle: Double = 3.2
    private static let wordDuration: Double = 0.32

    var body: some View {
        TimelineView(AppFrameRate.throttledTimeline(maximumFramesPerSecond: 60)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: Self.cycle)

            HStack(spacing: 0) {
                ForEach(Self.sampleWords.indices, id: \.self) { i in
                    let start = Double(i) * Self.wordDuration + 0.25
                    let progress = CGFloat((t - start) / Self.wordDuration)

                    KaraokeStyledWordView(
                        text: Self.sampleWords[i],
                        progress: min(max(progress, 0), 1),
                        font: .rounded(size: fontSize, weight: .bold),
                        style: style,
                        inactiveColor: .white.opacity(0.28),
                        activeColor: .white
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(accent.opacity(0.2), lineWidth: 1)
        }
    }
}
