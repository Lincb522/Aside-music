//  全新沉浸模式的歌词引擎 —— 从零复刻 folia-major 的歌词管线：
//  - 词级时间轴合成（parserCore.ts buildTimedWords：CJK 单字 / 英文 token 加权分配）
//  - 间奏插入（parserCore.ts attachInterludes：空隙 > 3s 生成 "......" 六点行）
//  - 副歌检测（chorusDetector.ts：重复次数最多的歌词行视为副歌）
//  - renderHints（renderHints.ts：micro/short/normal 三档时序 → 切句与逐字节奏）
//  - CJK 语义分组 + 标点黏附（cjkSemanticLayout.ts：display words 只影响排版，计时仍以原词为准）
//  - 字素时间轴（graphemeTiming.ts：词内均匀切分驱动逐字素辉光）
//  - 激活行判定（appPlaybackHelpers.ts findLatestActiveLineIndex：startTime ≤ t ≤ renderEndTime）

import Foundation
import NaturalLanguage

// MARK: - 数据模型（folia types.ts 对应）

struct AriaWord: Identifiable, Equatable {
    let id: Int
    let text: String
    let startTime: Double
    let endTime: Double

    var duration: Double { max(endTime - startTime, 0) }
}

struct AriaGrapheme {
    let char: String
    let startTime: Double
    let endTime: Double
}

enum AriaTimingClass { case normal, short, micro }
enum AriaTransitionMode { case normal, fast, none }
enum AriaRevealMode { case normal, fast, instant }

/// renderHints.ts 的移植：endTime 管“字何时出现完”，renderEndTime 管“整句最多占用时间轴到何时”
struct AriaRenderHints: Equatable {
    let rawDuration: Double
    let timingClass: AriaTimingClass
    let renderEndTime: Double
    let transitionMode: AriaTransitionMode
    let revealMode: AriaRevealMode

    static let microThreshold = 0.10
    static let shortThreshold = 0.18
    static let microRenderFloor = 0.067

    /// 逐字提前量（classic Visualizer wordLookahead）
    var wordLookahead: Double {
        switch revealMode {
        case .instant: return 0.03
        case .fast: return 0.08
        case .normal: return 0.15
        }
    }

    static func build(startTime: Double, endTime: Double, lastWordEndTime: Double?) -> AriaRenderHints {
        let rawDuration = max(endTime - startTime, 0)
        let timingClass: AriaTimingClass = rawDuration < microThreshold ? .micro
            : (rawDuration < shortThreshold ? .short : .normal)
        let transitionMode: AriaTransitionMode = timingClass == .micro ? .none
            : (timingClass == .short ? .fast : .normal)
        let revealMode: AriaRevealMode = timingClass == .micro ? .instant
            : (timingClass == .short ? .fast : .normal)

        let renderEndTime: Double
        if transitionMode == .none {
            renderEndTime = max(endTime, startTime + microRenderFloor)
        } else {
            let (enterDuration, exitDuration, passHold) = transitionTiming(
                rawDuration: rawDuration, transitionMode: transitionMode, revealMode: revealMode
            )
            let passStart = max(lastWordEndTime ?? endTime, startTime) + passHold
            let exitStart: Double
            if transitionMode == .fast {
                exitStart = max(startTime + enterDuration + 0.01, max(passStart, endTime - exitDuration))
            } else {
                exitStart = max(passStart, endTime - exitDuration)
            }
            renderEndTime = max(endTime, exitStart + exitDuration)
        }

        return AriaRenderHints(
            rawDuration: rawDuration,
            timingClass: timingClass,
            renderEndTime: renderEndTime,
            transitionMode: transitionMode,
            revealMode: revealMode
        )
    }

    /// getLineTransitionTiming 移植：(enter, exit, passHold)
    static func transitionTiming(
        rawDuration: Double,
        transitionMode: AriaTransitionMode,
        revealMode: AriaRevealMode
    ) -> (Double, Double, Double) {
        switch transitionMode {
        case .none:
            return (0, 0, 0)
        case .fast:
            return (
                min(max(rawDuration * 0.45, 0.045), 0.06),
                min(max(rawDuration * 0.22, 0.03), 0.04),
                revealMode == .instant ? 0 : 0.03
            )
        case .normal:
            let base = max(rawDuration, 0.12)
            return (
                min(0.42, max(0.22, base * 0.34)),
                min(0.32, max(0.18, base * 0.18)),
                revealMode == .instant ? 0 : 0.06
            )
        }
    }
}

