//
//  AriaFoliaCanopyView.swift
//  Monologue
//
//  「天幕」节奏大字幕（参考逐字动态排版视频）：
//  · 句首/句尾的单字关键词化作巨幅强调字，其余字排成竖列或横行；
//  · 普通字踩各自的演唱时间戳沿阅读方向滑入（带运动拖影），
//    巨字则在被唱到的一刻以「竖条墨雨」从上方砸落成形；
//  · 底部注音细线随句进度扫亮，亮缘带一颗流光。
//

import SwiftUI

// MARK: - 逐字模型与构图

private struct CanopyGlyph: Identifiable {
    let id: Int
    let text: String
    let start: Double
    let end: Double
    /// 强调字用本句轮换强调色，其余用主色
    var isEmphasis: Bool = false
    /// 尾词：唱到后强调色光影常驻（字体保持主色）
    var isTailGlow: Bool = false
}

private enum CanopyComposition {
    /// 巨字在左（句首关键词）+ 右侧竖排列，如「風 | 吹過山」
    case heroLeading(hero: CanopyGlyph, column: [CanopyGlyph])
    /// 竖排列在左 + 巨字在右（句尾关键词），如「你去往 | 南」
    case heroTrailing(column: [CanopyGlyph], hero: CanopyGlyph)
    /// 对开门框：双字关键词拆成左右两个巨字，小字与注音夹在中间。
    /// 门框可以跨句：「你搭上空蕩的｜地鐵」成形后，下一句「已是末班」换进中间。
    case heroPair(
        leading: CanopyGlyph,
        middleRows: [[CanopyGlyph]],
        trailing: CanopyGlyph
    )
    /// 单行大字，如「一點點看」
    case row([CanopyGlyph])
    /// 双行（长句），全部主色
    case twoRows([CanopyGlyph], [CanopyGlyph])
}

// MARK: - 注音缓存

/// Han-Latin 转写不便宜，逐行缓存；外语行直接用原文大写。
private enum AriaCanopyCaptionCache {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var storage: [String: String] = [:]

    static func caption(for line: AriaLine, language: AriaLyricLanguage) -> String {
        let key = "\(line.id)|\(line.fullText.hashValue)|\(language)"

        lock.lock()
        defer { lock.unlock() }

        if let cached = storage[key] {
            return cached
        }

        let source: String
        if language == .chinese {
            source = line.fullText
                .applyingTransform(StringTransform("Han-Latin"), reverse: false)?
                .applyingTransform(.stripDiacritics, reverse: false)
                ?? line.fullText
        } else {
            source = line.fullText
        }
        let caption = source
            .uppercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        if storage.count >= 200 {
            storage.removeAll(keepingCapacity: true)
        }
        storage[key] = caption
        return caption
    }
}

// MARK: - 天幕单句

struct AriaCanopyLyricLineView: View {
    let line: AriaLine
    let palette: AriaPalette
    let language: AriaLyricLanguage
    let fontChoice: AriaLyricFontChoice
    let fontScale: Double
    let time: Double
    let stageSize: CGSize
    /// 紧邻的上一句：用于门框跨句继承（「地鐵」立着不动，中间换词）
    var previousLine: AriaLine? = nil

    /// 开启后小字优先显示翻译，无翻译时回落注音/原文
    @AppStorage("ariaCanopyCaptionTranslation") private var captionShowsTranslation = false

    private var lineProgress: Double {
        AriaFoliaRuntime.clamp(
            (time - line.startTime) / max(line.rawDuration, 0.1)
        )
    }

    /// 按 token 展开为带时间戳的字级序列（外语按词），返回每个 token 的字组。
    /// 尾词整组打上 isTailGlow：唱到后强调色光影常驻。
    private var tokenGlyphGroups: [[CanopyGlyph]] {
        let tokens = AriaFoliaTokenCache.tokens(for: line)
        var nextID = 0
        var groups: [[CanopyGlyph]] = []

        for token in tokens {
            if language == .chinese {
                var group: [CanopyGlyph] = []
                for grapheme in token.graphemes
                where !grapheme.char.trimmingCharacters(in: .whitespaces).isEmpty {
                    group.append(
                        CanopyGlyph(
                            id: nextID,
                            text: grapheme.char,
                            start: grapheme.startTime,
                            end: grapheme.endTime
                        )
                    )
                    nextID += 1
                }
                if !group.isEmpty {
                    groups.append(group)
                }
            } else {
                let text = token.text
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .uppercased()
                guard !text.isEmpty else { continue }
                groups.append([
                    CanopyGlyph(
                        id: nextID,
                        text: text,
                        start: token.start,
                        end: token.end
                    )
                ])
                nextID += 1
            }
        }

        if let lastIndex = groups.indices.last {
            groups[lastIndex] = groups[lastIndex].map { glyph in
                var tail = glyph
                tail.isTailGlow = true
                return tail
            }
        }
        return groups
    }

