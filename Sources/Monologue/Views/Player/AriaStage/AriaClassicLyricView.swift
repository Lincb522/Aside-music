//
//  AriaClassicLyricView.swift
//  Monologue
//
//  全新沉浸模式的经典流光歌词渲染器 —— 从零复刻 folia-major classic/Visualizer.tsx：
//  - 以行首时间为种子的确定性散点布局（同一句歌词永远同一套几何，时间只改动画状态）
//  - 词三态：waiting（模糊散开）→ active（弹簧入场 ×1.4 + 逐字素辉光）→ passed（余晖慢旋漂移）
//  - 行级进出场按 renderHints 的 normal/fast/none 三档收放
//  - 整行呼吸浮动、副歌涟漪、间奏六点、底部翻译 / 下一句字幕层
//

import SwiftUI
import UIKit

// MARK: - 动画强度（theme.animationIntensity）

enum AriaIntensity: String, CaseIterable {
    case calm, normal, chaotic

    var label: String {
        switch self {
        case .calm: return String(localized: "平静")
        case .normal: return String(localized: "自然")
        case .chaotic: return String(localized: "狂想")
        }
    }

    /// 词散点最大偏移
    var spread: Double {
        switch self {
        case .calm: return 0
        case .normal: return 20
        case .chaotic: return 60
        }
    }

    /// 词随机旋转幅度
    var rotate: Double {
        switch self {
        case .calm: return 0
        case .normal: return 5
        case .chaotic: return 30
        }
    }

    /// 呼吸浮动（距离, 周期）
    var breathing: (distance: Double, duration: Double) {
        switch self {
        case .calm: return (10, 8.5)
        case .normal: return (14, 7)
        case .chaotic: return (18, 5.8)
        }
    }

    var passedOpacity: Double {
        self == .chaotic ? 0.9 : 0.82
    }
}

// MARK: - 词状态

enum AriaWordStatus {
    case waiting, active, passed
}

// MARK: - 散点布局（classic Visualizer 的 wordConfigs + flex-wrap 几何）

struct AriaWordConfig {
    let x: Double
    let y: Double
    let rotate: Double
    /// waiting 态的预倾角（folia：enableWordRotation ? rotate + 20 : 0）
    let waitingRotate: Double
    let scale: Double
    let marginRight: Double
    let passedRotate: Double
    let rippleScale: Double
}

private enum AriaJustify: CaseIterable {
    case leading, center, trailing, around, between
}

struct AriaLineLayout {
    struct Item {
        let word: AriaWord
        let config: AriaWordConfig
        /// 布局基准位置（散点偏移由渲染层叠加）
        let position: CGPoint
        let size: CGSize
        /// 预计算的字素时间轴，避免渲染层逐帧重复切分
        let graphemes: [AriaGrapheme]
    }

    let items: [Item]
    let containerSize: CGSize
    let fontSize: CGFloat

    // MARK: 构建

