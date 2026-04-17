import SwiftUI
import Combine

@MainActor
@Observable class PodcastPlayerViewModel {
    let radioId: Int
    private let detailVM: RadioDetailViewModel
    private let player = PlayerManager.shared

    var isAscendingOrder: Bool { detailVM.isAscendingOrder }

    var radioDetail: RadioStation? { detailVM.radioDetail }
    var programs: [RadioProgram] { detailVM.programs }
    var orderedPrograms: [RadioProgram] { detailVM.orderedPrograms }
    var isLoading: Bool { detailVM.isLoading }
    var isLoadingMore: Bool { detailVM.isLoadingMore }
    var hasMore: Bool { detailVM.hasMore }
    var errorMessage: String? { detailVM.errorMessage }

    init(radioId: Int) {
        self.radioId = radioId
        self.detailVM = RadioDetailViewModel(radioId: radioId)
    }

    // MARK: - State

    var isOwnContent: Bool {
        if case .podcast(let id) = player.playSource, id == radioId { return true }
        return false
    }

    var isRadioPlaying: Bool { isOwnContent && player.isPlaying }
    var isRadioLoading: Bool { isOwnContent && player.isLoading }

    var currentProgramIndex: Int {
        guard !orderedPrograms.isEmpty else { return 0 }
        guard isOwnContent, let currentSong = player.currentSong else { return 0 }

        return orderedPrograms.firstIndex(where: { $0.mainSong?.id == currentSong.id }) ?? 0
    }

    var currentProgram: RadioProgram? {
        guard !orderedPrograms.isEmpty,
              currentProgramIndex >= 0,
              currentProgramIndex < orderedPrograms.count else { return nil }
        return orderedPrograms[currentProgramIndex]
    }

    var totalProgramCount: Int {
        radioDetail?.programCount ?? max(programs.count, 1)
    }

    var currentEpisodeNumber: Int {
        guard let program = currentProgram else { return 1 }
        return displayEpisodeNumber(for: program, at: currentProgramIndex)
    }

    // MARK: - Actions

    func fetchDetail() {
        detailVM.fetchDetail()
    }

    func loadMorePrograms() {
        detailVM.loadMorePrograms()
    }

    func songsFromPrograms() -> [Song] {
        detailVM.songsFromPrograms()
    }

    func handlePlayPause() {
        if isOwnContent && player.currentSong != nil {
            player.togglePlayPause()
        } else if let program = currentProgram, let song = program.mainSong {
            let songs = songsFromPrograms()
            player.playPodcast(song: song, in: songs, radioId: radioId)
        }
    }

    func playProgramAt(index: Int) {
        guard index >= 0, index < orderedPrograms.count else { return }
        let program = orderedPrograms[index]
        guard let song = program.mainSong else { return }

        let songs = songsFromPrograms()
        player.playPodcast(song: song, in: songs, radioId: radioId)
    }

    func nextProgram() {
        let nextIndex = currentProgramIndex + 1
        if nextIndex < programs.count {
            playProgramAt(index: nextIndex)
        }
        if nextIndex >= programs.count - 3 {
            loadMorePrograms()
        }
    }

    func previousProgram() {
        let prevIndex = currentProgramIndex - 1
        if prevIndex >= 0 {
            playProgramAt(index: prevIndex)
        }
    }

    func seekForward() {
        if isOwnContent { player.seekForward(seconds: 30) }
    }

    func seekBackward() {
        if isOwnContent { player.seekBackward(seconds: 15) }
    }

    func toggleEpisodeOrder() {
        detailVM.toggleEpisodeOrder()
    }

    func displayEpisodeNumber(for program: RadioProgram, at index: Int) -> Int {
        detailVM.displayEpisodeNumber(at: index)
    }
}
