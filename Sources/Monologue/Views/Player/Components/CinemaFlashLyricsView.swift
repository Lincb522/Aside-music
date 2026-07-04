import SwiftUI
import UIKit

// ============================================================
//  影院沉浸模式的 VJ 字幕歌词 — 一次只显示一句。
//  动效体系（俱乐部 VJ 字幕风格）：
//  - 逐字/逐词错峰入场，每句轮换一种入场编排（升起/砸落/爆闪缩放/横扫）
//  - 节拍冲击：整句随 beatPulse/punch 做缩放 kick，逐字随节拍弹跳
//  - RGB 色差分离：红/青双色副本随高频与鼓点撕开
//  - 故障闪切：强拍瞬间整句横向抖动 + 剪切变形（24Hz 采样的确定性噪声）
//  - 入场白闪：换句瞬间亮度打闪后回落
//  - 卡拉 OK：唱过全亮、正在唱的字主题色点亮并放大
// ============================================================

struct CinemaFlashLyricsView: View {
    let song: Song
    let pulse: CinemaAudioPulse
    var onBackgroundTap: (() -> Void)?

    @ObservedObject private var viewModel = LyricViewModel.shared
    @AppStorage("showTranslation") var showTranslation: Bool = true

    /// 当前句开始展示的墙钟时刻（驱动入场编排的确定性时间轴）
    @State private var lineAnchor: Double = Date.timeIntervalSinceReferenceDate
    /// 封面取色：卡拉 OK 点亮色 / RGB 撕裂双色 / 辉光全部跟随封面
    @StateObject private var coverColors = CoverColorExtractor()