    /// 构图决策：句首/句尾单字 token 升格为巨字；否则单行或双行。
    /// 配色沿用「首词永久强调色」方案：每句必有一个封面轮换色锚点 ——
    /// 有巨字时由巨字承担，其余构图由第一个语义词承担，剩余字为主色。
    private var composition: CanopyComposition? {
        let groups = tokenGlyphGroups
        let flat = groups.flatMap { $0 }
        guard !flat.isEmpty else { return nil }

        func emphasized(_ glyph: CanopyGlyph) -> CanopyGlyph {
            var copy = glyph
            copy.isEmphasis = true
            return copy
        }

        /// 第一个语义词整体染色，其余保持主色
        func firstWordEmphasized() -> [CanopyGlyph] {
            guard let firstGroup = groups.first else { return flat }
            let firstIDs = Set(firstGroup.map(\.id))
            return flat.map { firstIDs.contains($0.id) ? emphasized($0) : $0 }
        }

        if language == .chinese {
            // 跨句门框继承：上一句以双字词收尾立起门框，
            // 本句放得进中间就直接换进同一副门框（「已是末班」进「地｜鐵」）。
            if let frame = inheritedFrameHeroes, flat.count <= 6 {
                return .heroPair(
                    leading: frame.0,
                    middleRows: middleRows(groups: groups, flat: flat),
                    trailing: frame.1
                )
            }
            // 句首单字关键词：「風」吹過山
            if let first = groups.first, first.count == 1,
               (2...6).contains(flat.count - 1) {
                return .heroLeading(
                    hero: emphasized(first[0]),
                    column: Array(flat.dropFirst())
                )
            }
            // 句尾单字关键词：你去往「南」
            if let last = groups.last, last.count == 1,
               (2...6).contains(flat.count - 1) {
                return .heroTrailing(
                    column: Array(flat.dropLast()),
                    hero: emphasized(last[0])
                )
            }
            // 句尾双字关键词拆成对开门框：「你搭上空蕩的」夹在「地｜鐵」中间
            if let last = groups.last, last.count == 2,
               (2...6).contains(flat.count - 2) {
                return .heroPair(
                    leading: last[0],
                    middleRows: middleRows(
                        groups: Array(groups.dropLast()),
                        flat: Array(flat.dropLast(2))
                    ),
                    trailing: last[1]
                )
            }
            let colored = firstWordEmphasized()
            if colored.count <= 6 {
                return .row(colored)
            }
            let boundary = splitBoundary(groups: groups, total: colored.count)
            return .twoRows(
                Array(colored[..<boundary]),
                Array(colored[boundary...])
            )
        }

        // 外语：首词染强调色，短句单行、长句双行
        let rowGlyphs = firstWordEmphasized()
        if rowGlyphs.count <= 3 {
            return .row(rowGlyphs)
        }
        let boundary = max(1, min(rowGlyphs.count - 1, (rowGlyphs.count + 1) / 2))
        return .twoRows(
            Array(rowGlyphs[..<boundary]),
            Array(rowGlyphs[boundary...])
        )
    }

    /// 门框中段：≤4 字单行，更长的在 token 边界断成两行（你搭上｜空蕩的）。
    private func middleRows(
        groups: [[CanopyGlyph]],
        flat: [CanopyGlyph]
    ) -> [[CanopyGlyph]] {
        guard flat.count > 4 else { return [flat] }
        let boundary = splitBoundary(groups: groups, total: flat.count)
        return [Array(flat[..<boundary]), Array(flat[boundary...])]
    }

