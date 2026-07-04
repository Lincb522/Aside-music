import SwiftUI

// ============================================================
//  心象模式（folia-major cadenza/VisualizerCadenza.tsx 移植）
//
//  folia 里最重的排版引擎：一句歌词先整句测量换行，再挑出一个
//  "英雄词"（语义权重 + 居中偏置得分最高的词）放大置于画面中心，
//  其余词从各自的自然行位出发、被英雄词径向推开，并用螺旋搜索
//  做碰撞规避 —— 最终形成一朵以英雄词为核心的词云（心象）。
//
//  词的三态：
//  waiting → 灰暗 + 轻模糊 + 微缩，占位但"未进场"
//  active  → 颜色点亮 + 词底光束（beam）+ 逐字辉光 + 高频微脉冲
//  passed  → 慢速漂移 + 微旋转 + 余晖淡出（5s easeInOut）
// ============================================================

struct FoliaCadenzaLineView: View {
    let line: LyricLine
    let pulse: CinemaAudioPulse
    let palette: VJPalette
    let fontSize: CGFloat
    let stageWidth: CGFloat
    let stageHeight: CGFloat

    private struct Placement {
        let word: FoliaDisplayWord
        let x: CGFloat          // 词左缘（相对画面中心）
        let y: CGFloat          // 基线 y
        let width: CGFloat
        let scale: Double       // 英雄词 ≈1.46+，普通词 1.01
        let isHero: Bool
        let passedRotate: Double
        let passedDriftX: CGFloat
        let passedDriftY: CGFloat
    }

    private let placements: [Placement]
    private let hints: FoliaRenderHints
    private let wordFontSize: CGFloat

    init(line: LyricLine, pulse: CinemaAudioPulse, palette: VJPalette, fontSize: CGFloat, stageWidth: CGFloat, stageHeight: CGFloat) {
        self.line = line
        self.pulse = pulse
        self.palette = palette
        self.fontSize = fontSize
        self.stageWidth = stageWidth
        self.stageHeight = stageHeight

        let words = FoliaTokenizer.displayWords(for: line)
        self.hints = FoliaRenderHints.build(
            start: line.time,
            end: line.time + max(line.duration, 0.3),
            lastWordEnd: words.last?.end ?? line.time + max(line.duration, 0.3)
        )

        // chooseFontPx：宽度基准 - 字数惩罚（原版 0.086 * width，28~104px）
        let graphemeCount = words.reduce(0) { $0 + $1.graphemes.count }
        let widthBase = min(max(stageWidth * 0.062, 26), 66)
        let lengthPenalty: CGFloat = graphemeCount > 12 ? min(CGFloat(graphemeCount - 12) * 1.4, 24) : 0
        let densityPenalty: CGFloat = words.count > 7 ? min(CGFloat(words.count - 7) * 1.2, 13) : 0
        let fpx = min(max(widthBase - lengthPenalty - densityPenalty, 22), 74)
        self.wordFontSize = fpx

        self.placements = Self.buildPlacements(
            words: words,
            fontPx: fpx,
            maxWidth: min(stageWidth * 0.64, 620),
            stageHeight: stageHeight,
            seed: line.time * 1000
        )
    }

    // MARK: - 布局（buildWordPlacements 移植）

    private static func estWidth(_ text: String, fontPx: CGFloat) -> CGFloat {
        var w: CGFloat = 0
        for ch in text {
            w += fontPx * (FoliaTokenizer.isCJKChar(ch) ? 1.02 : 0.56)
        }
        return max(w, fontPx * 0.4)
    }

