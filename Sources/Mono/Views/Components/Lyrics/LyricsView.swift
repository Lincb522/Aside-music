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

@MainActor
class LyricViewModel: ObservableObject {
    static let shared = LyricViewModel()

    private struct ParsedLyricCandidate {
        let source: LyricSource
        let lines: [LyricLine]
        let hasPlatformWordTiming: Bool
        let hasTranslation: Bool

        var qualityScore: Int {
            guard !lines.isEmpty else { return 0 }
            return 1
                + (hasPlatformWordTiming ? 4 : 0)
                + (hasTranslation ? 2 : 0)
        }
    }
    
    @Published var lyrics: [LyricLine] = []
    @Published var isLoading = false
    @Published var currentLineIndex: Int = 0
    @Published var hasLyrics = false
    @Published private(set) var activeSource: LyricSource?
    
    var currentLineSafely: LyricLine? {
        guard lyrics.indices.contains(currentLineIndex) else { return nil }
        return lyrics[currentLineIndex]
    }
    
    var currentLineText: String? {
        return currentLineSafely?.text
    }
    
    var currentLineProgress: Double = 0.0
    
    /// 当前已加载歌词的歌曲 ID（防止重复请求）
    private(set) var currentSongId: Int?
    /// 数字 ID 在不同平台之间可能重复；系统媒体信息与小组件使用完整播放身份判定。
    private(set) var currentSongIdentity: String?
    
    private var cancellables = Set<AnyCancellable>()
    private var translations: [TimeInterval: String] = [:]
    /// 当前歌词请求的会话 ID，防止旧请求回调覆盖新歌词
    private var lyricSessionId: Int = 0
    /// 仅对当前歌曲有效；完整播放身份可避免跨平台数字 ID 碰撞。
    private var currentSongSourceOverride: (
        identity: String,
        songId: Int,
        source: LyricSource
    )?
    
    func fetchLyrics(for song: Song) {
        prepareLyricIdentity(for: song)

        let identity = PlayerManager.playbackIdentityKey(for: song)
        if currentSongSourceOverride?.identity != identity {
            currentSongSourceOverride = nil
        }

        let source = currentSongSourceOverride?.source ?? LyricSource.resolvedGlobalSource(for: song)
        activeSource = source

        if applyDownloadedLyricsIfAvailable(for: song, source: source) {
            return
        }

        // 旧缓存没有记录歌词来源。只有歌词来源与歌曲平台一致时才复用，
        // 手动换源和跨平台默认源始终重新请求，防止显示错误来源的旧歌词。
        let canUseLegacyCache = currentSongSourceOverride?.songId == nil
            && source.musicSource == song.musicSource
        if canUseLegacyCache, applyCachedLyricsIfAvailable(for: song) {
            return
        }

        fetchLyrics(for: song, source: source, forceReload: false)
    }

    func hasCurrentLyrics(for song: Song) -> Bool {
        currentSongIdentity == PlayerManager.playbackIdentityKey(for: song)
            && currentSongId == song.id
            && hasLyrics
    }

    private func prepareLyricIdentity(for song: Song) {
        let identity = PlayerManager.playbackIdentityKey(for: song)
        guard currentSongIdentity != identity else { return }

        currentSongIdentity = identity
        // 强制新平台/新目录身份重新进入请求链，不能只按可能重复的数字 ID 复用。
        currentSongId = nil
    }

    private func applyDownloadedLyricsIfAvailable(for song: Song, source: LyricSource) -> Bool {
        guard let downloaded = LyricDownloadManager.offlineLyrics(for: song, source: source) else {
            return false
        }

        lyricSessionId += 1
        currentSongId = song.id
        currentSongIdentity = PlayerManager.playbackIdentityKey(for: song)
        activeSource = source
        lyrics = []
        hasLyrics = false
        currentLineIndex = 0
        currentLineProgress = 0
        translations = [:]
        isLoading = false

        if let translated = downloaded.translated {
            parseTranslations(translated)
        }
        parseQRC(downloaded.lyrics)
        hasLyrics = !lyrics.isEmpty
        return hasLyrics
    }

    func selectedSource(for song: Song) -> LyricSource {
        if currentSongSourceOverride?.identity == PlayerManager.playbackIdentityKey(for: song),
           currentSongSourceOverride?.songId == song.id,
           let source = currentSongSourceOverride?.source {
            return source
        }
        if currentSongIdentity == PlayerManager.playbackIdentityKey(for: song),
           currentSongId == song.id,
           let activeSource {
            return activeSource
        }
        return LyricSource.resolvedGlobalSource(for: song)
    }

    /// 临时更换当前歌曲的歌词来源；切歌后自动失效。
    func changeSource(_ source: LyricSource, for song: Song) {
        prepareLyricIdentity(for: song)
        currentSongSourceOverride = (
            PlayerManager.playbackIdentityKey(for: song),
            song.id,
            source
        )
        fetchLyrics(for: song, source: source, forceReload: true)
    }

    /// 应用当前全局来源策略，并清除当前歌曲的临时覆盖。
    func useGlobalSource(for song: Song) {
        prepareLyricIdentity(for: song)
        currentSongSourceOverride = nil
        let source = LyricSource.resolvedGlobalSource(for: song)
        fetchLyrics(for: song, source: source, forceReload: true)
    }

    private func fetchLyrics(for song: Song, source: LyricSource, forceReload: Bool) {
        activeSource = source

        switch source {
        case .netease:
            fetchNeteaseLyrics(
                for: song,
                fallbackQQMid: nil,
                // Apple Music 不向第三方提供歌词正文。跟随歌曲来源时先按
                // 元数据匹配 NCM，缺失后继续匹配 QCM。
                allowQQFallback: song.isAppleMusic,
                forceReload: forceReload
            )
        case .qqmusic:
            fetchQQLyrics(for: song, forceReload: forceReload)
        case .qishui:
            fetchQishuiLyrics(for: song, forceReload: forceReload)
        case .kugou:
            fetchKugouLyrics(for: song, forceReload: forceReload)
        }
    }

    private func beginLyricRequest(songId: Int, forceReload: Bool) -> Int? {
        if !forceReload, songId == currentSongId, hasLyrics || isLoading {
            return nil
        }

        let shouldClearLyrics = forceReload || songId != currentSongId

        lyricSessionId += 1
        currentSongId = songId
        isLoading = true

        if shouldClearLyrics {
            lyrics = []
            hasLyrics = false
            currentLineIndex = 0
            currentLineProgress = 0.0
            translations = [:]
        }

        return lyricSessionId
    }

    private func applyCachedLyricsIfAvailable(for song: Song) -> Bool {
        let identity = PlayerManager.playbackIdentityKey(for: song)
        if currentSongIdentity == identity,
           song.id == currentSongId,
           hasLyrics || isLoading {
            return true
        }
        guard let cached = OptimizedCacheManager.shared.getLyrics(songId: song.id) else { return false }

        lyricSessionId += 1
        currentSongId = song.id
        currentSongIdentity = identity
        lyrics = []
        hasLyrics = false
        currentLineIndex = 0
        currentLineProgress = 0.0
        translations = [:]
        isLoading = false

        if let translated = cached.translated {
            parseTranslations(translated)
        }

        let rawLyrics = cached.lyrics
        if rawLyrics.contains("<QrcInfos>") || rawLyrics.hasPrefix("<?xml") {
            parseQRC(rawLyrics)
        } else if rawLyrics.contains("(") && rawLyrics.contains(")") && rawLyrics.first == "[" {
            parseQRC(rawLyrics)
        } else {
            parseLyrics(rawLyrics)
        }
        hasLyrics = !lyrics.isEmpty
        return hasLyrics
    }

    private func fetchQishuiLyrics(for song: Song, forceReload: Bool) {
        if let trackId = song.qishuiTrackId, trackId > 0 {
            fetchQishuiLyrics(trackId: trackId, songId: song.id, forceReload: forceReload)
            return
        }

        guard let sessionId = beginLyricRequest(songId: song.id, forceReload: forceReload) else { return }
        searchQishuiLyricsByMetadata(for: song, sessionId: sessionId)
    }

