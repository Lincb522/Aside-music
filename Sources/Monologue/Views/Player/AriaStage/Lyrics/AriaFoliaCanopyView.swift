//  「巨幕」（canopy）节奏大字幕（参考逐字动态排版视频）。
//  经典模式（默认，开关关闭）—— 与最初落地的版本一致：
//  · 句首/句尾的关键词化作巨幅强调字（墨雨砸落），其余字排成竖列或横行；
//  · 普通字踩各自的演唱时间戳沿阅读方向滑入（带运动拖影）；
//  · 短句单行、长句双行，整句排版一次成形；
//  · 底部注音细线随句进度扫亮，亮缘带一颗流光。
//  碎幕律动模式（ariaCanopyFragmentStage，可选开启）：
//  · 整句切成 2~3 字（外语 1~2 词）小段，同一时刻舞台只挂正在唱的一小段，
//    不再提前铺满整句排版；
//  · 每段独立抽进场（滑入/升起/坠落/绽放）与退场（上飘/溶解/收缩/左右滑走）；
//  · 构图只在「接力换幕 / 诗笺竖排」里按字速 + 字间隔方差
//    （≈旋律缓急与跳跃度）加权抽选 —— 段与段永远原位换幕、保持巨幅，
//    不做小字逐行堆叠；巨字构图降频出现。

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

/// 语义短语：整句按 token 边界拆出的 2~4 字（外语 1~2 词）小段，
/// 是分段构图（接力/竖排）的排布单元。
private struct CanopyPhrase: Identifiable {
    let id: Int
    let glyphs: [CanopyGlyph]

    var start: Double { glyphs.first?.start ?? 0 }
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
    /// 接力换词：同一时刻只挂正在唱的短语，唱完上飘让位给下一段
    case relay([CanopyPhrase])
    /// 诗笺竖排：短语化作竖列，自右向左依次点亮（仅中文）
    case columns([CanopyPhrase])
}

/// 普通字的进场方式：经典模式整句统一抽一种；碎幕模式逐段抽
private enum CanopyEntrance {
    /// 沿阅读方向滑入（原始方案）
    case slide
    /// 从下方升起聚焦
    case rise
    /// 从上方轻坠落位
    case drop
    /// 原位放大绽放
    case bloom
}

/// 接力段的退场方式（碎幕模式逐段抽签；经典模式固定上飘）
private enum CanopyRelayExit {
    /// 缩小上飘化开（原始方案）
    case floatUp
    /// 原位溶解成雾
    case dissolve
    /// 向中心收缩
    case shrink
    /// 向左滑出
    case driftLeading
    /// 向右滑出
    case driftTrailing
}

/// 分段构图抽签的签筒（仅碎幕模式使用）。
/// 只保留原位换幕的巨幅构图 —— 小字逐行堆叠（层叠）观感廉价，已移除。
private enum CanopyStyleDraw {
    case relay
    case columns
}

// MARK: - 布局缓存

/// 每句解析结果：分词字组、构图、节奏特征。
/// 这些量在一句内完全不变，却曾在时间轴每个 tick（16~30fps）重算 ——
/// 含字符串处理、语义分段与多次 seeded random，是天幕的主要 CPU 热点。
private struct CanopyResolvedLayout {
    let groups: [[CanopyGlyph]]
    let composition: CanopyComposition?
    let seed: Double
    let glyphRate: Double
    let rhythmVariance: Double
}

private enum CanopyLayoutCache {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var storage: [String: CanopyResolvedLayout] = [:]