    static func build(
        line: AriaLine,
        maxWidth: CGFloat,
        fontSize: CGFloat,
        intensity: AriaIntensity,
        enableRotation: Bool,
        wordSpacing: Double
    ) -> AriaLineLayout {
        let seed = line.startTime
        let words = line.displayWords
        let isChaotic = intensity == .chaotic
        let spread = line.isInterlude ? 0 : intensity.spread
        let baseRotate = (line.isInterlude || !enableRotation) ? 0 : intensity.rotate
        // ClassicTuning.wordSpacing：0 紧贴 ~ 2 疏朗，folia 默认 0.7
        let spacingMultiplier = min(max(wordSpacing, 0), 2)

        let widths = words.map { measureWidth($0.text, pxSize: fontSize) }
        let lineHeight = fontSize * 1.22

        // 每词确定性配置（Visualizer.tsx wordConfigs）
        var configs: [AriaWordConfig] = []
        for index in words.indices {
            let wordSeed = seed + Double(index)
            func rand(_ offset: Double) -> Double { AriaLyricEngine.seededRandom(wordSeed, offset) }

            if line.isInterlude {
                configs.append(AriaWordConfig(
                    x: 0,
                    y: (rand(2) - 0.5) * 15,
                    rotate: 0,
                    waitingRotate: 0,
                    scale: 1.5,
                    marginRight: 40,
                    passedRotate: 0,
                    rippleScale: 1.5 + rand(9) * 2
                ))
                continue
            }

            let scale = isChaotic ? 0.8 + rand(4) * 0.6 : 1.1 + rand(4) * 0.2
            let x = (rand(1) - 0.5) * spread * 2
            let y = (rand(2) - 0.5) * spread * 2

            // 精确右边距：抵消激活放大与散点位移造成的视觉重叠
            let selfWidth = Double(widths[index])
            let selfActiveScale = scale * 1.4
            var nextWidth = 0.0
            var nextActiveScale = 1.0
            var nextX = 0.0
            if index + 1 < words.count {
                let nextSeed = seed + Double(index + 1)
                func nrand(_ offset: Double) -> Double { AriaLyricEngine.seededRandom(nextSeed, offset) }
                nextActiveScale = (isChaotic ? 0.8 + nrand(4) * 0.6 : 1.1 + nrand(4) * 0.2) * 1.4
                nextX = (nrand(1) - 0.5) * spread * 2
                nextWidth = Double(widths[index + 1])
            }
            let gap = 0.05 * Double(fontSize)
            let halfOverflowSelf = selfWidth * (selfActiveScale - 1) / 2
            let halfOverflowNext = nextWidth * (nextActiveScale - 1) / 2
            let calculated = (halfOverflowSelf + halfOverflowNext + (x - nextX) + gap) * spacingMultiplier
            let minMargin = (isChaotic ? 0.08 : 0.12) * Double(fontSize) * spacingMultiplier
            let margin = max(minMargin, calculated)

            let rotate = (rand(3) - 0.5) * baseRotate * 2
            configs.append(AriaWordConfig(
                x: x,
                y: y,
                rotate: rotate,
                waitingRotate: enableRotation ? rotate + 20 : 0,
                scale: scale,
                marginRight: margin,
                passedRotate: enableRotation ? (rand(8) - 0.5) * 45 : 0,
                rippleScale: 1.5 + rand(9) * 2
            ))
        }

        // 贪心换行（flex-wrap）
        var rows: [[Int]] = []
        var currentRow: [Int] = []
        var cursorX: CGFloat = 0
        for index in words.indices {
            let width = widths[index]
            if !currentRow.isEmpty && cursorX + width > maxWidth {
                rows.append(currentRow)
                currentRow = []
                cursorX = 0
            }
            currentRow.append(index)
            cursorX += width + CGFloat(configs[index].marginRight)
        }
        if !currentRow.isEmpty { rows.append(currentRow) }

        // 行内主轴分布（justify-content 随行种子）
        let justifyOptions: [AriaJustify] = (intensity == .calm || line.isInterlude)
            ? [.center]
            : AriaJustify.allCases
        let justify = justifyOptions[
            Int(abs(seed.truncatingRemainder(dividingBy: Double(justifyOptions.count))))
        ]

        let totalHeight = CGFloat(rows.count) * lineHeight
        let containerHeight = max(totalHeight, min(300, maxWidth * 0.5))
        var items: [Item] = []
        var rowY = (containerHeight - totalHeight) / 2 + lineHeight / 2

        for row in rows {
            let contentWidth: CGFloat = row.enumerated().reduce(0) { acc, entry in
                let (offset, index) = entry
                let margin = offset == row.count - 1 ? 0 : CGFloat(configs[index].marginRight)
                return acc + widths[index] + margin
            }
            let leftover = max(0, maxWidth - contentWidth)

            var x: CGFloat
            var extraGap: CGFloat = 0
            switch justify {
            case .leading:
                x = 0
            case .center:
                x = leftover / 2
            case .trailing:
                x = leftover
            case .between:
                x = 0
                extraGap = row.count > 1 ? leftover / CGFloat(row.count - 1) : 0
            case .around:
                extraGap = leftover / CGFloat(row.count)
                x = extraGap / 2
            }

            for (offset, index) in row.enumerated() {
                let width = widths[index]
                // chaotic 的 alignSelf 错落：三成词随机吸附行顶/行底（folia flex-start/flex-end）
                var alignJitter: CGFloat = 0
                if isChaotic {
                    let wordSeed = seed + Double(index)
                    if AriaLyricEngine.seededRandom(wordSeed, 6) > 0.7 {
                        alignJitter = AriaLyricEngine.seededRandom(wordSeed, 7) > 0.5
                            ? -lineHeight * 0.22
                            : lineHeight * 0.22
                    }
                }
                items.append(Item(
                    word: words[index],
                    config: configs[index],
                    position: CGPoint(x: x + width / 2, y: rowY + alignJitter),
                    size: CGSize(width: width, height: lineHeight),
                    graphemes: AriaLyricEngine.graphemeTimings(for: words[index])
                ))
                let margin = offset == row.count - 1 ? 0 : CGFloat(configs[index].marginRight)
                x += width + margin + extraGap
            }
            rowY += lineHeight
        }

        return AriaLineLayout(
            items: items,
            containerSize: CGSize(width: maxWidth, height: containerHeight),
            fontSize: fontSize
        )
    }