    private func fetchKugouLyrics(for song: Song, forceReload: Bool) {
        guard let sessionId = beginLyricRequest(songId: song.id, forceReload: forceReload) else { return }

        guard song.kugouHash?.isEmpty == false else {
            searchKugouLyricsByMetadata(for: song, sessionId: sessionId)
            return
        }

        APIService.shared.fetchKugouLyrics(song: song)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self, self.lyricSessionId == sessionId else { return }
                self.isLoading = false
                if case .failure(let error) = completion {
                    self.hasLyrics = false
                    AppLogger.warning("[Lyrics] KCM 歌词获取失败: \(error.localizedDescription)")
                }
            }, receiveValue: { [weak self] content in
                guard let self, self.lyricSessionId == sessionId else { return }
                self.isLoading = false
                self.applyKugouLyrics(content, songId: song.id)
            })
            .store(in: &cancellables)
    }

    private func searchKugouLyricsByMetadata(for song: Song, sessionId: Int) {
        guard !song.name.isEmpty || !song.artistName.isEmpty else {
            isLoading = false
            currentSongId = nil
            return
        }

        Task { @MainActor [weak self] in
            guard let self, self.lyricSessionId == sessionId else { return }

            let query = "\(song.artistName) \(song.name)"
                .trimmingCharacters(in: .whitespacesAndNewlines)

            do {
                let page = try await APIService.shared.searchKugouSongsWithTotal(
                    keyword: query,
                    page: 1,
                    pageSize: 10
                ).async()
                guard self.lyricSessionId == sessionId else { return }

                if let matchedSong = self.bestMetadataMatch(
                    from: page.songs,
                    title: song.name,
                    artist: song.artistName,
                    durationMs: song.dt
                ) {
                    let content = try await APIService.shared.fetchKugouLyrics(song: matchedSong).async()
                    guard self.lyricSessionId == sessionId else { return }

                    self.isLoading = false
                    self.applyKugouLyrics(content, songId: song.id)
                    if self.hasLyrics {
                        AppLogger.info("[Lyrics] 已从 KCM 搜索结果补全歌词: \(song.name) - \(song.artistName)")
                        return
                    }
                }
            } catch {
                AppLogger.warning("[Lyrics] KCM 搜索补全失败: \(query) - \(error.localizedDescription)")
            }

            self.isLoading = false
            self.currentSongId = nil
        }
    }

    private func applyKugouLyrics(_ content: String, songId: Int) {
        translations = [:]
        parseLyrics(content)
        hasLyrics = !lyrics.isEmpty
        guard hasLyrics else { return }

        activeSource = .kugou
        OptimizedCacheManager.shared.cacheLyrics(
            songId: songId,
            lyrics: content,
            translated: nil
        )
    }

    private func fetchQishuiLyrics(trackId: Int, songId: Int, forceReload: Bool = false) {
        guard let sessionId = beginLyricRequest(songId: songId, forceReload: forceReload) else { return }

        APIService.shared.fetchQishuiLyric(trackId: trackId)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self, self.lyricSessionId == sessionId else { return }
                self.isLoading = false
                if case .failure = completion {
                    AppLogger.warning("[Lyrics] 汽水歌词获取失败")
                }
            }, receiveValue: { [weak self] content in
                guard let self, self.lyricSessionId == sessionId else { return }
                self.isLoading = false
                if !content.isEmpty {
                    self.applyQishuiLyrics(content)
                    AppLogger.info("[Lyrics] 汽水歌词加载成功: \(self.lyrics.count) 行")
                }
            })
            .store(in: &cancellables)
    }

    private func searchQishuiLyricsByMetadata(for song: Song, sessionId: Int) {
        guard !song.name.isEmpty || !song.artistName.isEmpty else {
            isLoading = false
            currentSongId = nil
            return
        }

        Task { @MainActor [weak self] in
            guard let self, self.lyricSessionId == sessionId else { return }

            let query = "\(song.artistName) \(song.name)".trimmingCharacters(in: .whitespacesAndNewlines)

            do {
                let candidates = try await APIService.shared.searchQishuiSongs(keyword: query, page: 0).async()
                guard self.lyricSessionId == sessionId else { return }

                if let matchedSong = self.bestMetadataMatch(
                    from: candidates,
                    title: song.name,
                    artist: song.artistName,
                    durationMs: song.dt
                ), let trackId = matchedSong.qishuiTrackId, trackId > 0 {
                    let content = try await APIService.shared.fetchQishuiLyric(trackId: trackId).async()
                    guard self.lyricSessionId == sessionId else { return }

                    self.applyQishuiLyrics(content)
                    self.isLoading = false
                    if self.hasLyrics {
                        self.activeSource = .qishui
                        AppLogger.info("[Lyrics] 已从 QSM 搜索结果补全歌词: \(song.name) - \(song.artistName)")
                        return
                    }
                }
            } catch {
                AppLogger.warning("[Lyrics] QSM 搜索补全失败: \(query) - \(error.localizedDescription)")
            }

            self.isLoading = false
            self.currentSongId = nil
        }
    }

    private func applyQishuiLyrics(_ content: String) {
        let parsed = parseQishuiLyric(content)
        lyrics = parsed
        hasLyrics = !parsed.isEmpty
    }

    private func parseQishuiLyric(_ raw: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        for lineStr in raw.components(separatedBy: "\n") {
            let trimmed = lineStr.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.hasPrefix("[") else { continue }
            guard let bracketEnd = trimmed.firstIndex(of: "]") else { continue }
            let timeStr = String(trimmed[trimmed.index(after: trimmed.startIndex)..<bracketEnd])
            let parts = timeStr.split(separator: ",")
            guard let startMs = Int(parts.first ?? "") else { continue }
            let time = Double(startMs) / 1000.0
            let afterBracket = String(trimmed[trimmed.index(after: bracketEnd)...])
            let text = afterBracket
                .replacingOccurrences(of: "<[^>]*>", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                lines.append(LyricLine(time: time, text: text, translation: nil))
            }
        }
        return normalizedKaraokeLines(lines)
    }

    func fetchLyrics(for songId: Int) {
        activeSource = .netease
        let song = Song(
            id: songId,
            name: "",
            ar: nil,
            al: nil,
            dt: nil,
            fee: 0,
            mv: 0,
            h: nil,
            m: nil,
            l: nil,
            sq: nil,
            hr: nil,
            alia: nil
        )
        prepareLyricIdentity(for: song)
        fetchNeteaseLyrics(
            for: song,
            fallbackQQMid: nil,
            allowQQFallback: false,
            forceReload: false
        )
    }

    private func fetchNeteaseLyrics(
        for song: Song,
        fallbackQQMid: String?,
        allowQQFallback: Bool,
        forceReload: Bool
    ) {
        let songId = song.id
        guard let sessionId = beginLyricRequest(songId: songId, forceReload: forceReload) else { return }

        // 跨平台歌曲的数值 ID 不属于 NCM，必须先按元数据搜索。
        if song.musicSource != .netease {
            fetchLyricsByMetadataFallback(
                for: song,
                fallbackQQMid: fallbackQQMid,
                sessionId: sessionId,
                allowQQFallback: allowQQFallback
            )
            return
        }
        
        APIService.shared.fetchLyric(id: songId)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self = self, self.lyricSessionId == sessionId else { return }
                if case .failure(let error) = completion {
                    AppLogger.error("Failed to fetch lyrics: \(error)")
                    self.fetchLyricsByMetadataFallback(
                        for: song,
                        fallbackQQMid: fallbackQQMid,
                        sessionId: sessionId,
                        allowQQFallback: allowQQFallback
                    )
                }
            }, receiveValue: { [weak self] response in
                guard let self = self, self.lyricSessionId == sessionId else { return }
                self.applyNeteaseLyrics(response)

                if !self.hasLyrics {
                    self.fetchLyricsByMetadataFallback(
                        for: song,
                        fallbackQQMid: fallbackQQMid,
                        sessionId: sessionId,
                        allowQQFallback: allowQQFallback
                    )
                } else {
                    self.isLoading = false
                }
            })
            .store(in: &cancellables)
    }
    
    /// 获取 qcm歌词
    private func fetchQQLyrics(for song: Song, forceReload: Bool) {
        if let mid = song.qqMid, !mid.isEmpty {
            fetchQQLyrics(mid: mid, songId: song.id, forceReload: forceReload)
            return
        }

        guard let sessionId = beginLyricRequest(songId: song.id, forceReload: forceReload) else { return }
        searchQQLyricsByMetadata(for: song, sessionId: sessionId)
    }

    func fetchQQLyrics(mid: String, songId: Int, forceReload: Bool = false) {
        guard let sessionId = beginLyricRequest(songId: songId, forceReload: forceReload) else { return }
        
        APIService.shared.fetchQQLyric(mid: mid)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self = self, self.lyricSessionId == sessionId else { return }
                if case .failure(let error) = completion {
                    AppLogger.error("[QQMusic] 获取歌词失败: \(error)")
                    self.isLoading = false
                    // 请求失败时清除 currentSongId，允许下次重试
                    self.currentSongId = nil
                }
            }, receiveValue: { [weak self] response in
                guard let self = self, self.lyricSessionId == sessionId else { return }
                self.applyQQLyrics(response)
                self.isLoading = false
            })
            .store(in: &cancellables)
    }

    private func fetchQQLyricsFallback(
        mid: String,
        songId: Int,
        sessionId: Int,
        qishuiFallbackSong: Song? = nil
    ) {
        translations = [:]
        lyrics = []
        hasLyrics = false
        currentLineIndex = 0
        currentLineProgress = 0.0

        APIService.shared.fetchQQLyric(mid: mid)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self = self, self.lyricSessionId == sessionId else { return }
                if case .failure(let error) = completion {
                    AppLogger.warning("[Lyrics] NCM 歌词缺失，QCM 回退也失败: \(error)")
                    if let qishuiFallbackSong {
                        self.searchQishuiLyricsByMetadata(
                            for: qishuiFallbackSong,
                            sessionId: sessionId
                        )
                        return
                    }
                    self.isLoading = false
                    self.currentSongId = nil
                }
            }, receiveValue: { [weak self] response in
                guard let self = self, self.lyricSessionId == sessionId else { return }
                self.applyQQLyrics(response)
                if self.hasLyrics {
                    self.activeSource = .qqmusic
                    self.isLoading = false
                    AppLogger.info("[Lyrics] 已从 QCM 回退补全歌词: \(songId)")
                } else if let qishuiFallbackSong {
                    self.searchQishuiLyricsByMetadata(
                        for: qishuiFallbackSong,
                        sessionId: sessionId
                    )
                } else {
                    self.isLoading = false
                }
            })
            .store(in: &cancellables)
    }

    private func fetchLyricsByMetadataFallback(
        for song: Song,
        fallbackQQMid: String?,
        sessionId: Int,
        allowQQFallback: Bool
    ) {
        guard !song.name.isEmpty || !song.artistName.isEmpty else {
            finishNeteaseFallback(
                allowQQFallback: allowQQFallback,
                fallbackQQMid: fallbackQQMid,
                song: song,
                sessionId: sessionId
            )
            return
        }

        Task { @MainActor [weak self] in
            guard let self, self.lyricSessionId == sessionId else { return }

            let query = "\(song.artistName) \(song.name)".trimmingCharacters(in: .whitespacesAndNewlines)

            do {
                let candidates = try await APIService.shared.searchSongs(keyword: query, offset: 0).async()
                guard self.lyricSessionId == sessionId else { return }

                if let matchedSong = self.bestMetadataMatch(from: candidates, title: song.name, artist: song.artistName, durationMs: song.dt),
                   matchedSong.id != song.id || song.musicSource != .netease {
                    let response = try await APIService.shared.fetchLyric(id: matchedSong.id).async()
                    guard self.lyricSessionId == sessionId else { return }

                    self.applyNeteaseLyrics(response)
                    if self.hasLyrics {
                        let neteaseCandidate = self.captureLyricCandidate(
                            source: .netease,
                            hasPlatformWordTiming: self.hasNonEmptyText(response.yrc?.lyric),
                            hasTranslation: self.hasNonEmptyText(response.tlyric?.lyric)
                        )

                        // Apple Music 的公开 API 只暴露 hasLyrics，未开放歌词正文、
                        // 翻译或逐字时间轴。跨平台匹配时不能在首份普通 LRC
                        // 命中后就停止；继续比较 QCM 官方歌词，优先保留翻译和
                        // 平台逐字时间更完整的候选。
                        if song.isAppleMusic,
                           let neteaseCandidate,
                           neteaseCandidate.qualityScore < 7 {
                            let qqCandidate = await self.qqLyricCandidateByMetadata(
                                for: song,
                                sessionId: sessionId
                            )
                            guard self.lyricSessionId == sessionId else { return }

                            if let qqCandidate,
                               qqCandidate.qualityScore > neteaseCandidate.qualityScore {
                                self.applyLyricCandidate(qqCandidate)
                                AppLogger.info(
                                    "[Lyrics] AM 匹配到更完整的 QCM 官方歌词（翻译/逐字）: \(song.name) - \(song.artistName)"
                                )
                            } else {
                                self.applyLyricCandidate(neteaseCandidate)
                            }
                        }

                        self.isLoading = false
                        if song.isAppleMusic {
                            AppLogger.info(
                                "[Lyrics] 已为 AM 补全歌词，采用 \(self.activeSource?.shortName ?? "NCM"): \(song.name) - \(song.artistName)"
                            )
                        } else {
                            AppLogger.info(
                                "[Lyrics] 已从 NCM 搜索结果补全歌词: \(song.name) - \(song.artistName)"
                            )
                        }
                        return
                    }
                }
            } catch {
                AppLogger.warning("[Lyrics] NCM 搜索补全失败: \(query) - \(error.localizedDescription)")
            }

            self.finishNeteaseFallback(
                allowQQFallback: allowQQFallback,
                fallbackQQMid: fallbackQQMid,
                song: song,
                sessionId: sessionId
            )
        }
    }

    private func qqLyricCandidateByMetadata(
        for song: Song,
        sessionId: Int
    ) async -> ParsedLyricCandidate? {
        let query = "\(song.artistName) \(song.name)"
            .trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let candidates = try await APIService.shared.searchQQSongs(
                keyword: query,
                page: 1,
                num: 10
            ).async()
            guard lyricSessionId == sessionId,
                  let matchedSong = bestMetadataMatch(
                      from: candidates,
                      title: song.name,
                      artist: song.artistName,
                      durationMs: song.dt
                  ),
                  let qqMid = matchedSong.qqMid,
                  !qqMid.isEmpty else {
                return nil
            }

            let response = try await APIService.shared.fetchQQLyric(mid: qqMid).async()
            guard lyricSessionId == sessionId else { return nil }

            applyQQLyrics(response)
            return captureLyricCandidate(
                source: .qqmusic,
                hasPlatformWordTiming: hasNonEmptyText(response.qrc)
                    || isQRCFormatted(response.lyric),
                hasTranslation: hasNonEmptyText(response.trans)
            )
        } catch {
            AppLogger.warning(
                "[Lyrics] AM 的 QCM 完整歌词比较失败: \(query) - \(error.localizedDescription)"
            )
            return nil
        }
    }

    private func captureLyricCandidate(
        source: LyricSource,
        hasPlatformWordTiming: Bool,
        hasTranslation: Bool
    ) -> ParsedLyricCandidate? {
        guard hasLyrics, !lyrics.isEmpty else { return nil }
        return ParsedLyricCandidate(
            source: source,
            lines: lyrics,
            hasPlatformWordTiming: hasPlatformWordTiming,
            hasTranslation: hasTranslation && lyrics.contains {
                !($0.translation ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty
            }
        )
    }

    private func applyLyricCandidate(_ candidate: ParsedLyricCandidate) {
        translations = [:]
        lyrics = candidate.lines
        hasLyrics = !candidate.lines.isEmpty
        activeSource = candidate.source
        currentLineIndex = 0
        currentLineProgress = 0
    }

    private func hasNonEmptyText(_ value: String?) -> Bool {
        guard let value else { return false }
        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func isQRCFormatted(_ value: String?) -> Bool {
        guard let value, hasNonEmptyText(value) else { return false }
        return value.contains("<QrcInfos>")
            || value.hasPrefix("<?xml")
            || (value.first == "[" && value.contains("(") && value.contains(")"))
    }

    private func finishNeteaseFallback(
        allowQQFallback: Bool,
        fallbackQQMid: String?,
        song: Song,
        sessionId: Int
    ) {
        guard lyricSessionId == sessionId else { return }
        if allowQQFallback {
            fallbackToQQIfNeeded(mid: fallbackQQMid, song: song, sessionId: sessionId)
        } else {
            isLoading = false
            currentSongId = nil
        }
    }

    private func fallbackToQQIfNeeded(mid: String?, song: Song, sessionId: Int) {
        if let mid, !mid.isEmpty {
            fetchQQLyricsFallback(mid: mid, songId: song.id, sessionId: sessionId)
        } else {
            searchQQLyricsByMetadata(
                for: song,
                sessionId: sessionId,
                fallbackToQishui: song.isAppleMusic
            )
        }
    }

    private func searchQQLyricsByMetadata(
        for song: Song,
        sessionId: Int,
        fallbackToQishui: Bool = false
    ) {
        guard !song.name.isEmpty || !song.artistName.isEmpty else {
            isLoading = false
            currentSongId = nil
            return
        }

        Task { @MainActor [weak self] in
            guard let self, self.lyricSessionId == sessionId else { return }

            let query = "\(song.artistName) \(song.name)".trimmingCharacters(in: .whitespacesAndNewlines)

            do {
                let candidates = try await APIService.shared.searchQQSongs(keyword: query, page: 1, num: 10).async()
                guard self.lyricSessionId == sessionId else { return }

                if let matchedSong = self.bestMetadataMatch(from: candidates, title: song.name, artist: song.artistName, durationMs: song.dt),
                   let qqMid = matchedSong.qqMid,
                   !qqMid.isEmpty {
                    AppLogger.info("[Lyrics] 已从 QCM 搜索结果补全歌词入口: \(song.name) - \(song.artistName)")
                    self.fetchQQLyricsFallback(
                        mid: qqMid,
                        songId: song.id,
                        sessionId: sessionId,
                        qishuiFallbackSong: fallbackToQishui ? song : nil
                    )
                    return
                }
            } catch {
                AppLogger.warning("[Lyrics] QCM 搜索补全失败: \(query) - \(error.localizedDescription)")
            }

            if fallbackToQishui {
                self.searchQishuiLyricsByMetadata(for: song, sessionId: sessionId)
                return
            }
            self.isLoading = false
            self.currentSongId = nil
        }
    }

    private func applyNeteaseLyrics(_ response: LyricResponse) {
        translations = [:]

        if let tlyric = response.tlyric?.lyric {
            parseTranslations(tlyric)
        }

        if let yrc = response.yrc?.lyric {
            parseYRC(yrc)
            hasLyrics = !lyrics.isEmpty
        } else if let lrc = response.lrc?.lyric {
            parseLyrics(lrc)
            hasLyrics = !lyrics.isEmpty
        } else {
            hasLyrics = false
        }
    }

    private func bestMetadataMatch(from songs: [Song], title: String, artist: String, durationMs: Int?) -> Song? {
        let normalizedTitle = normalizeMatchText(title)
        let normalizedArtist = normalizeMatchText(effectiveArtistName(artist))
        let hasKnownArtist = !normalizedArtist.isEmpty

        var bestMatch: Song?
        var bestScore = 0.0

        for song in songs {
            let titleScore = similarityScore(normalizedTitle, normalizeMatchText(song.name))
            guard titleScore >= 0.72 else { continue }

            let artistScore = hasKnownArtist ? similarityScore(normalizedArtist, normalizeMatchText(song.artistName)) : 1.0
            if hasKnownArtist, artistScore < 0.42 { continue }

            let exactDurationScore = durationMatchScore(localDurationMs: durationMs, remoteDurationMs: song.dt)
            if let exactDurationScore, exactDurationScore < 0.35 { continue }
            if !hasKnownArtist, exactDurationScore == nil, titleScore < 0.96 { continue }

            let durationScore = exactDurationScore ?? (hasKnownArtist ? 0.72 : 0.0)
            let totalScore = hasKnownArtist
                ? titleScore * 0.58 + artistScore * 0.27 + durationScore * 0.15
                : titleScore * 0.70 + durationScore * 0.30

            if totalScore > bestScore {
                bestScore = totalScore
                bestMatch = song
            }
        }

        return bestScore >= (hasKnownArtist ? 0.78 : 0.88) ? bestMatch : nil
    }

    private func effectiveArtistName(_ artist: String) -> String {
        let trimmed = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.localizedCaseInsensitiveCompare("Unknown Artist") == .orderedSame ? "" : trimmed
    }

    private func durationMatchScore(localDurationMs: Int?, remoteDurationMs: Int?) -> Double? {
        guard let localDurationMs,
              let remoteDurationMs,
              localDurationMs > 0,
              remoteDurationMs > 0 else {
            return nil
        }

        let diff = abs(Double(localDurationMs - remoteDurationMs)) / 1000.0
        switch diff {
        case 0...3:
            return 1.0
        case 3...8:
            return 0.88
        case 8...15:
            return 0.68
        case 15...30:
            return 0.42
        default:
            return 0.0
        }
    }

    private func normalizeMatchText(_ text: String) -> String {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.union(.init(charactersIn: "\u{4E00}"..."\u{9FFF}")).inverted)
            .joined()
    }

    private func similarityScore(_ lhs: String, _ rhs: String) -> Double {
        guard !lhs.isEmpty && !rhs.isEmpty else { return lhs == rhs ? 1.0 : 0.0 }
        if lhs.contains(rhs) || rhs.contains(lhs) {
            return max(Double(min(lhs.count, rhs.count)) / Double(max(lhs.count, rhs.count)), 0.8)
        }

        let lhsChars = Array(lhs)
        let rhsChars = Array(rhs)
        let m = lhsChars.count
        let n = rhsChars.count

        if Double(min(m, n)) / Double(max(m, n)) < 0.3 {
            return 0.2
        }

        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        for i in 1...m {
            for j in 1...n {
                dp[i][j] = lhsChars[i - 1] == rhsChars[j - 1]
                    ? dp[i - 1][j - 1] + 1
                    : max(dp[i - 1][j], dp[i][j - 1])
            }
        }

        return Double(dp[m][n] * 2) / Double(m + n)
    }

    private func applyQQLyrics(_ response: QQLyricResponse) {
        translations = [:]

        if let trans = response.trans {
            parseTranslations(trans)
        }
        
        // 如果常规翻译解析后依然为空（例如此时 trans 是不支持时间戳映射的 [kana:...] 格式）
        // 则尝试解析 roma（罗马音 XML 格式）作为兜底翻译显示。
        if translations.isEmpty, let roma = response.roma {
            if roma.contains("<QrcInfos>") || roma.hasPrefix("<?xml") {
                parseRomajiXMLToTranslations(roma)
            } else {
                parseTranslations(roma)
            }
        }

        if let qrc = response.qrc, !qrc.isEmpty {
            parseQRC(qrc)
            hasLyrics = !lyrics.isEmpty
        } else if let lrc = response.lyric, !lrc.isEmpty {
            if lrc.contains("<QrcInfos>") || lrc.hasPrefix("<?xml") {
                parseQRC(lrc)
            } else if lrc.contains("(") && lrc.contains(")") && lrc.first == "[" {
                parseQRC(lrc)
            } else {
                parseLyrics(lrc)
            }
            hasLyrics = !lyrics.isEmpty
        } else {
            hasLyrics = false
        }
    }
    
    private func translationKey(_ time: TimeInterval) -> TimeInterval {
        (time * 100).rounded() / 100
    }

    private func parseTranslations(_ text: String) {
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let (time, content) = parseLine(line)
            if let time = time, !content.isEmpty {
                translations[translationKey(time)] = content
            }
        }
    }
    
    // 应用翻译到已经解析好的歌词行中
    private func applyTranslationsToLines(_ lines: inout [LyricLine]) {
        guard !translations.isEmpty else { return }
        
        let sortedTrans = translations.map { (time: $0.key, text: $0.value) }.sorted { $0.time < $1.time }
        
        // 匹配策略 1：如果数量完全相等，说明是非常规整的双语结构（常见于网易云 LRC 与 Tlyric）
        if lines.count == sortedTrans.count {
            for i in 0..<lines.count {
                lines[i].translation = sortedTrans[i].text
            }
            return
        }
        
        // 匹配策略 2：通过绝对时间差最接近来寻找翻译（最大允许误差 2.0 秒，用来兼容 YRC 与普通 LRC 翻译打轴的微量偏移）
        for i in 0..<lines.count {
            let lineTime = lines[i].time
            var bestTranslation: String? = nil
            var smallestDiff: TimeInterval = 2.0
            
            for trans in sortedTrans {
                let diff = abs(trans.time - lineTime)
                if diff <= smallestDiff {
                    smallestDiff = diff
                    bestTranslation = trans.text
                } else if trans.time > lineTime + smallestDiff {
                    // 因为 sortedTrans 是按时间顺序排列的，如果已经偏大很多就不需要继续找了
                    break
                }
            }
            
            if let bestTranslation {
                lines[i].translation = bestTranslation
            }
        }
    }
    
    // 解析 QQ 音乐的 XML roma 罗马音字段，并将其映射为翻译字段
    private func parseRomajiXMLToTranslations(_ xmlText: String) {
        let pattern = "LyricContent=\"([^\"]+)\""
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
        
        let matches = regex.matches(in: xmlText, options: [], range: NSRange(location: 0, length: xmlText.utf16.count))
        for match in matches {
            guard let range = Range(match.range(at: 1), in: xmlText) else { continue }
            let rawQrcContent = String(xmlText[range])
            let qrcContent = rawQrcContent.replacingOccurrences(of: "&#10;", with: "\n")
                .replacingOccurrences(of: "&apos;", with: "'")
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
            
            let lines = qrcContent.components(separatedBy: .newlines)
            for line in lines {
                guard let closeBracket = line.firstIndex(of: "]"), line.hasPrefix("[") else { continue }
                
                let timePart = line[line.index(after: line.startIndex)..<closeBracket]
                let contentPart = String(line[line.index(after: closeBracket)...])
                
                let times = timePart.components(separatedBy: ",")
                guard times.count >= 2, let startMs = Double(times[0]) else { continue }
                
                let startTime = startMs / 1000.0
                
                var plainText = ""
                var remaining = contentPart
                while !remaining.isEmpty {
                    guard let parenStart = remaining.firstIndex(of: "(") else {
                        plainText += remaining
                        break
                    }
                    let wText = String(remaining[remaining.startIndex..<parenStart])
                    remaining = String(remaining[remaining.index(after: parenStart)...])
                    
                    guard let parenEnd = remaining.firstIndex(of: ")") else { break }
                    remaining = String(remaining[remaining.index(after: parenEnd)...])
                    
                    if !wText.isEmpty {
                        plainText += wText
                    }
                }
                
                if plainText.isEmpty {
                    plainText = contentPart
                }
                
                translations[translationKey(startTime)] = plainText
            }
        }
    }
    
    private func parseYRC(_ text: String) {
        var parsedLines: [LyricLine] = []
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            guard let closeBracket = line.firstIndex(of: "]"),
                  line.hasPrefix("[") else { continue }
            
            let timePart = line[line.index(after: line.startIndex)..<closeBracket]
            let contentPart = line[line.index(after: closeBracket)...]
            
            let times = timePart.components(separatedBy: ",")
            guard times.count >= 2,
                  let startMs = Double(times[0]),
                  let durationMs = Double(times[1]) else { continue }
            
            let startTime = startMs / 1000.0
            let duration = durationMs / 1000.0
            
            var words: [LyricWord] = []
            var plainText = ""
            
            let scanner = Scanner(string: String(contentPart))
            scanner.charactersToBeSkipped = nil
            
            while !scanner.isAtEnd {
                if scanner.scanString("(") != nil {
                    guard let wStartMs = scanner.scanDouble(),
                          let _ = scanner.scanString(","),
                          let wDurMs = scanner.scanDouble(),
                          let _ = scanner.scanString(","),
                          let _ = scanner.scanInt(), // type
                          let _ = scanner.scanString(")") else {
                        break
                    }
                    
                    var wText = ""
                    if let text = scanner.scanUpToString("(") {
                        wText = text
                    } else {
                         wText = String(contentPart.suffix(from: contentPart.index(contentPart.startIndex, offsetBy: scanner.currentIndex.utf16Offset(in: contentPart))))
                    }
                    
                    if wText.isEmpty && !scanner.isAtEnd {
                        if let char = scanner.scanCharacter() {
                            wText = String(char)
                             if let rest = scanner.scanUpToString("(") {
                                 wText += rest
                             }
                        }
                    }

                    
                    let word = LyricWord(text: wText, startTime: wStartMs / 1000.0, duration: wDurMs / 1000.0)
                    words.append(word)
                    plainText += wText
                } else {
                     _ = scanner.scanCharacter()
                }
            }
            
            if words.isEmpty {
                plainText = String(contentPart)
            }
            
            parsedLines.append(LyricLine(time: startTime, text: plainText, translation: nil, duration: duration, words: words))
        }
        
        applyTranslationsToLines(&parsedLines)
        self.lyrics = normalizedKaraokeLines(parsedLines)
    }
    
    /// 解析 qcm QRC 逐字歌词
    /// 格式: [startMs,durationMs]字(startMs,duration)字(startMs,duration)...
    private func parseQRC(_ text: String) {
        var parsedLines: [LyricLine] = []
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            guard let closeBracket = line.firstIndex(of: "]"),
                  line.hasPrefix("[") else { continue }
            
            let timePart = line[line.index(after: line.startIndex)..<closeBracket]
            let contentPart = String(line[line.index(after: closeBracket)...])
            
            let times = timePart.components(separatedBy: ",")
            guard times.count >= 2,
                  let startMs = Double(times[0]),
                  let durationMs = Double(times[1]) else { continue }
            
            let startTime = startMs / 1000.0
            let duration = durationMs / 1000.0
            
            var words: [LyricWord] = []
            var plainText = ""
            
            // QRC: 字(startMs,duration)字(startMs,duration)
            var remaining = contentPart
            while !remaining.isEmpty {
                // 找下一个 "("
                guard let parenStart = remaining.firstIndex(of: "(") else {
                    plainText += remaining
                    break
                }
                
                // "(" 前面的是字
                let wText = String(remaining[remaining.startIndex..<parenStart])
                remaining = String(remaining[remaining.index(after: parenStart)...])
                
                // 解析 (startMs,duration)
                guard let parenEnd = remaining.firstIndex(of: ")") else { break }
                let paramStr = String(remaining[remaining.startIndex..<parenEnd])
                remaining = String(remaining[remaining.index(after: parenEnd)...])
                
                let params = paramStr.components(separatedBy: ",")
                guard params.count >= 2,
                      let wStartMs = Double(params[0]),
                      let wDurMs = Double(params[1]) else { continue }
                
                if !wText.isEmpty {
                    let word = LyricWord(text: wText, startTime: wStartMs / 1000.0, duration: wDurMs / 1000.0)
                    words.append(word)
                    plainText += wText
                }
            }
            
            if words.isEmpty {
                plainText = contentPart
            }
            
            parsedLines.append(LyricLine(time: startTime, text: plainText, translation: nil, duration: duration, words: words))
        }
        
        applyTranslationsToLines(&parsedLines)
        self.lyrics = normalizedKaraokeLines(parsedLines)
    }
    
    private func parseLyrics(_ text: String) {
        var parsedLines: [LyricLine] = []
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            let (time, content) = parseLine(line)
            if let time = time {
                parsedLines.append(LyricLine(time: time, text: content, translation: nil))
            }
        }
        
        applyTranslationsToLines(&parsedLines)
        parsedLines.sort { $0.time < $1.time }
        
        for i in 0..<parsedLines.count {
            if i < parsedLines.count - 1 {
                parsedLines[i].duration = parsedLines[i+1].time - parsedLines[i].time
            } else {
                parsedLines[i].duration = 5.0
            }
        }
        
        self.lyrics = normalizedKaraokeLines(parsedLines)
    }

    /// 把所有歌词来源统一成可逐字渲染的时间轴。平台提供 YRC/QRC 时保留
    /// 精确字轴；只有普通 LRC 时按当前行持续时间生成稳定的逐字回退。
    private func normalizedKaraokeLines(_ source: [LyricLine]) -> [LyricLine] {
        var lines = source.sorted { $0.time < $1.time }
        guard !lines.isEmpty else { return [] }

        for index in lines.indices {
            if !lines[index].duration.isFinite || lines[index].duration <= 0 {
                if index + 1 < lines.count {
                    lines[index].duration = max(lines[index + 1].time - lines[index].time, 0.5)
                } else {
                    lines[index].duration = min(
                        max(Double(lines[index].text.count) * 0.16, 1.8),
                        8
                    )
                }
            }
            lines[index].words = LyricKaraokeTimeline.resolvedWords(for: lines[index])
        }
        return lines
    }
    
    private func parseLine(_ line: String) -> (TimeInterval?, String) {
        guard let bracketCloseIndex = line.firstIndex(of: "]") else { return (nil, line) }
        
        let timeString = String(line[line.index(after: line.startIndex)..<bracketCloseIndex])
        let content = String(line[line.index(after: bracketCloseIndex)...]).trimmingCharacters(in: .whitespaces)
        
        let timeParts = timeString.components(separatedBy: ":")
        guard timeParts.count >= 2,
              let min = Double(timeParts[0]),
              let sec = Double(timeParts[1]) else {
            return (nil, content)
        }
        
        let totalTime = min * 60 + sec
        return (totalTime, content)
    }
    
    func updateCurrentTime(_ time: TimeInterval) {
        guard !lyrics.isEmpty else { return }

        if let index = lyrics.lastIndex(where: { $0.time <= time }) {
            if index != currentLineIndex {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentLineIndex = index
                }
            }

            let line = lyrics[index]
            let elapsed = time - line.time
            let newProgress = line.duration > 0
                ? min(max(elapsed / line.duration, 0.0), 1.0)
                : 0.0
            if abs(newProgress - currentLineProgress) > 0.02 {
                currentLineProgress = newProgress
            }

        } else {
            if currentLineIndex != 0 || currentLineProgress != 0.0 {
                currentLineIndex = 0
                currentLineProgress = 0.0
            }
        }
    }

    func clearLyrics() {
        lyrics = []
        hasLyrics = false
        currentLineIndex = 0
        currentLineProgress = 0.0
        translations = [:]
        currentSongId = nil
        currentSongIdentity = nil
        isLoading = false
        activeSource = nil
        currentSongSourceOverride = nil
    }
}

