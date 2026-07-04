import SwiftUI
import UIKit

// ============================================================
//  Folia 歌词系统（folia-major "经典流光" Visualizer 完整移植）
//  源：src/components/visualizer/classic/Visualizer.tsx
//      src/utils/lyrics/renderHints.ts
//      src/utils/lyrics/cjkSemanticLayout.ts
//      src/utils/lyrics/graphemeTiming.ts
//      src/components/visualizer/VisualizerSubtitleOverlay.tsx
//
//  体系：
//  - 渲染提示：按句时长分级（normal/short/micro），决定入退场与逐字节奏
//  - 布局单元：CJK 逐字散开、拉丁词整体、标点/缩写粘连到前词
//  - 三态词生命周期：waiting（模糊缩小漂离位）→ active（弹簧入位放大点亮
//    + 逐字素辉光扫掠）→ passed（余晖淡定 + 慢速回转）
//  - 确定性散点布局：seed = 句开始时间，同一句永不重排
//  - 整屏呼吸浮动 + 底部翻译/下句预告字幕层
// ============================================================

// MARK: - 渲染提示（renderHints.ts）

enum FoliaTransitionMode { case normal, fast, none }
enum FoliaRevealMode { case normal, fast, instant }

struct FoliaRenderHints {
    let rawDuration: Double
    let transitionMode: FoliaTransitionMode
    let revealMode: FoliaRevealMode
    let renderEndTime: Double
    /// 提前进入 active 的时间（原版 wordLookahead）
    var wordLookahead: Double {
        switch revealMode {
        case .instant: return 0.03
        case .fast: return 0.08
        case .normal: return 0.15
        }
    }

    /// 原版阈值：<0.10s micro、<0.18s short
    static func build(start: Double, end: Double, lastWordEnd: Double) -> FoliaRenderHints {
        let rawDuration = max(end - start, 0)
        let transitionMode: FoliaTransitionMode
        let revealMode: FoliaRevealMode
        if rawDuration < 0.10 {
            transitionMode = .none
            revealMode = .instant
        } else if rawDuration < 0.18 {
            transitionMode = .fast
            revealMode = .fast
        } else {
            transitionMode = .normal
            revealMode = .normal
        }

        // renderEndTime：句子最多还能留在屏幕上多久（buildLineRenderEndTime）
        let renderEnd: Double
        switch transitionMode {
        case .none:
            renderEnd = max(end, start + 0.067)
        case .fast:
            let exitDur = min(max(rawDuration * 0.22, 0.03), 0.04)
            let passStart = max(lastWordEnd, start) + 0.03
            let exitStart = max(start + 0.06, passStart, end - exitDur)
            renderEnd = max(end, exitStart + exitDur)
        case .normal:
            let exitDur = min(0.32, max(0.18, max(rawDuration, 0.12) * 0.18))
            let passStart = max(lastWordEnd, start) + 0.06
            let exitStart = max(passStart, end - exitDur)
            renderEnd = max(end, exitStart + exitDur)
        }
        return FoliaRenderHints(
            rawDuration: rawDuration,
            transitionMode: transitionMode,
            revealMode: revealMode,
            renderEndTime: renderEnd
        )
    }
}

// MARK: - 布局单元（cjkSemanticLayout.ts + graphemeTiming.ts）

struct FoliaGrapheme {
    let char: String
    let start: Double
    let end: Double
}

struct FoliaDisplayWord: Identifiable {
    let id: Int
    let text: String
    let start: Double
    let end: Double
    /// 逐字素时间轴（辉光扫掠 + 卡拉 OK 用；原版 buildWordGraphemeTimings）
    let graphemes: [FoliaGrapheme]

    static func make(id: Int, text: String, start: Double, end: Double) -> FoliaDisplayWord {
        let chars = text.map(String.init)
        let dur = max(end - start, 0)
        let unit = chars.isEmpty ? 0 : dur / Double(chars.count)
        let graphemes = chars.enumerated().map { i, ch in
            FoliaGrapheme(
                char: ch,
                start: start + unit * Double(i),
                end: i == chars.count - 1 ? end : start + unit * Double(i + 1)
            )
        }
        return FoliaDisplayWord(id: id, text: text, start: start, end: end, graphemes: graphemes)
    }
}

