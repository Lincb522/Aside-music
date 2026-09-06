import SwiftUI
import Combine

@MainActor
class LyricViewModel: ObservableObject {
    static let shared = LyricViewModel()

    private struct FallbackSourcePlan {
        let identity: String
        var remainingSources: [LyricSource]
    }

    private static let pinnedSourcesStorageKey = "pinnedLyricSourcesBySong.v1"
    
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
    private var fallbackSourcePlan: FallbackSourcePlan?
    
    func fetchLyrics(for song: Song) {
        loadLyrics(for: song, forceReload: false)
    }

    private func loadLyrics(for song: Song, forceReload: Bool) {
        prepareLyricIdentity(for: song)

        let identity = PlayerManager.playbackIdentityKey(for: song)
        let pinnedSource = pinnedSource(for: song)
        let source = pinnedSource ?? LyricSource.resolvedGlobalSource(for: song)
        let remainingSources = LyricSource.allCases.filter { $0 != source }
        fallbackSourcePlan = FallbackSourcePlan(
            identity: identity,
            remainingSources: remainingSources
        )
        activeSource = source

        if applyDownloadedLyricsIfAvailable(for: song, source: source) {
            fallbackSourcePlan = nil
            return
        }

        // 旧缓存没有记录歌词来源。只有歌词来源与歌曲平台一致时才复用，
        // 手动换源和跨平台默认源始终重新请求，防止显示错误来源的旧歌词。
        let canUseLegacyCache = pinnedSource == nil && source.musicSource == song.musicSource
        if canUseLegacyCache, applyCachedLyricsIfAvailable(for: song) {
            fallbackSourcePlan = nil
            return
        }

        fetchLyrics(for: song, source: source, forceReload: forceReload)
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
        fallbackSourcePlan = nil
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
        if currentSongIdentity == PlayerManager.playbackIdentityKey(for: song),
           currentSongId == song.id,
           let activeSource {
            return activeSource
        }
        return pinnedSource(for: song) ?? LyricSource.resolvedGlobalSource(for: song)
    }

    func pinnedSource(for song: Song) -> LyricSource? {
        let identity = PlayerManager.playbackIdentityKey(for: song)
        guard let rawValue = pinnedSourceValues()[identity] else { return nil }
        return LyricSource(rawValue: rawValue)
    }

    /// 固定当前歌曲的首选歌词来源，后续播放仍优先尝试该来源。
    func changeSource(_ source: LyricSource, for song: Song) {
        prepareLyricIdentity(for: song)
        setPinnedSource(source, for: song)
        loadLyrics(for: song, forceReload: true)
    }

    func useAutomaticSource(for song: Song) {
        prepareLyricIdentity(for: song)
        setPinnedSource(nil, for: song)
        loadLyrics(for: song, forceReload: true)
    }

    /// 全局来源策略变化时，只刷新未单独固定来源的歌曲。
    func useGlobalSource(for song: Song) {
        prepareLyricIdentity(for: song)
        guard pinnedSource(for: song) == nil else { return }
        loadLyrics(for: song, forceReload: true)
    }