// MARK: - Karaoke Components

struct KaraokeWordView: View {
    let word: LyricWord
    let progress: CGFloat
    var font: Font = .rounded(size: 26, weight: .bold)
    var activeColor: Color = .monoTextPrimary
    var inactiveColor: Color = .gray.opacity(0.3)
    var activeGradient: LinearGradient? = nil
    var style: KaraokeWordStyle = .flow
    
    var body: some View {
        KaraokeStyledWordView(
            text: word.text,
            progress: progress,
            font: font,
            style: style,
            inactiveColor: inactiveColor,
            activeColor: activeColor,
            activeGradient: activeGradient
        )
    }
    
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    /// 行内对齐：默认靠左（标签云等场景）；歌词逐字用 .center，
    /// 长句换行后每行都居中，而不是整块居中、行内靠左
    var rowAlignment: HorizontalAlignment = .leading
    /// Stable token for rapidly animated content whose intrinsic sizes do not
    /// change between frames. Other FlowLayout call sites keep the default and
    /// retain SwiftUI's normal cache invalidation semantics.
    var measurementToken: Int? = nil
    
    struct Cache {
        var sizes: [CGSize] = []
        var proposedWidth: CGFloat?
        var rows: [Row] = []
        var measurementToken: Int?
    }

    func makeCache(subviews: Subviews) -> Cache {
        Cache(
            sizes: subviews.map { $0.sizeThatFits(.unspecified) },
            measurementToken: measurementToken
        )
    }