    static func measureWidth(_ text: String, pxSize: CGFloat) -> CGFloat {
        let base = UIFont.systemFont(ofSize: pxSize, weight: .bold)
        let font: UIFont
        if let descriptor = base.fontDescriptor.withDesign(.rounded) {
            font = UIFont(descriptor: descriptor, size: pxSize)
        } else {
            font = base
        }
        return ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }
}

/// 布局缓存：布局是种子确定的，同一句只算一次
@MainActor
final class AriaLayoutCache {
    static let shared = AriaLayoutCache()
    private var cache: [String: AriaLineLayout] = [:]

    func layout(
        for line: AriaLine,
        maxWidth: CGFloat,
        fontSize: CGFloat,
        intensity: AriaIntensity,
        enableRotation: Bool,
        wordSpacing: Double
    ) -> AriaLineLayout {
        let key = "\(line.id)-\(Int(maxWidth))-\(Int(fontSize * 10))-\(intensity.rawValue)-\(enableRotation)-\(Int(wordSpacing * 100))"
        if let hit = cache[key] { return hit }
        if cache.count > 160 { cache.removeAll(keepingCapacity: true) }
        let built = AriaLineLayout.build(
            line: line,
            maxWidth: maxWidth,
            fontSize: fontSize,
            intensity: intensity,
            enableRotation: enableRotation,
            wordSpacing: wordSpacing
        )
        cache[key] = built
        return built
    }

    func clear() {
        cache.removeAll(keepingCapacity: true)
    }
}

// MARK: - 词渲染（Word 组件：三态 + 逐字素辉光 + 副歌涟漪）

struct AriaWordView: View {
    let word: AriaWord
    let config: AriaWordConfig
    let graphemes: [AriaGrapheme]
    let hints: AriaRenderHints
    let palette: AriaPalette
    let isChorus: Bool
    let intensity: AriaIntensity
    let fontSize: CGFloat
    let time: Double

    /// active 结束点随 reveal 档位缩放（getClassicWordActiveEndTime）
    private var activeEndTime: Double {
        switch hints.revealMode {
        case .instant: return hints.renderEndTime
        case .fast: return min(hints.renderEndTime, max(word.endTime, word.startTime + 0.12))
        case .normal: return word.endTime
        }
    }

    private var displayDuration: Double {
        let minDuration: Double
        switch hints.revealMode {
        case .instant: minDuration = 0.08
        case .fast: minDuration = 0.12
        case .normal: minDuration = 0.1
        }
        return max(activeEndTime - word.startTime, minDuration)
    }

    private var status: AriaWordStatus {
        if time >= word.startTime - hints.wordLookahead && time <= activeEndTime {
            return .active
        }
        if time > activeEndTime {
            return .passed
        }
        return .waiting
    }

    var body: some View {
        let status = self.status

        HStack(spacing: 0) {
            ForEach(graphemes.indices, id: \.self) { index in
                grapheme(graphemes[index], status: status)
            }
        }
        .blur(radius: status == .waiting ? 10 : 0)
        .animation(.easeOut(duration: 0.25), value: status == .waiting)
        .background {
            // 副歌涟漪：词激活瞬间向外扩散的光环（Chorus Ripple），不参与词的尺寸计算
            if isChorus {
                ripple
            }
        }
        .font(ariaFont)
        .fixedSize()
        // 透明度独立通道：激活瞬间快速点亮（folia opacity duration 0.1），位姿走弹簧
        .opacity(opacityFor(status))
        .animation(opacityAnimation(for: status), value: status)
        // 三态位姿：waiting 散开缩小 → active 弹簧入场 → passed 余晖停驻
        .modifier(poseModifier(for: status))
        .animation(mainAnimation(for: status), value: status)
        .rotationEffect(.degrees(rotationFor(status)))
        .animation(rotationAnimation(for: status), value: status)
    }

