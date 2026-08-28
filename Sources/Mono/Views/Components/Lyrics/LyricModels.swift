import SwiftUI
import Combine


// MARK: - Lyric Parser

struct LyricWord: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let startTime: TimeInterval
    let duration: TimeInterval
}

/// 一行标准歌词及其翻译、时长与可选逐字时间轴。
struct LyricLine: Identifiable, Equatable {
    let id = UUID()
    let time: TimeInterval
    let text: String
    var translation: String?
    var duration: TimeInterval = 0
    var words: [LyricWord] = []
}

/// 普通歌词页与歌词播放器共用的逐字时间轴。
/// 平台逐字数据可用时保留原时间；缺失、相对时间或明显异常时统一补齐。
enum LyricKaraokeTimeline {
    /// 歌词渲染使用的统一播放时钟。
    ///
    /// 普通平台由 FFmpeg 流播放器提供更细粒度的时间；Apple Music 由
    /// MusicKit 播放，旧流播放器通常停在 0，必须使用统一进度发布器。
    static func playbackTime(
        streamPlayerTime: TimeInterval,
        publishedTime: TimeInterval,
        isAppleMusic: Bool,
        appleMusicPlayerTime: TimeInterval? = nil
    ) -> TimeInterval {
        if isAppleMusic {
            if let appleMusicPlayerTime,
               appleMusicPlayerTime.isFinite,
               !appleMusicPlayerTime.isNaN,
               appleMusicPlayerTime >= 0 {
                return appleMusicPlayerTime
            }
            return publishedTime.isFinite && !publishedTime.isNaN
                ? max(publishedTime, 0)
                : 0
        }
        return streamPlayerTime.isFinite
            && !streamPlayerTime.isNaN
            && streamPlayerTime >= 0
            ? streamPlayerTime
            : max(publishedTime, 0)
    }

    static func resolvedWords(for line: LyricLine, displayText: String? = nil) -> [LyricWord] {
        let text = displayText ?? line.text.monoLyricDisplayText
        guard !text.isEmpty else { return [] }

        let platformWords = normalizedPlatformWords(for: line, displayText: text)
        if !platformWords.isEmpty {
            return platformWords
        }

        return syntheticWords(for: line, displayText: text)
    }

    /// Stateless word progress used by every karaoke surface. Passing this
    /// scalar into a word view (instead of the continuously changing playback
    /// clock) lets SwiftUI keep all completed and waiting word subtrees stable;
    /// only the actively sung word changes from frame to frame.
    static func progress(for word: LyricWord, at time: TimeInterval) -> CGFloat {
        guard word.duration > 0 else { return time >= word.startTime ? 1 : 0 }
        if time <= word.startTime { return 0 }
        if time >= word.startTime + word.duration { return 1 }
        return min(max(CGFloat((time - word.startTime) / word.duration), 0), 1)
    }

    private static func normalizedPlatformWords(for line: LyricLine, displayText: String) -> [LyricWord] {
        let validWords = line.words.filter {
            !$0.text.isEmpty
                && $0.startTime.isFinite
                && $0.duration.isFinite
                && $0.duration > 0
                && $0.duration < 60
        }
        guard !validWords.isEmpty else { return [] }

        let sorted = validWords.sorted { $0.startTime < $1.startTime }
        guard let first = sorted.first, let last = sorted.last else { return [] }

        let lineDuration = line.duration.isFinite && line.duration > 0 ? line.duration : 0
        let rawEnd = last.startTime + last.duration
        let looksRelative = line.time > 0.75
            && first.startTime >= -0.1
            && first.startTime < line.time - 0.5
            && lineDuration > 0
            && rawEnd <= lineDuration + 1
        let timeOffset = looksRelative ? line.time : 0

        let normalized = sorted.map {
            LyricWord(
                text: $0.text.monoLyricDisplayText,
                startTime: $0.startTime + timeOffset,
                duration: $0.duration
            )
        }

        let effectiveDuration = lineDuration > 0
            ? lineDuration
            : max((normalized.last.map { $0.startTime + $0.duration } ?? line.time) - line.time, 0)
        let lineEnd = line.time + max(effectiveDuration, 0.5)
        let overlapsLine = normalized.contains {
            $0.startTime <= lineEnd + 0.75 && $0.startTime + $0.duration >= line.time - 0.35
        }

        let expectedCharacterCount = displayText.filter { !$0.isWhitespace }.count
        let timedCharacterCount = normalized
            .map(\.text)
            .joined()
            .filter { !$0.isWhitespace }
            .count
        let hasEnoughText = expectedCharacterCount == 0
            || Double(timedCharacterCount) / Double(expectedCharacterCount) >= 0.45

        return overlapsLine && hasEnoughText ? normalized : []
    }

    private static func syntheticWords(for line: LyricLine, displayText: String) -> [LyricWord] {
        let characters = Array(displayText)
        guard !characters.isEmpty else { return [] }

        let fallbackDuration = min(max(Double(characters.count) * 0.16, 1.8), 8)
        let duration = line.duration.isFinite && line.duration > 0 ? line.duration : fallbackDuration
        let characterDuration = duration / Double(characters.count)

        return characters.enumerated().map { index, character in
            LyricWord(
                text: String(character),
                startTime: line.time + Double(index) * characterDuration,
                duration: characterDuration
            )
        }
    }
}
