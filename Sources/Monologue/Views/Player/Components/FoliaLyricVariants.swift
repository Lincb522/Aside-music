import SwiftUI

// ============================================================
//  Folia 歌词模式变体（folia-major 移植）
//  - FoliaPartitaLineView：云阶模式（partita/VisualizerPartita.tsx）
//    先把整句拆成不等长的分行（chunk），行与行左右交错（stagger）
//    形成阶梯结构；词在既定结构里走 waiting/active/passed 三态，
//    "词穿过结构"而不是"结构跟着词重搭"
//  - FoliaTiltLineView：倾诉模式（tilt/VisualizerTilt.tsx）
//    按概率把整句切成 1~4 行，随机挑一行用斜体大字强调（字符上下
//    交错），各行按各自时间顺序渐显，字符按时间轴逐个亮起 + 脉冲
// ============================================================

// MARK: - 云阶（Partita）

struct FoliaPartitaLineView: View {
    let line: LyricLine
    let pulse: CinemaAudioPulse
    let palette: VJPalette
    let fontSize: CGFloat
    let stageHeight: CGFloat

    private struct Row {
        let words: [FoliaDisplayWord]
        let staggerX: CGFloat
        let offsetY: CGFloat
        let scale: Double
        let passedRotate: Double
    }

    private let rows: [Row]
    private let hints: FoliaRenderHints
    private let rowFontSize: CGFloat

    init(line: LyricLine, pulse: CinemaAudioPulse, palette: VJPalette, fontSize: CGFloat, stageHeight: CGFloat) {
        self.line = line
        self.pulse = pulse
        self.palette = palette
        self.fontSize = fontSize
        self.stageHeight = stageHeight
        self.rowFontSize = fontSize * 0.88

        let words = FoliaTokenizer.displayWords(for: line)
        self.hints = FoliaRenderHints.build(
            start: line.time,
            end: line.time + max(line.duration, 0.3),
            lastWordEnd: words.last?.end ?? line.time + max(line.duration, 0.3)
        )

        // 目标行数（getTargetColumnCount）：按字素量分级，再受舞台高度约束
        let graphemeCount = words.reduce(0) { $0 + $1.graphemes.count }
        let byContent: Int
        if words.count <= 2 || graphemeCount <= 5 { byContent = 1 }
        else if graphemeCount <= 10 { byContent = 2 }
        else if graphemeCount <= 16 { byContent = 3 }
        else if graphemeCount <= 24 { byContent = 4 }
        else { byContent = 5 }
        let byHeight = max(1, Int((stageHeight * 0.6) / (fontSize * 2.0)))
        let rowCount = max(1, min(words.count, min(byContent, byHeight)))

        // 原版 buildSequentialColumns：分行长度刻意不均匀（"手写谱"感）
        var seed = line.time
        func random() -> Double {
            let x = sin(seed) * 10000
            seed += 1
            return x - x.rounded(.down)
        }

        var chunks: [[FoliaDisplayWord]] = []
        var remainingUnits = words.count
        var remainingChunks = rowCount
        var cursor = 0
        for c in 0..<rowCount {
            let isLast = c == rowCount - 1
            let avg = Double(remainingUnits) / Double(remainingChunks)
            var len: Int
            if isLast {
                len = remainingUnits
            } else {
                let maxLen = Int(ceil(avg * 1.5))
                len = max(1, min(maxLen, Int((avg + (random() - 0.5) * avg).rounded())))
            }
            len = max(1, min(len, remainingUnits - (remainingChunks - 1)))
            chunks.append(Array(words[cursor..<(cursor + len)]))
            cursor += len
            remainingUnits -= len
            remainingChunks -= 1
        }

        // 行配置（stagger 交错 + 随机缩放，staggerMin 20 / staggerMax 100）
        self.rows = chunks.enumerated().map { rowIndex, chunkWords in
            let rowBias = Double(rowIndex) - Double(rowCount - 1) / 2
            let isLeft = rowIndex % 2 == 0
            let magnitude = 20.0 + random() * 80.0
            return Row(
                words: chunkWords,
                staggerX: CGFloat(isLeft ? -magnitude : magnitude),
                offsetY: CGFloat(rowBias * 2.5),
                scale: 0.8 + random() * 0.9,
                passedRotate: (rowIndex % 2 == 0 ? 1.0 : -1.0) * 3
            )
        }
    }

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

            // 行间距按行缩放上限（1.14）预留，scaleEffect 不改布局尺寸，
            // 间距不够时放大的行会压到相邻行上叠字
            VStack(spacing: rowFontSize * 0.62) {
                ForEach(rows.indices, id: \.self) { ri in
                    let row = rows[ri]
                    HStack(spacing: rowFontSize * 0.34) {
                        ForEach(row.words) { w in
                            FoliaWordView(
                                word: w,
                                config: FoliaWordConfig(
                                    x: 0, y: 0, rotate: 0,
                                    scale: 1,
                                    passedRotate: row.passedRotate
                                ),
                                status: status(w, at: t),
                                now: t,
                                palette: palette,
                                fontSize: rowFontSize,
                                isChorus: isChorus,
                                beatPulse: snap.beatPulse,
                                activeBoost: 1.12
                            )
                        }
                    }
                    .scaleEffect(min(1.14, max(0.88, row.scale)))
                    .offset(x: row.staggerX, y: row.offsetY)
                }
            }
            .frame(maxWidth: 760)
        }
    }
}