    func updateCache(_ cache: inout Cache, subviews: Subviews) {
        if let measurementToken,
           cache.measurementToken == measurementToken,
           cache.sizes.count == subviews.count {
            return
        }
        cache.sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        cache.proposedWidth = nil
        cache.rows.removeAll(keepingCapacity: true)
        cache.measurementToken = measurementToken
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        let rows = cachedRows(proposal: proposal, subviews: subviews, cache: &cache)
        let maxWidth = rows.map(\.maxX).max() ?? 0
        let totalHeight = rows.last.map { $0.y + $0.height } ?? 0
        return CGSize(width: maxWidth, height: totalHeight)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        // SwiftUI may omit the width in the placement proposal even though it
        // supplied one during measurement. Reuse the measured wrapping width
        // instead of measuring every word for a second time on every lyric tick.
        let placementProposal = ProposedViewSize(
            width: proposal.width ?? cache.proposedWidth ?? bounds.width,
            height: proposal.height
        )
        let rows = cachedRows(proposal: placementProposal, subviews: subviews, cache: &cache)
        for row in rows {
            let leftover = max(0, bounds.width - row.maxX)
            let rowOffset: CGFloat
            switch rowAlignment {
            case .center: rowOffset = leftover / 2
            case .trailing: rowOffset = leftover
            default: rowOffset = 0
            }
            for item in row.items {
                guard subviews.indices.contains(item.index) else { continue }
                subviews[item.index].place(
                    at: CGPoint(x: bounds.minX + rowOffset + item.x, y: bounds.minY + row.y),
                    proposal: ProposedViewSize(cache.sizes[item.index])
                )
            }
        }
    }
    
