// LyricSyncer.swift
// FFmpegSwiftSDK
//
// 歌词同步引擎。解析 LRC 格式歌词，根据播放时间实时匹配当前歌词行。
// 支持标准 LRC、增强 LRC（逐字）、时间偏移调整。

import Foundation

// MARK: - 数据模型

/// 逐字歌词中的单个字/词。
public struct LyricWord {
    /// 该字的起始时间（秒）
    public let startTime: TimeInterval
    /// 该字的结束时间（秒）
    public let endTime: TimeInterval
    /// 文字内容
    public let text: String

    public init(startTime: TimeInterval, endTime: TimeInterval, text: String) {
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
    }
}

/// 一行歌词。
public struct LyricLine {
    /// 该行的起始时间（秒）
    public let time: TimeInterval
    /// 整行文字
    public let text: String
    /// 逐字数据（增强 LRC 格式才有，普通 LRC 为空数组）
    public let words: [LyricWord]
    /// 翻译文本（双语歌词）
    public let translation: String?

    public init(time: TimeInterval, text: String, words: [LyricWord] = [], translation: String? = nil) {
        self.time = time
        self.text = text
        self.words = words
        self.translation = translation
    }
}

/// LRC 文件的元信息标签。
public struct LyricMetadata {
    /// 歌曲标题 [ti:]
    public let title: String?
    /// 艺术家 [ar:]
    public let artist: String?
    /// 专辑 [al:]
    public let album: String?
    /// 作词 [by:]
    public let author: String?
    /// 整体偏移（毫秒）[offset:]
    public let offset: Int?
}


// MARK: - LRC 解析器

/// LRC 歌词解析器。
///
/// 支持格式：
/// - 标准 LRC：`[mm:ss.xx]歌词文本`
/// - 多时间标签：`[mm:ss.xx][mm:ss.xx]歌词文本`
/// - 增强 LRC（逐字）：`[mm:ss.xx]<mm:ss.xx>字<mm:ss.xx>字`
/// - 元信息标签：`[ti:标题]`、`[ar:艺术家]`、`[al:专辑]`、`[offset:毫秒]`
public final class LyricParser {

    public init() {}

    /// 解析 LRC 格式歌词字符串。
    ///
    /// - Parameter content: LRC 文件内容
    /// - Returns: (metadata, lines) 元组
    public func parse(_ content: String) -> (metadata: LyricMetadata, lines: [LyricLine]) {
        var title: String?
        var artist: String?
        var album: String?
        var author: String?
        var offset: Int?
        var lines = [LyricLine]()

        let rawLines = content.components(separatedBy: .newlines)

        for rawLine in rawLines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // 尝试解析元信息标签
            if let meta = parseMetaTag(trimmed) {
                switch meta.0 {
                case "ti": title = meta.1
                case "ar": artist = meta.1
                case "al": album = meta.1
                case "by": author = meta.1
                case "offset": offset = Int(meta.1)
                default: break
                }
                continue
            }

            // 解析时间标签 + 歌词
            let parsed = parseTimedLine(trimmed)
            lines.append(contentsOf: parsed)
        }

        // 按时间排序
        lines.sort { $0.time < $1.time }