    var body: some View {
        ZStack {
            if viewModel.isLoading {
                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else if !viewModel.hasLyrics {
                Text("No Lyrics Available")
                    .font(.rounded(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            } else {
                vjStage
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { onBackgroundTap?() }
        .onChange(of: viewModel.currentLineIndex) { _, _ in
            lineAnchor = Date.timeIntervalSinceReferenceDate
        }
        .task(id: song.coverUrl?.absoluteString) {
            coverColors.extract(from: song.coverUrl?.sized(200).absoluteString)
        }
    }

    @ViewBuilder
    private var vjStage: some View {
        let index = viewModel.currentLineIndex
        let line: LyricLine? = viewModel.lyrics.indices.contains(index) ? viewModel.lyrics[index] : nil
        let palette = VJPalette.derive(
            dominant: coverColors.dominantColor,
            secondary: coverColors.secondaryColor
        )

        ZStack {
            if let line, !line.text.isEmpty {
                VJLyricLine(
                    line: line,
                    lineIndex: index,
                    pulse: pulse,
                    anchor: lineAnchor,
                    showTranslation: showTranslation,
                    palette: palette
                )
                .id(index)
                .transition(
                    .asymmetric(
                        // 入场由 VJLyricLine 内部的逐字编排接管
                        insertion: .identity,
                        removal: .modifier(
                            active: LyricFlyPast(progress: 0),
                            identity: LyricFlyPast(progress: 1)
                        )
                    )
                )
            }
        }
        .animation(.easeOut(duration: 0.30), value: index)
        .padding(.horizontal, 48)
    }
}

// MARK: - 封面派生调色板

/// 从封面主色派生的 VJ 字幕配色（Mineradio lyricTextPaletteFromHsl 语义）：
/// - base：未唱底色（封面色相的淡彩，原版 uBaseColor，不是灰白）
/// - sung：唱过点亮色（色相微移 + 低饱和的暖白，原版 uHiColor）
/// - accent：正在唱的字（提饱和提亮）
/// - fringeA/fringeB：RGB 撕裂双色（主色相 + 互补色相，最大化色差感）
/// - 黑白/低饱和封面回退银蓝色系（原版 silverBlueLyricPalette）
struct VJPalette: Equatable {
    var accent: Color
    var base: Color
    var sung: Color
    var fringeA: Color
    var fringeB: Color

    static func derive(dominant: Color, secondary: Color) -> VJPalette {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(dominant).getHue(&h, saturation: &s, brightness: &b, alpha: &a)

        // 低饱和（黑白封面）：色相不可信，回退银蓝色系
        guard s > 0.12 else {
            return VJPalette(
                accent: .monologueAccent,
                base: Color(red: 0.847, green: 0.945, blue: 1.0),   // #d8f1ff
                sung: Color(red: 0.933, green: 0.969, blue: 1.0),   // #eef7ff
                fringeA: Color(red: 1, green: 0.16, blue: 0.28),
                fringeB: Color(red: 0.12, green: 0.9, blue: 1)
            )
        }

        let hue = Double(h)
        let accent = Color(hue: hue, saturation: Double(max(s, 0.55)), brightness: Double(max(b, 0.88)))
        // 原版：primary = 封面色相、饱和 clamp(s+0.16, 0.42~0.78)、暗场亮度 0.74
        let baseSat = Double(min(max(s + 0.16, 0.42), 0.78)) * 0.6
        let base = Color(hue: hue, saturation: baseSat, brightness: 0.90)
        // 原版：highlight = 色相 +0.03、降饱和、亮度 0.86 → 带色相的暖白
        let sung = Color(
            hue: (hue + 0.03).truncatingRemainder(dividingBy: 1),
            saturation: max(0.16, baseSat - 0.22),
            brightness: 1.0
        )
        let fringeS = Double(max(s, 0.80))
        // 主色相与互补色相的高亮对，撕裂时形成霓虹色差
        let fringeA = Color(hue: hue, saturation: fringeS, brightness: 1)
        let fringeB = Color(hue: (hue + 0.5).truncatingRemainder(dividingBy: 1), saturation: fringeS, brightness: 1)
        return VJPalette(accent: accent, base: base, sung: sung, fringeA: fringeA, fringeB: fringeB)
    }
}

// MARK: - 单句 VJ 编排

/// 一句歌词的逐字舞台。所有动效都从同一个 TimelineView 帧回调里推导，
/// 逐字变换只做算术（无独立动画器），60fps 下開销可控。
private struct VJLyricLine: View {
    let line: LyricLine
    let lineIndex: Int
    let pulse: CinemaAudioPulse
    let anchor: Double
    let showTranslation: Bool
    let palette: VJPalette

    private let tokens: [LyricToken]
    private let style: EntranceStyle
    /// 按整句视觉长度自适应的主字号（短句大、长句收）
    private let fontSize: CGFloat
    /// 估算文本宽度：星河带与太阳溢光按它自适应尺寸（Mineradio starRiver 语义）
    private let estWidth: CGFloat

    init(line: LyricLine, lineIndex: Int, pulse: CinemaAudioPulse,
         anchor: Double, showTranslation: Bool, palette: VJPalette) {
        self.line = line
        self.lineIndex = lineIndex
        self.pulse = pulse
        self.anchor = anchor
        self.showTranslation = showTranslation
        self.palette = palette
        let tokens = Self.tokenize(line)
        self.tokens = tokens
        self.style = EntranceStyle.pick(lineIndex: lineIndex)
        let size = Self.adaptiveFontSize(tokens: tokens)
        self.fontSize = size
        let visualLen = tokens.reduce(0.0) { sum, tk in
            sum + (tk.isCJK ? 1.0 : Double(tk.text.count) * 0.52)
        }
        self.estWidth = min(680, max(220, CGFloat(visualLen) * size * 1.02 + 80))
    }

    /// 视觉长度：CJK 记 1 字宽，拉丁字符约 0.52 字宽
    private static func adaptiveFontSize(tokens: [LyricToken]) -> CGFloat {
        let visualLen = tokens.reduce(0.0) { sum, tk in
            sum + (tk.isCJK ? 1.0 : Double(tk.text.count) * 0.52)
        }
        switch visualLen {
        case ..<7:   return 46
        case ..<11:  return 40
        case ..<16:  return 35
        case ..<24:  return 30
        case ..<34:  return 26
        default:     return 23
        }
    }

    /// 逐 token 每帧变换结果
    private struct TokenFX {
        var opacity: Double = 1
        var dx: CGFloat = 0
        var dy: CGFloat = 0
        var scale: Double = 1
        var blur: CGFloat = 0
        var rotZ: Double = 0
        /// 0 未唱 / 1 正在唱 / 2 已唱
        var sung: Int = 0
    }

    var body: some View {
        TimelineView(AppFrameRate.animationTimeline(
            maximumFramesPerSecond: CinemaPerformanceGovernor.shared.stageFPS,
            paused: false
        )) { timeline in
            let wall = timeline.date.timeIntervalSinceReferenceDate
            let elapsed = max(0, wall - anchor)
            let snap = pulse.snapshot()
            let playT = PlaybackTimePublisher.shared.currentTime

            let fx = tokenFX(elapsed: elapsed, wall: wall, snap: snap, playT: playT)

            // ---- 整句级动效（Mineradio updateStageLyrics3D 移植）----
            let seed = Double(lineIndex % 97) * 0.7
            // 呼吸：双频正弦缩放 + bass 呼吸 + 节拍冲击（原版 breathe + bass*0.038 + beatPulse*0.014）
            let breathe = sin(wall * 0.92 + seed) * 0.030 + sin(wall * 0.41 + seed * 0.7) * 0.018
            let lineScale = 0.99 + breathe + snap.bass * 0.030 + snap.punch * 0.06 + snap.beatPulse * 0.03
            // 慢速漂浮 + 微滚转（原版 mesh.position.y 浮动 + rotation.z）
            let floatY = CGFloat(sin(wall * 0.55 + seed) * 5.5 + sin(wall * 1.35 + seed) * 1.4)
            let rollDeg = sin(wall * 0.34 + seed) * 1.0
            // 太阳溢光强度（原版 solarBloom：lyricSun 副歌检测 + beatGlow）
            let solar = min(1.0, snap.lyricSun * 1.05 + snap.beatPulse * 0.16)
            // 辉光层跟随节拍镜头（原版 glowFollowX/Y/Roll）
            let glowDX = CGFloat(snap.rollKick * 1400 + snap.thetaKick * 900)
            let glowDY = CGFloat(snap.phiKick * 1800 - snap.radiusKick * 26)
            // 故障闪切：强拍时 24Hz 采样的横向抖动 + 剪切
            let glitch = max(0, (snap.beatPulse - 0.40) / 0.60)
            let bucket = Int(wall * 24)
            let jitterX = CGFloat(Self.noise(bucket, 3) * 9 * glitch)
            let shear = CGFloat(Self.noise(bucket, 11) * 0.11 * glitch)
            // RGB 色差分离量：高频 + 镜头 punch + 故障加成
            let split = CGFloat(min(9, 0.5 + snap.treble * 5.5 + snap.punch * 4 + glitch * 6))
            // 入场白闪
            let flash = max(0, 1 - elapsed / 0.24)

            VStack(spacing: 14) {
                ZStack {
                    // 歌词星河带：文字后方流动的星尘（原版 starRiver）
                    riverCanvas(wall: wall, snap: snap, solar: solar)
                        .offset(x: glowDX * 0.14, y: glowDY * 0.12)

                    ZStack {
                        // 撕裂双色副本（screen 混合，暗场上呈霓虹色差）——色相取自封面
                        if split > 0.8 {
                            tokenLine(fx: fx, paint: .fringe(palette.fringeA))
                                .offset(x: -split)
                                .blendMode(.screen)
                                .opacity(0.85)
                            tokenLine(fx: fx, paint: .fringe(palette.fringeB))
                                .offset(x: split)
                                .blendMode(.screen)
                                .opacity(0.85)
                        }
                        tokenLine(fx: fx, paint: .karaoke(palette))
                    }
                    .compositingGroup()
                    .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 3)
                    .shadow(color: palette.accent.opacity(0.30 + snap.beatPulse * 0.35 + solar * 0.20), radius: 20)
                }
                // 字幕列宽上限：横屏全宽太散，收成居中列更有 VJ 字幕感
                .frame(maxWidth: 740)

                if showTranslation, let translation = line.translation, !translation.isEmpty {
                    translationLine(translation, elapsed: elapsed)
                }
            }
            .scaleEffect(lineScale)
            .offset(x: jitterX, y: floatY)
            .rotationEffect(.degrees(rollDeg))
            .transformEffect(CGAffineTransform(a: 1, b: 0, c: shear, d: 1, tx: 0, ty: 0))
            // 入场白闪 + 副歌太阳增亮（原版 uSolar 对文字的暖色提亮）
            .brightness(Double(flash) * 0.55 + solar * 0.10)
        }
    }

    // MARK: - 歌词星河带（Mineradio starRiver 移植）

    private static let sunHot = Color(red: 1.0, green: 0.957, blue: 0.800)    // #fff4cc（星河带暖色星尘用）

    private struct RiverMote {
        let seed: Double
        let lane: Double
        let speed: Double
        let size: Double
    }

    private static let riverMotes: [RiverMote] = {
        var g = SystemRandomNumberGenerator()
        func rnd() -> Double { Double.random(in: 0..<1, using: &g) }
        return (0..<84).map { _ in
            RiverMote(seed: rnd() * 1000, lane: rnd(), speed: 0.030 + rnd() * 0.055, size: 1.2 + rnd() * 2.2)
        }
    }()

    /// 文字后方一条随文字宽度自适应的流动星带：
    /// 5 条泳道横向流动、边缘淡出、随节拍提亮（原版 starRiver 顶点着色器语义）
    private func riverCanvas(wall: Double, snap: CinemaAudioPulse.Snapshot, solar: Double) -> some View {
        let bandW = estWidth * 1.12 + 60
        let bandH = max(52, fontSize * 2.1)
        let baseOpacity = 0.16 + solar * 0.42 + snap.beatPulse * 0.10
        return Canvas(rendersAsynchronously: true) { context, size in
            let w = Double(size.width)
            let h = Double(size.height)
            for m in Self.riverMotes {
                let laneBand = (m.lane * 5).rounded(.down)
                let flow = ((m.seed * 2.13).truncatingRemainder(dividingBy: 1) + wall * m.speed)
                    .truncatingRemainder(dividingBy: 1)
                let x = flow * w
                let curve = sin(flow * 6.283 * 0.92 + m.seed * 0.071 + wall * 0.34)
                let y = h * 0.5 + (laneBand - 2) * h * 0.135 + curve * h * 0.20
                // 两端淡入淡出
                let edge = min(1, flow / 0.18) * min(1, (1 - flow) / 0.18)
                guard edge > 0.02 else { continue }
                let twinkle = 0.5 + 0.5 * sin(wall * (0.9 + m.seed.truncatingRemainder(dividingBy: 1) * 0.7) + m.seed)
                let alpha = baseOpacity * edge * (0.30 + twinkle * 0.70)
                guard alpha > 0.015 else { continue }
                let d = m.size * (1 + snap.bass * 0.18 + snap.beatPulse * 0.14)
                let tint = m.lane > 0.55 ? Self.sunHot : palette.accent
                context.fill(
                    Path(ellipseIn: CGRect(x: x - d / 2, y: y - d / 2, width: d, height: d)),
                    with: .color(tint.opacity(alpha))
                )
            }
        }
        .frame(width: bandW, height: bandH)
        .blendMode(.screen)
        .allowsHitTesting(false)
    }

    // MARK: - 逐字排版

    @ViewBuilder
    private func tokenLine(fx: [TokenFX], paint: TokenPaint) -> some View {
        LyricFlowLayout(lineSpacing: 8) {
            ForEach(tokens.indices, id: \.self) { i in
                let f = fx[i]
                Text(tokens[i].text)
                    .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                    .tracking(tokens[i].isCJK ? fontSize * 0.05 : 0)
                    .foregroundColor(paint.color(sung: f.sung))
                    .opacity(f.opacity)
                    .scaleEffect(f.scale)
                    .rotationEffect(.degrees(f.rotZ))
                    .blur(radius: f.blur)
                    .offset(x: f.dx, y: f.dy)
                    // 标点不落行首：与前一个字粘连断行
                    .layoutValue(key: LyricGlueLeft.self, value: tokens[i].glueLeft)
            }
        }
    }

    private func translationLine(_ text: String, elapsed: Double) -> some View {
        // 翻译行延迟 0.16s 淡入上升，不参与逐字编排
        let p = Self.clamp01((elapsed - 0.16) / 0.30)
        let e = Self.easeOutCubic(p)
        // 翻译行字号跟随主行（约 0.46 倍），保持视觉配比
        return Text(text)
            .font(.system(size: max(15, fontSize * 0.46), weight: .semibold, design: .rounded))
            .foregroundColor(.white.opacity(0.66))
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: 560)
            .opacity(e)
            .offset(y: (1 - e) * 16)
            .blur(radius: (1 - e) * 5)
    }

    // MARK: - 逐字变换计算

    private func tokenFX(elapsed: Double, wall: Double, snap: CinemaAudioPulse.Snapshot,
                         playT: Double) -> [TokenFX] {
        let count = max(1, tokens.count)
        let mid = Double(count - 1) / 2
        var out = [TokenFX](repeating: TokenFX(), count: tokens.count)

        for i in tokens.indices {
            var f = TokenFX()
            let fi = Double(i)

            // ---- 入场编排 ----
            let (delay, dur) = style.timing(index: fi, count: Double(count))
            let p = Self.clamp01((elapsed - delay) / dur)
            switch style {
            case .cascade:
                let e = Self.easeOutCubic(p)
                f.opacity = e
                f.dy = (1 - e) * 46
                f.scale = 0.66 + 0.34 * e
                f.blur = (1 - e) * 7
                f.rotZ = (1 - e) * (i.isMultiple(of: 2) ? 10 : -10)
            case .slam:
                let e = Self.easeOutBack(p)
                f.opacity = Self.clamp01(p * 3)
                f.dy = (1 - e) * -84
                f.scale = 1.30 - 0.30 * e
            case .zoomBlast:
                let e = Self.easeOutQuint(p)
                f.opacity = e
                f.scale = 2.3 - 1.3 * e
                f.blur = (1 - e) * 13
                f.dx = CGFloat((fi - mid) * (1 - e) * 26)
            case .sweep:
                let e = Self.easeOutCubic(p)
                f.opacity = e
                f.dx = CGFloat((1 - e) * (110 + fi * 9))
                f.rotZ = (1 - e) * -9
                f.blur = (1 - e) * 6
            }

            // ---- 常驻 VJ 律动（入场完成后逐渐接管）----
            let settle = Self.clamp01((elapsed - delay - dur * 0.7) / 0.3)
            if settle > 0 {
                // 中频驱动的逐字波浪漂浮
                f.dy += CGFloat(sin(wall * 2.1 + fi * 0.72) * (1.4 + snap.mid * 3.4) * settle)
                // 节拍逐字弹跳（相邻字反相，像音符在跳）
                f.dy -= CGFloat(snap.beatPulse * 7 * (0.5 + 0.5 * sin(fi * 2.399)) * settle)
                f.rotZ += sin(wall * 1.3 + fi * 1.1) * 1.6 * settle
            }

            // ---- 卡拉 OK ----
            if let start = tokens[i].start, let end = tokens[i].end {
                if playT >= end {
                    f.sung = 2
                } else if playT >= start {
                    f.sung = 1
                    // 正在唱的字放大 + 随节拍再顶一下
                    f.scale *= 1.16 + snap.beatPulse * 0.10
                    f.dy -= 3
                } else {
                    f.sung = 0
                }
            } else {
                f.sung = 2  // 无逐字时间轴：整句全亮
            }

            out[i] = f
        }
        return out
    }

    // MARK: - 分词

    /// CJK 逐字（时间轴按字均分）、拉丁按词整体（避免断词换行）。
    /// 空格并入前一个 token 的尾部，宽度自然保留；标点标记 glueLeft 防止落行首。
    private static func tokenize(_ line: LyricLine) -> [LyricToken] {
        var out: [LyricToken] = []
        if line.words.isEmpty {
            appendTokens(text: line.text, start: nil, end: nil, into: &out)
        } else {
            for word in line.words {
                let end = word.startTime + max(word.duration, 0.01)
                appendTokens(text: word.text, start: word.startTime, end: end, into: &out)
            }
        }
        return out
    }

    /// 把一段文本切成 token 流：CJK 字符单独成 token，拉丁/数字连续段成词 token，
    /// 空白追加到上一个 token 尾部（行内空格宽度不丢）
    private static func appendTokens(text: String, start: Double?, end: Double?, into out: inout [LyricToken]) {
        var pieces: [String] = []
        var latinRun = ""

        func flushLatin() {
            if !latinRun.isEmpty {
                pieces.append(latinRun)
                latinRun = ""
            }
        }

        for ch in text {
            if ch.isWhitespace {
                flushLatin()
                if !pieces.isEmpty {
                    pieces[pieces.count - 1].append(ch)
                } else if let last = out.indices.last, start == nil {
                    out[last] = out[last].appendingText(String(ch))
                }
            } else if isCJK(ch) {
                flushLatin()
                pieces.append(String(ch))
            } else {
                latinRun.append(ch)
            }
        }
        flushLatin()
        guard !pieces.isEmpty else { return }

        // 时间轴按 piece 均分（word 内逐字卡拉 OK）
        let n = Double(pieces.count)
        for (j, piece) in pieces.enumerated() {
            var s: Double? = nil, e: Double? = nil
            if let start, let end {
                let span = end - start
                s = start + span * Double(j) / n
                e = start + span * Double(j + 1) / n
            }
            let first = piece.first ?? " "
            out.append(LyricToken(
                text: piece,
                start: s,
                end: e,
                isCJK: isCJK(first),
                glueLeft: isClosingPunctuation(first)
            ))
        }
    }

    private static func isCJK(_ ch: Character) -> Bool {
        guard let scalar = ch.unicodeScalars.first else { return false }
        let v = scalar.value
        return (0x4E00...0x9FFF).contains(v)      // CJK 统一表意
            || (0x3040...0x30FF).contains(v)      // 平假名/片假名
            || (0xAC00...0xD7AF).contains(v)      // 谚文
            || (0x3400...0x4DBF).contains(v)
    }

    /// 不允许出现在行首的收尾标点（禁则处理）
    private static func isClosingPunctuation(_ ch: Character) -> Bool {
        "，。！？、；：…—”』」）》】,.!?;:)]".contains(ch)
    }

    // MARK: - 工具

    private static func clamp01(_ v: Double) -> Double { min(1, max(0, v)) }
    private static func easeOutCubic(_ p: Double) -> Double { 1 - pow(1 - p, 3) }
    private static func easeOutQuint(_ p: Double) -> Double { 1 - pow(1 - p, 5) }
    private static func easeOutBack(_ p: Double) -> Double {
        let c1 = 1.70158, c3 = c1 + 1
        let x = p - 1
        return 1 + c3 * x * x * x + c1 * x * x
    }
    /// 确定性噪声 -1...1（同一帧桶内稳定，跨帧闪变）
    private static func noise(_ n: Int, _ salt: Int) -> Double {
        var h = UInt64(bitPattern: Int64(n &* 374761393 &+ salt &* 668265263))
        h ^= h >> 13; h = h &* 1274126177; h ^= h >> 16
        return Double(h % 2000) / 1000 - 1
    }
}

// MARK: - Token 与着色

private struct LyricToken {
    let text: String
    let start: Double?
    let end: Double?
    var isCJK: Bool = false
    /// 收尾标点：换行时与前一个 token 粘连，不落行首
    var glueLeft: Bool = false

    func appendingText(_ s: String) -> LyricToken {
        LyricToken(text: text + s, start: start, end: end, isCJK: isCJK, glueLeft: glueLeft)
    }
}

/// 排版粘连标记：通过 LayoutValueKey 传给流式布局
struct LyricGlueLeft: LayoutValueKey {
    static let defaultValue = false
}

private enum TokenPaint {
    /// 卡拉 OK 着色（Mineradio 文字着色器语义：
    /// 未唱 = 封面淡彩底色，唱过 = 带色相暖白，正在唱 = 点亮色）
    case karaoke(VJPalette)
    case fringe(Color)

    func color(sung: Int) -> Color {
        switch self {
        case .fringe(let c):
            return c
        case .karaoke(let palette):
            switch sung {
            case 1: return palette.accent
            case 2: return palette.sung
            default: return palette.base.opacity(0.52)
            }
        }
    }
}

// MARK: - 入场编排风格

private enum EntranceStyle: CaseIterable {
    case cascade    // 逐字升起聚焦
    case slam       // 自上砸落回弹
    case zoomBlast  // 整句爆闪缩放 + 从中心聚拢
    case sweep      // 右侧横扫入场

    static func pick(lineIndex: Int) -> EntranceStyle {
        let all = Self.allCases
        var h = UInt64(bitPattern: Int64(lineIndex &* 2654435761))
        h ^= h >> 15; h = h &* 2246822519; h ^= h >> 13
        return all[Int(h % UInt64(all.count))]
    }

    /// 逐 token 的入场 (延迟, 时长)
    func timing(index: Double, count: Double) -> (Double, Double) {
        switch self {
        case .cascade:   return (index * 0.036, 0.34)
        case .slam:      return (index * 0.022, 0.30)
        case .zoomBlast: return (0, 0.34)
        case .sweep:     return (index * 0.018, 0.30)
        }
    }
}

// MARK: - 出场（向舞台深处退场，Mineradio outgoing 语义）

/// 出场：缩小 + 上飘 + 虚化淡出，读作"退回舞台深处"
struct LyricFlyPast: ViewModifier {
    var progress: Double

    func body(content: Content) -> some View {
        let inv = 1 - progress
        content
            .opacity(progress)
            .scaleEffect(1 - inv * 0.10)
            .blur(radius: inv * 9)
            .offset(y: -inv * 30)
    }
}

// MARK: - 居中流式排版（逐 token 独立视图，支持自动换行）

private struct LyricFlowLayout: Layout {
    var lineSpacing: CGFloat = 6

    struct Row {
        var range: Range<Int>
        var width: CGFloat
        var height: CGFloat
    }

    /// 换行簇：token + 其后所有 glueLeft 标点视为一个不可拆分单元
    private struct Cluster {
        var range: Range<Int>
        var width: CGFloat
        var height: CGFloat
    }

    private func computeClusters(subviews: Subviews) -> [Cluster] {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var clusters: [Cluster] = []
        var i = 0
        while i < subviews.count {
            var j = i + 1
            var w = sizes[i].width
            var h = sizes[i].height
            while j < subviews.count, subviews[j][LyricGlueLeft.self] {
                w += sizes[j].width
                h = max(h, sizes[j].height)
                j += 1
            }
            clusters.append(Cluster(range: i..<j, width: w, height: h))
            i = j
        }
        return clusters
    }

    /// 均衡换行：先按总宽估算行数，把断点目标压到 total/行数，
    /// 各行宽度接近、不出现"最后一行孤零零一个字"的排版
    private func computeRows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        let clusters = computeClusters(subviews: subviews)
        guard !clusters.isEmpty else { return [] }
        let total = clusters.reduce(0) { $0 + $1.width }

        var target = maxWidth
        if maxWidth.isFinite, total > maxWidth {
            let rowCount = ceil(total / maxWidth)
            target = min(maxWidth, total / rowCount * 1.12)
        }

        var rows: [Row] = []
        var start = clusters[0].range.lowerBound
        var width: CGFloat = 0
        var height: CGFloat = 0
        var end = start
        for c in clusters {
            if width > 0, width + c.width > target {
                rows.append(Row(range: start..<end, width: width, height: height))
                start = c.range.lowerBound
                width = 0
                height = 0
            }
            width += c.width
            height = max(height, c.height)
            end = c.range.upperBound
        }
        if start < end {
            rows.append(Row(range: start..<end, width: width, height: height))
        }
        return rows
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = computeRows(maxWidth: maxWidth, subviews: subviews)
        let h = rows.reduce(0) { $0 + $1.height } + CGFloat(max(0, rows.count - 1)) * lineSpacing
        let w = rows.map(\.width).max() ?? 0
        return CGSize(width: maxWidth.isFinite ? min(maxWidth, w) : w, height: h)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX + (bounds.width - row.width) / 2
            for i in row.range {
                let s = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(
                    at: CGPoint(x: x, y: y + (row.height - s.height) / 2),
                    proposal: ProposedViewSize(s)
                )
                x += s.width
            }
            y += row.height + lineSpacing
        }
    }
}
