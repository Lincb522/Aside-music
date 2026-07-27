import Foundation
import WidgetKit
import SwiftUI
import UIKit

private let appGroupID = "group.zijiu.Mono.com"

// MARK: - App Group 歌词载荷

/// 主 App 写入 App Group 的单行同步歌词。
struct WidgetLyricLine: Decodable {
    let t: TimeInterval
    let x: String
    let tr: String?
}

private struct WidgetLyricsPayload: Decodable {
    let songId: Int
    let songIdentity: String?
    let lines: [WidgetLyricLine]
}

/// 从 App Group 构建当前播放快照，并按主题动画与歌词时序生成 Widget 时间线。
struct NowPlayingProvider: TimelineProvider {
    let theme: WidgetTheme

    private var groupDefaults: UserDefaults? { UserDefaults(suiteName: appGroupID) }

    func placeholder(in context: Context) -> NowPlayingEntry {
        NowPlayingEntry.preview(theme: theme)
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (NowPlayingEntry) -> Void
    ) {
        completion(snapshotEntry(in: context))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<NowPlayingEntry>) -> Void
    ) {
        completion(makeTimeline(in: context))
    }

    /// 同步构建入口，供「自选主题」的 AppIntent Provider 直接调用，
    /// 避免 continuation 跨并发域传非 Sendable 值。
    func snapshotEntry(in context: Context) -> NowPlayingEntry {
        let entry = currentEntry(theme: theme)
        if context.isPreview || entry.isEmpty {
            return NowPlayingEntry.preview(theme: theme)
        }
        return entry
    }

    func makeTimeline(in context: Context) -> Timeline<NowPlayingEntry> {
        var base = currentEntry(theme: theme)
        let fallbackUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: base.date) ?? base.date.addingTimeInterval(300)

        guard base.isPlaying else {
            return Timeline(entries: [base], policy: .after(fallbackUpdate))
        }

        let now = Date()
        let elapsed = max(0, now.timeIntervalSince(base.playbackReferenceDate))
        let position = base.playbackCurrentTime + elapsed

        base.date = now
        base.playbackCurrentTime = position
        base.playbackReferenceDate = now

        // 唱片旋转主题需要连续转动：WidgetKit 的过渡动画有 2 秒硬上限，
        // 只有让相邻 entry 间隔 ≤2 秒、每段动画铺满间隔，旋转才能首尾无缝衔接。
        let rotatingThemes: Set<WidgetTheme> = [.aperture, .vinyl]
        let needsContinuousRotation = rotatingThemes.contains(theme)

        // 多条目时间线会把每条 entry 的视图连同封面一起归档，
        // 必须用缩小后的封面控制归档体积，否则扩展会被系统按内存上限杀掉。
        // 旋转主题条目数量大，封面压得更小。
        base.coverImageData = downscaledCoverData(
            base.coverImageData,
            maxDimension: needsContinuousRotation ? 360 : 500
        )

        var entries: [NowPlayingEntry] = []
        let lines = loadLyricLines()

        if needsContinuousRotation {
            // 严格 1.5 秒等距网格：动画时长恒为「间隔 + 0.5 秒提前量」= 2 秒
            // （顶满 WidgetKit 动画上限）。等距让每段动画形状完全相同，
            // entry 切换的随机延迟只造成极小的速度修正，不会忽快忽慢；
            // 不再为歌词时间戳插入额外切换点（歌词改在最近的网格点换行，
            // 最多迟 1.5 秒），减少切换次数就是减少抖动机会。
            let step: TimeInterval = 1.5
            let maxEntries = 150
            let remaining = base.playbackDuration > position
                ? (base.playbackDuration - position + step)
                : 300
            let horizon = min(remaining, Double(maxEntries) * step)

            for offset in stride(from: 0, through: horizon, by: step) {
                var entry = base
                entry.date = now.addingTimeInterval(offset)
                entry.playbackCurrentTime = position + offset
                entry.playbackReferenceDate = entry.date
                if !lines.isEmpty {
                    applyLyricContext(&entry, lines: lines, index: lyricIndex(in: lines, at: position + offset))
                }
                entries.append(entry)
            }
        } else if lines.isEmpty {
            // 无同步歌词：按固定节拍生成条目，让旋转等随进度推进的动画持续衔接
            let step: TimeInterval = 15
            let remaining = base.playbackDuration > position ? (base.playbackDuration - position + 2) : 300
            let count = min(20, max(1, Int(remaining / step) + 1))
            for index in 0..<count {
                var entry = base
                entry.date = now.addingTimeInterval(Double(index) * step)
                entry.playbackCurrentTime = position + Double(index) * step
                entry.playbackReferenceDate = entry.date
                entries.append(entry)
            }
        } else {
            // 有整首同步歌词：按歌词时间戳预生成条目，
            // 由 WidgetKit 在准确时刻自动换行，无需主 App 逐句 reload。
            applyLyricContext(&base, lines: lines, index: lyricIndex(in: lines, at: position))
            entries.append(base)

            let maxFutureEntries = 30
            for (index, line) in lines.enumerated() where line.t > position + 0.05 {
                guard entries.count <= maxFutureEntries else { break }
                var entry = base
                entry.date = now.addingTimeInterval(line.t - position)
                entry.playbackCurrentTime = line.t
                entry.playbackReferenceDate = entry.date
                applyLyricContext(&entry, lines: lines, index: index)
                if let last = entries.last, entry.date.timeIntervalSince(last.date) < 0.05 {
                    entries[entries.count - 1] = entry
                } else {
                    entries.append(entry)
                }
            }
        }

        // 歌曲结束（或时间线窗口耗尽）后再请求新时间线
        let horizonEnd: Date
        if needsContinuousRotation {
            // 旋转主题：窗口用完立刻续一条时间线，避免最后一条 entry 长时间停转
            horizonEnd = (entries.last?.date ?? now).addingTimeInterval(2)
        } else if base.playbackDuration > position {
            let songEnd = now.addingTimeInterval(base.playbackDuration - position + 2)
            let windowEnd = (entries.last?.date ?? now).addingTimeInterval(300)
            horizonEnd = min(songEnd, windowEnd)
        } else {
            horizonEnd = (entries.last?.date ?? now).addingTimeInterval(300)
        }
        let policyDate = max(horizonEnd, now.addingTimeInterval(15))

        // 标记每条 entry 的展示时长，供视图把过渡动画铺满整个展示期（如唱片持续旋转）
        for index in entries.indices {
            let nextDate = index + 1 < entries.count ? entries[index + 1].date : policyDate
            entries[index].entryDisplayDuration = max(0, nextDate.timeIntervalSince(entries[index].date))
        }

        return Timeline(entries: entries, policy: .after(policyDate))
    }

    // MARK: - Synced Lyrics

    private func downscaledCoverData(_ data: Data?, maxDimension: CGFloat = 500) -> Data? {
        guard let data, let image = UIImage(data: data) else { return data }
        let maxSide = max(image.size.width, image.size.height)
        guard maxSide > maxDimension else { return data }
        let scale = maxDimension / maxSide
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        return resized.jpegData(compressionQuality: 0.82) ?? data
    }

    private func loadLyricLines() -> [WidgetLyricLine] {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else { return [] }
        let fileURL = containerURL.appendingPathComponent("widget_lyrics.json")
        guard let data = try? Data(contentsOf: fileURL, options: [.mappedIfSafe]),
              let payload = try? JSONDecoder().decode(WidgetLyricsPayload.self, from: data) else { return [] }
        let expectedSongId = groupDefaults?.integer(forKey: "widget_song_id") ?? 0
        let expectedIdentity = groupDefaults?.string(forKey: "widget_song_identity") ?? ""
        if !expectedIdentity.isEmpty,
           let payloadIdentity = payload.songIdentity,
           !payloadIdentity.isEmpty,
           payloadIdentity != expectedIdentity {
            return []
        }
        if expectedSongId != 0, payload.songId != expectedSongId { return [] }
        return payload.lines
    }

    private func lyricIndex(in lines: [WidgetLyricLine], at position: TimeInterval) -> Int {
        lines.lastIndex(where: { $0.t <= position }) ?? -1
    }

    private func applyLyricContext(_ entry: inout NowPlayingEntry, lines: [WidgetLyricLine], index: Int) {
        entry.lyricCount = lines.count
        entry.lyricIndex = index
        entry.prevLyricText = index > 0 ? lines[index - 1].x : ""
        entry.nextLyricText = (index + 1) < lines.count && index >= -1 ? lines[index + 1].x : ""
        if index >= 0 {
            entry.lyricText = lines[index].x
            entry.lyricTranslation = lines[index].tr ?? ""
        } else {
            entry.lyricText = ""
            entry.lyricTranslation = ""
        }
    }

    private func currentEntry(theme: WidgetTheme) -> NowPlayingEntry {
        let songName = groupDefaults?.string(forKey: "widget_songName") ?? ""
        let artistName = groupDefaults?.string(forKey: "widget_artistName") ?? ""
        let albumName = groupDefaults?.string(forKey: "widget_album_name") ?? ""
        let playbackState: PlaybackSurfaceState = {
            if let raw = groupDefaults?.string(forKey: "widget_playbackState"),
               let state = PlaybackSurfaceState(rawValue: raw) {
                return state
            }
            return (groupDefaults?.bool(forKey: "widget_isPlaying") ?? false) ? .playing : .paused
        }()

        let dominantRGB = (groupDefaults?.array(forKey: "widget_dominantRGB") as? [CGFloat]) ?? []
        let secondaryRGB = (groupDefaults?.array(forKey: "widget_secondaryRGB") as? [CGFloat]) ?? []
        let coverIsDark = groupDefaults?.bool(forKey: "widget_coverIsDark") ?? true
        let sourceName = groupDefaults?.string(forKey: "widget_source") ?? ""
        let qualityText = groupDefaults?.string(forKey: "widget_quality") ?? ""
        let playModeText = groupDefaults?.string(forKey: "widget_play_mode") ?? "顺序"
        let queueIndex = groupDefaults?.integer(forKey: "widget_queue_index") ?? 0
        let queueCount = groupDefaults?.integer(forKey: "widget_queue_count") ?? 0
        let tempoBPM = groupDefaults?.object(forKey: "widget_tempo_bpm") as? Int
        let tempoIsAnalyzing = groupDefaults?.bool(forKey: "widget_tempo_analyzing") ?? false
        let playbackCurrentTime = groupDefaults?.double(forKey: "widget_current_time") ?? 0
        let playbackDuration = groupDefaults?.double(forKey: "widget_duration") ?? 0
        let playbackReferenceDate = groupDefaults?.object(forKey: "widget_progress_reference_date") as? Date ?? .now

        var coverData: Data?
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let coverURL = url.appendingPathComponent("widget_cover.jpg")
            let expectedIdentity = groupDefaults?.string(forKey: "widget_song_identity") ?? ""
            let coverIdentity = groupDefaults?.string(forKey: "widget_cover_identity") ?? ""
            let attributes = try? FileManager.default.attributesOfItem(atPath: coverURL.path)
            if (expectedIdentity.isEmpty || coverIdentity == expectedIdentity),
               let fileSize = attributes?[.size] as? NSNumber,
               fileSize.intValue <= 500_000 {
                coverData = try? Data(contentsOf: coverURL, options: [.mappedIfSafe])
            }
        }

        if songName.isEmpty {
            return NowPlayingEntry(
                date: .now, songName: "", artistName: "", albumName: "", playbackState: .idle,
                coverImageData: nil, theme: theme,
                dominantRGB: [], secondaryRGB: [], coverIsDark: true,
                sourceName: "", qualityText: "", playModeText: "顺序", queueIndex: 0, queueCount: 0,
                tempoBPM: nil, tempoIsAnalyzing: false, lyricText: "",
                playbackCurrentTime: 0, playbackDuration: 0, playbackReferenceDate: .now
            )
        }

        var entry = NowPlayingEntry(
            date: .now, songName: songName, artistName: artistName, albumName: albumName,
            playbackState: playbackState, coverImageData: coverData, theme: theme,
            dominantRGB: dominantRGB, secondaryRGB: secondaryRGB, coverIsDark: coverIsDark,
            sourceName: sourceName, qualityText: qualityText, playModeText: playModeText,
            queueIndex: queueIndex, queueCount: queueCount,
            tempoBPM: tempoBPM, tempoIsAnalyzing: tempoIsAnalyzing,
            lyricText: groupDefaults?.string(forKey: "widget_lyricText") ?? "",
            playbackCurrentTime: playbackCurrentTime,
            playbackDuration: playbackDuration,
            playbackReferenceDate: playbackReferenceDate
        )
        let lines = loadLyricLines()
        if !lines.isEmpty {
            let elapsed = playbackState.isPlaying ? max(0, Date().timeIntervalSince(playbackReferenceDate)) : 0
            let position = playbackCurrentTime + elapsed
            applyLyricContext(&entry, lines: lines, index: lyricIndex(in: lines, at: position))
        }
        return entry
    }

}