        let metadata = LyricMetadata(
            title: title, artist: artist, album: album,
            author: author, offset: offset
        )
        return (metadata, lines)
    }

    /// 解析元信息标签，如 [ti:标题]
    private func parseMetaTag(_ line: String) -> (String, String)? {
        let metaTags = ["ti", "ar", "al", "by", "offset", "re", "ve"]
        for tag in metaTags {
            let prefix = "[\(tag):"
            if line.lowercased().hasPrefix(prefix) && line.hasSuffix("]") {
                let start = line.index(line.startIndex, offsetBy: prefix.count)
                let end = line.index(line.endIndex, offsetBy: -1)
                guard start < end else { return nil }
                let value = String(line[start..<end]).trimmingCharacters(in: .whitespaces)
                return (tag, value)
            }
        }
        return nil
    }

    /// 解析带时间标签的歌词行。
    /// 支持多时间标签：[00:01.00][00:15.00]重复歌词
    private func parseTimedLine(_ line: String) -> [LyricLine] {
        var times = [TimeInterval]()
        var remaining = line[line.startIndex...]

        // 提取所有 [mm:ss.xx] 时间标签
        while remaining.hasPrefix("[") {
            guard let closeBracket = remaining.firstIndex(of: "]") else { break }
            let tagContent = remaining[remaining.index(after: remaining.startIndex)..<closeBracket]
            if let time = parseTimeTag(String(tagContent)) {
                times.append(time)
                remaining = remaining[remaining.index(after: closeBracket)...]
            } else {
                break // 不是时间标签，可能是元信息
            }
        }

        guard !times.isEmpty else { return [] }

        let text = String(remaining).trimmingCharacters(in: .whitespaces)

        // 检查是否有逐字标签 <mm:ss.xx>
        let words = parseWordTags(text, baseTime: times[0])

        let cleanText: String
        if !words.isEmpty {
            // 去掉逐字时间标签，只保留文字
            cleanText = words.map { $0.text }.joined()
        } else {
            cleanText = text
        }

        // 每个时间标签生成一行（多时间标签 = 重复歌词）
        return times.map { time in
            LyricLine(time: time, text: cleanText, words: words)
        }
    }

    /// 解析时间标签内容 "mm:ss.xx" → 秒
    private func parseTimeTag(_ tag: String) -> TimeInterval? {
        // 支持 mm:ss.xx、mm:ss.xxx、mm:ss
        let parts = tag.split(separator: ":")
        guard parts.count == 2 else { return nil }
        guard let minutes = Double(parts[0]) else { return nil }

        let secParts = parts[1].split(separator: ".")
        guard let seconds = Double(secParts[0]) else { return nil }

        var fraction: Double = 0
        if secParts.count > 1 {
            let fracStr = String(secParts[1])
            if let f = Double("0." + fracStr) {
                fraction = f
            }
        }

        return minutes * 60.0 + seconds + fraction
    }

    /// 解析增强 LRC 的逐字标签：<mm:ss.xx>字<mm:ss.xx>字
    private func parseWordTags(_ text: String, baseTime: TimeInterval) -> [LyricWord] {
        guard text.contains("<") && text.contains(">") else { return [] }

        var words = [LyricWord]()
        var scanner = text[text.startIndex...]

        while !scanner.isEmpty {
            // 查找 <mm:ss.xx>
            guard let openAngle = scanner.firstIndex(of: "<") else {
                // 剩余文本没有时间标签了
                break
            }
            guard let closeAngle = scanner.firstIndex(of: ">"), closeAngle > openAngle else { break }

            let tagContent = scanner[scanner.index(after: openAngle)..<closeAngle]
            guard let wordTime = parseTimeTag(String(tagContent)) else { break }

            // 标签后面到下一个 < 或行尾就是文字
            let afterTag = scanner.index(after: closeAngle)
            let nextOpen = scanner[afterTag...].firstIndex(of: "<") ?? scanner.endIndex
            let wordText = String(scanner[afterTag..<nextOpen])

            if !wordText.isEmpty {
                // endTime 暂时设为下一个词的 startTime，最后一个词用行尾
                words.append(LyricWord(startTime: wordTime, endTime: wordTime, text: wordText))
            }

            scanner = scanner[nextOpen...]
        }

        // 修正 endTime：每个词的 endTime = 下一个词的 startTime
        for i in 0..<words.count {
            let endTime: TimeInterval
            if i + 1 < words.count {
                endTime = words[i + 1].startTime
            } else {
                // 最后一个词，endTime = startTime + 合理估计
                endTime = words[i].startTime + 2.0
            }
            words[i] = LyricWord(startTime: words[i].startTime, endTime: endTime, text: words[i].text)
        }

        return words
    }
}


