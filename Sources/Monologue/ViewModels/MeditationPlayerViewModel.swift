import Combine
import Foundation

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

    var orderedPrograms: [RadioProgram] {
        sortedPrograms(programs)
    }

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

    private func startFromFirstIfNeeded() {
        guard !didAutoStart else { return }
        if startFirstPlayableSong() {
            didAutoStart = true
        }
    }

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