enum FoliaTokenizer {
    static func isCJKChar(_ ch: Character) -> Bool {
        guard let v = ch.unicodeScalars.first?.value else { return false }
        return (0x4E00...0x9FFF).contains(v) || (0x3040...0x30FF).contains(v)
            || (0xAC00...0xD7AF).contains(v) || (0x3400...0x4DBF).contains(v)
    }

    /// 粘连型收尾标点（STICKY_TRAILING_PUNCTUATION_REGEX）
    static func isStickyPunctuation(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return false }
        return t.allSatisfy { ",.;:!?，。！？、：；）】》」』〉〕］)}]\"'’”".contains($0) }
    }

    /// 缩写后缀（'s / 't / 'll …，CONTRACTION_SUFFIX_REGEX）
    static func isContractionSuffix(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespaces).lowercased()
        guard t.first == "'" || t.first == "’" else { return false }
        return ["s", "t", "m", "d", "ll", "re", "ve", "em"].contains(String(t.dropFirst()))
    }

    /// LyricLine → 展示词序列：
    /// - 有逐词时间轴：CJK 词逐字拆开（各字均分词时长），标点/缩写粘回前词
    /// - 无逐词时间轴：全文按词/字切分，时长按视觉长度加权均分
    static func displayWords(for line: LyricLine) -> [FoliaDisplayWord] {
        var units: [(text: String, start: Double, end: Double)] = []

        if !line.words.isEmpty {
            for w in line.words {
                let text = w.text.trimmingCharacters(in: .whitespaces)
                guard !text.isEmpty else { continue }
                let start = w.startTime
                let end = w.startTime + max(w.duration, 0.01)
                let chars = Array(text)
                if chars.allSatisfy({ isCJKChar($0) }) && chars.count > 1 {
                    // 原版语义单元返回原始逐字词 → CJK 逐字散开
                    let unit = (end - start) / Double(chars.count)
                    for (i, ch) in chars.enumerated() {
                        units.append((String(ch), start + unit * Double(i), start + unit * Double(i + 1)))
                    }
                } else {
                    units.append((text, start, end))
                }
            }
        } else {
            // 整句时间轴：按视觉长度加权均分
            let lineStart = line.time
            let lineEnd = line.time + max(line.duration, 0.8)
            var pieces: [String] = []
            var latin = ""
            for ch in line.text {
                if ch.isWhitespace {
                    if !latin.isEmpty { pieces.append(latin); latin = "" }
                } else if isCJKChar(ch) {
                    if !latin.isEmpty { pieces.append(latin); latin = "" }
                    pieces.append(String(ch))
                } else {
                    latin.append(ch)
                }
            }
            if !latin.isEmpty { pieces.append(latin) }
            let weights = pieces.map { p in max(1.0, Double(p.count) * (isCJKChar(p.first ?? " ") ? 1.0 : 0.5)) }
            let total = max(weights.reduce(0, +), 1)
            var cursor = lineStart
            for (i, p) in pieces.enumerated() {
                let span = (lineEnd - lineStart) * weights[i] / total
                units.append((p, cursor, cursor + span))
                cursor += span
            }
        }

        // 粘连处理（applyStickyPunctuationLayoutUnits）：标点 / 缩写并入前词
        var merged: [(text: String, start: Double, end: Double)] = []
        for u in units {
            if let last = merged.last,
               isStickyPunctuation(u.text) || isContractionSuffix(u.text) {
                merged[merged.count - 1] = (last.text + u.text, last.start, u.end)
            } else {
                merged.append(u)
            }
        }

        return merged.enumerated().map { i, u in
            FoliaDisplayWord.make(id: i, text: u.text, start: u.start, end: u.end)
        }
    }
}