    private static func buildPlacements(
        words: [FoliaDisplayWord],
        fontPx: CGFloat,
        maxWidth: CGFloat,
        stageHeight: CGFloat,
        seed: Double
    ) -> [Placement] {
        guard !words.isEmpty else { return [] }

        let lineHeight = fontPx * 1.24
        let gap = fontPx * 0.34

        // 1) 自然换行流（layoutWithLines 的语义）：得到每词 baseX/baseY
        struct Flow { let index: Int; var row: Int; var x: CGFloat; let w: CGFloat }
        var flows: [Flow] = []
        var row = 0
        var cursorX: CGFloat = 0
        var rowWidths: [CGFloat] = []
        for (i, w) in words.enumerated() {
            let ww = estWidth(w.text, fontPx: fontPx)
            if cursorX > 0 && cursorX + ww > maxWidth {
                rowWidths.append(cursorX - gap)
                row += 1
                cursorX = 0
            }
            flows.append(Flow(index: i, row: row, x: cursorX, w: ww))
            cursorX += ww + gap
        }
        rowWidths.append(cursorX - gap)
        let rowCount = row + 1
        let totalHeight = CGFloat(rowCount) * lineHeight

        // 2) 英雄词（buildEmphasisMap）：语义权重 + 居中偏置
        var heroIndex = 0
        var bestScore = -Double.infinity
        for (i, w) in words.enumerated() {
            let gcount = max(w.graphemes.count, 1)
            let isCJK = w.text.first.map { FoliaTokenizer.isCJKChar($0) } ?? false
            let semanticWeight = isCJK ? 0.18 : min(Double(gcount) * 0.08, 0.36)
            let centerBias = 1 - abs(Double(i) - Double(words.count - 1) / 2) / Double(max(words.count, 1))
            let score = semanticWeight + centerBias * 0.18
            if score > bestScore { bestScore = score; heroIndex = i }
        }
        let heroEmphasis = 1.46 * (1 + min(max(bestScore - 0.48, 0), 0.52))

        func rand(_ i: Int, _ offset: Double) -> Double {
            let x = sin(seed + Double(i) * 17 + offset) * 10000
            return x - x.rounded(.down)
        }

        // 3) 逐词放置：英雄居中，其余从行位出发被英雄推开 + 螺旋碰撞规避
        var rects: [CGRect] = []
        var result: [Placement] = Array()
        let heroW = estWidth(words[heroIndex].text, fontPx: fontPx) * heroEmphasis
        let heroH = fontPx * heroEmphasis

        // 顺序：先英雄，后其余（原版按 emphasis 排序）
        let order = [heroIndex] + words.indices.filter { $0 != heroIndex }

        for i in order {
            let flow = flows[i]
            let isHero = i == heroIndex
            let scale = isHero ? heroEmphasis : 1.01
            let w = flow.w * scale
            let h = fontPx * scale

            var px: CGFloat
            var py: CGFloat
            if isHero {
                px = -w / 2
                py = 0
            } else {
                // 自然行位（行内居中，整体垂直居中）
                let rowW = rowWidths[flow.row]
                px = flow.x - rowW / 2
                py = -totalHeight / 2 + fontPx + CGFloat(flow.row) * lineHeight

                // 距英雄太近则径向推开（minHeroSeparation）
                let cx = px + w / 2
                let cy = py - h * 0.46
                var dx = cx - 0
                var dy = cy - (-heroH * 0.46)
                var dist = sqrt(dx * dx + dy * dy)
                if dist < 1 {
                    dx = px >= 0 ? 1 : -1
                    dy = flow.row % 2 == 0 ? -0.65 : 0.65
                    dist = 1
                }
                let minSep = heroW * 0.34 + w * 0.52 + 16
                if dist < minSep {
                    let push = minSep - dist
                    px += dx / dist * push
                    py += dy / dist * push * 0.92
                }
            }

            // 螺旋碰撞规避（简化版：径向步进 + 8~12 向采样）
            let pad: CGFloat = isHero ? 14 : 7
            let colW = w * (isHero ? 1.4 : 1.24)
            let colH = h * (isHero ? 1.32 : 1.22)
            let step = max(10, fontPx * 0.14)
            let maxRadius: CGFloat = isHero ? max(20, lineHeight * 0.5) : max(lineHeight * 2.2, colW * 0.75, 56)
            let hBound = maxWidth / 2 + 72
            let vBound = max(totalHeight * 0.9, lineHeight * 1.6)

            var chosenX = px
            var chosenY = py
            var found = false
            var bestFallback: (x: CGFloat, y: CGFloat, score: CGFloat) = (px, py, .infinity)
            var radius: CGFloat = 0
            while radius <= maxRadius && !found {
                let samples = radius == 0 ? 1 : (isHero ? 8 : 12)
                for s in 0..<samples {
                    let angle = Double(s) / Double(samples) * 2 * .pi + rand(i, 40) * 0.6
                    let dx = radius == 0 ? 0 : CGFloat(cos(angle)) * radius
                    let dy = radius == 0 ? 0 : CGFloat(sin(angle)) * radius * 0.92
                    let rect = CGRect(
                        x: px + dx - pad,
                        y: py + dy - colH - pad,
                        width: colW + pad * 2,
                        height: colH + pad * 2
                    )
                    guard rect.minX >= -hBound, rect.maxX <= hBound,
                          rect.minY >= -vBound, rect.maxY <= vBound else { continue }

                    var overlap: CGFloat = 0
                    for r in rects {
                        let inter = rect.intersection(r)
                        if !inter.isNull { overlap += inter.width * inter.height }
                    }
                    let travel = sqrt(dx * dx + dy * dy)
                    let score = overlap * 2.2 + travel
                    if score < bestFallback.score {
                        bestFallback = (px + dx, py + dy, score)
                    }
                    if overlap <= 0 {
                        chosenX = px + dx
                        chosenY = py + dy
                        rects.append(rect)
                        found = true
                        break
                    }
                }
                radius += step
            }
            if !found {
                chosenX = bestFallback.x
                chosenY = bestFallback.y
                rects.append(CGRect(x: chosenX - pad, y: chosenY - colH - pad, width: colW + pad * 2, height: colH + pad * 2))
            }

            result.append(Placement(
                word: words[i],
                x: chosenX,
                y: chosenY,
                width: flow.w,
                scale: scale,
                isHero: isHero,
                passedRotate: (rand(i, 3) - 0.5) * 12,
                passedDriftX: CGFloat(rand(i, 5) - 0.5) * 26,
                passedDriftY: CGFloat(rand(i, 6) - 0.3) * 20
            ))
        }

        // 按词序渲染（时间顺序），放置顺序仅影响碰撞优先级
        return result.sorted { $0.word.id < $1.word.id }
    }