    struct Row {
        var y: CGFloat
        var height: CGFloat
        var items: [Item]
        var maxX: CGFloat = 0
    }
    
    struct Item {
        var index: Int
        var x: CGFloat
    }

    private func cachedRows(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) -> [Row] {
        let proposedWidth = proposal.width
        if cache.sizes.count != subviews.count {
            cache.sizes = subviews.map { $0.sizeThatFits(.unspecified) }
            cache.proposedWidth = nil
        }

        if cache.rows.isEmpty || cache.proposedWidth != proposedWidth {
            cache.rows = arrangeSubviews(proposal: proposal, sizes: cache.sizes)
            cache.proposedWidth = proposedWidth
        }
        return cache.rows
    }
    
    private func arrangeSubviews(proposal: ProposedViewSize, sizes: [CGSize]) -> [Row] {
        var rows: [Row] = []
        var currentRowY: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var currentX: CGFloat = 0
        var currentItems: [Item] = []
        
        let maxWidth = proposal.width ?? .infinity
        
        for (index, viewSize) in sizes.enumerated() {
            
            if currentX + viewSize.width > maxWidth && !currentItems.isEmpty {
                rows.append(Row(y: currentRowY, height: currentRowHeight, items: currentItems, maxX: currentX - spacing))
                currentRowY += currentRowHeight + spacing
                currentX = 0
                currentRowHeight = 0
                currentItems = []
            }
            
            currentItems.append(Item(index: index, x: currentX))
            currentX += viewSize.width + spacing
            currentRowHeight = max(currentRowHeight, viewSize.height)
        }
        
        if !currentItems.isEmpty {
            rows.append(Row(y: currentRowY, height: currentRowHeight, items: currentItems, maxX: currentX - spacing))
        }
        
        return rows
    }
}