// MARK: - 确定性散点布局（classic wordConfigs）

struct FoliaWordConfig {
    let x: CGFloat
    let y: CGFloat
    let rotate: Double
    let scale: Double
    let passedRotate: Double
}

enum FoliaIntensity {
    case calm, normal, chaotic

    // 数值比原版收敛：网页端词间有大 margin 吸收散点位移，
    // SwiftUI 流式布局格位固定，散点过大会压到邻词上
    var spread: Double {
        switch self {
        case .calm: return 0
        case .normal: return 9
        case .chaotic: return 30
        }
    }

    var rotate: Double {
        switch self {
        case .calm: return 0
        case .normal: return 2.5
        case .chaotic: return 14
        }
    }
}

enum FoliaLayoutBuilder {
    /// 原版 sin 伪随机：random(offset) = fract(sin(seed+offset)*10000)
    static func rand(_ seed: Double, _ offset: Double) -> Double {
        let x = sin(seed + offset) * 10000
        return x - x.rounded(.down)
    }

    static func wordConfigs(seed: Double, count: Int, intensity: FoliaIntensity) -> [FoliaWordConfig] {
        (0..<count).map { i in
            let ws = seed + Double(i)
            // 基础缩放同样收敛（原版 1.1~1.3 + active ×1.4 在 SwiftUI 里必叠字）
            let scale: Double = intensity == .chaotic
                ? 0.85 + rand(ws, 4) * 0.4
                : 1.0 + rand(ws, 4) * 0.12
            return FoliaWordConfig(
                x: CGFloat((rand(ws, 1) - 0.5) * intensity.spread * 2),
                y: CGFloat((rand(ws, 2) - 0.5) * intensity.spread * 2),
                rotate: (rand(ws, 3) - 0.5) * intensity.rotate * 2,
                scale: scale,
                passedRotate: (rand(ws, 8) - 0.5) * 24
            )
        }
    }

    /// 行主轴对齐随机（justifyOptions：start/center/end/around/between → 折算为三种行对齐）
    static func lineJustify(seed: Double, intensity: FoliaIntensity) -> FoliaRowJustify {
        guard intensity != .calm else { return .center }
        let options: [FoliaRowJustify] = [.leading, .center, .trailing, .center, .center]
        let idx = abs(Int(seed.rounded(.down))) % options.count
        return options[idx]
    }
}

// MARK: - 词状态

enum FoliaWordStatus: Equatable {
    case waiting, active, passed
}

/// 行主轴对齐（原版 justifyContent 随机）
enum FoliaRowJustify {
    case leading, center, trailing
}

// MARK: - 主视图

struct FoliaLyricsView: View {
    let song: Song
    let pulse: CinemaAudioPulse
    /// folia 模式（经典流光 / 心象 / 云阶 / 倾诉 / 浮名 / 群唱 / 莫奈）
    var style: CinemaLyricStyle = .folia
    var onBackgroundTap: (() -> Void)?

    @ObservedObject private var viewModel = LyricViewModel.shared
    @AppStorage("showTranslation") var showTranslation: Bool = true
    @StateObject private var coverColors = CoverColorExtractor()