    // MARK: - 每帧包络（原版 getClassic* 系列）

    private func easeOutCubic(_ v: Double) -> Double {
        let c = min(max(v, 0), 1)
        return 1 - pow(1 - c, 3)
    }

    private func easeInOutQuad(_ v: Double) -> Double {
        let c = min(max(v, 0), 1)
        return c < 0.5 ? 2 * c * c : 1 - pow(-2 * c + 2, 2) / 2
    }

    /// 主体颜色进度（getClassicBodyMix）
    private func bodyMix(_ w: FoliaDisplayWord, now: Double) -> Double {
        if now < w.start { return 0 }
        if now <= w.end {
            let dur = max(w.end - w.start, 0.01)
            return min(max((now - w.start) / dur, 0), 1)
        }
        let fade = min(max((now - w.end) / 0.8, 0), 1)
        return 1 - fade
    }

    /// 辉光包络（getClassicGlowEnvelope normal 路径）
    private func glowEnvelope(_ w: FoliaDisplayWord, now: Double) -> Double {
        let dur = max(w.end - w.start, 0.1)
        if now < w.start { return 0 }
        if now <= w.end {
            let p = min(max((now - w.start) / dur, 0), 1)
            if p < 0.18 { return easeOutCubic(p / 0.18) }
            if p < 0.9 { return 1 }
            return 1 + (0.9 - 1) * ((p - 0.9) / 0.1)
        }
        let fadeOut = min(max((now - w.end) / 0.9, 0), 1)
        return 0.9 * pow(1 - fadeOut, 2)
    }

    /// passed 漂移进度（getClassicPassedDrift：5s easeInOutQuad）
    private func passedDrift(_ w: FoliaDisplayWord, now: Double) -> Double {
        guard now > w.end else { return 0 }
        return easeInOutQuad(min(max((now - w.end) / 5, 0), 1))
    }

    var body: some View {
        TimelineView(AppFrameRate.animationTimeline(
            maximumFramesPerSecond: CinemaPerformanceGovernor.shared.stageFPS,
            paused: false
        )) { _ in
            let now = PlaybackTimePublisher.shared.currentTime
            let snap = pulse.snapshot()

            ZStack {
                ForEach(placements, id: \.word.id) { p in
                    wordView(p, now: now, energy: snap.energy)
                        .offset(
                            x: p.x + p.width * CGFloat(p.scale) / 2,
                            y: p.y - wordFontSize * CGFloat(p.scale) * 0.46
                        )
                }
            }
        }
    }

    @ViewBuilder
    private func wordView(_ p: Placement, now: Double, energy: Double) -> some View {
        let w = p.word
        let mixP = bodyMix(w, now: now)
        let glow = glowEnvelope(w, now: now)
        let drift = passedDrift(w, now: now)
        let isWaiting = now < w.start - hints.wordLookahead
        // active 高频微脉冲（ACTIVE_PULSE_FREQUENCY = 10）
        let pulseWave: Double = sin(now * 10 * 2 * .pi) * 0.008 * mixP
        let pulseScale: Double = (mixP > 0.01 && now <= w.end) ? 1 + pulseWave : 1.0
        let color = mixColor(palette.base.opacity(0.5), palette.accent, p: mixP)
        let bodyOpacity: Double = 0.34 + 0.66 * mixP + glow * 0.2
        let finalOpacity: Double = isWaiting ? 0.34 : max(0.28, bodyOpacity)
        let finalScale: Double = p.scale * pulseScale * (isWaiting ? 0.96 : 1)

        ZStack(alignment: .bottomLeading) {
            Text(w.text)
                .font(.system(size: wordFontSize, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .shadow(color: palette.accent.opacity(glow * 0.9), radius: 14)
                .shadow(color: palette.accent.opacity(glow * 0.4), radius: 30)

            // 词底光束（drawBeam）：active 期间词下方的圆头光条
            if glow > 0.05 {
                let beamH = max(2, wordFontSize * (0.05 + energy * 0.03) * glow)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                palette.accent.opacity(0.05),
                                palette.accent.opacity(0.85 * glow),
                                palette.accent.opacity(0.05)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: p.width, height: beamH)
                    .offset(y: wordFontSize * 0.22)
                    .blur(radius: 0.5)
            }
        }
        .fixedSize()
        .scaleEffect(finalScale)
        .rotationEffect(.degrees(p.passedRotate * drift))
        .offset(x: p.passedDriftX * CGFloat(drift), y: p.passedDriftY * CGFloat(drift))
        .opacity(finalOpacity)
        .blur(radius: isWaiting ? 2.5 : 0)
        .animation(.easeOut(duration: 0.25), value: isWaiting)
    }

    private func mixColor(_ a: Color, _ b: Color, p: Double) -> Color {
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
