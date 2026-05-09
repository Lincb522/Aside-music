import Combine
import SwiftUI

/// Narrow playback state for song rows.
///
/// `SongListRow` can appear hundreds of times inside scrolling pages. Observing
/// the full `PlayerManager` from every row makes unrelated playback changes fan
/// out through the whole list. This model republishes only the row highlight
/// state and keeps queue actions as passthrough calls.
@MainActor
final class SongRowPlaybackModel: ObservableObject {
    static let shared = SongRowPlaybackModel()

    @Published private(set) var currentSongId: Int?
    @Published private(set) var isPlaying: Bool

    private var cancellables: Set<AnyCancellable> = []

    private init() {
        let player = PlayerManager.shared
        currentSongId = player.currentSong?.id
        isPlaying = player.isPlaying

        player.$currentSong
            .map { $0?.id }
            .removeDuplicates()
            .sink { [weak self] songId in
                Task { @MainActor [weak self] in
                    self?.currentSongId = songId
                }
            }
            .store(in: &cancellables)

        player.$isPlaying
            .removeDuplicates()
            .sink { [weak self] isPlaying in
                Task { @MainActor [weak self] in
                    self?.isPlaying = isPlaying
                }
            }
            .store(in: &cancellables)
    }

    func playNext(song: Song) {
        PlayerManager.shared.playNext(song: song)
    }

    func addToQueue(song: Song) {
        PlayerManager.shared.addToQueue(song: song)
    }
}