    private var ariaFont: Font {
        .system(size: fontSize, weight: .bold, design: .rounded)
    }

    // MARK: 字素层：主体颜色浸染 + 辉光

    /// 双层辉光半径随 reveal 档位缩放（folia：instant 14/24px、fast 18/32px、normal 20/40px）
    private var glowRadii: (inner: CGFloat, outer: CGFloat) {
        switch hints.revealMode {
        case .instant: return (7, 12)
        case .fast: return (9, 16)
        case .normal: return (10, 20)
        }
    }

    @ViewBuilder
    private func grapheme(_ grapheme: AriaGrapheme, status: AriaWordStatus) -> some View {
        let glow = glowIntensity(for: grapheme)
        let radii = glowRadii
        Text(grapheme.char)
            .foregroundStyle(bodyColor(for: grapheme))
            .background {
                // textShadow "0 0 20px accent, 0 0 40px accent" 的双层等价：
                // 内圈实、外圈晕，光斑随字素时间轴流过整词
                if glow > 0.01 {
                    ZStack {
                        Text(grapheme.char)
                            .foregroundStyle(resolvedAccent)
                            .blur(radius: radii.inner)
                        Text(grapheme.char)
                            .foregroundStyle(resolvedAccent.opacity(0.85))
                            .blur(radius: radii.outer)
                    }
                    .opacity(glow)
                }
            }
    }

    /// 激活色：副歌行向次色偏移三成（wordColors 关键词专色的动态等价），让副歌自带辨识色
    private var resolvedAccent: Color {
        isChorus ? mix(palette.accent, palette.secondary, 0.3) : palette.accent
    }

    /// 主体色：base → accent 随词进度浸染，passed 后缓慢回落
    private func bodyColor(for grapheme: AriaGrapheme) -> Color {
        let riseProgress = clamped((time - word.startTime) / displayDuration)
        let fallDuration: Double
        switch hints.revealMode {
        case .instant: fallDuration = 0.12
        case .fast: fallDuration = 0.24
        case .normal: fallDuration = 0.8
        }
        let fallProgress = clamped((time - activeEndTime) / fallDuration)
        let amount = riseProgress * (1 - fallProgress)
        return mix(palette.primary, resolvedAccent, amount)
    }

    /// 逐字素辉光包络（glowVariants）：按字素时间轴延迟点亮，峰值靠前后缓慢消散
    private func glowIntensity(for grapheme: AriaGrapheme) -> Double {
        switch hints.revealMode {
        case .instant:
            return pulseEnvelope(
                elapsed: time - word.startTime,
                duration: min(displayDuration, 0.12),
                peakAt: 0.35
            )
        case .fast:
            return pulseEnvelope(
                elapsed: time - word.startTime,
                duration: min(max(displayDuration, 0.12), 0.2),
                peakAt: 0.4
            )
        case .normal:
            let charDuration = max(grapheme.endTime - grapheme.startTime, 0.001)
            // 拖长到数个字素的时长，让光斑像流过整词
            return pulseEnvelope(
                elapsed: time - grapheme.startTime,
                duration: charDuration * 6,
                peakAt: 0.3
            )
        }
    }

    /// [0 → 峰值 → 0] 的时间包络
    private func pulseEnvelope(elapsed: Double, duration: Double, peakAt: Double) -> Double {
        guard duration > 0, elapsed > 0, elapsed < duration else { return 0 }
        let u = elapsed / duration
        if u < peakAt {
            return easeInOut(u / peakAt)
        }
        return 1 - easeInOut((u - peakAt) / (1 - peakAt))
    }

    // MARK: 三态位姿

    private func opacityFor(_ status: AriaWordStatus) -> Double {
        switch status {
        case .waiting: return 0
        case .active: return 1
        case .passed: return intensity.passedOpacity
        }
    }