enum AriaChorusEffect: CaseIterable { case bars, circles, beams }

/// 舞台歌词引擎的单行输出，同时保留原始计时词与经过语义排版的展示词。
struct AriaLine: Identifiable {
    let id: Int
    let startTime: Double
    let endTime: Double
    let fullText: String
    let translation: String?
    /// 原始计时词（时间真值）
    let words: [AriaWord]
    /// 语义分组 + 标点黏附后的展示词（排版用）
    let displayWords: [AriaWord]
    let isInterlude: Bool
    let isChorus: Bool
    let chorusEffect: AriaChorusEffect
    let hints: AriaRenderHints
    /// 歌词开头的制作/发行信息行（作词/作曲/制作人/发行…），
    /// 各效果对它做克制渲染，不参与巨字/碎幕等强动画
    var isCredit: Bool = false

    var rawDuration: Double { max(endTime - startTime, 0) }
}

// MARK: - 引擎

enum AriaLyricEngine {
    static let interludeText = "......"

    // MARK: - 管线入口：项目 LyricLine → AriaLine

    static func buildLines(
        from source: [LyricLine],
        forceUppercaseEnglish: Bool = false
    ) -> [AriaLine] {
        guard !source.isEmpty else { return [] }

        // 1. 归一化每行的结束时间：LRC 无 duration 时以下一行开头兜底
        struct RawLine {
            let startTime: Double
            let endTime: Double
            let text: String
            let translation: String?
            let words: [AriaWord]
        }

        var rawLines: [RawLine] = []
        var wordIdSeed = 0
        for (index, line) in source.enumerated() {
            let originalText = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let text = forceUppercaseEnglish
                ? originalText.monologueUppercasingEnglish()
                : originalText
            guard !text.isEmpty else { continue }

            let nextStart = index + 1 < source.count ? source[index + 1].time : line.time + 6
            let endTime: Double
            if line.duration > 0 {
                endTime = line.time + line.duration
            } else {
                endTime = max(line.time + 0.8, min(nextStart, line.time + 12))
            }

            var words: [AriaWord]
            if !line.words.isEmpty {
                words = line.words.map { w in
                    wordIdSeed += 1
                    return AriaWord(
                        id: wordIdSeed,
                        text: forceUppercaseEnglish
                            ? w.text.monologueUppercasingEnglish()
                            : w.text,
                        startTime: w.startTime,
                        endTime: w.startTime + max(w.duration, 0.05)
                    )
                }
            } else {
                words = buildTimedWords(text: text, startTime: line.time, endTime: endTime, idSeed: &wordIdSeed)
            }
            guard !words.isEmpty else { continue }

            rawLines.append(RawLine(
                startTime: line.time,
                endTime: endTime,
                text: text,
                translation: line.translation?.isEmpty == false
                    ? (forceUppercaseEnglish
                        ? line.translation?.monologueUppercasingEnglish()
                        : line.translation)
                    : nil,
                words: words
            ))
        }
        guard !rawLines.isEmpty else { return [] }

        // 2. 副歌检测（chorusDetector.ts：重复次数最多的行文本 = 副歌）
        let chorusTexts = detectChorusTexts(rawLines.map(\.text))

        // 3. 组装 + 间奏插入（attachInterludes：gap > 3s）
        var result: [AriaLine] = []
        var lineId = 0

        func appendInterlude(start: Double, end: Double) {
            guard end - start > 0.2 else { return }
            let wordDuration = (end - start) / 6
            var dots: [AriaWord] = []
            for i in 0..<6 {
                wordIdSeed += 1
                dots.append(AriaWord(
                    id: wordIdSeed,
                    text: ".",
                    startTime: start + Double(i) * wordDuration,
                    endTime: start + Double(i + 1) * wordDuration
                ))
            }
            lineId += 1
            result.append(AriaLine(
                id: lineId,
                startTime: start,
                endTime: end,
                fullText: interludeText,
                translation: nil,
                words: dots,
                displayWords: dots,
                isInterlude: true,
                isChorus: false,
                chorusEffect: .circles,
                hints: AriaRenderHints.build(startTime: start, endTime: end, lastWordEndTime: end)
            ))
        }

        if let first = rawLines.first, first.startTime > 3 {
            appendInterlude(start: 0.5, end: first.startTime - 0.5)
        }

        for (index, raw) in rawLines.enumerated() {
            let isChorus = chorusTexts.contains(raw.text)
            lineId += 1
            result.append(AriaLine(
                id: lineId,
                startTime: raw.startTime,
                endTime: raw.endTime,
                fullText: raw.text,
                translation: raw.translation,
                words: raw.words,
                displayWords: buildDisplayWords(fullText: raw.text, words: raw.words, idSeed: &wordIdSeed),
                isInterlude: false,
                isChorus: isChorus,
                chorusEffect: chorusEffect(for: raw.text),
                hints: AriaRenderHints.build(
                    startTime: raw.startTime,
                    endTime: raw.endTime,
                    lastWordEndTime: raw.words.last?.endTime
                ),
                isCredit: isCreditText(
                    raw.text,
                    isFirstLine: index == 0,
                    startTime: raw.startTime
                )
            ))

            if index + 1 < rawLines.count {
                let next = rawLines[index + 1]
                if next.startTime - raw.endTime > 3 {
                    appendInterlude(start: raw.endTime + 0.05, end: next.startTime - 0.05)
                }
            }
        }

        return result
    }