struct KaraokeLineView: View {
    let line: LyricLine
    let isCurrent: Bool
    let currentTime: TimeInterval
    let progress: Double
    let showTranslation: Bool
    let enableKaraoke: Bool
    var lyricColorMode: String = "default"
    var lyricSolidColorHex: String = "007AFF"
    var lyricGradientStartHex: String = "FF6B6B"
    var lyricGradientEndHex: String = "4ECDC4"
    var lyricAutoPalette: [Color] = []
    var forceUppercaseEnglish = false
    var playerFontSelectionRaw = MonoPlayerFont.followThemeRawValue
    var playerCustomFontID = ""
    var playerFontScale = 1.0
    var karaokeStyle: KaraokeWordStyle = .flow
    var adaptivePrimaryColor: Color? = nil
    var adaptiveSecondaryColor: Color? = nil
    var enforcesAdaptiveContrast = false
    
    @Environment(\.colorScheme) private var colorScheme
    
    // 大字报主题判断
    private var isPoster: Bool {
        PlayerThemeManager.shared.currentTheme == .poster
    }
    
    // 水韵主题判断
    private var isAqua: Bool {
        PlayerThemeManager.shared.currentTheme == .aqua
    }

    // 打字机主题判断
    private var isTypewriter: Bool {
        PlayerThemeManager.shared.currentTheme == .typewriter
    }
    
    // 字魂半天云魅黑手书字体
    private let posterFont = "zihunbantianyunmeiheishoushu"
    
    // 文道泡泡体（水韵主题）
    private let aquaFont = "WDPPT"

    private var displayText: String {
        forceUppercaseEnglish
            ? line.text.monoUppercasingEnglish()
            : line.text
    }

    private var displayTranslation: String? {
        guard let translation = line.translation else { return nil }
        return forceUppercaseEnglish
            ? translation.monoUppercasingEnglish()
            : translation
    }
    
