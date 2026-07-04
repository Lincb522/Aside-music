import SwiftUI

// ============================================================
//  folia-major 全舞台歌词模式移植（多行上下文，不走单句转场壳）
//
//  - FoliaFumeStage（浮名，fume/VisualizerFume.tsx）
//    整首歌词排成一篇"文章"，镜头在纸面上移动追焦当前句；
//    字素随演唱逐个"印刷"上纸，唱过的段落留在纸面上
//  - FoliaCappellaStage（群唱，cappella/VisualizerCappella.tsx）
//    歌词变成聊天室叙事：每句一个气泡，左右分侧、头像固定、
//    当前气泡逐字打字，旧气泡上推淡出
//  - FoliaMonetStage（莫奈，monet/VisualizerMonet.tsx）
//    海报式布局：左侧艺术家 + 大标题 + 歌词轨道，右侧封面肖像，
//    底部音频律动条
// ============================================================

// MARK: - 浮名（Fume）

struct FoliaFumeStage: View {
    let lyrics: [LyricLine]
    let currentIndex: Int
    let pulse: CinemaAudioPulse
    let palette: VJPalette
    let size: CGSize

    /// 可见窗口：当前句前 3 后 5
    private var window: [(index: Int, line: LyricLine)] {
        let lo = max(0, currentIndex - 3)
        let hi = min(lyrics.count - 1, currentIndex + 5)
        guard lo <= hi else { return [] }
        return (lo...hi).map { ($0, lyrics[$0]) }
    }

    var body: some View {
        let blocks = window
        let activePos = blocks.firstIndex { $0.index == currentIndex } ?? 0

        TimelineView(AppFrameRate.animationTimeline(
            maximumFramesPerSecond: CinemaPerformanceGovernor.shared.stageFPS,
            paused: false
        )) { _ in
            let now = PlaybackTimePublisher.shared.currentTime

            // 文章块尺寸估算 → 镜头 y 偏移（追焦当前块居中）
            let blockHeights: [CGFloat] = blocks.map { blockHeight(for: $0.line) }
            let spacing: CGFloat = 26
            let offsetToActive: CGFloat = blockHeights.prefix(activePos).reduce(0) { $0 + $1 + spacing }
            let activeHeight: CGFloat = activePos < blockHeights.count ? blockHeights[activePos] : 0
            let totalHeight: CGFloat = blockHeights.reduce(0, +) + spacing * CGFloat(max(blockHeights.count - 1, 0))
            // VStack 以内容中心为锚点，镜头偏移 = 内容中心到当前块中心的距离
            let cameraY: CGFloat = totalHeight / 2 - offsetToActive - activeHeight / 2

            VStack(alignment: .leading, spacing: spacing) {
                ForEach(blocks, id: \.index) { entry in
                    fumeBlock(entry.line, state: blockState(entry.index), now: now)
                }
            }
            .frame(width: min(size.width * 0.56, 560), alignment: .leading)
            .padding(28)
            .background(
                // 纸面（paper）
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.035))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(palette.base.opacity(0.08), lineWidth: 1)
                    )
            )
            .offset(y: cameraY)
            // 镜头追焦：块切换时平滑推移 + 轻微聚焦放大
            .animation(.spring(response: 0.85, dampingFraction: 0.9), value: currentIndex)
            .scaleEffect(1.02)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .mask(
            // 上下渐隐：只让镜头焦点附近的文章可读
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.22),
                    .init(color: .black, location: 0.78),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private enum BlockState { case passed, active, future }

    private func blockState(_ index: Int) -> BlockState {
        if index < currentIndex { return .passed }
        if index > currentIndex { return .future }
        return .active
    }

    private var blockFont: CGFloat { min(30, max(19, size.width * 0.026)) }

    private func blockHeight(for line: LyricLine) -> CGFloat {
        // 粗估行数：可用宽度 / 平均字宽
        let width = min(size.width * 0.56, 560) - 56
        var w: CGFloat = 0
        for ch in line.text { w += blockFont * (FoliaTokenizer.isCJKChar(ch) ? 1.02 : 0.52) }
        let rows = max(1, ceil(w / width))
        return rows * blockFont * 1.4
    }

    @ViewBuilder
    private func fumeBlock(_ line: LyricLine, state: BlockState, now: Double) -> some View {
        switch state {
        case .passed:
            // 已印刷：留在纸面上（原版 passed text 层）
            Text(line.text)
                .font(.system(size: blockFont, weight: .medium, design: .serif))
                .foregroundColor(palette.base.opacity(0.42))
                .fixedSize(horizontal: false, vertical: true)
        case .future:
            // 未印刷：纸面上只有极淡的"底稿"
            Text(line.text)
                .font(.system(size: blockFont, weight: .medium, design: .serif))
                .foregroundColor(palette.base.opacity(0.10))
                .fixedSize(horizontal: false, vertical: true)
        case .active:
            // 印刷中：字素随演唱逐个上纸，刚印上的带辉光
            activeBlock(line, now: now)
        }
    }

    @ViewBuilder
    private func activeBlock(_ line: LyricLine, now: Double) -> some View {
        let words = FoliaTokenizer.displayWords(for: line)
        // 用 Text 拼接保持自然换行（AttributedString 逐字素着色）
        let printed = printedText(words: words, now: now)
        printed
            .font(.system(size: blockFont * 1.08, weight: .semibold, design: .serif))
            .fixedSize(horizontal: false, vertical: true)
            .shadow(color: palette.accent.opacity(0.35), radius: 12)
    }

    private func printedText(words: [FoliaDisplayWord], now: Double) -> Text {
        var result = Text(verbatim: "")
        for (wi, w) in words.enumerated() {
            for g in w.graphemes {
                let dur = max(g.end - g.start, 0.03)
                let p = min(1, max(0, (now - g.start) / dur))
                let color: Color
                if p <= 0 {
                    color = palette.base.opacity(0.13)          // 底稿
                } else if p < 1 {
                    color = palette.accent                       // 印刷中：高亮
                } else {
                    // 刚印完 0.6s 内从 accent 回落到正文色
                    let cool = min(1, max(0, (now - g.end) / 0.6))
                    color = cool < 1 ? palette.accent.opacity(1 - cool * 0.35) : palette.base.opacity(0.92)
                }
                result = result + Text(verbatim: g.char).foregroundColor(color)
            }
            // 词间空格（拉丁词之间）
            if wi < words.count - 1,
               let last = w.text.last, !FoliaTokenizer.isCJKChar(last) {
                result = result + Text(verbatim: " ")
            }
        }
        return result
    }
}