    // MARK: - 制作信息行识别

    private static let creditKeywords: [String] = [
        "作词", "作詞", "作曲", "编曲", "編曲", "制作", "製作", "监制", "監製",
        "出品", "发行", "發行", "演唱", "歌手", "原唱", "翻唱", "混音", "母带", "母帶",
        "录音", "錄音", "和声", "和聲", "吉他", "贝斯", "貝斯", "键盘", "鍵盤",
        "弦乐", "弦樂", "打击乐", "企划", "企劃", "统筹", "統籌", "封面", "设计", "設計",
        "文案", "音效", "缩混", "縮混", "制作人", "製作人", "配唱", "版权", "版權",
        "lyrics", "composed", "produced", "arranged", "mixed", "mastered", "vocal"
    ]

    /// 歌词开头的制作/发行信息：`作词 : 某某` / `出品：某公司`，
    /// 以及首行 0 秒附近的「歌名 - 歌手」标题行。
    /// 这类行不该吃到巨字/碎幕等强动画。
    static func isCreditText(
        _ text: String,
        isFirstLine: Bool,
        startTime: Double
    ) -> Bool {
        if isFirstLine, startTime < 1.5, text.contains(" - ") {
            return true
        }

        guard let separator = text.firstIndex(where: { $0 == ":" || $0 == "：" }) else {
            return false
        }
        let label = text[..<separator].trimmingCharacters(in: .whitespaces)
        guard !label.isEmpty, label.count <= 14 else { return false }

        let lowered = label.lowercased()
        return creditKeywords.contains { lowered.contains($0) }
    }

    // MARK: - 激活行判定（findLatestActiveLineIndex）

    /// 先二分定位最后一个 startTime ≤ t 的候选，再向前检查可能重叠的
    /// renderEndTime。结果与原来的逆序线性扫描一致，但正常播放每帧只需
    /// log₂(n) 次比较和一次候选检查。
    static func activeLineIndex(in lines: [AriaLine], at time: Double) -> Int {
        guard !lines.isEmpty else { return -1 }

        var lower = 0
        var upper = lines.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if lines[middle].startTime <= time {
                lower = middle + 1
            } else {
                upper = middle
            }
        }

