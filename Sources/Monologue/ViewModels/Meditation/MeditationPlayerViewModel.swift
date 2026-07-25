import Combine
import Foundation

/// 冥想播放页的数据源：把电台节目或 Sati 资源统一成 `RadioProgram` 列表，
/// 以播客模式交给 `PlayerManager` 播放，并提供当前集数/封面/标题等展示状态。
@MainActor
final class MeditationPlayerViewModel: ObservableObject {
    let source: MeditationPlaybackSource
    let radio: RadioStation

    @Published private(set) var radioDetail: RadioStation?
    @Published private(set) var programs: [RadioProgram] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let player = PlayerManager.shared
    private let programLimit = 1000
    private var didAutoStart = false

    init(radio: RadioStation) {
        self.source = .radio(radio)
        self.radio = radio
        self.radioDetail = radio
    }

    init(source: MeditationPlaybackSource) {
        self.source = source
        self.radio = source.radio
        self.radioDetail = source.radio
    }

    // MARK: - 播放内容

    var orderedPrograms: [RadioProgram] {
        sortedPrograms(programs)
    }

    /// 把节目转为可播放歌曲：去重、补齐播客封面与所属电台信息。
    var playableSongs: [Song] {
        var seen = Set<Int>()

        return orderedPrograms.compactMap { program -> Song? in
            guard var song = program.mainSong,
                  seen.insert(song.id).inserted else {
                return nil
            }

            if song.al?.picUrl == nil || (song.al?.picUrl?.isEmpty ?? true) {
                song.podcastCoverUrl = program.coverUrl ?? radioDetail?.picUrl ?? radio.picUrl
            }
            song.podcastRadioId = program.radio?.id ?? radioDetail?.id ?? radio.id
            song.podcastRadioName = program.radio?.name ?? radioDetail?.name ?? radio.name
            return song
        }
    }

    // MARK: - 播放器状态映射

    /// 当前全局播放器是否正在播本页对应的电台内容（区分"控制自己"与"从头开始"）。
    var isOwnContent: Bool {
        if case .podcast(let id) = player.playSource, id == radio.id { return true }
        return false
    }

    var isMeditationPlaying: Bool {
        isOwnContent && player.isPlaying
    }

    var isMeditationLoading: Bool {
        isOwnContent && player.isLoading
    }

    var currentProgramIndex: Int {
        guard !orderedPrograms.isEmpty else { return 0 }
        guard isOwnContent, let currentSong = player.currentSong else { return 0 }
        return orderedPrograms.firstIndex { $0.mainSong?.id == currentSong.id } ?? 0
    }

    var currentProgram: RadioProgram? {
        let programs = orderedPrograms
        guard !programs.isEmpty else { return nil }
        return programs[max(0, min(currentProgramIndex, programs.count - 1))]
    }

    var currentTitle: String {
        currentProgram?.name ?? radioDetail?.name ?? radio.name
    }

    var currentSubtitle: String {
        radioDetail?.name ?? radio.name
    }

    var currentCoverURL: URL? {
        currentProgram?.programCoverUrl ?? radioDetail?.coverUrl ?? radio.coverUrl
    }

    var totalProgramCount: Int {
        radioDetail?.programCount ?? max(orderedPrograms.count, 1)
    }

    var currentEpisodeNumber: Int {
        if let serial = currentProgram?.serialNum, serial > 0 { return serial }
        return currentProgramIndex + 1
    }

    var episodeProgressText: String {
        String(
            format: String(localized: "meditation_player_episode_progress"),
            currentEpisodeNumber,
            max(totalProgramCount, currentEpisodeNumber)
        )
    }

    // MARK: - 加载与播放控制

    /// 加载节目列表并自动开始播放（仅首次）；电台源走 API 拉取，Sati 源直接本地转换。
    func loadAndStartIfNeeded() async {
        if !programs.isEmpty {
            startFromFirstIfNeeded()
            return
        }

        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            switch source {
            case .radio:
                do {
                    radioDetail = try await APIService.shared.fetchDJDetail(id: radio.id).async()
                } catch {
                    radioDetail = radio
                    AppLogger.warning("MeditationPlayerViewModel: 电台详情加载失败 \(radio.id) - \(error.localizedDescription)")
                }

                let loadedPrograms = try await APIService.shared
                    .fetchDJPrograms(radioId: radio.id, limit: programLimit, offset: 0, asc: true)
                    .async()

                programs = sortedPrograms(loadedPrograms)

            case .sati:
                radioDetail = radio
                programs = source.normalizedSatiResources.enumerated().map { index, resource in
                    resource.asRadioProgram(serialNum: index + 1, radio: radio)
                }
            }

            isLoading = false

            if programs.isEmpty {
                errorMessage = String(localized: "meditation_player_empty")
            } else {
                startFromFirstIfNeeded()
            }
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            AppLogger.warning("MeditationPlayerViewModel: 冥想节目加载失败 \(radio.id) - \(error.localizedDescription)")
        }
    }

    func retry() async {
        didAutoStart = false
        programs = []
        await loadAndStartIfNeeded()
    }

    func startFromBeginning() {
        guard startFirstPlayableSong() else { return }
        didAutoStart = true
    }

    func togglePlayPause() {
        if isOwnContent && player.currentSong != nil {
            player.togglePlayPause()
        } else {
            startFromBeginning()
        }
    }

    func nextTrack() {
        guard isOwnContent else {
            startFromBeginning()
            return
        }
        player.next()
    }

    func previousTrack() {
        guard isOwnContent else {
            startFromBeginning()
            return
        }
        player.previous()
    }

    func seekForward() {
        guard isOwnContent else { return }
        player.seekForward(seconds: 30)
    }

    func seekBackward() {
        guard isOwnContent else { return }
        player.seekBackward(seconds: 15)
    }

    /// 首次加载完成后自动起播，之后不再重复触发。
    private func startFromFirstIfNeeded() {
        guard !didAutoStart else { return }
        if startFirstPlayableSong() {
            didAutoStart = true
        }
    }

    /// 从指定起播曲目（若有）或第一首开始，以播客模式接管全局播放器。
    @discardableResult
    private func startFirstPlayableSong() -> Bool {
        let songs = playableSongs
        let preferredSong = source.preferredStartSongID.flatMap { preferredID in
            songs.first { $0.id == preferredID }
        }
        guard let firstSong = preferredSong ?? songs.first else { return false }

        player.playPodcast(song: firstSong, in: songs, radioId: radio.id, restoreSavedContext: false)
        return true
    }

    /// 节目排序：优先按集数，其次按创建时间，最后按 id 升序。
    private func sortedPrograms(_ programs: [RadioProgram]) -> [RadioProgram] {
        programs.sorted { lhs, rhs in
            if let lhsSerial = lhs.serialNum,
               let rhsSerial = rhs.serialNum,
               lhsSerial != rhsSerial {
                return lhsSerial < rhsSerial
            }

            if let lhsTime = lhs.createTime,
               let rhsTime = rhs.createTime,
               lhsTime != rhsTime {
                return lhsTime < rhsTime
            }

            return lhs.id < rhs.id
        }
    }
}