    static func resolved(
        key: String,
        build: () -> CanopyResolvedLayout
    ) -> CanopyResolvedLayout {
        lock.lock()
        if let cached = storage[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        // build 在锁外执行（构建过程可能较重，且避免任何重入风险）
        let built = build()

        lock.lock()
        if storage.count >= 160 {
            storage.removeAll(keepingCapacity: true)
        }
        storage[key] = built
        lock.unlock()
        return built
    }
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
    @AppStorage("showTranslation") private var showTranslation = true

    /// 碎幕律动：整句拆成小段接力显示 + 逐段随机进退场（默认关，保留经典排版）
    @AppStorage("ariaCanopyFragmentStage") private var fragmentStage = false

    private var lineProgress: Double {
        AriaFoliaRuntime.clamp(
            (time - line.startTime) / max(line.rawDuration, 0.1)
        )
    }

    // MARK: - 布局解析（逐句缓存）

    /// 分词/构图/节奏一次算好整句复用；时间轴每帧只做 O(1) 查表。
    private var resolvedLayout: CanopyResolvedLayout {
        let key = "\(line.id)|\(line.fullText.hashValue)|\(language)|"
            + "\(fragmentStage ? 1 : 0)|\(previousLine?.id ?? Int.min)"
        return CanopyLayoutCache.resolved(key: key) {
            let groups = buildTokenGlyphGroups()
            let seed = buildLineSeed()
            let rate = buildGlyphRate(groups: groups)
            let variance = buildRhythmVariance(groups: groups)
            return CanopyResolvedLayout(
                groups: groups,
                composition: buildComposition(
                    groups: groups,
                    seed: seed,
                    rate: rate,
                    variance: variance
                ),
                seed: seed,
                glyphRate: rate,
                rhythmVariance: variance
            )
        }
    }

    private var tokenGlyphGroups: [[CanopyGlyph]] { resolvedLayout.groups }
    private var composition: CanopyComposition? { resolvedLayout.composition }
    private var lineSeed: Double { resolvedLayout.seed }
    private var glyphRate: Double { resolvedLayout.glyphRate }
    private var rhythmVariance: Double { resolvedLayout.rhythmVariance }

    /// 按 token 展开为带时间戳的字级序列（外语按词），返回每个 token 的字组。
    /// 尾词整组打上 isTailGlow：唱到后强调色光影常驻。
    private func buildTokenGlyphGroups() -> [[CanopyGlyph]] {
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

    // MARK: - 节奏与种子

    /// 逐句稳定种子：行号 + 文字标量和，跨帧不变、逐句/逐歌都不同，
    /// 保证同一句每帧抽到同一构图，而不同歌不会共用一套排版序列。
    private func buildLineSeed() -> Double {
        let scalarSum = line.fullText.unicodeScalars.reduce(0) {
            $0 &+ Int($1.value % 1024)
        }
        return Double((line.id &* 131 &+ scalarSum) % 100_000)
    }

    /// 演唱密度（字/秒）：近似旋律节奏 —— 快歌抽干脆的构图与进场，
    /// 慢歌抽舒展的接力/竖排。
    private func buildGlyphRate(groups: [[CanopyGlyph]]) -> Double {
        let count = groups.reduce(0) { $0 + $1.count }
        return Double(count) / max(line.rawDuration, 0.5)
    }

    /// 字间隔标准差：越大说明本句旋律越「跳」（碎幕模式的抽签特征）
    private func buildRhythmVariance(groups: [[CanopyGlyph]]) -> Double {
        let starts = groups.flatMap { $0 }.map(\.start)
        guard starts.count >= 2 else { return 0.18 }
        var intervals: [Double] = []
        for index in 1..<starts.count {
            intervals.append(max(0.04, starts[index] - starts[index - 1]))
        }
        let mean = intervals.reduce(0, +) / Double(intervals.count)
        let variance = intervals.reduce(0) { $0 + pow($1 - mean, 2) } / Double(intervals.count)
        return sqrt(variance)
    }

    /// 碎幕模式：每段短语独立抽进场，旋律越快/越跳越偏干脆的方式。
    /// 经典模式固定沿阅读方向滑入（原始行为）。
    private func entrance(forPhrase index: Int) -> CanopyEntrance {
        guard fragmentStage else { return .slide }
        let roll = AriaLyricEngine.seededRandom(
            lineSeed,
            Double(index) * 7.3 + rhythmVariance * 11
        )
        if glyphRate > 3.4 || rhythmVariance > 0.42 {
            switch roll {
            case ..<0.45: return .slide
            case ..<0.75: return .drop
            default: return .bloom
            }
        }
        if glyphRate < 2.0, rhythmVariance < 0.22 {
            switch roll {
            case ..<0.40: return .rise
            case ..<0.72: return .bloom
            default: return .slide
            }
        }
        switch roll {
        case ..<0.28: return .slide
        case ..<0.52: return .rise
        case ..<0.76: return .drop
        default: return .bloom
        }
    }

    /// 接力段退场：经典模式固定上飘；碎幕模式逐段抽签
    private func relayExit(forPhrase index: Int) -> CanopyRelayExit {
        guard fragmentStage else { return .floatUp }
        let roll = AriaLyricEngine.seededRandom(
            lineSeed,
            Double(index) * 13.1 + rhythmVariance * 5
        )
        switch roll {
        case ..<0.34: return .floatUp
        case ..<0.58: return .dissolve
        case ..<0.76: return .shrink
        case ..<0.88: return .driftLeading
        default: return .driftTrailing
        }
    }

    /// 碎幕模式下慢歌有概率竖向接力换段
    private func relayUsesVertical(phrases: [CanopyPhrase]) -> Bool {
        guard fragmentStage, language == .chinese else { return false }
        let roll = AriaLyricEngine.seededRandom(lineSeed, 31.7)
        if glyphRate < 2.1, roll < 0.42 { return true }
        return roll < 0.16 && phrases.allSatisfy { $0.glyphs.count <= 3 }
    }

    /// 构图决策。
    /// 经典模式（默认）完全复刻最初版本：门框继承 / 巨字构图结构命中即触发，
    /// 其余中文 ≤6 字单行、更长双行；外语 ≤3 词单行、更长双行。
    /// 碎幕模式：巨字降频（42% 抽签），其余全部交给分段构图
    /// （接力 / 竖排），整句永远不会提前铺满舞台。
    /// 配色沿用「首词永久强调色」方案：每句必有一个封面轮换色锚点 ——
    /// 有巨字时由巨字承担，其余构图由第一个语义词承担，剩余字为主色。
    private func buildComposition(
        groups: [[CanopyGlyph]],
        seed: Double,
        rate: Double,
        variance: Double
    ) -> CanopyComposition? {
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

        // 经典模式：结构命中即触发巨字（原始行为）；
        // 碎幕模式：压低命中率，让接力换幕成为主旋律。
        let heroRoll = fragmentStage
            ? AriaLyricEngine.seededRandom(seed, 9.1) < 0.42
            : true

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
            if heroRoll, let first = groups.first, first.count == 1,
               (2...6).contains(flat.count - 1) {
                return .heroLeading(
                    hero: emphasized(first[0]),
                    column: Array(flat.dropFirst())
                )
            }
            // 句尾单字关键词：你去往「南」
            if heroRoll, let last = groups.last, last.count == 1,
               (2...6).contains(flat.count - 1) {
                return .heroTrailing(
                    column: Array(flat.dropLast()),
                    hero: emphasized(last[0])
                )
            }
            // 句尾双字关键词拆成对开门框：「你搭上空蕩的」夹在「地｜鐵」中间
            if heroRoll, let last = groups.last, last.count == 2,
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
        }

        let colored = firstWordEmphasized()
        let coloredGroups = regroup(colored, like: groups)

        if fragmentStage {
            // 碎幕模式：只要拆得出 ≥2 段就走分段构图
            let phrases = makePhrases(groups: coloredGroups)
            if phrases.count >= 2 {
                switch buildDrawStyle(
                    phrases: phrases,
                    seed: seed,
                    rate: rate,
                    variance: variance
                ) {
                case .relay:
                    return .relay(phrases)
                case .columns:
                    return .columns(phrases)
                }
            }
            return .row(colored)
        }

        // —— 经典排版路径（与最初版本一致）——

        if language == .chinese {
            if colored.count <= 6 {
                return .row(colored)
            }
            let boundary = splitBoundary(groups: coloredGroups, total: colored.count)
            return .twoRows(
                Array(colored[..<boundary]),
                Array(colored[boundary...])
            )
        }

        if colored.count <= 3 {
            return .row(colored)
        }
        let boundary = max(1, min(colored.count - 1, (colored.count + 1) / 2))
        return .twoRows(
            Array(colored[..<boundary]),
            Array(colored[boundary...])
        )
    }

    /// 染色后的平铺字重新按原 token 结构分组（id 一一对应）
    private func regroup(
        _ colored: [CanopyGlyph],
        like groups: [[CanopyGlyph]]
    ) -> [[CanopyGlyph]] {
        var iterator = colored.makeIterator()
        return groups.map { group in
            group.compactMap { _ in iterator.next() }
        }
    }

    // MARK: - 语义分段

    /// 整句按 token 边界切成语义短语（仅碎幕模式）：
    /// 中文攒 2~3 字、外语攒 1~2 词。超长 token（如五字词）独立成段，不硬拆。
    private func makePhrases(groups: [[CanopyGlyph]]) -> [CanopyPhrase] {
        let targetLimit = language == .chinese ? 3 : 2
        var phrases: [CanopyPhrase] = []
        var buffer: [CanopyGlyph] = []

        func flush() {
            guard !buffer.isEmpty else { return }
            phrases.append(CanopyPhrase(id: phrases.count, glyphs: buffer))
            buffer = []
        }

        for group in groups {
            let unit = language == .chinese ? group.count : 1
            let buffered = language == .chinese
                ? buffer.count
                : (buffer.isEmpty ? 0 : 1)
            if buffered > 0, buffered + unit > targetLimit {
                flush()
            }
            buffer.append(contentsOf: group)
            if language != .chinese, buffer.count >= targetLimit {
                flush()
            }
        }
        flush()

        // 尾段只剩 1 字会显得漏拍，并回上一段
        if language == .chinese,
           phrases.count >= 2,
           let last = phrases.last, last.glyphs.count == 1 {
            let merged = phrases[phrases.count - 2].glyphs + last.glyphs
            phrases.removeLast(2)
            phrases.append(CanopyPhrase(id: phrases.count, glyphs: merged))
        }

        // 只拆出一段但字数够多时，从中点 token 边界硬拆成两段，
        // 保证"每次只出现几个字"的观感
        if phrases.count == 1,
           let only = phrases.first,
           language == .chinese ? only.glyphs.count >= 4 : only.glyphs.count >= 3 {
            let boundary = splitBoundary(groups: groups, total: only.glyphs.count)
            phrases = [
                CanopyPhrase(id: 0, glyphs: Array(only.glyphs[..<boundary])),
                CanopyPhrase(id: 1, glyphs: Array(only.glyphs[boundary...])),
            ]
        }
        return phrases
    }

    /// 分段构图抽签（仅碎幕模式）：接力为主旋律，
    /// 平稳的慢句偶尔换诗笺竖排当变奏。
    private func buildDrawStyle(
        phrases: [CanopyPhrase],
        seed: Double,
        rate: Double,
        variance: Double
    ) -> CanopyStyleDraw {
        let longestPhrase = phrases.map(\.glyphs.count).max() ?? 1
        let canColumns = language == .chinese
            && (2...4).contains(phrases.count)
            && longestPhrase <= 4

        guard canColumns else { return .relay }

        // 旋律越跳（字间隔忽长忽短）越值得逐段换幕，竖排只留给平稳慢句
        var columnsWeight = 0.7
        if variance > 0.38 || rate > 3.6 {
            columnsWeight = 0.2
        } else if rate < 2.2 {
            columnsWeight = 1.15
        }

        let total = 2.4 + columnsWeight
        let roll = AriaLyricEngine.seededRandom(seed, 17.7) * total
        return roll < columnsWeight ? .columns : .relay
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
              !previousLine.isCredit,
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

    // MARK: - 构图渲染

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
            glyphRow(
                glyphs,
                fontSize: size,
                slideAxis: .horizontal,
                visibleOnly: fragmentStage
            )

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

        case .relay(let phrases):
            relayLayout(phrases)

        case .columns(let phrases):
            columnsLayout(phrases)
        }
    }