// MARK: - 歌词同步引擎

/// 歌词同步回调。
/// - Parameters:
///   - lineIndex: 当前歌词行索引
///   - line: 当前歌词行
///   - wordIndex: 当前逐字索引（无逐字数据时为 nil）
///   - progress: 当前行的播放进度 [0, 1]
public typealias LyricSyncCallback = (
    _ lineIndex: Int,
    _ line: LyricLine,
    _ wordIndex: Int?,
    _ progress: Float
) -> Void

/// 实时歌词同步引擎。
///
/// 加载 LRC 歌词后，根据播放时间实时匹配当前行和逐字进度。
/// 支持时间偏移调整（歌词提前/延后）。
///
/// ```swift
/// let syncer = LyricSyncer()
/// syncer.load(lrcContent: lrcString)
/// syncer.onSync = { lineIndex, line, wordIndex, progress in
///     // 更新 UI：高亮当前行、逐字进度条
/// }
/// // 在播放循环中调用：
/// syncer.update(time: player.currentTime)
/// ```
public final class LyricSyncer {

    // MARK: - 属性

    /// 解析后的歌词行（按时间排序）
    public private(set) var lines: [LyricLine] = []

    /// 歌词元信息
    public private(set) var metadata: LyricMetadata?

    /// 时间偏移（秒）。正值 = 歌词延后，负值 = 歌词提前。
    /// 用于手动微调歌词与音频的对齐。
    public var offset: TimeInterval = 0

    /// 同步回调。每次 update 时如果当前行发生变化就会触发。
    public var onSync: LyricSyncCallback?

    /// 当前行索引（-1 = 歌词尚未开始）
    public private(set) var currentLineIndex: Int = -1

    /// 当前逐字索引
    public private(set) var currentWordIndex: Int?

    /// 是否已加载歌词
    public var isLoaded: Bool { !lines.isEmpty }

    private let parser = LyricParser()

    // MARK: - 初始化

    public init() {}

    // MARK: - 加载歌词

    /// 加载 LRC 格式歌词。
    /// - Parameter lrcContent: LRC 文件内容字符串
    public func load(lrcContent: String) {
        let result = parser.parse(lrcContent)
        self.metadata = result.metadata
        self.lines = result.lines
        self.currentLineIndex = -1
        self.currentWordIndex = nil

        // 应用 LRC 文件中的 offset 标签
        if let lrcOffset = result.metadata.offset {
            self.offset = Double(lrcOffset) / 1000.0
        }
    }

    /// 加载已解析的歌词行（用于非 LRC 格式或自定义解析）。
    /// - Parameter lines: 歌词行数组，必须按时间排序
    public func load(lines: [LyricLine]) {
        self.lines = lines.sorted { $0.time < $1.time }
        self.metadata = nil
        self.currentLineIndex = -1
        self.currentWordIndex = nil
    }

    /// 加载双语歌词（原文 + 翻译）。
    /// 两个 LRC 按时间合并，翻译填入 LyricLine.translation。
    /// - Parameters:
    ///   - originalLRC: 原文 LRC
    ///   - translationLRC: 翻译 LRC
    public func loadBilingual(originalLRC: String, translationLRC: String) {
        let original = parser.parse(originalLRC)
        let translation = parser.parse(translationLRC)

        self.metadata = original.metadata

        // 按时间匹配翻译行（容差 0.5 秒）
        var mergedLines = [LyricLine]()
        for line in original.lines {
            let matchedTranslation = translation.lines.first { abs($0.time - line.time) < 0.5 }
            mergedLines.append(LyricLine(
                time: line.time,
                text: line.text,
                words: line.words,
                translation: matchedTranslation?.text
            ))
        }

        self.lines = mergedLines
        self.currentLineIndex = -1
        self.currentWordIndex = nil
    }

