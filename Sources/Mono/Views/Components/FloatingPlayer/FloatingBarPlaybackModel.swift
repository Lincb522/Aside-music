import Combine
import SwiftUI

/// Narrow playback state used by custom floating tab bars.
///
/// `PlayerManager` owns a lot of published state. Observing it directly from the
/// tab bar makes the whole dock refresh for unrelated playback and queue changes.
/// This proxy only republishes the fields the dock needs.
@MainActor
final class FloatingBarPlaybackModel: ObservableObject {
    static let shared = FloatingBarPlaybackModel()

    @Published private(set) var currentSong: Song?
    @Published private(set) var isPlaying: Bool
    @Published private(set) var isLoading: Bool
    @Published private(set) var playSource: PlayerManager.PlaySource
    @Published private(set) var isTabBarHidden: Bool

    private var cancellables: Set<AnyCancellable> = []

    private init() {
        let player = PlayerManager.shared
        currentSong = player.currentSong
        isPlaying = player.isPlaying
        isLoading = player.isLoading
        playSource = player.playSource
        isTabBarHidden = player.isTabBarHidden

        player.$currentSong
            .removeDuplicates()
            .sink { [weak self] song in
                Task { @MainActor [weak self] in
                    self?.currentSong = song
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

        player.$isLoading
            .removeDuplicates()
            .sink { [weak self] isLoading in
                Task { @MainActor [weak self] in
                    self?.isLoading = isLoading
                }
            }
            .store(in: &cancellables)

        player.$playSource
            .removeDuplicates()
            .sink { [weak self] playSource in
                Task { @MainActor [weak self] in
                    self?.playSource = playSource
                }
            }
            .store(in: &cancellables)

        player.$isTabBarHidden
            .removeDuplicates()
            .sink { [weak self] isHidden in
                Task { @MainActor [weak self] in
                    self?.isTabBarHidden = isHidden
                }
            }
            .store(in: &cancellables)

    }

    var isPlayingPodcast: Bool {
        playSource.isPodcast
    }

    func togglePlayPause() {
        PlayerManager.shared.togglePlayPause()
    }

    func previous() {
        PlayerManager.shared.previous()
    }

    func next() {
        PlayerManager.shared.next()
    }

    func seek(to time: Double) {
        PlayerManager.shared.seek(to: time)
    }

    func dismissMiniPlayerPreservingQueue() {
        PlayerManager.shared.dismissMiniPlayerPreservingQueue()
    }

}