    private func opacityAnimation(for status: AriaWordStatus) -> Animation {
        switch status {
        case .active: return .easeOut(duration: 0.1)
        case .passed: return .easeOut(duration: 0.5)
        case .waiting: return .easeOut(duration: 0.4)
        }
    }

    private func poseModifier(for status: AriaWordStatus) -> AriaWordPoseModifier {
        switch status {
        case .waiting:
            // 以自身散点位为基准再被 sin/cos 抛远，制造从雾里聚拢的入场
            return AriaWordPoseModifier(
                scale: 0.5,
                offset: CGPoint(
                    x: config.x + sin(config.y) * 100,
                    y: config.y + cos(config.x) * 50
                )
            )
        case .active:
            return AriaWordPoseModifier(
                scale: config.scale * 1.4,
                offset: CGPoint(x: config.x, y: config.y)
            )
        case .passed:
            return AriaWordPoseModifier(
                scale: config.scale,
                offset: CGPoint(x: config.x, y: config.y)
            )
        }
    }

    private func rotationFor(_ status: AriaWordStatus) -> Double {
        switch status {
        case .waiting: return config.waitingRotate
        case .active: return config.rotate
        case .passed: return config.rotate + config.passedRotate
        }
    }

    private func mainAnimation(for status: AriaWordStatus) -> Animation {
        switch status {
        case .active:
            // spring stiffness 200 / damping 20 的等价
            return .spring(response: 0.44, dampingFraction: 0.7)
        case .passed:
            return .easeOut(duration: 0.5)
        case .waiting:
            return .easeOut(duration: 0.4)
        }
    }

    private func rotationAnimation(for status: AriaWordStatus) -> Animation {
        status == .passed ? .linear(duration: 5) : .spring(response: 0.44, dampingFraction: 0.7)
    }

    // MARK: 涟漪

    @ViewBuilder
    private var ripple: some View {
        let rippleDuration = 0.5
        let progress = (time - word.startTime) / rippleDuration
        if progress > 0 && progress < 1 {
            let scale = 0.2 + (config.rippleScale - 0.2) * progress
            Circle()
                .stroke(resolvedAccent, lineWidth: 1)
                .blur(radius: 1)
                .frame(width: fontSize * 1.5, height: fontSize * 1.5)
                .scaleEffect(scale)
                .opacity(0.8 * (1 - progress))
        }
    }

    // MARK: 工具

    private func clamped(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    private func easeInOut(_ u: Double) -> Double {
        let x = min(max(u, 0), 1)
        return x * x * (3 - 2 * x)
    }

    private func mix(_ from: Color, _ to: Color, _ amount: Double) -> Color {
        let a = min(max(amount, 0), 1)
        guard a > 0.001 else { return from }
        guard a < 0.999 else { return to }
        var fr: CGFloat = 0, fg: CGFloat = 0, fb: CGFloat = 0, fa: CGFloat = 0
        var tr: CGFloat = 0, tg: CGFloat = 0, tb: CGFloat = 0, ta: CGFloat = 0
        UIColor(from).getRed(&fr, green: &fg, blue: &fb, alpha: &fa)
        UIColor(to).getRed(&tr, green: &tg, blue: &tb, alpha: &ta)
        return Color(
            red: fr + (tr - fr) * a,
            green: fg + (tg - fg) * a,
            blue: fb + (tb - fb) * a
        )
    }
}

/// 词位姿：缩放 / 偏移打包成一个可动画修饰器，三态切换一次弹簧到位（透明度走独立通道）
struct AriaWordPoseModifier: ViewModifier {
    let scale: Double
    let offset: CGPoint

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .offset(x: offset.x, y: offset.y)
    }
}

// MARK: - 行渲染（散点词容器）

struct AriaClassicLineView: View {
    let line: AriaLine
    let layout: AriaLineLayout
    let palette: AriaPalette
    let intensity: AriaIntensity
    let time: Double

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(layout.items, id: \.word.id) { item in
                AriaWordView(
                    word: item.word,
                    config: item.config,
                    graphemes: item.graphemes,
                    hints: line.hints,
                    palette: palette,
                    isChorus: line.isChorus,
                    intensity: intensity,
                    fontSize: layout.fontSize,
                    time: time
                )
                .position(item.position)
            }
        }
        .frame(width: layout.containerSize.width, height: layout.containerSize.height)
    }
}