    // 当前行字体
    private var currentLineFont: Font {
        let size: CGFloat
        let fallback: Font
        if isPoster {
            size = 28 * CGFloat(playerFontScale)
            fallback = .custom(posterFont, size: size)
        } else if isAqua {
            size = 26 * CGFloat(playerFontScale)
            fallback = .custom(aquaFont, size: size)
        } else if isTypewriter {
            size = 24 * CGFloat(playerFontScale)
            fallback = .system(size: size, weight: .semibold, design: .monospaced)
        } else {
            size = 26 * CGFloat(playerFontScale)
            fallback = .rounded(size: size, weight: .bold)
        }
        return MonoPlayerFont.font(
            selectionRaw: playerFontSelectionRaw,
            customFontID: playerCustomFontID,
            size: size,
            weight: .bold,
            fallback: fallback
        )
    }
    
    // 非当前行字体
    private var normalLineFont: Font {
        let size: CGFloat
        let fallback: Font
        if isPoster {
            size = 16 * CGFloat(playerFontScale)
            fallback = .custom(posterFont, size: size)
        } else if isAqua {
            size = 16 * CGFloat(playerFontScale)
            fallback = .custom(aquaFont, size: size)
        } else if isTypewriter {
            size = 15 * CGFloat(playerFontScale)
            fallback = .system(size: size, weight: .medium, design: .monospaced)
        } else {
            size = 16 * CGFloat(playerFontScale)
            fallback = .rounded(size: size, weight: .medium)
        }
        return MonoPlayerFont.font(
            selectionRaw: playerFontSelectionRaw,
            customFontID: playerCustomFontID,
            size: size,
            weight: .medium,
            fallback: fallback
        )
    }
    
    // 翻译字体
    private func translationFont(isCurrent: Bool) -> Font {
        let size: CGFloat
        let fallback: Font
        if isPoster {
            size = (isCurrent ? 16 : 12) * CGFloat(playerFontScale)
            fallback = .custom(posterFont, size: size)
        } else if isAqua {
            size = (isCurrent ? 15 : 13) * CGFloat(playerFontScale)
            fallback = .custom(aquaFont, size: size)
        } else if isTypewriter {
            size = (isCurrent ? 14 : 12) * CGFloat(playerFontScale)
            fallback = .system(size: size, weight: .regular, design: .monospaced)
        } else {
            size = (isCurrent ? 15 : 13) * CGFloat(playerFontScale)
            fallback = .rounded(size: size, weight: .regular)
        }
        return MonoPlayerFont.font(
            selectionRaw: playerFontSelectionRaw,
            customFontID: playerCustomFontID,
            size: size,
            weight: .regular,
            fallback: fallback
        )
    }
    
    // MARK: - 自定义歌词颜色（仅默认主题）
    
    private var customActiveColor: Color {
        if enforcesAdaptiveContrast, let adaptivePrimaryColor {
            return adaptivePrimaryColor
        }
        guard lyricColorMode != "default" else {
            return adaptivePrimaryColor ?? .monoTextPrimary
        }
        if lyricColorMode == "auto" {
            return lyricAutoPalette.first ?? .monoTextPrimary
        }
        if lyricColorMode == "solid" {
            return Color(hex: lyricSolidColorHex)
        }
        return Color(hex: lyricGradientStartHex)
    }
    
    private var customActiveGradient: LinearGradient? {
        if enforcesAdaptiveContrast { return nil }
        if lyricColorMode == "auto", lyricAutoPalette.count > 1 {
            return LinearGradient(
                colors: Array(lyricAutoPalette.prefix(6)),
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        guard lyricColorMode == "gradient" else { return nil }
        return LinearGradient(
            colors: [Color(hex: lyricGradientStartHex), Color(hex: lyricGradientEndHex)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    var body: some View {
        VStack(spacing: isPoster ? 4 : (isTypewriter ? 5 : 6)) {
            if isPoster {
                // 大字报歌词 — 黑条从左滑入
                posterLyricContent
            } else {
                // 默认歌词样式
                defaultLyricContent
            }
            
            // 翻译
            if showTranslation, let trans = displayTranslation, !trans.isEmpty {
                if isPoster {
                    let transColor: Color = isCurrent
                        ? (colorScheme == .dark ? .black.opacity(0.7) : .white.opacity(0.7))
                        : .monoTextPrimary.opacity(0.12)
                    Text(trans)
                        .font(translationFont(isCurrent: isCurrent))
                        .foregroundColor(transColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, isCurrent ? 12 : 0)
                        .padding(.vertical, isCurrent ? 6 : 0)
                        .background(isCurrent ? Color(hex: "FF0000").opacity(0.8) : .clear)
                } else {
                    Text(trans)
                        .font(translationFont(isCurrent: isCurrent))
                        .foregroundColor(
                            isCurrent
                                ? (adaptivePrimaryColor ?? .monoTextPrimary).opacity(0.82)
                                : (adaptiveSecondaryColor ?? .gray.opacity(0.5))
                        )
                        .multilineTextAlignment(.center)
                        .blur(radius: isCurrent ? 0 : 0.3)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isCurrent)
                        .transition(.opacity)
                }
            }
        }
    }
    
    // MARK: - 大字报歌词样式
    @ViewBuilder
    private var posterLyricContent: some View {
        if isCurrent && !displayText.trimmingCharacters(in: .whitespaces).isEmpty {
            // 当前行 — 黑条贴左边缘，和屏幕左边连成一体，支持自动换行
            HStack(spacing: 0) {
                currentPosterLine
                    .padding(.leading, 32)
                    .padding(.trailing, 16)
                    .padding(.vertical, 12)
                    .background(Color.monoTextPrimary)
                
                Spacer(minLength: 0)
            }
            .padding(.leading, -32)
            .transition(.asymmetric(
                insertion: .move(edge: .leading),
                removal: .opacity
            ))
            .id("poster_\(line.time)")
        } else {
            // 非当前行
            Text(displayText)
                .font(normalLineFont)
                .foregroundColor(.monoTextPrimary.opacity(0.15))
                .tracking(1)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    /// 大字报当前行内容 — 使用字魂字体，支持自动换行
    @ViewBuilder
    private var currentPosterLine: some View {
        // 大字报当前行：背景是 fg（深色=白，浅色=黑），文字需要反色
        let invertedFg: Color = colorScheme == .dark ? .black : .white
        
        Text(displayText)
            .font(currentLineFont)
            .foregroundColor(invertedFg)
            .tracking(-1)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - 默认歌词样式
    @ViewBuilder
    private var defaultLyricContent: some View {
        if isCurrent {
            if enableKaraoke {
                if #available(iOS 16.0, *) {
                    let words = resolvedKaraokeWords()
                    FlowLayout(
                        spacing: 0,
                        rowAlignment: .center,
                        measurementToken: karaokeMeasurementToken(words: words)
                    ) {
                        ForEach(words.indices, id: \.self) { i in
                            KaraokeWordView(
                                word: words[i],
                                progress: LyricKaraokeTimeline.progress(
                                    for: words[i],
                                    at: currentTime
                                ),
                                font: currentLineFont,
                                activeColor: customActiveColor,
                                inactiveColor: adaptiveSecondaryColor ?? .gray.opacity(0.3),
                                activeGradient: customActiveGradient,
                                style: karaokeStyle
                            )
                        }
                    }
                    .scaleEffect(1.05)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isCurrent)
                } else {
                    constructFallbackText()
                        .multilineTextAlignment(.center)
                        .scaleEffect(1.05)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isCurrent)
                }
            } else {
                if let gradient = customActiveGradient {
                    Text(displayText)
                        .font(currentLineFont)
                        .foregroundStyle(gradient)
                        .multilineTextAlignment(.center)
                        .scaleEffect(1.05)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isCurrent)
                } else {
                    Text(displayText)
                        .font(currentLineFont)
                        .foregroundColor(customActiveColor)
                        .multilineTextAlignment(.center)
                        .scaleEffect(1.05)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isCurrent)
                }
            }
        } else {
            Text(displayText)
                .font(normalLineFont)
                .foregroundColor(adaptiveSecondaryColor ?? .gray.opacity(0.6))
                .multilineTextAlignment(.center)
                .blur(radius: 0.5)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isCurrent)
        }
    }
    
    private func resolvedKaraokeWords() -> [LyricWord] {
        // The parser normalizes every line once before publishing it. Reusing
        // that immutable timeline avoids filtering, sorting and allocating new
        // UUID-backed words at 60 fps. Uppercase mode is the only case that
        // needs a display-only copy.
        if !line.words.isEmpty {
            guard forceUppercaseEnglish else { return line.words }
            return line.words.map {
                LyricWord(
                    text: $0.text.monoUppercasingEnglish(),
                    startTime: $0.startTime,
                    duration: $0.duration
                )
            }
        }
        return LyricKaraokeTimeline.resolvedWords(for: line, displayText: displayText)
    }

    private func karaokeMeasurementToken(words: [LyricWord]) -> Int {
        var hasher = Hasher()
        hasher.combine(line.id)
        hasher.combine(words.count)
        hasher.combine(forceUppercaseEnglish)
        hasher.combine(playerFontSelectionRaw)
        hasher.combine(playerCustomFontID)
        hasher.combine(playerFontScale.bitPattern)
        return hasher.finalize()
    }

    private func constructFallbackText() -> Text {
        let chars = Array(displayText)
        let threshold = Int(Double(chars.count) * progress)
        
        var combined = Text("")
        for (index, char) in chars.enumerated() {
            let isActive = index <= threshold && progress > 0
            let color: Color = isActive
                ? (adaptivePrimaryColor ?? .monoTextPrimary)
                : (adaptiveSecondaryColor ?? .gray.opacity(0.3))
            combined = combined + Text(String(char))
                .font(currentLineFont)
                .foregroundColor(color)
        }
        return combined
    }
    
}

// MARK: - 歌词初始定位

extension ScrollViewProxy {
    /// 歌词页挂载时把当前行定位到锚点。
    ///
    /// 单次 `scrollTo` 在播放器主题切换的 spring 过渡期间经常因为内容尚未完成布局而被吞掉，
    /// 表现为「切完主题歌词要等到下一句才滚出来 / 一片空白」。
    /// 这里在挂载后分三拍补位（立即 / 下一帧 / 过渡动画结束后），全部关闭动画，
    /// 保证歌词一挂载就停在当前行。
    @MainActor
    func monoRestoreLyricPosition(
        anchor: UnitPoint = .center,
        isCancelled: (@MainActor () -> Bool)? = nil,
        index: @escaping @MainActor () -> Int
    ) {
        let jump = { @MainActor in
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                self.scrollTo(index(), anchor: anchor)
            }
        }
        jump()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 60_000_000)
            if isCancelled?() == true { return }
            jump()
            try? await Task.sleep(nanoseconds: 440_000_000)
            if isCancelled?() == true { return }
            jump()
        }
    }
}