    private func pinnedSourceValues() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: Self.pinnedSourcesStorageKey)?
            .compactMapValues { $0 as? String } ?? [:]
    }

    private func setPinnedSource(_ source: LyricSource?, for song: Song) {
        let identity = PlayerManager.playbackIdentityKey(for: song)
        var values = pinnedSourceValues()
        values[identity] = source?.rawValue
        UserDefaults.standard.set(values, forKey: Self.pinnedSourcesStorageKey)
    }

    private func fetchLyrics(for song: Song, source: LyricSource, forceReload: Bool) {
        activeSource = source

        switch source {
        case .netease:
            fetchNeteaseLyrics(for: song, forceReload: forceReload)
        case .qqmusic:
            fetchQQLyrics(for: song, forceReload: forceReload)
        case .qishui:
            fetchQishuiLyrics(for: song, forceReload: forceReload)
        case .kugou:
            fetchKugouLyrics(for: song, forceReload: forceReload)
        }
    }

    private func completeLyricRequest(source: LyricSource, sessionId: Int) {
        guard lyricSessionId == sessionId else { return }
        activeSource = source
        fallbackSourcePlan = nil
        isLoading = false
    }

    private func finishFailedLyricRequest(
        source: LyricSource,
        for song: Song,
        sessionId: Int
    ) {
        guard lyricSessionId == sessionId else { return }

        let identity = PlayerManager.playbackIdentityKey(for: song)
        if var plan = fallbackSourcePlan,
           plan.identity == identity,
           let nextSource = plan.remainingSources.first {
            plan.remainingSources.removeFirst()
            fallbackSourcePlan = plan
            AppLogger.info(
                "[Lyrics] \(source.shortName) 无可用歌词，自动尝试 \(nextSource.shortName): \(song.name) - \(song.artistName)"
            )
            fetchLyrics(for: song, source: nextSource, forceReload: true)
            return
        }

        fallbackSourcePlan = nil
        isLoading = false
        currentSongId = nil
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
        guard let cached = OptimizedCacheManager.shared.getLyrics(songId: song.id, source: song.musicSource) else { return false }

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
            fetchQishuiLyrics(trackId: trackId, for: song, forceReload: forceReload)
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
                if case .failure(let error) = completion {
                    self.hasLyrics = false
                    AppLogger.warning("[Lyrics] KCM 歌词获取失败: \(error.localizedDescription)")
                    self.finishFailedLyricRequest(source: .kugou, for: song, sessionId: sessionId)
                }
            }, receiveValue: { [weak self] content in
                guard let self, self.lyricSessionId == sessionId else { return }
                self.applyKugouLyrics(content, songId: song.id)
                if self.hasLyrics {
                    self.completeLyricRequest(source: .kugou, sessionId: sessionId)
                } else {
                    self.finishFailedLyricRequest(source: .kugou, for: song, sessionId: sessionId)
                }
            })
            .store(in: &cancellables)
    }

    private func searchKugouLyricsByMetadata(for song: Song, sessionId: Int) {
        guard !song.name.isEmpty || !song.artistName.isEmpty else {
            finishFailedLyricRequest(source: .kugou, for: song, sessionId: sessionId)
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

                    self.applyKugouLyrics(content, songId: song.id)
                    if self.hasLyrics {
                        self.completeLyricRequest(source: .kugou, sessionId: sessionId)
                        AppLogger.info("[Lyrics] 已从 KCM 搜索结果补全歌词: \(song.name) - \(song.artistName)")
                        return
                    }
                }
            } catch {
                AppLogger.warning("[Lyrics] KCM 搜索补全失败: \(query) - \(error.localizedDescription)")
            }

            self.finishFailedLyricRequest(source: .kugou, for: song, sessionId: sessionId)
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
            source: .kugou,
            lyrics: content,
            translated: nil
        )
    }

    private func fetchQishuiLyrics(trackId: Int, for song: Song, forceReload: Bool) {
        guard let sessionId = beginLyricRequest(songId: song.id, forceReload: forceReload) else { return }

        APIService.shared.fetchQishuiLyric(trackId: trackId)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self, self.lyricSessionId == sessionId else { return }
                if case .failure = completion {
                    AppLogger.warning("[Lyrics] 汽水歌词获取失败")
                    self.finishFailedLyricRequest(source: .qishui, for: song, sessionId: sessionId)
                }
            }, receiveValue: { [weak self] content in
                guard let self, self.lyricSessionId == sessionId else { return }
                if !content.isEmpty {
                    self.applyQishuiLyrics(content)
                }
                if self.hasLyrics {
                    self.completeLyricRequest(source: .qishui, sessionId: sessionId)
                    AppLogger.info("[Lyrics] 汽水歌词加载成功: \(self.lyrics.count) 行")
                } else {
                    self.finishFailedLyricRequest(source: .qishui, for: song, sessionId: sessionId)
                }
            })
            .store(in: &cancellables)
    }

    private func searchQishuiLyricsByMetadata(for song: Song, sessionId: Int) {
        guard !song.name.isEmpty || !song.artistName.isEmpty else {
            finishFailedLyricRequest(source: .qishui, for: song, sessionId: sessionId)
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
                    if self.hasLyrics {
                        self.completeLyricRequest(source: .qishui, sessionId: sessionId)
                        AppLogger.info("[Lyrics] 已从 QSM 搜索结果补全歌词: \(song.name) - \(song.artistName)")
                        return
                    }
                }
            } catch {
                AppLogger.warning("[Lyrics] QSM 搜索补全失败: \(query) - \(error.localizedDescription)")
            }

            self.finishFailedLyricRequest(source: .qishui, for: song, sessionId: sessionId)
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
        fallbackSourcePlan = nil
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
        fetchNeteaseLyrics(for: song, forceReload: false)
    }

    private func fetchNeteaseLyrics(
        for song: Song,
        forceReload: Bool
    ) {
        let songId = song.id
        guard let sessionId = beginLyricRequest(songId: songId, forceReload: forceReload) else { return }

        // 跨平台歌曲的数值 ID 不属于 NCM，必须先按元数据搜索。
        if song.musicSource != .netease {
            fetchLyricsByMetadataFallback(
                for: song,
                sessionId: sessionId
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
                        sessionId: sessionId
                    )
                }
            }, receiveValue: { [weak self] response in
                guard let self = self, self.lyricSessionId == sessionId else { return }
                self.applyNeteaseLyrics(response)

                if !self.hasLyrics {
                    self.fetchLyricsByMetadataFallback(
                        for: song,
                        sessionId: sessionId
                    )
                } else {
                    self.completeLyricRequest(source: .netease, sessionId: sessionId)
                }
            })
            .store(in: &cancellables)
    }
    
    /// 获取 qcm歌词
    private func fetchQQLyrics(for song: Song, forceReload: Bool) {
        if let mid = song.qqMid, !mid.isEmpty {
            fetchQQLyrics(mid: mid, for: song, forceReload: forceReload)
            return
        }

        guard let sessionId = beginLyricRequest(songId: song.id, forceReload: forceReload) else { return }
        searchQQLyricsByMetadata(for: song, sessionId: sessionId)
    }

    private func fetchQQLyrics(mid: String, for song: Song, forceReload: Bool) {
        guard let sessionId = beginLyricRequest(songId: song.id, forceReload: forceReload) else { return }

        APIService.shared.fetchQQLyric(mid: mid)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self = self, self.lyricSessionId == sessionId else { return }
                if case .failure(let error) = completion {
                    AppLogger.error("[QQMusic] 获取歌词失败: \(error)")
                    self.finishFailedLyricRequest(source: .qqmusic, for: song, sessionId: sessionId)
                }
            }, receiveValue: { [weak self] response in
                guard let self = self, self.lyricSessionId == sessionId else { return }
                self.applyQQLyrics(response)
                if self.hasLyrics {
                    self.completeLyricRequest(source: .qqmusic, sessionId: sessionId)
                } else {
                    self.finishFailedLyricRequest(source: .qqmusic, for: song, sessionId: sessionId)
                }
            })
            .store(in: &cancellables)
    }

    private func fetchQQLyrics(
        mid: String,
        for song: Song,
        sessionId: Int
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
                    AppLogger.warning("[Lyrics] QCM 歌词获取失败: \(error)")
                    self.finishFailedLyricRequest(source: .qqmusic, for: song, sessionId: sessionId)
                }
            }, receiveValue: { [weak self] response in
                guard let self = self, self.lyricSessionId == sessionId else { return }
                self.applyQQLyrics(response)
                if self.hasLyrics {
                    self.completeLyricRequest(source: .qqmusic, sessionId: sessionId)
                    AppLogger.info("[Lyrics] 已从 QCM 搜索结果补全歌词: \(song.name) - \(song.artistName)")
                } else {
                    self.finishFailedLyricRequest(source: .qqmusic, for: song, sessionId: sessionId)
                }
            })
            .store(in: &cancellables)
    }

    private func fetchLyricsByMetadataFallback(
        for song: Song,
        sessionId: Int
    ) {
        guard !song.name.isEmpty || !song.artistName.isEmpty else {
            finishFailedLyricRequest(source: .netease, for: song, sessionId: sessionId)
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
                        self.completeLyricRequest(source: .netease, sessionId: sessionId)
                        AppLogger.info(
                            "[Lyrics] 已从 NCM 搜索结果补全歌词: \(song.name) - \(song.artistName)"
                        )
                        return
                    }
                }
            } catch {
                AppLogger.warning("[Lyrics] NCM 搜索补全失败: \(query) - \(error.localizedDescription)")
            }

            self.finishFailedLyricRequest(source: .netease, for: song, sessionId: sessionId)
        }
    }

    private func searchQQLyricsByMetadata(
        for song: Song,
        sessionId: Int
    ) {
        guard !song.name.isEmpty || !song.artistName.isEmpty else {
            finishFailedLyricRequest(source: .qqmusic, for: song, sessionId: sessionId)
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
                    self.fetchQQLyrics(
                        mid: qqMid,
                        for: song,
                        sessionId: sessionId
                    )
                    return
                }
            } catch {
                AppLogger.warning("[Lyrics] QCM 搜索补全失败: \(query) - \(error.localizedDescription)")
            }

            self.finishFailedLyricRequest(source: .qqmusic, for: song, sessionId: sessionId)
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
        fallbackSourcePlan = nil
    }
}