// MARK: - 行进出场过渡（getClassicLineContainerMotion）

private struct AriaLineTransitionModifier: ViewModifier {
    let opacity: Double
    let scale: Double
    let blur: Double

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .scaleEffect(scale)
            .blur(radius: blur)
    }
}

extension AnyTransition {
    static func ariaLine(_ mode: AriaTransitionMode) -> AnyTransition {
        switch mode {
        case .none:
            return .asymmetric(
                insertion: .identity,
                removal: .modifier(
                    active: AriaLineTransitionModifier(opacity: 0, scale: 1.02, blur: 6),
                    identity: AriaLineTransitionModifier(opacity: 1, scale: 1, blur: 0)
                ).animation(.easeOut(duration: 0.12))
            )
        case .fast:
            return .asymmetric(
                insertion: .modifier(
                    active: AriaLineTransitionModifier(opacity: 0.35, scale: 0.96, blur: 4),
                    identity: AriaLineTransitionModifier(opacity: 1, scale: 1, blur: 0)
                ).animation(.easeOut(duration: 0.16)),
                removal: .modifier(
                    active: AriaLineTransitionModifier(opacity: 0, scale: 1.04, blur: 10),
                    identity: AriaLineTransitionModifier(opacity: 1, scale: 1, blur: 0)
                ).animation(.easeInOut(duration: 0.16))
            )
        case .normal:
            return .asymmetric(
                insertion: .modifier(
                    active: AriaLineTransitionModifier(opacity: 0, scale: 0.9, blur: 10),
                    identity: AriaLineTransitionModifier(opacity: 1, scale: 1, blur: 0)
                ).animation(.easeOut(duration: 0.35)),
                removal: .modifier(
                    active: AriaLineTransitionModifier(opacity: 0, scale: 1.1, blur: 20),
                    identity: AriaLineTransitionModifier(opacity: 1, scale: 1, blur: 0)
                ).animation(.easeOut(duration: 0.3))
            )
        }
    }
}

// MARK: - 舞台歌词层（单句居中 + 呼吸浮动 + 空态）

struct AriaClassicLyricStage: View {
    let lines: [AriaLine]
    let palette: AriaPalette
    let intensity: AriaIntensity
    let enableRotation: Bool
    let wordSpacing: Double
    /// ClassicTuning.breathingFloatMultiplier：0 静止 ~ 2 双倍呼吸
    let breathingMultiplier: Double
    let fontScale: Double
    let time: Double
    let stageSize: CGSize

    /// 已展示的行，切换走 withAnimation 触发进出场过渡
    @State private var displayedLineId: Int = -1

    private var activeIndex: Int {
        AriaLyricEngine.activeLineIndex(in: lines, at: time)
    }

    private var displayedLine: AriaLine? {
        lines.first(where: { $0.id == displayedLineId })
    }

    private var fontSize: CGFloat {
        // clamp(2.25rem, 6vw, 4.5rem) × fontScale：跟随视口宽度
        let scale = CGFloat(fontScale)
        return min(max(36 * scale, stageSize.width * 0.06 * scale), 72 * scale)
    }