    var body: some View {
        GeometryReader { geo in
            let palette = VJPalette.derive(
                dominant: coverColors.dominantColor,
                secondary: coverColors.secondaryColor
            )

            ZStack {
                if viewModel.isLoading {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else if !viewModel.hasLyrics {
                    Text("No Lyrics Available")
                        .font(.rounded(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                } else {
                    stage(size: geo.size, palette: palette)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { onBackgroundTap?() }
        }
        .task(id: song.coverUrl?.absoluteString) {
            coverColors.extract(from: song.coverUrl?.sized(200).absoluteString)
        }
    }

    @ViewBuilder
    private func stage(size: CGSize, palette: VJPalette) -> some View {
        switch style {
        case .fume:
            FoliaFumeStage(
                lyrics: viewModel.lyrics,
                currentIndex: viewModel.currentLineIndex,
                pulse: pulse,
                palette: palette,
                size: size
            )
        case .cappella:
            FoliaCappellaStage(
                lyrics: viewModel.lyrics,
                currentIndex: viewModel.currentLineIndex,
                pulse: pulse,
                palette: palette,
                size: size
            )
        case .monet:
            FoliaMonetStage(
                song: song,
                lyrics: viewModel.lyrics,
                currentIndex: viewModel.currentLineIndex,
                pulse: pulse,
                palette: palette,
                size: size,
                showTranslation: showTranslation
            )
        default:
            lineStage(size: size, palette: palette)
        }
    }

    @ViewBuilder
    private func lineStage(size: CGSize, palette: VJPalette) -> some View {
        let index = viewModel.currentLineIndex
        let line: LyricLine? = viewModel.lyrics.indices.contains(index) ? viewModel.lyrics[index] : nil
        // 原版 clamp(2.25rem, 6vw, 4.5rem)
        let fontSize = min(64, max(30, size.width * 0.052))

        ZStack {
            // 呼吸浮动容器（lyricContainerFloat：y [0,-14,0,6.3,0] / 7s）
            TimelineView(AppFrameRate.animationTimeline(maximumFramesPerSecond: 30, paused: false)) { timeline in
                let wall = timeline.date.timeIntervalSinceReferenceDate
                let phase = (wall.truncatingRemainder(dividingBy: 7)) / 7 * 2 * .pi
                let floatY = CGFloat(-sin(phase) * 10 - sin(phase * 2) * 3.5)

                ZStack {
                    if let line, !line.text.isEmpty, !isInterlude(line) {
                        Group {
                            switch style {
                            case .partita:
                                FoliaPartitaLineView(
                                    line: line,
                                    pulse: pulse,
                                    palette: palette,
                                    fontSize: fontSize,
                                    stageHeight: size.height
                                )
                            case .tilt:
                                FoliaTiltLineView(
                                    line: line,
                                    pulse: pulse,
                                    palette: palette,
                                    fontSize: fontSize,
                                    stageWidth: size.width
                                )
                            case .cadenza:
                                FoliaCadenzaLineView(
                                    line: line,
                                    pulse: pulse,
                                    palette: palette,
                                    fontSize: fontSize,
                                    stageWidth: size.width,
                                    stageHeight: size.height
                                )
                            default:
                                FoliaLineView(
                                    line: line,
                                    lineIndex: index,
                                    pulse: pulse,
                                    palette: palette,
                                    fontSize: fontSize
                                )
                            }
                        }
                        .id(index)
                        .transition(style == .tilt ? .opacity : foliaLineTransition(line))
                    } else {
                        FoliaInterludeView(palette: palette)
                            .id("interlude-\(index)")
                            .transition(.opacity)
                    }
                }
                .animation(.easeOut(duration: 0.3), value: index)
                .offset(y: floatY)
            }

            // 底部字幕层（VisualizerSubtitleOverlay）
            subtitleOverlay(activeIndex: index, activeLine: line, palette: palette, size: size)
        }
        .padding(.horizontal, 40)
    }

    private func isInterlude(_ line: LyricLine) -> Bool {
        let t = line.text.trimmingCharacters(in: .whitespaces)
        return t == "......" || t == "..." || t == "…" || t.isEmpty
    }

    /// 入退场（getClassicLineContainerMotion）：正常句 blur+缩放，短句快切
    private func foliaLineTransition(_ line: LyricLine) -> AnyTransition {
        let hints = FoliaRenderHints.build(
            start: line.time,
            end: line.time + max(line.duration, 0.3),
            lastWordEnd: line.words.last.map { $0.startTime + $0.duration } ?? line.time + max(line.duration, 0.3)
        )
        switch hints.transitionMode {
        case .none:
            return .asymmetric(
                insertion: .identity,
                removal: .modifier(
                    active: FoliaLineExit(progress: 0, blur: 6, scale: 1.02),
                    identity: FoliaLineExit(progress: 1, blur: 6, scale: 1.02)
                )
            )
        case .fast:
            return .asymmetric(
                insertion: .modifier(
                    active: FoliaLineEnter(progress: 0, blur: 4, scale: 0.96, opacityFloor: 0.35),
                    identity: FoliaLineEnter(progress: 1, blur: 4, scale: 0.96, opacityFloor: 0.35)
                ),
                removal: .modifier(
                    active: FoliaLineExit(progress: 0, blur: 10, scale: 1.04),
                    identity: FoliaLineExit(progress: 1, blur: 10, scale: 1.04)
                )
            )
        case .normal:
            return .asymmetric(
                insertion: .modifier(
                    active: FoliaLineEnter(progress: 0, blur: 10, scale: 0.9, opacityFloor: 0),
                    identity: FoliaLineEnter(progress: 1, blur: 10, scale: 0.9, opacityFloor: 0)
                ),
                removal: .modifier(
                    active: FoliaLineExit(progress: 0, blur: 20, scale: 1.1),
                    identity: FoliaLineExit(progress: 1, blur: 20, scale: 1.1)
                )
            )
        }
    }

    /// 底部翻译 / 下句预告（VisualizerSubtitleOverlay 语义：
    /// 有翻译显示翻译；无翻译时预览接下来两句；空窗期沿用最近完成句的翻译）
    @ViewBuilder
    private func subtitleOverlay(activeIndex: Int, activeLine: LyricLine?, palette: VJPalette, size: CGSize) -> some View {
        let translation: String? = {
            if showTranslation, let t = activeLine?.translation, !t.isEmpty { return t }
            return nil
        }()
        let upcoming: [LyricLine] = {
            guard translation == nil, activeLine != nil else { return [] }
            let next = activeIndex + 1
            return Array(viewModel.lyrics.dropFirst(next).prefix(2))
        }()

        VStack(spacing: 6) {
            if let translation {
                Text(translation)
                    .font(.rounded(size: min(22, max(15, size.width * 0.018)), weight: .medium))
                    .foregroundColor(palette.base.opacity(0.78))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .id("trans-\(activeIndex)")
                    .transition(.opacity.combined(with: .offset(y: 10)))
            } else {
                ForEach(upcoming.indices, id: \.self) { i in
                    Text(upcoming[i].text)
                        .font(.rounded(size: min(16, max(12, size.width * 0.014)), weight: .regular))
                        .foregroundColor(palette.base.opacity(0.45))
                        .lineLimit(1)
                        .blur(radius: 1)
                }
            }
        }
        .frame(maxWidth: size.width * 0.7)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 18)
        .opacity(0.85)
        .animation(.easeOut(duration: 0.24), value: activeIndex)
        .allowsHitTesting(false)
    }
}

// MARK: - 入退场 modifier

struct FoliaLineEnter: ViewModifier {
    var progress: Double
    var blur: CGFloat
    var scale: Double
    var opacityFloor: Double

    func body(content: Content) -> some View {
        let inv = 1 - progress
        content
            .opacity(opacityFloor + (1 - opacityFloor) * progress)
            .scaleEffect(scale + (1 - scale) * progress)
            .blur(radius: blur * inv)
    }
}

struct FoliaLineExit: ViewModifier {
    var progress: Double
    var blur: CGFloat
    var scale: Double

    func body(content: Content) -> some View {
        let inv = 1 - progress
        content
            .opacity(progress)
            .scaleEffect(1 + (scale - 1) * inv)
            .blur(radius: blur * inv)
    }
}

// MARK: - 间奏视图（三点呼吸）

private struct FoliaInterludeView: View {
    let palette: VJPalette

    var body: some View {
        TimelineView(AppFrameRate.animationTimeline(maximumFramesPerSecond: 30, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 22) {
                ForEach(0..<3, id: \.self) { i in
                    let p = 0.5 + 0.5 * sin(t * 1.8 - Double(i) * 0.9)
                    Circle()
                        .fill(palette.base.opacity(0.25 + p * 0.55))
                        .frame(width: 13, height: 13)
                        .scaleEffect(0.8 + p * 0.5)
                }
            }
        }
    }
}

// MARK: - 单句渲染

private struct FoliaLineView: View {
    let line: LyricLine
    let lineIndex: Int
    let pulse: CinemaAudioPulse
    let palette: VJPalette
    let fontSize: CGFloat

    private let words: [FoliaDisplayWord]
    private let configs: [FoliaWordConfig]
    private let hints: FoliaRenderHints
    private let intensity: FoliaIntensity = .normal

    init(line: LyricLine, lineIndex: Int, pulse: CinemaAudioPulse, palette: VJPalette, fontSize: CGFloat) {
        self.line = line
        self.lineIndex = lineIndex
        self.pulse = pulse
        self.palette = palette
        self.fontSize = fontSize
        let words = FoliaTokenizer.displayWords(for: line)
        self.words = words
        self.configs = FoliaLayoutBuilder.wordConfigs(seed: line.time, count: words.count, intensity: .normal)
        self.hints = FoliaRenderHints.build(
            start: line.time,
            end: line.time + max(line.duration, 0.3),
            lastWordEnd: words.last?.end ?? line.time + max(line.duration, 0.3)
        )
    }

    /// active 结束时刻（getClassicWordActiveEndTime）
    private func activeEnd(_ w: FoliaDisplayWord) -> Double {
        switch hints.revealMode {
        case .instant: return hints.renderEndTime
        case .fast: return min(hints.renderEndTime, max(w.end, w.start + 0.12))
        case .normal: return w.end
        }
    }

    private func status(_ w: FoliaDisplayWord, at t: Double) -> FoliaWordStatus {
        let end = activeEnd(w)
        if t >= w.start - hints.wordLookahead && t <= end { return .active }
        if t > end { return .passed }
        return .waiting
    }

    var body: some View {
        TimelineView(AppFrameRate.animationTimeline(
            maximumFramesPerSecond: CinemaPerformanceGovernor.shared.stageFPS,
            paused: false
        )) { _ in
            let t = PlaybackTimePublisher.shared.currentTime
            let snap = pulse.snapshot()
            let isChorus = snap.lyricSun > 0.38

            // 间距按 active 放大量预留：布局格位是未缩放尺寸，
            // 间距不吃掉放大量的话相邻词会叠字
            FoliaFlowLayout(
                spacing: fontSize * 0.42,
                lineSpacing: fontSize * 0.52,
                justify: FoliaLayoutBuilder.lineJustify(seed: line.time, intensity: intensity)
            ) {
                ForEach(words) { w in
                    FoliaWordView(
                        word: w,
                        config: configs[w.id],
                        status: status(w, at: t),
                        now: t,
                        palette: palette,
                        fontSize: fontSize,
                        isChorus: isChorus,
                        beatPulse: snap.beatPulse
                    )
                }
            }
            .frame(maxWidth: 760)
        }
    }
}

// MARK: - 单词视图（三态 + 弹簧 + 逐字素辉光）

struct FoliaWordView: View {
    let word: FoliaDisplayWord
    let config: FoliaWordConfig
    let status: FoliaWordStatus
    let now: Double
    let palette: VJPalette
    let fontSize: CGFloat
    let isChorus: Bool
    let beatPulse: Double
    /// active 态的放大倍率。原版 classic 是 1.4，但网页词间有弹性 margin
    /// 吸收放大量；这里布局格位固定，1.4 会压到邻词，收敛到 1.16
    var activeBoost: Double = 1.16

    /// waiting 漂离位（layoutVariants.waiting：x + sin(y)*100, y + cos(x)*50）
    private var waitingOffset: CGSize {
        CGSize(
            width: config.x + CGFloat(sin(Double(config.y))) * 60,
            height: config.y + CGFloat(cos(Double(config.x))) * 32
        )
    }

    /// partita 语义：waiting 词保持可见的浅态（结构先立住，词在其中穿行）
    var waitingVisible: Bool = false

    var body: some View {
        let pose = currentPose

        ZStack {
            // 副歌涟漪（Chorus Ripple）：active 词背后扩散的圆环
            // 原版 rippleScale = 1.5 + random * 2，每词确定性随机
            if isChorus && status == .active {
                let rippleT = min(1, max(0, (now - word.start) / 0.5))
                let rippleScale = 1.5 + FoliaLayoutBuilder.rand(word.start, 9) * 2
                Circle()
                    .stroke(palette.accent.opacity(0.8 * (1 - rippleT)), lineWidth: 1.5)
                    .frame(width: fontSize * 1.5, height: fontSize * 1.5)
                    .scaleEffect(0.2 + rippleT * (rippleScale - 0.2))
                    .blur(radius: 1)
            }

            // 逐字素双层：底层字体（颜色渐变）+ 辉光层（textShadow 扫掠）
            HStack(spacing: 0) {
                ForEach(word.graphemes.indices, id: \.self) { gi in
                    graphemeText(word.graphemes[gi])
                }
            }
        }
        .scaleEffect(pose.scale)
        .offset(pose.offset)
        .opacity(pose.opacity)
        .blur(radius: pose.blur)
        // 弹簧：stiffness 200 / damping 20 → response 0.44 / dampingFraction 0.71
        .animation(.spring(response: 0.44, dampingFraction: 0.71), value: status)
        // 旋转独立动画：passed 时慢速回转 5s linear（原版 rotate transition）
        .rotationEffect(.degrees(pose.rotate))
        .animation(
            status == .passed
                ? .linear(duration: 5)
                : .spring(response: 0.44, dampingFraction: 0.71),
            value: status
        )
        .fixedSize()
    }

    private struct Pose {
        var opacity: Double
        var scale: Double
        var offset: CGSize
        var rotate: Double
        var blur: CGFloat
    }

    private var currentPose: Pose {
        switch status {
        case .waiting:
            if waitingVisible {
                // partita：布局已就位，词处于"未进入"浅态
                return Pose(
                    opacity: 0.35, scale: 0.96,
                    offset: .zero,
                    rotate: 0,
                    blur: 1.5
                )
            }
            return Pose(
                opacity: 0, scale: 0.5,
                offset: waitingOffset,
                rotate: config.rotate + 20,
                blur: 8
            )
        case .active:
            return Pose(
                opacity: 1,
                scale: config.scale * activeBoost + beatPulse * 0.03,
                offset: CGSize(width: config.x, height: config.y),
                rotate: config.rotate,
                blur: 0
            )
        case .passed:
            return Pose(
                opacity: 0.82, scale: config.scale,
                offset: CGSize(width: config.x, height: config.y),
                rotate: config.rotate + config.passedRotate,
                blur: 0
            )
        }
    }

    /// 逐字素渲染：卡拉 OK 颜色 + 辉光扫掠（bodyVariants + glowVariants 合并为逐帧插值）
    @ViewBuilder
    private func graphemeText(_ g: FoliaGrapheme) -> some View {
        // 颜色进度：base → active（原版 color transition over duration）
        let sungP = fillProgress(g)
        // 辉光包络：字素开始时打亮，随后拖长淡出（glow duration*6, peak 0.3）
        let glow = glowEnvelope(g)

        Text(g.char)
            .font(.system(size: fontSize, weight: .bold, design: .rounded))
            .foregroundColor(blend(palette.base.opacity(0.55), palette.accent, p: sungP))
            .shadow(color: palette.accent.opacity(glow * 0.85), radius: 10)
            .shadow(color: palette.accent.opacity(glow * 0.5), radius: 20)
    }

    private func fillProgress(_ g: FoliaGrapheme) -> Double {
        switch status {
        case .waiting: return 0
        case .passed:
            // passed 回落到底色（原版 passed color → baseColor over 0.8s）
            let back = min(1, max(0, (now - activeEndApprox) / 0.8))
            return 1 - back * 0.55
        case .active:
            guard g.end > g.start else { return now >= g.start ? 1 : 0 }
            return min(1, max(0, (now - g.start) / (g.end - g.start)))
        }
    }

    private var activeEndApprox: Double { word.end }

    private func glowEnvelope(_ g: FoliaGrapheme) -> Double {
        guard status != .waiting else { return 0 }
        let charDur = max(g.end - g.start, 0.05)
        // 原版：duration = charDuration*6，peak 在 30% 处
        let span = charDur * 6
        let p = (now - g.start) / span
        guard p > 0, p < 1 else { return 0 }
        if p < 0.3 { return p / 0.3 }
        return 1 - (p - 0.3) / 0.7
    }

    private func blend(_ a: Color, _ b: Color, p: Double) -> Color {
        guard p > 0.001 else { return a }
        guard p < 0.999 else { return b }
        let ua = UIColor(a), ub = UIColor(b)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        ua.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        ub.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let q = CGFloat(p)
        return Color(
            red: Double(r1 + (r2 - r1) * q),
            green: Double(g1 + (g2 - g1) * q),
            blue: Double(b1 + (b2 - b1) * q),
            opacity: Double(a1 + (a2 - a1) * q)
        )
    }
}

// MARK: - 流式布局（flex-wrap + 居中，行内基线对齐）

private struct FoliaFlowLayout: Layout {
    var spacing: CGFloat = 14
    var lineSpacing: CGFloat = 16
    var justify: FoliaRowJustify = .center

    private func rows(subviews: Subviews, maxWidth: CGFloat) -> [[Int]] {
        var rows: [[Int]] = []
        var row: [Int] = []
        var x: CGFloat = 0
        for i in subviews.indices {
            let size = subviews[i].sizeThatFits(.unspecified)
            let needed = size.width + (row.isEmpty ? 0 : spacing)
            if !row.isEmpty && x + needed > maxWidth {
                rows.append(row)
                row = [i]
                x = size.width
            } else {
                row.append(i)
                x += needed
            }
        }
        if !row.isEmpty { rows.append(row) }
        return rows
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 760
        let rowList = rows(subviews: subviews, maxWidth: maxWidth)
        var height: CGFloat = 0
        var width: CGFloat = 0
        for (ri, row) in rowList.enumerated() {
            var rowW: CGFloat = 0
            var rowH: CGFloat = 0
            for (ci, i) in row.enumerated() {
                let s = subviews[i].sizeThatFits(.unspecified)
                rowW += s.width + (ci > 0 ? spacing : 0)
                rowH = max(rowH, s.height)
            }
            width = max(width, rowW)
            height += rowH + (ri > 0 ? lineSpacing : 0)
        }
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rowList = rows(subviews: subviews, maxWidth: bounds.width)
        var totalH: CGFloat = 0
        var rowHeights: [CGFloat] = []
        for row in rowList {
            var rowH: CGFloat = 0
            for i in row { rowH = max(rowH, subviews[i].sizeThatFits(.unspecified).height) }
            rowHeights.append(rowH)
            totalH += rowH
        }
        totalH += CGFloat(max(0, rowList.count - 1)) * lineSpacing

        var y = bounds.midY - totalH / 2
        for (ri, row) in rowList.enumerated() {
            var rowW: CGFloat = 0
            for (ci, i) in row.enumerated() {
                rowW += subviews[i].sizeThatFits(.unspecified).width + (ci > 0 ? spacing : 0)
            }
            var x: CGFloat
            switch justify {
            case .leading: x = bounds.minX
            case .center: x = bounds.midX - rowW / 2
            case .trailing: x = bounds.maxX - rowW
            }
            for i in row {
                let s = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(
                    at: CGPoint(x: x, y: y + rowHeights[ri] / 2),
                    anchor: .leading,
                    proposal: .unspecified
                )
                x += s.width + spacing
            }
            y += rowHeights[ri] + lineSpacing
        }
    }
}