    /// 上一句尾部双字门框的巨字：时间戳已在过去 → 进场动画自然静止成形。
    private var inheritedFrameHeroes: (CanopyGlyph, CanopyGlyph)? {
        guard language == .chinese,
              let previousLine,
              !previousLine.isInterlude,
              previousLine.id == line.id - 1 else {
            return nil
        }

        let prevTokens = AriaFoliaTokenCache.tokens(for: previousLine)
        guard let lastToken = prevTokens.last, lastToken.isCJK else { return nil }

        let heroGraphemes = lastToken.graphemes.filter {
            !$0.char.trimmingCharacters(in: .whitespaces).isEmpty
        }
        guard heroGraphemes.count == 2 else { return nil }

        let prevCharCount = prevTokens.reduce(0) { count, token in
            count + token.graphemes.filter {
                !$0.char.trimmingCharacters(in: .whitespaces).isEmpty
            }.count
        }
        // 上一句必须真的走了门框构图（中段 2~6 字）
        guard (2...6).contains(prevCharCount - 2) else { return nil }

        return (
            CanopyGlyph(
                id: -1,
                text: heroGraphemes[0].char,
                start: heroGraphemes[0].startTime,
                end: heroGraphemes[0].endTime
            ),
            CanopyGlyph(
                id: -2,
                text: heroGraphemes[1].char,
                start: heroGraphemes[1].startTime,
                end: heroGraphemes[1].endTime
            )
        )
    }

    /// 双行在最接近中点的 token 边界断行。
    private func splitBoundary(groups: [[CanopyGlyph]], total: Int) -> Int {
        let half = Double(total) / 2
        var running = 0
        var best = total / 2
        var bestDistance = Double.infinity

        for group in groups.dropLast() {
            running += group.count
            let distance = abs(Double(running) - half)
            if distance < bestDistance {
                bestDistance = distance
                best = running
            }
        }
        return max(1, min(best, total - 1))
    }

    /// 对开门框构图的注音夹在两巨字中间，不再显示底部注音线
    private var captionIsEmbedded: Bool {
        if case .heroPair = composition { return true }
        return false
    }