    /// 清除歌词。
    public func clear() {
        lines = []
        metadata = nil
        currentLineIndex = -1
        currentWordIndex = nil
        offset = 0
    }

    // MARK: - 实时同步

    /// 根据当前播放时间更新歌词状态。
    ///
    /// 在播放循环或定时器中调用。如果当前行发生变化，会触发 onSync 回调。
    ///
    /// - Parameter time: 当前播放时间（秒）
    public func update(time: TimeInterval) {
        guard !lines.isEmpty else { return }

        let adjustedTime = time + offset

        // 二分查找当前行
        let newIndex = findLineIndex(for: adjustedTime)

        // 计算逐字索引
        var wordIdx: Int?
        var progress: Float = 0

        if newIndex >= 0 && newIndex < lines.count {
            let line = lines[newIndex]

            // 计算行内进度
            let lineStart = line.time
            let lineEnd: TimeInterval
            if newIndex + 1 < lines.count {
                lineEnd = lines[newIndex + 1].time
            } else {
                lineEnd = lineStart + 5.0 // 最后一行默认 5 秒
            }
            let lineDuration = lineEnd - lineStart
            if lineDuration > 0 {
                progress = Float((adjustedTime - lineStart) / lineDuration)
                progress = min(max(progress, 0), 1)
            }

            // 逐字匹配
            if !line.words.isEmpty {
                for (i, word) in line.words.enumerated() {
                    if adjustedTime >= word.startTime && adjustedTime < word.endTime {
                        wordIdx = i
                        break
                    }
                }
                // 如果超过最后一个词的 endTime，指向最后一个词
                if wordIdx == nil && adjustedTime >= (line.words.last?.startTime ?? 0) {
                    wordIdx = line.words.count - 1
                }
            }
        }

        // 状态变化时触发回调
        if newIndex != currentLineIndex || wordIdx != currentWordIndex {
            currentLineIndex = newIndex
            currentWordIndex = wordIdx

            if newIndex >= 0 && newIndex < lines.count {
                onSync?(newIndex, lines[newIndex], wordIdx, progress)
            }
        }
    }

    /// 获取指定时间的歌词行（不触发回调）。
    /// - Parameter time: 时间（秒）
    /// - Returns: 歌词行，nil = 该时间点没有歌词
    public func line(at time: TimeInterval) -> LyricLine? {
        let idx = findLineIndex(for: time + offset)
        guard idx >= 0 && idx < lines.count else { return nil }
        return lines[idx]
    }

    /// 获取当前行附近的歌词（用于滚动显示）。
    /// - Parameter range: 前后各取多少行，默认 3
    /// - Returns: (行索引, 歌词行) 数组
    public func nearbyLines(range: Int = 3) -> [(index: Int, line: LyricLine)] {
        guard currentLineIndex >= 0 else {
            // 歌词未开始，返回前几行
            return Array(lines.prefix(range)).enumerated().map { ($0.offset, $0.element) }
        }

        let start = max(0, currentLineIndex - range)
        let end = min(lines.count, currentLineIndex + range + 1)
        return (start..<end).map { ($0, lines[$0]) }
    }

    /// seek 后重置同步状态。
    public func reset() {
        currentLineIndex = -1
        currentWordIndex = nil
    }

    // MARK: - 内部方法

    /// 二分查找：找到 time 对应的歌词行索引。
    /// 返回最后一个 time >= line.time 的行索引，-1 = 在第一行之前。
    private func findLineIndex(for time: TimeInterval) -> Int {
        guard !lines.isEmpty else { return -1 }

        // 在第一行之前
        if time < lines[0].time { return -1 }

        // 二分查找
        var lo = 0
        var hi = lines.count - 1

        while lo <= hi {
            let mid = (lo + hi) / 2
            if lines[mid].time <= time {
                lo = mid + 1
            } else {
                hi = mid - 1
            }
        }

        return hi
    }
}