        var index = lower - 1
        while index >= 0 {
            let line = lines[index]
            if time <= line.hints.renderEndTime { return index }
            index -= 1
        }
        return -1
    }

    /// 空窗期最近完成的一行（runtime.ts getRecentCompletedLine）：字幕层空隙兜底
    static func recentCompletedLine(in lines: [AriaLine], at time: Double) -> AriaLine? {
        for index in stride(from: lines.count - 1, through: 0, by: -1) {
            if time > lines[index].hints.renderEndTime { return lines[index] }
        }
        return nil
    }

    /// 下一句（runtime.ts getUpcomingLines）
    static func upcomingLines(in lines: [AriaLine], activeIndex: Int, at time: Double, count: Int = 2) -> [AriaLine] {
        if activeIndex >= 0 {
            return Array(lines.dropFirst(activeIndex + 1).prefix(count))
        }
        if let idx = lines.firstIndex(where: { $0.startTime > time }) {
            return Array(lines.dropFirst(idx).prefix(count))
        }
        return []
    }

    // MARK: - 词时间轴合成（buildTimedWords 移植）

    static func isCJKChar(_ ch: Character) -> Bool {
        guard let scalar = ch.unicodeScalars.first else { return false }
        switch scalar.value {
        case 0x4E00...0x9FA5, 0x3040...0x30FF, 0xAC00...0xD7AF: return true
        default: return false
        }
    }

    static func hasCJK(_ text: String) -> Bool {
        text.contains(where: isCJKChar)
    }

    private static let cjkPunctuation = Set("，。！？、：；\"'）")

    static func buildTimedWords(text: String, startTime: Double, endTime: Double, idSeed: inout Int) -> [AriaWord] {
        let duration = max(endTime - startTime, 0.1)
        let rawTokens = text.split(whereSeparator: { $0.isWhitespace }).map(String.init)

        struct Token { let text: String; let weight: Double }
        var tokens: [Token] = []
        var totalWeight = 0.0

        for token in rawTokens {
            if hasCJK(token) {
                for char in token {
                    let weight: Double = cjkPunctuation.contains(char) ? 0 : 1
                    tokens.append(Token(text: String(char), weight: weight))
                    totalWeight += weight
                }
            } else {
                let weight = 1 + Double(token.count) * 0.15
                tokens.append(Token(text: token, weight: weight))
                totalWeight += weight
            }
        }
        if totalWeight == 0 { totalWeight = 1 }

        let activeDuration = duration * 0.9
        let timePerWeight = activeDuration / totalWeight
        var cursor = startTime
        var words: [AriaWord] = []

        for token in tokens {
            let wordDuration = token.weight * timePerWeight
            idSeed += 1
            words.append(AriaWord(
                id: idSeed,
                text: token.text,
                startTime: cursor,
                endTime: cursor + max(wordDuration, 0.05)
            ))
            cursor += token.weight > 0 ? wordDuration : 0.05
        }

        // 超出整行时长则整体线性压回
        if let last = words.last, last.endTime > endTime, last.endTime > startTime {
            let scale = (endTime - startTime) / (last.endTime - startTime)
            words = words.map { w in
                AriaWord(
                    id: w.id,
                    text: w.text,
                    startTime: startTime + (w.startTime - startTime) * scale,
                    endTime: startTime + (w.endTime - startTime) * scale
                )
            }
        }
        return words
    }

    // MARK: - 字素时间轴（graphemeTiming.ts）

    static func graphemeTimings(for word: AriaWord) -> [AriaGrapheme] {
        let graphemes = Array(word.text).map(String.init)
        guard !graphemes.isEmpty else { return [] }
        let unit = word.duration / Double(graphemes.count)
        return graphemes.enumerated().map { index, char in
            AriaGrapheme(
                char: char,
                startTime: word.startTime + unit * Double(index),
                endTime: index == graphemes.count - 1 ? word.endTime : word.startTime + unit * Double(index + 1)
            )
        }
    }

    // MARK: - 副歌检测（chorusDetector.ts）

    static func detectChorusTexts(_ texts: [String]) -> Set<String> {
        var counts: [String: Int] = [:]
        for text in texts {
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            guard trimmed.count >= 2, trimmed != interludeText else { continue }
            counts[trimmed, default: 0] += 1
        }
        guard let maxCount = counts.values.max(), maxCount > 1 else { return [] }
        return Set(counts.filter { $0.value == maxCount }.keys)
    }

    /// 同一句文本永远拿到同一种副歌效果（folia 用随机 map，这里以文本哈希做确定性等价）
    static func chorusEffect(for text: String) -> AriaChorusEffect {
        var hash: UInt64 = 5381
        for byte in text.utf8 { hash = hash &* 33 &+ UInt64(byte) }
        let all = AriaChorusEffect.allCases
        return all[Int(hash % UInt64(all.count))]
    }

    // MARK: - CJK 语义分组 + 标点黏附（cjkSemanticLayout.ts）

    private struct LayoutUnit {
        var text: String
        var words: [AriaWord]
        var startTime: Double
        var endTime: Double
        var isSemantic: Bool
        var isSticky: Bool = false
    }

    private static let stickyTrailingPunctuation = Set(",.;:!?，。！？、：；）】》」』〉〕］)}]\"'’”")
    private static let contractionSuffixes: Set<String> = ["s", "t", "m", "d", "ll", "re", "ve", "em"]

    /// 展示词：黏附非语义单元合成一个视觉词（It + ’ + s → It’s），CJK 语义单元保留原词以保住逐字计时
    static func buildDisplayWords(fullText: String, words: [AriaWord], idSeed: inout Int) -> [AriaWord] {
        let semanticUnits = buildSemanticUnits(fullText: fullText, words: words)
        let merged = applyStickyPunctuation(semanticUnits)

        var display: [AriaWord] = []
        for unit in merged {
            if !unit.isSticky || unit.isSemantic {
                display.append(contentsOf: unit.words)
            } else {
                idSeed += 1
                display.append(AriaWord(id: idSeed, text: unit.text, startTime: unit.startTime, endTime: unit.endTime))
            }
        }
        return display.isEmpty ? words : display
    }

    /// Folia 的重排类可视化以语义词组为排版单位，而不是把 CJK 动态歌词
    /// 拆成散落的单字。时间范围仍覆盖词组内原始计时词，逐字模式继续使用
    /// `buildDisplayWords`，两条管线互不影响。
    static func buildVisualizerDisplayWords(fullText: String, words: [AriaWord]) -> [AriaWord] {
        let units = applyStickyPunctuation(
            buildSemanticUnits(fullText: fullText, words: words)
        )
        let display = units.compactMap { unit -> AriaWord? in
            let text = unit.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, let first = unit.words.first else { return nil }
            return AriaWord(
                id: first.id,
                text: text,
                startTime: unit.startTime,
                endTime: unit.endTime
            )
        }
        return display.isEmpty ? words : display
    }

    private static func singleWordUnits(_ words: [AriaWord]) -> [LayoutUnit] {
        words.map { LayoutUnit(text: $0.text, words: [$0], startTime: $0.startTime, endTime: $0.endTime, isSemantic: false) }
    }

    private static func buildSemanticUnits(fullText: String, words: [AriaWord]) -> [LayoutUnit] {
        guard hasCJK(fullText), words.count > 1 else { return singleWordUnits(words) }

        // NLTokenizer 等价 Intl.Segmenter：词单元 + 词间的标点碎片
        struct Segment { let text: String; let isWordLike: Bool }
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = fullText

        var segments: [Segment] = []
        var cursor = fullText.startIndex
        tokenizer.enumerateTokens(in: fullText.startIndex..<fullText.endIndex) { range, _ in
            if cursor < range.lowerBound {
                let gap = String(fullText[cursor..<range.lowerBound])
                if !gap.trimmingCharacters(in: .whitespaces).isEmpty {
                    segments.append(Segment(text: gap, isWordLike: false))
                }
            }
            segments.append(Segment(text: String(fullText[range]), isWordLike: true))
            cursor = range.upperBound
            return true
        }
        if cursor < fullText.endIndex {
            let tail = String(fullText[cursor..<fullText.endIndex])
            if !tail.trimmingCharacters(in: .whitespaces).isEmpty {
                segments.append(Segment(text: tail, isWordLike: false))
            }
        }
        guard !segments.isEmpty else { return singleWordUnits(words) }

        // mapSegmentsToWords：把分词结果精确映射回原始计时词，映射不上则整体回退
        var units: [LayoutUnit] = []
        var wordIndex = 0

        for segment in segments {
            let segmentText = segment.text.trimmingCharacters(in: .whitespaces)
            guard !segmentText.isEmpty else { continue }

            let startWordIndex = wordIndex
            var collected = ""
            while wordIndex < words.count && collected.count < segmentText.count {
                collected += words[wordIndex].text.trimmingCharacters(in: .whitespaces)
                wordIndex += 1
                if !segmentText.hasPrefix(collected) { return singleWordUnits(words) }
            }
            guard collected == segmentText else { return singleWordUnits(words) }

            let segmentWords = Array(words[startWordIndex..<wordIndex])
            guard let first = segmentWords.first, let last = segmentWords.last else { return singleWordUnits(words) }

            if !segment.isWordLike, !units.isEmpty {
                units[units.count - 1].text += segmentText
                units[units.count - 1].words.append(contentsOf: segmentWords)
                units[units.count - 1].endTime = last.endTime
                continue
            }

            units.append(LayoutUnit(
                text: segmentText,
                words: segmentWords,
                startTime: first.startTime,
                endTime: last.endTime,
                isSemantic: segment.isWordLike && hasCJK(segmentText) && segmentWords.count > 1
            ))
        }

        guard wordIndex == words.count, !units.isEmpty else { return singleWordUnits(words) }
        return units
    }

    private static func applyStickyPunctuation(_ units: [LayoutUnit]) -> [LayoutUnit] {
        var merged: [LayoutUnit] = []

        func endsWithWordChar(_ text: String) -> Bool {
            guard let last = text.trimmingCharacters(in: .whitespaces).last else { return false }
            return last.isLetter || last.isNumber
        }
        func endsWithApostrophe(_ text: String) -> Bool {
            guard let last = text.trimmingCharacters(in: .whitespaces).last else { return false }
            return last == "'" || last == "’"
        }
        func isApostropheOnly(_ unit: LayoutUnit) -> Bool {
            let t = unit.text.trimmingCharacters(in: .whitespaces)
            return t == "'" || t == "’"
        }
        func isContractionSuffix(_ unit: LayoutUnit) -> Bool {
            contractionSuffixes.contains(unit.text.trimmingCharacters(in: .whitespaces).lowercased())
        }
        func isDirectContraction(_ unit: LayoutUnit) -> Bool {
            let t = unit.text.trimmingCharacters(in: .whitespaces).lowercased()
            guard let first = t.first, first == "'" || first == "’" else { return false }
            return contractionSuffixes.contains(String(t.dropFirst()))
        }
        func isTrailingPunctuation(_ unit: LayoutUnit) -> Bool {
            let t = unit.text.trimmingCharacters(in: .whitespaces)
            return !t.isEmpty && t.allSatisfy { stickyTrailingPunctuation.contains($0) }
        }
        func attach(_ unit: LayoutUnit) {
            merged[merged.count - 1].text += unit.text
            merged[merged.count - 1].words.append(contentsOf: unit.words)
            merged[merged.count - 1].endTime = unit.endTime
            merged[merged.count - 1].isSticky = true
        }

        var index = 0
        while index < units.count {
            let current = units[index]
            guard !merged.isEmpty else {
                merged.append(current)
                index += 1
                continue
            }
            let previous = merged[merged.count - 1]

            if isApostropheOnly(current),
               index + 1 < units.count,
               endsWithWordChar(previous.text),
               isContractionSuffix(units[index + 1]) {
                attach(current)
                attach(units[index + 1])
                index += 2
                continue
            }
            if isDirectContraction(current), endsWithWordChar(previous.text) {
                attach(current)
                index += 1
                continue
            }
            if isContractionSuffix(current), endsWithApostrophe(previous.text) {
                attach(current)
                index += 1
                continue
            }
            if isTrailingPunctuation(current), endsWithWordChar(previous.text) {
                attach(current)
                index += 1
                continue
            }
            merged.append(current)
            index += 1
        }
        return merged
    }

    // MARK: - 确定性随机（classic Visualizer 的 sin-hash RNG）

    /// fract(sin(seed + offset) * 10000)：同一句歌词永远得到同一套散点布局
    static func seededRandom(_ seed: Double, _ offset: Double) -> Double {
        let x = sin(seed + offset) * 10000
        return x - floor(x)
    }
}