    var body: some View {
        let progress = lineProgress

        VStack(spacing: min(24, stageSize.height * 0.05)) {
            if let composition {
                compositionView(composition)
            }
            if !captionIsEmbedded {
                captionLine(progress: progress)
            }
        }
        .scaleEffect(1 + CGFloat(progress) * 0.025)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: 构图渲染

    @ViewBuilder
    private func compositionView(_ composition: CanopyComposition) -> some View {
        let usableWidth = stageSize.width * 0.84

        switch composition {
        case .heroLeading(let hero, let column):
            heroLayout(hero: hero, column: column, heroLeading: true)

        case .heroTrailing(let column, let hero):
            heroLayout(hero: hero, column: column, heroLeading: false)

        case .heroPair(let leading, let middleRows, let trailing):
            heroPairLayout(leading: leading, middleRows: middleRows, trailing: trailing)

        case .row(let glyphs):
            let size = min(
                usableWidth / CGFloat(max(rowSpan(glyphs), 1)),
                stageSize.height * 0.34,
                200
            ) * CGFloat(fontScale)
            glyphRow(glyphs, fontSize: size, slideAxis: .horizontal)

        case .twoRows(let top, let bottom):
            let widest = max(rowSpan(top), rowSpan(bottom))
            let size = min(
                usableWidth / max(widest, 1),
                stageSize.height * 0.22,
                156
            ) * CGFloat(fontScale)

            VStack(spacing: size * 0.16) {
                glyphRow(top, fontSize: size, slideAxis: .horizontal)
                glyphRow(bottom, fontSize: size, slideAxis: .horizontal)
            }
        }
    }

    private func heroLayout(
        hero: CanopyGlyph,
        column: [CanopyGlyph],
        heroLeading: Bool
    ) -> some View {
        let heroSize = min(stageSize.height * 0.46, 240) * CGFloat(fontScale)
        let columnSize = min(
            heroSize * 0.30,
            heroSize / (CGFloat(max(column.count, 1)) * 1.14)
        )

        return HStack(alignment: .center, spacing: heroSize * 0.11) {
            if heroLeading {
                heroGlyph(hero, fontSize: heroSize)
                glyphColumn(column, fontSize: columnSize)
            } else {
                glyphColumn(column, fontSize: columnSize)
                heroGlyph(hero, fontSize: heroSize)
            }
        }
    }

    /// 对开门框：「地｜已是末班＋注音｜鐵」—— 巨字用主色分立两侧，
    /// 中间小字一到两行，注音换用强调色承担本句的颜色锚点。
    private func heroPairLayout(
        leading: CanopyGlyph,
        middleRows: [[CanopyGlyph]],
        trailing: CanopyGlyph
    ) -> some View {
        let heroSize = min(stageSize.height * 0.42, 224) * CGFloat(fontScale)
        let widestRow = middleRows.map { CGFloat($0.count) }.max() ?? 1
        let middleSize = min(
            middleRows.count > 1 ? heroSize * 0.22 : heroSize * 0.27,
            stageSize.width * 0.36 / max(widestRow, 1)
        )

        return HStack(alignment: .center, spacing: heroSize * 0.10) {
            heroGlyph(leading, fontSize: heroSize)

            VStack(spacing: middleSize * 0.30) {
                ForEach(Array(middleRows.enumerated()), id: \.offset) { _, row in
                    glyphRow(row, fontSize: middleSize, slideAxis: .horizontal)
                }
                captionLine(
                    progress: lineProgress,
                    embedded: true
                )
            }

            heroGlyph(trailing, fontSize: heroSize)
        }
    }

    private func glyphColumn(_ glyphs: [CanopyGlyph], fontSize: CGFloat) -> some View {
        VStack(spacing: fontSize * 0.20) {
            ForEach(glyphs) { glyph in
                slidingGlyph(glyph, fontSize: fontSize, axis: .vertical)
            }
        }
    }

    private enum SlideAxis {
        case horizontal
        case vertical
    }

    private func glyphRow(
        _ glyphs: [CanopyGlyph],
        fontSize: CGFloat,
        slideAxis: SlideAxis
    ) -> some View {
        HStack(spacing: language == .chinese ? fontSize * 0.04 : fontSize * 0.24) {
            ForEach(glyphs) { glyph in
                slidingGlyph(glyph, fontSize: fontSize, axis: slideAxis)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }

    /// 外语词长短不一，按视觉宽度（半角字符 ≈ 0.55 字宽）估行宽。
    private func rowSpan(_ glyphs: [CanopyGlyph]) -> CGFloat {
        guard language != .chinese else {
            return CGFloat(glyphs.count)
        }
        let characters = glyphs.reduce(0) { $0 + $1.text.count + 1 }
        return CGFloat(characters) * 0.55
    }

    // MARK: 普通字：沿阅读方向滑入 + 运动拖影

    private func slidingGlyph(
        _ glyph: CanopyGlyph,
        fontSize: CGFloat,
        axis: SlideAxis
    ) -> some View {
        let appear = AriaFoliaRuntime.easeOutCubic(
            AriaFoliaRuntime.clamp((time - glyph.start) / 0.24)
        )
        let remain = CGFloat(1 - appear)
        let isActive = time >= glyph.start && time <= glyph.end + 0.1
        let color = glyph.isEmphasis ? palette.accent : palette.primary
        let slide = fontSize * 0.38 * remain

        return Text(glyph.text)
            .font(fontChoice.font(size: fontSize, weight: .heavy))
            .foregroundStyle(color)
            .opacity(appear)
            .offset(
                x: axis == .horizontal ? slide : 0,
                y: axis == .vertical ? -slide * 0.7 : 0
            )
            // 运动拖影：进场瞬间沿滑入方向拉开的模糊残像
            .background {
                if appear > 0.01, appear < 0.99 {
                    Text(glyph.text)
                        .font(fontChoice.font(size: fontSize, weight: .heavy))
                        .foregroundStyle(color.opacity(0.5 * Double(remain)))
                        .blur(radius: 5 + remain * 7)
                        .offset(
                            x: axis == .horizontal ? slide * 2.2 : 0,
                            y: axis == .vertical ? -slide * 1.6 : 0
                        )
                }
            }
            .blur(radius: remain * 2.5)
            // 唱到时所有字亮强调色光影；尾词唱过后光影常驻（字体保持主色）
            .shadow(
                color: palette.accent.opacity(
                    isActive
                        ? 0.55
                        : (glyph.isTailGlow && time > glyph.end ? 0.4 : 0)
                ),
                radius: fontSize * 0.10
            )
    }

    // MARK: 巨字：竖条墨雨砸落

    private func heroGlyph(_ glyph: CanopyGlyph, fontSize: CGFloat) -> some View {
        let progress = AriaFoliaRuntime.clamp((time - glyph.start) / 0.55)
        let isActive = time >= glyph.start && time <= glyph.end + 0.15
        // 对开门框的巨字用主色（参考「地｜鐵」全白），颜色锚点交给中间注音
        let color = glyph.isEmphasis ? palette.accent : palette.primary

        return CanopyInkRainGlyph(
            text: glyph.text,
            font: fontChoice.font(size: fontSize, weight: .heavy),
            color: color,
            fontSize: fontSize,
            progress: progress,
            seed: Double(line.id % 977)
        )
        .shadow(
            color: color.opacity(isActive ? 0.42 : 0.16),
            radius: fontSize * 0.09
        )
    }

    // MARK: 注音细线

    private func captionLine(progress: Double, embedded: Bool = false) -> some View {
        let translation = captionShowsTranslation
            ? (line.translation ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            : ""
        let caption = translation.isEmpty
            ? AriaCanopyCaptionCache.caption(for: line, language: language)
            : translation
        let captionSize = min(max(stageSize.width * 0.023, 12), 16) * CGFloat(fontScale)
        let sweep = AriaFoliaRuntime.easeInOutQuad(progress)

        return captionText(
            caption,
            size: captionSize,
            sweep: sweep,
            // 门框内的注音承担本句颜色锚点（参考视频里的蓝色拼音）
            sweepColor: embedded ? palette.accent : palette.primary,
            // 翻译（多为中文）不适合注音那么大的字距
            isTranslation: !translation.isEmpty
        )
        .padding(.horizontal, embedded ? 0 : stageSize.width * 0.08)
    }

    private func captionText(
        _ caption: String,
        size: CGFloat,
        sweep: Double,
        sweepColor: Color,
        isTranslation: Bool = false
    ) -> some View {
        let base = Text(caption)
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .tracking(size * (isTranslation ? 0.10 : 0.30))
            .lineLimit(1)
            .minimumScaleFactor(0.5)

        return base
            .foregroundStyle(palette.primary.opacity(0.30))
            .overlay {
                base
                    .foregroundStyle(sweepColor)
                    .mask {
                        GeometryReader { proxy in
                            Rectangle()
                                .frame(width: proxy.size.width * CGFloat(sweep))
                                .frame(
                                    maxWidth: .infinity,
                                    maxHeight: .infinity,
                                    alignment: .leading
                                )
                        }
                    }
            }
            // 扫亮前缘的流光
            .overlay {
                GeometryReader { proxy in
                    if sweep > 0.01, sweep < 0.99 {
                        Capsule()
                            .fill(sweepColor.opacity(0.85))
                            .frame(width: size * 2.4, height: size * 1.05)
                            .blur(radius: size * 0.55)
                            .position(
                                x: proxy.size.width * CGFloat(sweep),
                                y: proxy.size.height / 2
                            )
                            .blendMode(.plusLighter)
                    }
                }
            }
    }
}

// MARK: - 墨雨巨字

/// 把字形切成竖条，各条从上方错落坠入原位（带模糊拖尾），
/// 复刻参考视频里巨字"竖向拉丝成形"的进场。
private struct CanopyInkRainGlyph: View {
    let text: String
    let font: Font
    let color: Color
    let fontSize: CGFloat
    let progress: Double
    let seed: Double

    private let stripeCount = 6

    var body: some View {
        ZStack {
            ForEach(0..<stripeCount, id: \.self) { index in
                stripe(index)
            }
        }
    }

    private func stripe(_ index: Int) -> some View {
        let stagger = AriaLyricEngine.seededRandom(seed, Double(index)) * 0.38
        let local = AriaFoliaRuntime.easeOutCubic(
            AriaFoliaRuntime.clamp((progress - stagger) / max(0.62 - stagger * 0.4, 0.2))
        )
        let remain = CGFloat(1 - local)
        let fallDistance = fontSize
            * (0.42 + CGFloat(AriaLyricEngine.seededRandom(seed, Double(index) + 40)) * 0.5)

        return glyphText
            .mask {
                HStack(spacing: 0) {
                    ForEach(0..<stripeCount, id: \.self) { column in
                        Rectangle()
                            .opacity(column == index ? 1 : 0)
                    }
                }
            }
            .offset(y: -fallDistance * remain)
            .opacity(min(1, Double(local) * 1.7))
            .blur(radius: remain * 6)
            // 坠落拖尾：条带上方的发光残影
            .background {
                if local > 0.01, local < 0.96 {
                    glyphText
                        .foregroundStyle(color.opacity(0.4 * Double(remain)))
                        .mask {
                            HStack(spacing: 0) {
                                ForEach(0..<stripeCount, id: \.self) { column in
                                    Rectangle()
                                        .opacity(column == index ? 1 : 0)
                                }
                            }
                        }
                        .offset(y: -fallDistance * remain - fontSize * 0.16)
                        .blur(radius: 9)
                }
            }
    }

    private var glyphText: some View {
        Text(text)
            .font(font)
            .foregroundStyle(color)
    }
}
