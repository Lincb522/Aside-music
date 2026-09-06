//  Dedicated Latin / non-Chinese visualizers. Foreign lyrics stay word-led
//  instead of inheriting the character-led composition used for Chinese.

import SwiftUI

// MARK: - Shared foreign lyric structure

private struct AriaForeignPhrase: Identifiable {
    let id: Int
    let tokens: [AriaFoliaToken]

    var start: Double { tokens.first?.start ?? 0 }
    var end: Double { tokens.last?.end ?? start }
    var text: String { tokens.map(\.text).joined(separator: " ") }
}

private enum AriaForeignPhraseCache {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var storage: [String: [AriaForeignPhrase]] = [:]

    static func phrases(for line: AriaLine, maximumCount: Int) -> [AriaForeignPhrase] {
        let key = "\(line.id)|\(line.fullText.hashValue)|\(maximumCount)"

        lock.lock()
        defer { lock.unlock() }

        if let cached = storage[key] {
            return cached
        }

        let tokens = AriaFoliaTokenCache.tokens(for: line)
        guard !tokens.isEmpty else { return [] }

        let phraseCount = min(
            max(1, Int(ceil(Double(tokens.count) / 3))),
            max(maximumCount, 1)
        )
        let baseLength = tokens.count / phraseCount
        let remainder = tokens.count % phraseCount
        var cursor = 0
        var phrases: [AriaForeignPhrase] = []

        for index in 0..<phraseCount {
            let length = baseLength + (index < remainder ? 1 : 0)
            let end = min(cursor + max(length, 1), tokens.count)
            guard cursor < end else { continue }
            phrases.append(
                AriaForeignPhrase(
                    id: index,
                    tokens: Array(tokens[cursor..<end])
                )
            )
            cursor = end
        }

        if storage.count >= 96 {
            storage.removeAll(keepingCapacity: true)
        }
        storage[key] = phrases
        return phrases
    }
}

private enum AriaForeignRuntime {
    static func activeTokenIndex(
        in tokens: [AriaFoliaToken],
        hints: AriaRenderHints,
        time: Double
    ) -> Int {
        if let active = tokens.firstIndex(where: {
            AriaFoliaRuntime.status(for: $0, hints: hints, time: time) == .active
        }) {
            return active
        }
        if let passed = tokens.lastIndex(where: { time >= $0.start }) {
            return passed
        }
        return tokens.isEmpty ? -1 : 0
    }

    static func phraseStatus(
        _ phrase: AriaForeignPhrase,
        hints: AriaRenderHints,
        time: Double
    ) -> AriaWordStatus {
        let end = phrase.tokens.last.map {
            AriaFoliaRuntime.activeEnd(for: $0, hints: hints)
        } ?? phrase.end
        if time >= phrase.start - hints.wordLookahead, time <= end {
            return .active
        }
        return time > end ? .passed : .waiting
    }
}

private struct AriaForeignCenteredFlowLayout: Layout {
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    private struct Row {
        let range: Range<Int>
        let width: CGFloat
        let height: CGFloat
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maximumWidth = proposal.width ?? .infinity
        let rows = makeRows(subviews: subviews, maximumWidth: maximumWidth)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.reduce(CGFloat.zero) { $0 + $1.height }
            + CGFloat(max(rows.count - 1, 0)) * verticalSpacing
        return CGSize(width: width, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let rows = makeRows(subviews: subviews, maximumWidth: bounds.width)
        var y = bounds.minY

        for row in rows {
            var x = bounds.midX - row.width / 2
            for index in row.range {
                let size = measuredSize(
                    for: subviews[index],
                    maximumWidth: bounds.width
                )
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(size)
                )
                x += size.width + horizontalSpacing
            }
            y += row.height + verticalSpacing
        }
    }

