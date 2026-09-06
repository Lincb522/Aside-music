import Combine

/// Track-only presentation state for pages that do not render playback controls.
@MainActor
final class CurrentSongPresentationModel: ObservableObject {
    static let shared = CurrentSongPresentationModel()

    @Published private(set) var currentSong: Song?
    private var subscription: AnyCancellable?

    private init() {
        let player = PlayerManager.shared
        currentSong = player.currentSong
        // Song equality only compares identity; metadata updates must also propagate.
        subscription = player.$currentSong.sink { [weak self] song in
            self?.currentSong = song
        }
    }
}