// MARK: - 群唱（Cappella）

struct FoliaCappellaStage: View {
    let lyrics: [LyricLine]
    let currentIndex: Int
    let pulse: CinemaAudioPulse
    let palette: VJPalette
    let size: CGSize

    private enum ChatSide { case left, right }

    /// 原版 sideSequence + flip 概率：每句的侧向/头像确定性分配
    private func sideFor(_ index: Int) -> ChatSide {
        let sequence: [ChatSide] = [.left, .right, .left, .right, .right]
        let base = sequence[index % sequence.count]
        let flip = FoliaLayoutBuilder.rand(Double(index) * 7.7, 11) < 0.18
        if flip { return base == .left ? .right : .left }
        return base
    }

    private static let avatarGlyphs = ["🎤", "🎧", "🎸", "🎹", "🥁", "🎻", "🎺", "🪕", "🎷"]

    private func avatarFor(_ index: Int) -> String {
        let i = Int(FoliaLayoutBuilder.rand(Double(index) * 3.3, 21) * Double(Self.avatarGlyphs.count))
        return Self.avatarGlyphs[min(i, Self.avatarGlyphs.count - 1)]
    }

    /// 可见气泡：当前句 + 之前 3 句
    private var visible: [(index: Int, line: LyricLine)] {
        guard currentIndex >= 0, !lyrics.isEmpty else { return [] }
        let lo = max(0, currentIndex - 3)
        let hi = min(lyrics.count - 1, currentIndex)
        return (lo...hi).compactMap { i in
            let line = lyrics[i]
            let t = line.text.trimmingCharacters(in: .whitespaces)
            guard !t.isEmpty, t != "......", t != "…" else { return nil }
            return (i, line)
        }
    }