    private func makeRows(
        subviews: Subviews,
        maximumWidth: CGFloat
    ) -> [Row] {
        guard !subviews.isEmpty else { return [] }

        var rows: [Row] = []
        var start = 0
        var width: CGFloat = 0
        var height: CGFloat = 0

        for index in subviews.indices {
            let size = measuredSize(
                for: subviews[index],
                maximumWidth: maximumWidth
            )
            let proposed = width == 0 ? size.width : width + horizontalSpacing + size.width
            if proposed > maximumWidth, index > start {
                rows.append(Row(range: start..<index, width: width, height: height))
                start = index
                width = size.width
                height = size.height
            } else {
                width = proposed
                height = max(height, size.height)
            }
        }

        rows.append(Row(range: start..<subviews.count, width: width, height: height))
        return rows
    }

    private func measuredSize(
        for subview: LayoutSubview,
        maximumWidth: CGFloat
    ) -> CGSize {
        let natural = subview.sizeThatFits(.unspecified)
        guard maximumWidth.isFinite, natural.width > maximumWidth else {
            return natural
        }
        let constrained = subview.sizeThatFits(
            ProposedViewSize(width: maximumWidth, height: nil)
        )
        return CGSize(
            width: min(maximumWidth, constrained.width),
            height: constrained.height
        )
    }
}

private struct AriaForeignPauseMark: View {
    let line: AriaLine
    let palette: AriaPalette
    let time: Double

    var body: some View {
        let progress = AriaFoliaRuntime.clamp(
            (time - line.startTime) / max(line.rawDuration, 0.1)
        )

        HStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(
                        index <= Int(progress * 4)
                            ? palette.accent
                            : palette.primary.opacity(0.16)
                    )
                    .frame(width: index.isMultiple(of: 2) ? 28 : 14, height: 3)
            }
        }
    }
}

// MARK: - Foreign Classic

struct AriaForeignClassicLyricStage: View {
    let line: AriaLine
    let palette: AriaPalette
    let fontChoice: AriaLyricFontChoice
    let fontScale: Double
    let time: Double
    let stageSize: CGSize
    /// 人声呼吸字重 0~1（0 = 关闭）
    var breathing: Double = 0

    var body: some View {
        if line.isInterlude {
            AriaForeignPauseMark(line: line, palette: palette, time: time)
        } else {
            let fontSize = min(max(stageSize.width * 0.052, 38), 66)
                * CGFloat(fontScale)
            let tokens = AriaFoliaTokenCache.tokens(for: line)
            let baseFont = fontChoice.font(size: fontSize, weight: .bold)
            let breathingFont = breathing > 0.001
                ? fontChoice.breathingFont(
                    size: fontSize,
                    amount: breathing,
                    baseWeight: .bold
                )
                : nil
            let colorMixer = AriaFoliaColor.mixer(palette.primary, palette.accent)

            AriaForeignCenteredFlowLayout(
                horizontalSpacing: max(12, fontSize * 0.22),
                verticalSpacing: max(10, fontSize * 0.16)
            ) {
                ForEach(tokens) { token in
                    AriaForeignClassicWord(
                        token: token,
                        hints: line.hints,
                        palette: palette,
                        fontChoice: fontChoice,
                        baseFont: baseFont,
                        breathingFont: breathingFont,
                        colorMixer: colorMixer,
                        time: time,
                        breathing: breathing
                    )
                }
            }
            .frame(width: max(260, stageSize.width * 0.82))
            .padding(.vertical, max(18, fontSize * 0.34))
        }
    }
}

private struct AriaForeignClassicWord: View {
    let token: AriaFoliaToken
    let hints: AriaRenderHints
    let palette: AriaPalette
    let fontChoice: AriaLyricFontChoice
    let baseFont: Font
    let breathingFont: Font?
    let colorMixer: AriaFoliaColor.Mixer
    let time: Double
    var breathing: Double = 0

    private var status: AriaWordStatus {
        AriaFoliaRuntime.status(for: token, hints: hints, time: time)
    }