    // MARK: - 分段构图渲染

    /// 接力换词：舞台同一时刻只挂正在唱的短语，
    /// 唱完让位给下一段 —— 一句词被拆成几幕。
    /// 经典模式固定「缩小上飘」退场；碎幕模式逐段抽退场，慢歌还可能竖排接力。
    private func relayLayout(_ phrases: [CanopyPhrase]) -> some View {
        let vertical = relayUsesVertical(phrases: phrases)
        let usableWidth = stageSize.width * 0.84
        let maxSpan = phrases.map { rowSpan($0.glyphs) }.max() ?? 1
        let tallest = phrases.map(\.glyphs.count).max() ?? 1
        let size: CGFloat = vertical
            ? min(
                stageSize.height * 0.52 / (CGFloat(tallest) * 1.22),
                stageSize.width * 0.30,
                168
            ) * CGFloat(fontScale)
            : min(
                usableWidth / max(maxSpan, 1),
                stageSize.height * 0.30,
                190
            ) * CGFloat(fontScale)

        return ZStack {
            ForEach(Array(phrases.enumerated()), id: \.element.id) { index, phrase in
                let nextStart = index + 1 < phrases.count
                    ? phrases[index + 1].start
                    : line.endTime + 0.4
                let exit = AriaFoliaRuntime.easeInOutQuad(
                    AriaFoliaRuntime.clamp((time - nextStart) / 0.34)
                )
                if time >= phrase.start - 0.05, exit < 1 {
                    Group {
                        if vertical {
                            glyphColumn(
                                phrase.glyphs,
                                fontSize: size,
                                phraseIndex: index
                            )
                        } else {
                            glyphRow(
                                phrase.glyphs,
                                fontSize: size,
                                slideAxis: .horizontal,
                                phraseIndex: index
                            )
                        }
                    }
                    .modifier(
                        CanopyRelayExitModifier(
                            exit: exit,
                            style: relayExit(forPhrase: index),
                            fontSize: size
                        )
                    )
                }
            }
        }
        // 占稳一段高度，避免换段时注音线上下跳动
        .frame(
            height: vertical
                ? size * CGFloat(tallest) * 1.22 + size * 0.4
                : size * 1.5
        )
    }