    var body: some View {
        TimelineView(AppFrameRate.animationTimeline(
            maximumFramesPerSecond: CinemaPerformanceGovernor.shared.stageFPS,
            paused: false
        )) { _ in
            let now = PlaybackTimePublisher.shared.currentTime

            VStack(spacing: 14) {
                Spacer(minLength: 0)
                ForEach(visible, id: \.index) { entry in
                    bubbleRow(entry.line, index: entry.index, isActive: entry.index == currentIndex, now: now)
                        .transition(
                            .asymmetric(
                                insertion: .offset(y: 26).combined(with: .opacity).combined(with: .scale(scale: 0.9)),
                                removal: .opacity
                            )
                        )
                }
            }
            .frame(maxWidth: min(size.width * 0.58, 600))
            .animation(.spring(response: 0.5, dampingFraction: 0.82), value: currentIndex)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }

    @ViewBuilder
    private func bubbleRow(_ line: LyricLine, index: Int, isActive: Bool, now: Double) -> some View {
        let side = sideFor(index)
        let age = currentIndex - index

        HStack(alignment: .bottom, spacing: 10) {
            if side == .right { Spacer(minLength: 40) }

            if side == .left { avatarView(index) }

            bubble(line, isActive: isActive, side: side, now: now)

            if side == .right { avatarView(index) }

            if side == .left { Spacer(minLength: 40) }
        }
        .opacity(isActive ? 1 : max(0.35, 1 - Double(age) * 0.22))
        .scaleEffect(isActive ? 1 : max(0.9, 1 - Double(age) * 0.03), anchor: side == .left ? .bottomLeading : .bottomTrailing)
    }

    private func avatarView(_ index: Int) -> some View {
        Text(avatarFor(index))
            .font(.system(size: 17))
            .frame(width: 34, height: 34)
            .background(Circle().fill(Color.white.opacity(0.10)))
            .overlay(Circle().stroke(palette.base.opacity(0.2), lineWidth: 1))
    }

    @ViewBuilder
    private func bubble(_ line: LyricLine, isActive: Bool, side: ChatSide, now: Double) -> some View {
        let fontSize = min(24, max(17, size.width * 0.021))

        Group {
            if isActive {
                typedText(line, now: now)
                    .font(.system(size: fontSize, weight: .semibold, design: .rounded))
            } else {
                Text(line.text)
                    .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                    .foregroundColor(palette.base.opacity(0.85))
            }
        }
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 18,
                bottomLeadingRadius: side == .left ? 5 : 18,
                bottomTrailingRadius: side == .right ? 5 : 18,
                topTrailingRadius: 18,
                style: .continuous
            )
            .fill(isActive ? palette.accent.opacity(0.16) : Color.white.opacity(0.07))
        )
        .overlay(
            UnevenRoundedRectangle(
                topLeadingRadius: 18,
                bottomLeadingRadius: side == .left ? 5 : 18,
                bottomTrailingRadius: side == .right ? 5 : 18,
                topTrailingRadius: 18,
                style: .continuous
            )
            .stroke(isActive ? palette.accent.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    /// 当前气泡逐字打字（字素时间轴驱动）
    private func typedText(_ line: LyricLine, now: Double) -> Text {
        let words = FoliaTokenizer.displayWords(for: line)
        var result = Text(verbatim: "")
        for (wi, w) in words.enumerated() {
            for g in w.graphemes {
                // 打字机语义：到点出现，微提前 0.05s 让节奏不迟钝
                let appeared = now >= g.start - 0.05
                if appeared {
                    let fresh = now - g.start < 0.18
                    result = result + Text(verbatim: g.char)
                        .foregroundColor(fresh ? palette.accent : palette.base.opacity(0.95))
                }
            }
            if wi < words.count - 1,
               let last = w.text.last, !FoliaTokenizer.isCJKChar(last),
               now >= w.end - 0.05 {
                result = result + Text(verbatim: " ")
            }
        }
        // 打字光标
        if now < (words.last?.end ?? 0) {
            let blink = sin(now * 6) > 0
            result = result + Text(verbatim: "▎").foregroundColor(palette.accent.opacity(blink ? 0.9 : 0.25))
        }
        return result
    }
}

// MARK: - 莫奈（Monet）

struct FoliaMonetStage: View {
    let song: Song
    let lyrics: [LyricLine]
    let currentIndex: Int
    let pulse: CinemaAudioPulse
    let palette: VJPalette
    let size: CGSize
    let showTranslation: Bool

    var body: some View {
        HStack(spacing: 0) {
            leftColumn
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.leading, 46)
                .padding(.vertical, 30)

            portrait
                .padding(.trailing, 42)
        }
        .frame(maxWidth: min(size.width, 1100), maxHeight: .infinity)
        .overlay(alignment: .bottom) { audioBars }
    }

    // 左列：艺术家 → 竖线 → 大标题 → 元信息 → 歌词轨道
    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(song.artistName)
                .font(.system(size: min(24, max(15, size.width * 0.018)), weight: .regular, design: .serif))
                .italic()
                .foregroundColor(palette.base.opacity(0.96))

            // 渐隐竖线（原版 h-14 w-px gradient）
            LinearGradient(
                colors: [palette.base.opacity(0.72), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: 1, height: 42)
            .padding(.vertical, 8)

            Text(song.name)
                .font(.system(size: min(42, max(23, size.width * 0.033)), weight: .semibold, design: .serif))
                .foregroundColor(palette.base)
                .lineLimit(2)
                .shadow(color: .black.opacity(0.28), radius: 18, y: 7)

            Text((song.album?.name ?? "").uppercased())
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .tracking(2)
                .foregroundColor(palette.base.opacity(0.5))
                .padding(.top, 4)

            lyricsRail
                .padding(.top, 22)

            Spacer(minLength: 0)
        }
    }