    var body: some View {
        let mix = AriaFoliaRuntime.bodyMix(for: token, hints: hints, time: time)
        let glow = AriaFoliaRuntime.glowEnvelope(for: token, hints: hints, time: time)
        let color = status == .waiting
            ? palette.primary.opacity(0.17)
            : colorMixer.color(amount: mix)

        Text(token.text)
            .font(status == .active ? (breathingFont ?? baseFont) : baseFont)
            .italic(status == .active)
            .foregroundStyle(color)
            .ariaSyntheticBreathingWeight(
                fontChoice: fontChoice,
                amount: breathing,
                active: status == .active
            )
            .lineLimit(1)
            .fixedSize()
            .opacity(status == .passed ? 0.66 : 1)
            .scaleEffect(status == .active ? 1.09 : 1)
            .offset(y: status == .waiting ? 13 : (status == .active ? -3 : 0))
            .overlay(alignment: .bottom) {
                Capsule()
                    .fill(palette.accent.opacity(status == .active ? 0.78 : 0))
                    .frame(height: 2)
                    .offset(y: 7)
            }
            .modifier(
                AriaForeignClassicGlowModifier(
                    color: palette.accent,
                    glow: glow
                )
            )
            .animation(.smooth(duration: 0.26), value: status)
    }
}

private struct AriaForeignClassicGlowModifier: ViewModifier {
    let color: Color
    let glow: Double

    @ViewBuilder
    func body(content: Content) -> some View {
        if glow > 0.001 {
            content.shadow(color: color.opacity(glow * 0.38), radius: 14)
        } else {
            content
        }
    }
}

// MARK: - Foreign Cadenza

struct AriaForeignCadenzaLineView: View {
    let line: AriaLine
    let palette: AriaPalette
    let fontChoice: AriaLyricFontChoice
    let fontScale: Double
    let time: Double
    let stageSize: CGSize