// MARK: - 倾诉（Tilt）

struct FoliaTiltLineView: View {
    let line: LyricLine
    let pulse: CinemaAudioPulse
    let palette: VJPalette
    let fontSize: CGFloat
    let stageWidth: CGFloat

    private struct Segment {
        let chars: [String]
        let isTilt: Bool
        let start: Double     // 分句开始时间
        let end: Double
    }

    private let segments: [Segment]
    private let scaleMultiplier: Double
    private let tiltFontSize: CGFloat

    init(line: LyricLine, pulse: CinemaAudioPulse, palette: VJPalette, fontSize: CGFloat, stageWidth: CGFloat) {
        self.line = line
        self.pulse = pulse
        self.palette = palette
        self.fontSize = fontSize
        self.stageWidth = stageWidth
        // 原版倾诉模式字号更大（clamp 3.125rem ~ 5.625rem）
        let baseFont = fontSize * 1.12
        self.tiltFontSize = baseFont

        let seed = line.time
        let text = line.text.trimmingCharacters(in: .whitespaces)
        let charCount = Double(text.count)

        // determineLineCount：对数标准化 × 抖动 × 分行概率(0.75)
        let normalized = log(charCount + 4) / log(20 + 4)
        let jitter = FoliaLayoutBuilder.rand(seed * 1000, 1) * 0.6 + 0.7
        let score = normalized * jitter * 0.75
        let lineCount: Int = score < 0.45 ? 1 : score < 1.05 ? 2 : score < 1.7 ? 3 : 4

        let pieces = Self.splitIntoSegments(text: text, target: lineCount)

        // 斜体行抽签（tiltStyleProbability 0.35，候选中再随机挑一行）
        var candidates: [Int] = []
        for i in pieces.indices where FoliaLayoutBuilder.rand(seed * 1000, 100 + Double(i)) < 0.35 {
            candidates.append(i)
        }
        let tiltIndex: Int = candidates.isEmpty
            ? -1
            : candidates[Int(FoliaLayoutBuilder.rand(seed * 1000, 200) * Double(candidates.count)) % candidates.count]

        // 分句时间：按字符量比例切分整句时间轴（原版按词范围求界，
        // 我们的词时间轴同样按字符占比近似）
        let lineStart = line.time
        let lineEnd = line.time + max(line.duration, 0.8)
        let totals = pieces.map { max(1, $0.count) }
        let totalChars = max(1, totals.reduce(0, +))
        var segs: [Segment] = []
        var timeCursor = lineStart
        for (i, piece) in pieces.enumerated() {
            let span = (lineEnd - lineStart) * Double(totals[i]) / Double(totalChars)
            segs.append(Segment(
                chars: piece.map(String.init),
                isTilt: i == tiltIndex,
                start: timeCursor,
                end: timeCursor + span
            ))
            timeCursor += span
        }
        self.segments = segs

        // 溢出缩放（SCALE_FLOOR 0.5）：估算最宽行宽度
        let available = stageWidth * 0.85
        var widest: CGFloat = 0
        for seg in segs {
            var w: CGFloat = 0
            for ch in seg.chars {
                let isCJK = ch.first.map { FoliaTokenizer.isCJKChar($0) } ?? false
                w += baseFont * (isCJK ? 1.0 : 0.56)
                w += baseFont * (seg.isTilt ? 0.15 : 0.08)   // letterSpacing
            }
            widest = max(widest, w)
        }
        self.scaleMultiplier = widest > available ? max(0.5, available / widest) : 1
    }

    /// 简化版 SentenceLayout.splitIntoSentences：
    /// 先按标点切，不足按字符均分补切，超出合并相邻短行
    private static func splitIntoSegments(text: String, target: Int) -> [String] {
        guard target > 1 else { return [text] }

        // 一级：标点切分（标点归属前段）
        let punctuation: Set<Character> = ["，", "。", "；", "！", "？", "、", "…", "·", ",", ".", ";", "!", "?"]
        var pieces: [String] = []
        var current = ""
        for ch in text {
            current.append(ch)
            if punctuation.contains(ch) {
                let trimmed = current.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { pieces.append(trimmed) }
                current = ""
            }
        }
        let tail = current.trimmingCharacters(in: .whitespaces)
        if !tail.isEmpty { pieces.append(tail) }
        if pieces.isEmpty { pieces = [text] }

        // 补切：把最长的段在字符中点（拉丁词不拆散）继续二分
        while pieces.count < target {
            guard let idx = pieces.indices.max(by: { pieces[$0].count < pieces[$1].count }),
                  pieces[idx].count >= 4 else { break }
            let piece = pieces[idx]
            let (a, b) = Self.bisect(piece)
            guard !a.isEmpty, !b.isEmpty else { break }
            pieces.replaceSubrange(idx...idx, with: [a, b])
        }

        // 合并：把相邻的最短对合并，直到行数达标
        while pieces.count > target {
            var bestPair = 0
            var bestLen = Int.max
            for i in 0..<(pieces.count - 1) {
                let len = pieces[i].count + pieces[i + 1].count
                if len < bestLen { bestLen = len; bestPair = i }
            }
            pieces[bestPair] = pieces[bestPair] + pieces[bestPair + 1]
            pieces.remove(at: bestPair + 1)
        }

        return pieces
    }