    /// 歌词轨道（MonetLyricsRail）：上句小字 → 当前句大字卡拉 OK → 下句小字
    private var lyricsRail: some View {
        TimelineView(AppFrameRate.animationTimeline(
            maximumFramesPerSecond: CinemaPerformanceGovernor.shared.stageFPS,
            paused: false
        )) { _ in
            let now = PlaybackTimePublisher.shared.currentTime
            let active: LyricLine? = lyrics.indices.contains(currentIndex) ? lyrics[currentIndex] : nil
            let prev: LyricLine? = lyrics.indices.contains(currentIndex - 1) ? lyrics[currentIndex - 1] : nil
            let next: LyricLine? = lyrics.indices.contains(currentIndex + 1) ? lyrics[currentIndex + 1] : nil
            let bigFont = min(30, max(19, size.width * 0.024))
            let smallFont = min(19, max(13, size.width * 0.015))

            VStack(alignment: .leading, spacing: 9) {
                if let prev {
                    Text(prev.text)
                        .font(.system(size: smallFont, weight: .regular, design: .serif))
                        .foregroundColor(palette.base.opacity(0.35))
                        .lineLimit(1)
                }

                if let active {
                    karaokeText(active, now: now)
                        .font(.system(size: bigFont, weight: .semibold, design: .serif))
                        .fixedSize(horizontal: false, vertical: true)
                        .id(currentIndex)
                        .transition(.opacity.combined(with: .offset(y: 8)))

                    if showTranslation, let trans = active.translation, !trans.isEmpty {
                        Text(trans)
                            .font(.system(size: smallFont, weight: .regular, design: .serif))
                            .foregroundColor(palette.base.opacity(0.55))
                            .lineLimit(2)
                    }
                }

                if let next {
                    Text(next.text)
                        .font(.system(size: smallFont, weight: .regular, design: .serif))
                        .foregroundColor(palette.base.opacity(0.35))
                        .lineLimit(1)
                }
            }
            .animation(.easeOut(duration: 0.35), value: currentIndex)
        }
    }

    /// 卡拉 OK：唱到的词染 accent（原版 keyword coloring + 进度色）
    private func karaokeText(_ line: LyricLine, now: Double) -> Text {
        let words = FoliaTokenizer.displayWords(for: line)
        guard !words.isEmpty else {
            return Text(line.text).foregroundColor(palette.base)
        }
        var result = Text(verbatim: "")
        for (wi, w) in words.enumerated() {
            let sung = now >= w.end
            let singing = now >= w.start && now < w.end
            let color: Color = singing ? palette.accent : (sung ? palette.base : palette.base.opacity(0.45))
            result = result + Text(verbatim: w.text).foregroundColor(color)
            if wi < words.count - 1,
               let last = w.text.last, !FoliaTokenizer.isCJKChar(last) {
                result = result + Text(verbatim: " ")
            }
        }
        return result
    }

    // 右侧肖像（portrait）：封面竖版卡片
    private var portrait: some View {
        let h = min(size.height * 0.62, 330)
        return Group {
            if let url = song.coverUrl?.sized(500) {
                CachedAsyncImage(url: url) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                }
                .aspectRatio(0.74, contentMode: .fill)
                .frame(width: h * 0.74, height: h)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(palette.base.opacity(0.16), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.4), radius: 26, y: 12)
            }
        }
    }

    /// 底部音频律动条（原版 bottom h-10 音频条带）
    private var audioBars: some View {
        TimelineView(AppFrameRate.animationTimeline(maximumFramesPerSecond: 30, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let snap = pulse.snapshot()

            Canvas { context, canvasSize in
                let barCount = 42
                let gap: CGFloat = 5
                let barW = (canvasSize.width - gap * CGFloat(barCount - 1)) / CGFloat(barCount)
                for i in 0..<barCount {
                    let f = Double(i) / Double(barCount - 1)
                    // 三段频带插值 + 每条抖动
                    let band = f < 0.33 ? snap.bass : (f < 0.66 ? snap.mid : snap.treble)
                    let jitter = 0.5 + 0.5 * sin(t * (2.2 + f * 3.1) + Double(i) * 1.7)
                    let level = min(1, band * 0.85 + jitter * 0.18 + snap.beatPulse * 0.15)
                    let h = max(2, canvasSize.height * level)
                    let rect = CGRect(
                        x: CGFloat(i) * (barW + gap),
                        y: canvasSize.height - h,
                        width: barW,
                        height: h
                    )
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: barW / 2),
                        with: .color(palette.accent.opacity(0.28 + level * 0.4))
                    )
                }
            }
        }
        .frame(height: 34)
        .padding(.horizontal, 52)
        .padding(.bottom, 10)
        .allowsHitTesting(false)
    }
}