    var body: some View {
        GeometryReader { proxy in
            let tokens = AriaFoliaTokenCache.tokens(for: line)
            let activeIndex = AriaForeignRuntime.activeTokenIndex(
                in: tokens,
                hints: line.hints,
                time: time
            )
            let spacing = min(max(proxy.size.width * 0.19, 104), 156)

            ZStack {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.clear, palette.primary.opacity(0.12), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: proxy.size.width * 0.76, height: 1)

                ForEach(tokens.indices, id: \.self) { index in
                    let token = tokens[index]
                    let relativeIndex = index - activeIndex
                    if abs(relativeIndex) <= 3 {
                        AriaForeignCadenzaWord(
                            token: token,
                            relativeIndex: relativeIndex,
                            hints: line.hints,
                            palette: palette,
                            fontChoice: fontChoice,
                            fontScale: fontScale,
                            time: time,
                            availableWidth: proxy.size.width
                        )
                        .position(
                            x: proxy.size.width / 2 + CGFloat(relativeIndex) * spacing,
                            y: proxy.size.height / 2
                                + sin(CGFloat(relativeIndex) * 1.15) * 44
                        )
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .animation(.smooth(duration: 0.32), value: activeIndex)
        }
    }
}

private struct AriaForeignCadenzaWord: View {
    let token: AriaFoliaToken
    let relativeIndex: Int
    let hints: AriaRenderHints
    let palette: AriaPalette
    let fontChoice: AriaLyricFontChoice
    let fontScale: Double
    let time: Double
    let availableWidth: CGFloat

    var body: some View {
        let isHero = relativeIndex == 0
        let distance = abs(relativeIndex)
        let status = AriaFoliaRuntime.status(for: token, hints: hints, time: time)
        let glow = AriaFoliaRuntime.glowEnvelope(for: token, hints: hints, time: time)
        let fontSize = (isHero ? min(92, availableWidth * 0.105) : 30)
            * CGFloat(fontScale)

        Text(token.text)
            .font(fontChoice.font(size: fontSize, weight: isHero ? .heavy : .medium))
            .italic(isHero)
            .tracking(isHero ? -1 : 1.2)
            .foregroundStyle(isHero ? palette.accent : palette.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.48)
            .frame(width: isHero ? availableWidth * 0.42 : availableWidth * 0.18)
            .opacity(isHero ? 1 : max(0.18, 0.68 - Double(distance) * 0.15))
            .scaleEffect(isHero ? 1.05 : max(0.72, 1 - CGFloat(distance) * 0.08))
            .blur(radius: distance >= 3 ? 1.5 : 0)
            .shadow(color: palette.accent.opacity(glow * 0.55), radius: 20)
            .overlay(alignment: .bottom) {
                if isHero {
                    Capsule()
                        .fill(palette.accent.opacity(0.7))
                        .frame(width: 44, height: 3)
                        .offset(y: 11)
                }
            }
            .opacity(status == .waiting && !isHero ? 0.28 : 1)
    }
}

// MARK: - Foreign Partita

struct AriaForeignPartitaLineView: View {
    let line: AriaLine
    let palette: AriaPalette
    let fontChoice: AriaLyricFontChoice
    let fontScale: Double
    let time: Double
    let stageSize: CGSize

    var body: some View {
        let phrases = AriaForeignPhraseCache.phrases(for: line, maximumCount: 5)
        let fontSize = min(max(stageSize.width * 0.038, 28), 48)
            * CGFloat(fontScale)
        let center = CGFloat(phrases.count - 1) / 2
        let direction: CGFloat = line.id.isMultiple(of: 2) ? 1 : -1
        let step = min(stageSize.width * 0.055, 46)

        VStack(spacing: max(8, fontSize * 0.16)) {
            ForEach(phrases) { phrase in
                AriaForeignPartitaPhraseRow(
                    phrase: phrase,
                    hints: line.hints,
                    palette: palette,
                    fontChoice: fontChoice,
                    fontSize: fontSize,
                    time: time,
                    guideFromLeading: direction > 0
                )
                .offset(x: (CGFloat(phrase.id) - center) * step * direction)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct AriaForeignPartitaPhraseRow: View {
    let phrase: AriaForeignPhrase
    let hints: AriaRenderHints
    let palette: AriaPalette
    let fontChoice: AriaLyricFontChoice
    let fontSize: CGFloat
    let time: Double
    let guideFromLeading: Bool

    private var status: AriaWordStatus {
        AriaForeignRuntime.phraseStatus(phrase, hints: hints, time: time)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: max(8, fontSize * 0.18)) {
            ForEach(phrase.tokens) { token in
                let tokenStatus = AriaFoliaRuntime.status(for: token, hints: hints, time: time)
                let mix = AriaFoliaRuntime.bodyMix(for: token, hints: hints, time: time)

                Text(token.text)
                    .font(fontChoice.font(size: fontSize, weight: .semibold))
                    .italic(tokenStatus == .active)
                    .foregroundStyle(
                        tokenStatus == .waiting
                            ? palette.primary.opacity(0.2)
                            : AriaFoliaColor.mix(
                                palette.primary,
                                palette.accent,
                                amount: mix
                            )
                    )
                    .scaleEffect(tokenStatus == .active ? 1.08 : 1)
            }
        }
        .fixedSize()
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .overlay(alignment: guideFromLeading ? .bottomLeading : .bottomTrailing) {
            HStack(spacing: 5) {
                Circle()
                    .fill(status == .active ? palette.accent : palette.primary.opacity(0.22))
                    .frame(width: 4, height: 4)
                Capsule()
                    .fill(status == .active ? palette.accent : palette.primary.opacity(0.16))
                    .frame(width: max(40, fontSize * 1.4), height: 1)
            }
            .offset(y: 6)
        }
        .opacity(status == .waiting ? 0.3 : (status == .passed ? 0.65 : 1))
        .offset(y: status == .waiting ? 10 : 0)
        .animation(.smooth(duration: 0.28), value: status)
    }
}

// MARK: - Foreign Tilt

struct AriaForeignTiltLineView: View {
    let line: AriaLine
    let palette: AriaPalette
    let fontChoice: AriaLyricFontChoice
    let fontScale: Double
    let time: Double
    let stageSize: CGSize

    var body: some View {
        let phrases = AriaForeignPhraseCache.phrases(for: line, maximumCount: 3)
        let fontSize = min(max(stageSize.width * 0.055, 42), 72)
            * CGFloat(fontScale)

        VStack(spacing: max(12, fontSize * 0.14)) {
            ForEach(phrases) { phrase in
                AriaForeignTiltPhraseRow(
                    phrase: phrase,
                    hints: line.hints,
                    palette: palette,
                    fontChoice: fontChoice,
                    fontSize: fontSize,
                    time: time
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct AriaForeignTiltPhraseRow: View {
    let phrase: AriaForeignPhrase
    let hints: AriaRenderHints
    let palette: AriaPalette
    let fontChoice: AriaLyricFontChoice
    let fontSize: CGFloat
    let time: Double

    private var status: AriaWordStatus {
        AriaForeignRuntime.phraseStatus(phrase, hints: hints, time: time)
    }

    var body: some View {
        let fromLeading = phrase.id.isMultiple(of: 2)
        let reveal = AriaFoliaRuntime.revealProgress(
            at: time,
            start: phrase.start - hints.wordLookahead,
            duration: hints.revealMode == .fast ? 0.14 : 0.34
        )

        HStack(spacing: max(9, fontSize * 0.14)) {
            ForEach(phrase.tokens) { token in
                let tokenStatus = AriaFoliaRuntime.status(for: token, hints: hints, time: time)

                Text(token.text)
                    .font(fontChoice.font(size: fontSize, weight: .medium))
                    .italic()
                    .foregroundStyle(tokenStatus == .active ? palette.accent : palette.primary)
                    .scaleEffect(tokenStatus == .active ? 1.12 : 1)
                    .shadow(
                        color: palette.accent.opacity(tokenStatus == .active ? 0.28 : 0),
                        radius: 14
                    )
            }
        }
        .fixedSize()
        .rotationEffect(.degrees(fromLeading ? -3.2 : 3.2))
        .opacity(status == .waiting ? reveal : (status == .passed ? 0.62 : 1))
        .offset(
            x: (fromLeading ? -1 : 1) * CGFloat(1 - reveal) * 54,
            y: status == .active ? -4 : 0
        )
    }
}

// MARK: - Foreign Fume

struct AriaForeignFumeStage: View {
    let lines: [AriaLine]
    let activeIndex: Int
    let palette: AriaPalette
    let fontChoice: AriaLyricFontChoice
    let fontScale: Double
    let time: Double
    let stageSize: CGSize

    private var activeLineID: Int {
        lines.indices.contains(activeIndex) ? lines[activeIndex].id : -1
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 20) {
                    Color.clear.frame(height: stageSize.height * 0.35)

                    ForEach(lines.indices, id: \.self) { index in
                        let line = lines[index]
                        let isActive = index == activeIndex
                        AriaForeignFumeLine(
                            line: line,
                            index: index,
                            distance: activeIndex < 0 ? 99 : abs(index - activeIndex),
                            isActive: isActive,
                            palette: palette.lineVariant(line.id),
                            fontChoice: fontChoice,
                            fontScale: fontScale,
                            // 非活跃/非间奏行不消费时间：冻结 + Equatable 跳过重排
                            time: isActive || line.isInterlude ? time : 0,
                            stageWidth: max(
                                220,
                                stageSize.width
                                    - 2 * max(32, stageSize.width * 0.08)
                            )
                        )
                        .equatable()
                        .id(line.id)
                    }

                    Color.clear.frame(height: stageSize.height * 0.38)
                }
                .frame(maxWidth: stageSize.width * 0.82)
                .frame(maxWidth: .infinity)
            }
            .scrollDisabled(true)
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .white, location: 0.14),
                        .init(color: .white, location: 0.84),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .onAppear {
                guard activeLineID >= 0 else { return }
                proxy.scrollTo(activeLineID, anchor: .center)
            }
            .onChange(of: activeLineID) { _, newValue in
                guard newValue >= 0 else { return }
                withAnimation(.smooth(duration: 0.44)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }
}

private struct AriaForeignFumeLine: View, @MainActor Equatable {
    let line: AriaLine
    let index: Int
    let distance: Int
    let isActive: Bool
    let palette: AriaPalette
    let fontChoice: AriaLyricFontChoice
    let fontScale: Double
    let time: Double
    let stageWidth: CGFloat

    static func == (lhs: AriaForeignFumeLine, rhs: AriaForeignFumeLine) -> Bool {
        lhs.line.id == rhs.line.id
            && lhs.line.fullText == rhs.line.fullText
            && lhs.index == rhs.index
            && lhs.distance == rhs.distance
            && lhs.isActive == rhs.isActive
            && lhs.palette == rhs.palette
            && lhs.fontChoice == rhs.fontChoice
            && lhs.fontScale == rhs.fontScale
            && lhs.time == rhs.time
            && lhs.stageWidth == rhs.stageWidth
    }

    private var fontSize: CGFloat {
        let base = min(48, max(30, stageWidth * 0.04)) * CGFloat(fontScale)
        return isActive ? base * 1.1 : base * 0.84
    }

    var body: some View {
        VStack(spacing: 7) {
            Text(String(format: "%02d", index + 1))
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .tracking(2)
                .foregroundStyle(
                    isActive ? palette.accent.opacity(0.86) : palette.secondary.opacity(0.28)
                )

            if line.isInterlude {
                AriaForeignPauseMark(line: line, palette: palette, time: time)
            } else if isActive {
                AriaForeignCenteredFlowLayout(
                    horizontalSpacing: max(9, fontSize * 0.2),
                    verticalSpacing: 7
                ) {
                    ForEach(AriaFoliaTokenCache.tokens(for: line)) { token in
                        let status = AriaFoliaRuntime.status(
                            for: token,
                            hints: line.hints,
                            time: time
                        )
                        let mix = AriaFoliaRuntime.bodyMix(
                            for: token,
                            hints: line.hints,
                            time: time
                        )

                        Text(token.text)
                            .font(fontChoice.font(size: fontSize, weight: .bold))
                            .italic(status == .active)
                            .foregroundStyle(
                                status == .waiting
                                    ? palette.primary.opacity(0.22)
                                    : AriaFoliaColor.mix(
                                        palette.primary,
                                        palette.accent,
                                        amount: mix
                                    )
                            )
                            .scaleEffect(status == .active ? 1.06 : 1)
                    }
                }
                .frame(width: stageWidth * 0.72)
                .ariaLyricActiveRowSurface()
            } else {
                Text(line.fullText)
                    .font(fontChoice.font(size: fontSize, weight: .medium))
                    .italic()
                    .tracking(0.6)
                    .foregroundStyle(palette.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity)
        .opacity(lineOpacity)
        .scaleEffect(isActive ? 1 : max(0.92, 1 - CGFloat(distance) * 0.018))
        .blur(radius: distance > 3 ? CGFloat(distance - 3) * 0.45 : 0)
        .animation(.smooth(duration: 0.38), value: isActive)
    }

    private var lineOpacity: Double {
        if isActive { return 1 }
        if distance == 1 { return 0.4 }
        if distance == 2 { return 0.22 }
        return max(0.06, 0.14 - Double(distance) * 0.016)
    }
}

// MARK: - Foreign Cappella

struct AriaForeignCappellaStage: View {
    let lines: [AriaLine]
    let activeIndex: Int
    let palette: AriaPalette
    let fontChoice: AriaLyricFontChoice
    let fontScale: Double
    let time: Double
    let stageSize: CGSize

    @ObservedObject private var player = CurrentSongPresentationModel.shared
    @ObservedObject private var homeViewModel = HomeViewModel.shared
    @State private var cachedAvatarURL: URL?

    private var activeLineID: Int {
        lines.indices.contains(activeIndex) ? lines[activeIndex].id : -1
    }

    private var profileURL: URL? {
        if let value = homeViewModel.userProfile?.avatarUrl {
            return URL(string: value)
        }
        return cachedAvatarURL
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 16) {
                    Color.clear.frame(height: stageSize.height * 0.32)

                    ForEach(lines.indices, id: \.self) { index in
                        let line = lines[index]
                        let isActive = index == activeIndex
                        AriaForeignCappellaRow(
                            line: line,
                            index: index,
                            distance: activeIndex < 0 ? 99 : abs(index - activeIndex),
                            isActive: isActive,
                            palette: palette.lineVariant(line.id),
                            fontChoice: fontChoice,
                            fontScale: fontScale,
                            // 非活跃/非间奏行不消费时间：冻结 + Equatable 跳过重排
                            time: isActive || line.isInterlude ? time : 0,
                            coverURL: player.currentSong?.coverUrl?.sized(100),
                            profileURL: profileURL,
                            stageWidth: stageSize.width
                        )
                        .equatable()
                        .id(line.id)
                    }

                    Color.clear.frame(height: stageSize.height * 0.36)
                }
                .padding(.horizontal, max(32, stageSize.width * 0.08))
            }
            .scrollDisabled(true)
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .white, location: 0.12),
                        .init(color: .white, location: 0.86),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .onAppear {
                loadCachedAvatar()
                guard activeLineID >= 0 else { return }
                proxy.scrollTo(activeLineID, anchor: .center)
            }
            .onChange(of: activeLineID) { _, newValue in
                guard newValue >= 0 else { return }
                withAnimation(.smooth(duration: 0.42)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
            .onChange(of: homeViewModel.userProfile?.avatarUrl) { _, newValue in
                cachedAvatarURL = newValue.flatMap(URL.init(string:))
            }
        }
    }

    private func loadCachedAvatar() {
        if let value = homeViewModel.userProfile?.avatarUrl,
           let url = URL(string: value) {
            cachedAvatarURL = url
            return
        }

        if let profile = OptimizedCacheManager.shared.getObject(
            forKey: "user_profile_detail",
            type: UserProfile.self
        ), let value = profile.avatarUrl {
            cachedAvatarURL = URL(string: value)
        }
    }
}

private struct AriaForeignCappellaRow: View, @MainActor Equatable {
    let line: AriaLine
    let index: Int
    let distance: Int
    let isActive: Bool
    let palette: AriaPalette
    let fontChoice: AriaLyricFontChoice
    let fontScale: Double
    let time: Double
    let coverURL: URL?
    let profileURL: URL?
    let stageWidth: CGFloat

    static func == (lhs: AriaForeignCappellaRow, rhs: AriaForeignCappellaRow) -> Bool {
        lhs.line.id == rhs.line.id
            && lhs.line.fullText == rhs.line.fullText
            && lhs.index == rhs.index
            && lhs.distance == rhs.distance
            && lhs.isActive == rhs.isActive
            && lhs.palette == rhs.palette
            && lhs.fontChoice == rhs.fontChoice
            && lhs.fontScale == rhs.fontScale
            && lhs.time == rhs.time
            && lhs.coverURL == rhs.coverURL
            && lhs.profileURL == rhs.profileURL
            && lhs.stageWidth == rhs.stageWidth
    }

    private var isLeft: Bool { index.isMultiple(of: 2) }

    private var visualLength: CGFloat {
        line.fullText.unicodeScalars.reduce(0) { partial, scalar in
            CharacterSet.whitespacesAndNewlines.contains(scalar)
                ? partial + 0.34
                : partial + 0.56
        }
    }

    private var cardContentWidth: CGFloat {
        let available = stageWidth - 40 - 13 - max(16, stageWidth * 0.04) - 36
        let ratio: CGFloat
        switch visualLength {
        case ...18: ratio = 0.44
        case ...32: ratio = 0.55
        case ...48: ratio = 0.62
        default: ratio = 0.69
        }
        return min(max(available, 96), max(96, stageWidth * ratio))
    }

    private var adaptiveFontSize: CGFloat {
        let base = min(30, max(21, stageWidth * 0.03)) * CGFloat(fontScale)
        switch visualLength {
        case ...28: return base
        case ...44: return max(18, base * 0.88)
        case ...62: return max(16, base * 0.76)
        default: return max(14, base * 0.66)
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 13) {
            if isLeft {
                avatar(url: coverURL, fallback: .microphone)
                transcriptCard
                Spacer(minLength: max(16, stageWidth * 0.04))
            } else {
                Spacer(minLength: max(16, stageWidth * 0.04))
                transcriptCard
                avatar(url: profileURL, fallback: .profileFilled)
            }
        }
        .frame(maxWidth: .infinity)
        .opacity(rowOpacity)
        .scaleEffect(isActive ? 1 : 0.97, anchor: isLeft ? .leading : .trailing)
        .blur(radius: distance > 3 ? CGFloat(distance - 3) * 0.42 : 0)
        .animation(.smooth(duration: 0.34), value: isActive)
    }

    private var transcriptCard: some View {
        Group {
            if line.isInterlude {
                AriaForeignPauseMark(line: line, palette: palette, time: time)
            } else if isActive {
                AriaForeignCenteredFlowLayout(
                    horizontalSpacing: 7,
                    verticalSpacing: 5
                ) {
                    ForEach(AriaFoliaTokenCache.tokens(for: line)) { token in
                        let status = AriaFoliaRuntime.status(
                            for: token,
                            hints: line.hints,
                            time: time
                        )

                        Text(token.text)
                            .font(
                                fontChoice.font(
                                    size: adaptiveFontSize,
                                    weight: .bold
                                )
                            )
                            .italic(status == .active)
                            .foregroundStyle(
                                status == .active
                                    ? palette.accent
                                    : palette.primary.opacity(status == .waiting ? 0.24 : 0.76)
                            )
                            .scaleEffect(status == .active ? 1.05 : 1)
                            .lineLimit(1)
                            .minimumScaleFactor(0.52)
                    }
                }
                .frame(width: cardContentWidth)
            } else {
                Text(line.fullText)
                    .font(
                        fontChoice.font(
                            size: adaptiveFontSize * 0.9,
                            weight: .medium
                        )
                    )
                    .italic()
                    .foregroundStyle(palette.primary.opacity(0.78))
                    .multilineTextAlignment(isLeft ? .leading : .trailing)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: cardContentWidth)
            }
        }
        .ariaLyricActiveRowSurface(enabled: isActive && !line.isInterlude)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(isActive ? 0.24 : 0.14))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            isActive
                                ? palette.accent.opacity(0.34)
                                : palette.primary.opacity(0.08),
                            lineWidth: 1
                        )
                }
        }
        .overlay(alignment: isLeft ? .leading : .trailing) {
            Capsule()
                .fill(isActive ? palette.accent : palette.primary.opacity(0.18))
                .frame(width: 3, height: 26)
                .offset(x: isLeft ? -1 : 1)
        }
    }

    private func avatar(
        url: URL?,
        fallback: MonoIcon.IconType
    ) -> some View {
        Group {
            if let url {
                CachedAsyncImage(url: url) {
                    palette.primary.opacity(0.08)
                }
                .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    palette.primary.opacity(0.08)
                    MonoIcon(
                        icon: fallback,
                        size: 17,
                        color: palette.secondary,
                        lineWidth: 1.7
                    )
                }
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(
                    isActive ? palette.accent.opacity(0.72) : palette.primary.opacity(0.12),
                    lineWidth: isActive ? 1.5 : 1
                )
        }
        .shadow(color: palette.accent.opacity(isActive ? 0.2 : 0), radius: 9)
    }

    private var rowOpacity: Double {
        if isActive { return 1 }
        if distance == 1 { return 0.5 }
        if distance == 2 { return 0.28 }
        return max(0.08, 0.2 - Double(distance) * 0.022)
    }
}