    /// 在字符中点附近二分，拉丁词/空格边界优先
    private static func bisect(_ text: String) -> (String, String) {
        let chars = Array(text)
        let mid = chars.count / 2
        // 就近找空格或 CJK 边界
        var cut = mid
        var bestDist = Int.max
        for i in 1..<chars.count {
            let boundary = chars[i - 1] == " "
                || FoliaTokenizer.isCJKChar(chars[i - 1])
                || FoliaTokenizer.isCJKChar(chars[i])
            if boundary {
                let d = abs(i - mid)
                if d < bestDist { bestDist = d; cut = i }
            }
        }
        let a = String(chars[0..<cut]).trimmingCharacters(in: .whitespaces)
        let b = String(chars[cut...]).trimmingCharacters(in: .whitespaces)
        return (a, b)
    }

    var body: some View {
        TimelineView(AppFrameRate.animationTimeline(
            maximumFramesPerSecond: CinemaPerformanceGovernor.shared.stageFPS,
            paused: false
        )) { _ in
            let t = PlaybackTimePublisher.shared.currentTime

            VStack(spacing: tiltFontSize * 0.3) {
                ForEach(segments.indices, id: \.self) { si in
                    segmentView(segments[si], now: t)
                }
            }
            .scaleEffect(scaleMultiplier)
            .frame(maxWidth: 780)
        }
    }

    @ViewBuilder
    private func segmentView(_ seg: Segment, now: Double) -> some View {
        // 分句提前 0.25s 渐显（原版 visibleSegmentIndex 逻辑）
        let revealAt = seg.start - 0.25
        let containerP = smooth((now - revealAt) / 0.55)

        if containerP > 0.001 {
            HStack(spacing: 0) {
                ForEach(seg.chars.indices, id: \.self) { ci in
                    charView(seg, index: ci, now: now, revealAt: revealAt)
                }
            }
            .opacity(containerP)
            .offset(y: (seg.isTilt ? 24 : 20) * (1 - containerP))
            .scaleEffect(seg.isTilt ? 0.92 + 0.08 * containerP : 1)
        }
    }

    @ViewBuilder
    private func charView(_ seg: Segment, index ci: Int, now: Double, revealAt: Double) -> some View {
        let ch = seg.chars[ci]
        let charCount = max(1, seg.chars.count)
        // 逐字时间轴：分句时长均分（buildCharTimings 均分回退路径）
        let charDur = max((seg.end - seg.start) / Double(charCount), 0.05)
        let charStart = seg.start + Double(ci) * charDur
        // 逐字渐显：delay = ci * 0.04（tilt 0.05），时长 0.5
        let delay = Double(ci) * (seg.isTilt ? 0.05 : 0.04)
        let fadeP = smooth((now - revealAt - delay) / 0.5)
        // 脉冲（getCharPulseIntensity）：sin 包络 + 0.25 余晖
        let pulseI = charPulse(now: now, start: charStart, dur: charDur)
        let scale = 1 + pulseI * (seg.isTilt ? 0.18 : 0.15)
        // 斜体行字符上下交错（yOffset = 字号/6，进场时从 2 倍收拢）
        let stagger: CGFloat = seg.isTilt
            ? (ci % 2 == 0 ? -1 : 1) * tiltFontSize / 6 * (2 - CGFloat(fadeP))
            : 0

        Text(ch == " " ? "\u{00A0}" : ch)
            .font(.system(
                size: tiltFontSize,
                weight: seg.isTilt ? .light : .regular,
                design: .rounded
            ))
            .italic(seg.isTilt)
            .tracking(tiltFontSize * (seg.isTilt ? 0.15 : 0.08))
            .foregroundColor(seg.isTilt ? palette.accent : palette.base)
            .opacity(fadeP)
            .scaleEffect(scale)
            .offset(y: stagger)
            .shadow(
                color: (seg.isTilt ? palette.accent : palette.base).opacity(pulseI * 0.4),
                radius: 8
            )
    }

    /// 原版 getCharPulseIntensity：唱到时 sin 包络冲顶，随后爬升到 0.25 余晖
    private func charPulse(now: Double, start: Double, dur: Double) -> Double {
        let duration = min(max(dur, 0.2), 0.9)
        let elapsed = now - start
        if elapsed < 0 { return 0 }
        if elapsed <= duration {
            return sin(elapsed / duration * .pi)
        }
        let after = elapsed - duration
        let ramp = duration * 1.2
        if after >= ramp { return 0.25 }
        return 0.25 * (after / ramp)
    }

    private func smooth(_ x: Double) -> Double {
        let c = min(1, max(0, x))
        return c * c * (3 - 2 * c)
    }
}