    /// 诗笺竖排（仅中文）：短语化作竖列、自右向左排布，
    /// 各列顶端对齐（不做错位，避免台阶感），竖列随演唱一列列点亮。
    private func columnsLayout(_ phrases: [CanopyPhrase]) -> some View {
        let tallest = phrases.map(\.glyphs.count).max() ?? 1
        let size = min(
            stageSize.height * 0.50 / (CGFloat(tallest) * 1.22),
            stageSize.width * 0.70 / (CGFloat(phrases.count) * 1.55),
            120
        ) * CGFloat(fontScale)
        let shown = phrases.filter { time >= $0.start - 0.05 }

        return HStack(alignment: .top, spacing: size * 0.55) {
            ForEach(Array(shown.enumerated().reversed()), id: \.element.id) { index, phrase in
                glyphColumn(phrase.glyphs, fontSize: size, phraseIndex: index)
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.85), value: shown.count)
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
                glyphColumn(column, fontSize: columnSize, visibleOnly: fragmentStage)
            } else {
                glyphColumn(column, fontSize: columnSize, visibleOnly: fragmentStage)
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
                    glyphRow(
                        row,
                        fontSize: middleSize,
                        slideAxis: .horizontal,
                        visibleOnly: fragmentStage
                    )
                }
                captionLine(
                    progress: lineProgress,
                    embedded: true
                )
            }

            heroGlyph(trailing, fontSize: heroSize)
        }
    }

    /// 碎幕模式的"只显示已唱到的字"：未开演的字不占位
    private func visibleGlyphs(_ glyphs: [CanopyGlyph]) -> [CanopyGlyph] {
        glyphs.filter { time >= $0.start - 0.03 }
    }

    private func glyphColumn(
        _ glyphs: [CanopyGlyph],
        fontSize: CGFloat,
        phraseIndex: Int = 0,
        visibleOnly: Bool = false
    ) -> some View {
        let shown = visibleOnly ? visibleGlyphs(glyphs) : glyphs
        return VStack(spacing: fontSize * 0.20) {
            ForEach(shown) { glyph in
                slidingGlyph(
                    glyph,
                    fontSize: fontSize,
                    axis: .vertical,
                    phraseIndex: phraseIndex
                )
            }
        }
        .animation(
            visibleOnly ? .spring(response: 0.34, dampingFraction: 0.86) : nil,
            value: shown.count
        )
    }

    private enum SlideAxis {
        case horizontal
        case vertical
    }

    private func glyphRow(
        _ glyphs: [CanopyGlyph],
        fontSize: CGFloat,
        slideAxis: SlideAxis,
        phraseIndex: Int = 0,
        visibleOnly: Bool = false
    ) -> some View {
        let shown = visibleOnly ? visibleGlyphs(glyphs) : glyphs
        return HStack(spacing: language == .chinese ? fontSize * 0.04 : fontSize * 0.24) {
            ForEach(shown) { glyph in
                slidingGlyph(
                    glyph,
                    fontSize: fontSize,
                    axis: slideAxis,
                    phraseIndex: phraseIndex
                )
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .animation(
            visibleOnly ? .spring(response: 0.34, dampingFraction: 0.86) : nil,
            value: shown.count
        )
    }

    /// 外语词长短不一，按视觉宽度（半角字符 ≈ 0.55 字宽）估行宽。
    private func rowSpan(_ glyphs: [CanopyGlyph]) -> CGFloat {
        guard language != .chinese else {
            return CGFloat(glyphs.count)
        }
        let characters = glyphs.reduce(0) { $0 + $1.text.count + 1 }
        return CGFloat(characters) * 0.55
    }

    // MARK: - 普通字：按本句抽中的进场方式现身 + 运动拖影

    /// 各进场方式的位移/缩放向量（remain = 1 为完全未进场）
    private func entranceOffset(
        remain: CGFloat,
        fontSize: CGFloat,
        axis: SlideAxis,
        entrance: CanopyEntrance
    ) -> (x: CGFloat, y: CGFloat, scale: CGFloat) {
        let travel = fontSize * 0.38 * remain
        switch entrance {
        case .slide:
            return axis == .horizontal
                ? (travel, 0, 1)
                : (0, -travel * 0.7, 1)
        case .rise:
            return (0, travel * 1.15, 1)
        case .drop:
            return (0, -travel * 1.25, 1)
        case .bloom:
            return (0, 0, 1 + remain * 0.55)
        }
    }

    private func slidingGlyph(
        _ glyph: CanopyGlyph,
        fontSize: CGFloat,
        axis: SlideAxis,
        phraseIndex: Int = 0
    ) -> some View {
        let appear = AriaFoliaRuntime.easeOutCubic(
            AriaFoliaRuntime.clamp((time - glyph.start) / 0.24)
        )
        let remain = CGFloat(1 - appear)
        let isActive = time >= glyph.start && time <= glyph.end + 0.1
        let color = glyph.isEmphasis ? palette.accent : palette.primary
        let motion = entranceOffset(
            remain: remain,
            fontSize: fontSize,
            axis: axis,
            entrance: entrance(forPhrase: phraseIndex)
        )

        return Text(glyph.text)
            .font(fontChoice.font(size: fontSize, weight: .heavy))
            .foregroundStyle(color)
            .opacity(appear)
            .scaleEffect(motion.scale)
            .offset(x: motion.x, y: motion.y)
            // 运动拖影：进场瞬间沿来向拉开的模糊残像（绽放式为原位光晕）
            .background {
                if appear > 0.01, appear < 0.99 {
                    Text(glyph.text)
                        .font(fontChoice.font(size: fontSize, weight: .heavy))
                        .foregroundStyle(color.opacity(0.5 * Double(remain)))
                        .blur(radius: 5 + remain * 7)
                        .scaleEffect(motion.scale == 1 ? 1 : motion.scale * 1.2)
                        .offset(x: motion.x * 2.2, y: motion.y * 1.9)
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

    // MARK: - 巨字：竖条墨雨砸落

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

    // MARK: - 注音细线

    private func captionLine(progress: Double, embedded: Bool = false) -> some View {
        let translation = showTranslation && captionShowsTranslation
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

// MARK: - 接力退场

/// 接力段的退场动画：exit ∈ [0, 1]，按抽中的方式让位给下一段
private struct CanopyRelayExitModifier: ViewModifier {
    let exit: Double
    let style: CanopyRelayExit
    let fontSize: CGFloat

    func body(content: Content) -> some View {
        let e = CGFloat(exit)
        switch style {
        case .floatUp:
            content
                .scaleEffect(1 - e * 0.26)
                .offset(y: -e * fontSize * 0.9)
                .opacity(1 - exit)
                .blur(radius: e * 3)
        case .dissolve:
            content
                .scaleEffect(1 + e * 0.06)
                .opacity(1 - exit)
                .blur(radius: e * 9)
        case .shrink:
            content
                .scaleEffect(1 - e * 0.55)
                .opacity(1 - exit)
                .blur(radius: e * 2)
        case .driftLeading:
            content
                .offset(x: -e * fontSize * 1.4)
                .scaleEffect(1 - e * 0.14)
                .opacity(1 - exit)
                .blur(radius: e * 4)
        case .driftTrailing:
            content
                .offset(x: e * fontSize * 1.4)
                .scaleEffect(1 - e * 0.14)
                .opacity(1 - exit)
                .blur(radius: e * 4)
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