    var body: some View {
        let activeIndex = self.activeIndex
        let activeLineId = activeIndex >= 0 ? lines[activeIndex].id : -1
        let maxWidth = maxContentWidth

        ZStack {
            if let line = displayedLine {
                AriaClassicLineView(
                    line: line,
                    layout: AriaLayoutCache.shared.layout(
                        for: line,
                        maxWidth: maxWidth,
                        fontSize: line.isInterlude ? fontSize * 0.9 : fontSize,
                        intensity: intensity,
                        enableRotation: enableRotation,
                        wordSpacing: wordSpacing
                    ),
                    palette: palette,
                    intensity: intensity,
                    time: time
                )
                .id(line.id)
                .transition(.ariaLine(line.hints.transitionMode))
            } else {
                Text(String(localized: "等待音乐…"))
                    .font(.system(size: fontSize * 0.5, weight: .medium, design: .rounded))
                    .foregroundStyle(palette.secondary)
                    .opacity(0.5)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 整行呼吸浮动：屏幕在词事件之间也保持轻微的生命感
        .offset(y: breathingOffset)
        .scaleEffect(breathingScale)
        .onChange(of: activeLineId) { _, newValue in
            withAnimation(.easeOut(duration: 0.3)) {
                displayedLineId = newValue
            }
            // 预热下一句布局（prepareActiveAndUpcoming）：切句瞬间不再有测量开销
            if let index = lines.firstIndex(where: { $0.id == newValue }), index + 1 < lines.count {
                let upcoming = lines[index + 1]
                _ = AriaLayoutCache.shared.layout(
                    for: upcoming,
                    maxWidth: maxContentWidth,
                    fontSize: upcoming.isInterlude ? fontSize * 0.9 : fontSize,
                    intensity: intensity,
                    enableRotation: enableRotation,
                    wordSpacing: wordSpacing
                )
            }
        }
        .onAppear {
            displayedLineId = activeLineId
        }
    }

    private var maxContentWidth: CGFloat {
        min(stageSize.width * 0.86, 1152)
    }

    // MARK: 呼吸浮动（lyricContainerFloat：y [0, -d, 0, 0.45d, 0] × multiplier）

    private var breathingPhase: Double {
        let (_, duration) = intensity.breathing
        return (time.truncatingRemainder(dividingBy: duration)) / duration * 2 * .pi
    }

    private var breathingOffset: CGFloat {
        guard breathingMultiplier > 0 else { return 0 }
        let (distance, _) = intensity.breathing
        let scaled = distance * breathingMultiplier
        let theta = breathingPhase
        if theta < .pi {
            return CGFloat(-scaled * sin(theta))
        }
        return CGFloat(0.45 * scaled * sin(theta - .pi))
    }

    private var breathingScale: CGFloat {
        guard breathingMultiplier > 0 else { return 1 }
        let theta = breathingPhase
        if theta < .pi {
            return 1 + CGFloat(0.01 * breathingMultiplier * sin(theta))
        }
        return 1 - CGFloat(0.005 * breathingMultiplier * sin(theta - .pi))
    }
}

// MARK: - 字幕层（VisualizerSubtitleOverlay.tsx）

struct AriaSubtitleOverlay: View {
    let lines: [AriaLine]
    let palette: AriaPalette
    let time: Double
    let showTranslation: Bool
    let chromeHidden: Bool

    private struct Content: Equatable {
        var translation: String?
        var translationKey: Int
        var upcoming: [String]
    }

    private var content: Content {
        let activeIndex = AriaLyricEngine.activeLineIndex(in: lines, at: time)
        let activeLine = activeIndex >= 0 ? lines[activeIndex] : nil
        let recent = activeLine == nil ? AriaLyricEngine.recentCompletedLine(in: lines, at: time) : nil

        if let translation = activeLine?.translation ?? recent?.translation {
            return Content(
                translation: translation,
                translationKey: activeLine?.id ?? recent?.id ?? 0,
                upcoming: []
            )
        }
        if activeLine != nil {
            let next = AriaLyricEngine.upcomingLines(in: lines, activeIndex: activeIndex, at: time)
            return Content(
                translation: nil,
                translationKey: 0,
                upcoming: next.filter { !$0.isInterlude }.map(\.fullText)
            )
        }
        return Content(translation: nil, translationKey: 0, upcoming: [])
    }

    var body: some View {
        let content = self.content

        VStack(spacing: 8) {
            if showTranslation, let translation = content.translation {
                // 翻译字号对应 folia clamp(1.125rem, 2.6vw, 1.25rem)
                Text(translation)
                    .font(.system(size: 19, weight: .medium, design: .rounded))
                    .foregroundStyle(palette.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .id(content.translationKey)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                ForEach(content.upcoming.indices, id: \.self) { index in
                    Text(content.upcoming[index])
                        .font(.system(size: 14.5, weight: .regular, design: .rounded))
                        .foregroundStyle(palette.secondary)
                        .lineLimit(1)
                        .blur(radius: 1)
                }
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: 820)
        .opacity(0.6)
        .animation(.easeOut(duration: 0.24), value: content)
        // 底距对应 folia chrome 显隐时的 32 / 112
        .padding(.bottom, chromeHidden ? 32 : 112)
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: chromeHidden)
        .allowsHitTesting(false)
    }
}