struct LyricsView: View {
    let song: Song
    var onBackgroundTap: (() -> Void)?
    var adaptivePrimaryColor: Color? = nil
    var adaptiveSecondaryColor: Color? = nil
    var enforcesAdaptiveContrast = false
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject private var viewModel = LyricViewModel.shared
    @ObservedObject private var timePublisher = PlaybackTimePublisher.shared
    @StateObject private var coverColors = CoverColorExtractor()
    
    @State private var isUserScrolling = false
    @State private var userScrollTimer: Timer?
    
    @AppStorage("showTranslation") var showTranslation: Bool = true
    @AppStorage("enableKaraoke") var enableKaraoke: Bool = false
    @AppStorage(KaraokeWordStyle.storageKey) private var karaokeStyleRaw = KaraokeWordStyle.defaultStyle.rawValue
    @AppStorage("lyricColorMode") private var lyricColorMode: String = "default"
    @AppStorage("lyricSolidColorHex") private var lyricSolidColorHex: String = "007AFF"
    @AppStorage("lyricGradientStartHex") private var lyricGradientStartHex: String = "FF6B6B"
    @AppStorage("lyricGradientEndHex") private var lyricGradientEndHex: String = "4ECDC4"
    @AppStorage("lyricsForceUppercaseEnglish") private var forceUppercaseEnglish = false
    @AppStorage("playerDisplayFont") private var playerFontSelectionRaw = MonoPlayerFont.followThemeRawValue
    @AppStorage("playerCustomFontID") private var playerCustomFontID = ""
    @AppStorage("playerFontScale") private var playerFontScale = 1.0
    
    var body: some View {
        VStack {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(
                            CircularProgressViewStyle(
                                tint: adaptivePrimaryColor ?? .monoTextPrimary
                            )
                        )
                } else if !viewModel.hasLyrics {
                    Text("No Lyrics Available")
                        .font(.rounded(size: 18, weight: .medium))
                        .foregroundColor(
                            (adaptivePrimaryColor ?? .monoTextPrimary).opacity(0.6)
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onBackgroundTap?()
                        }
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 24) {
                                Color.clear.frame(height: 200)

                                ForEach(Array(viewModel.lyrics.enumerated()), id: \.element.id) { index, line in
                                    Button(action: {
                                        HapticManager.shared.light()
                                        PlayerManager.shared.seek(to: line.time)
                                    }) {
                                        renderedLyricLine(line, at: index)
                                        .frame(maxWidth: .infinity)
                                        .padding(.horizontal, 32)
                                        .animation(.easeInOut(duration: 0.3), value: viewModel.currentLineIndex)
                                    }
                                    .buttonStyle(.plain)
                                    .id(index)
                                }

                                Color.clear.frame(height: 300)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .scrollIndicators(.hidden)
                        .simultaneousGesture(
                            DragGesture().onChanged { _ in
                                isUserScrolling = true
                                resetScrollTimer()
                            }
                        )
                        .onChange(of: viewModel.currentLineIndex) { _, newIndex in
                            if !isUserScrolling {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    proxy.scrollTo(newIndex, anchor: .center)
                                }
                            }
                        }
                        .onTapGesture {
                            isUserScrolling = false
                            onBackgroundTap?()
                        }
                        .onAppear {
                            isUserScrolling = false
                            proxy.monoRestoreLyricPosition(isCancelled: { isUserScrolling }) {
                                viewModel.currentLineIndex
                            }
                        }
                        .mask(
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .black, location: 0.15),
                                    .init(color: .black, location: 0.85),
                                    .init(color: .clear, location: 1.0)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                }
            }
        .task(id: song.coverUrl?.absoluteString) {
            coverColors.extract(
                from: song.coverUrl?.sized(200).absoluteString
            )
        }
    }

    @ViewBuilder
    private func renderedLyricLine(_ line: LyricLine, at index: Int) -> some View {
        let isCurrent = index == viewModel.currentLineIndex
        if isCurrent && enableKaraoke && player.isPlaying {
            TimelineView(
                AppFrameRate.throttledTimeline(maximumFramesPerSecond: 60)
            ) { _ in
                karaokeLine(line, isCurrent: true, currentTime: livePlaybackTime)
            }
        } else {
            karaokeLine(
                line,
                isCurrent: isCurrent,
                currentTime: isCurrent ? timePublisher.currentTime : 0
            )
        }
    }

    private func karaokeLine(
        _ line: LyricLine,
        isCurrent: Bool,
        currentTime: TimeInterval
    ) -> some View {
        KaraokeLineView(
            line: line,
            isCurrent: isCurrent,
            currentTime: currentTime,
            progress: isCurrent ? viewModel.currentLineProgress : 0,
            showTranslation: showTranslation,
            enableKaraoke: enableKaraoke,
            lyricColorMode: lyricColorMode,
            lyricSolidColorHex: lyricSolidColorHex,
            lyricGradientStartHex: lyricGradientStartHex,
            lyricGradientEndHex: lyricGradientEndHex,
            lyricAutoPalette: coverColors.palette,
            forceUppercaseEnglish: forceUppercaseEnglish,
            playerFontSelectionRaw: playerFontSelectionRaw,
            playerCustomFontID: playerCustomFontID,
            playerFontScale: playerFontScale,
            karaokeStyle: KaraokeWordStyle.resolve(karaokeStyleRaw),
            adaptivePrimaryColor: adaptivePrimaryColor,
            adaptiveSecondaryColor: adaptiveSecondaryColor,
            enforcesAdaptiveContrast: enforcesAdaptiveContrast
        )
    }

    private var livePlaybackTime: TimeInterval {
        LyricKaraokeTimeline.playbackTime(
            streamPlayerTime: player.streamPlayer.currentTime,
            publishedTime: timePublisher.currentTime,
            isAppleMusic: player.currentSong?.isAppleMusic == true,
            appleMusicPlayerTime: player.appleMusicPlayback.renderingPlaybackTime
        )
    }
    
    private func resetScrollTimer() {
        userScrollTimer?.invalidate()
        userScrollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            Task { @MainActor in
                withAnimation {
                    isUserScrolling = false
                }
            }
        }
    }
}
