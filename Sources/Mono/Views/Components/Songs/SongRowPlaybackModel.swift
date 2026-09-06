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

    struct Presentation: Equatable {
        let songID: Int
        let playbackIdentity: String
        let isCurrent: Bool
        let isLoading: Bool
        let isPlaying: Bool
    }

    @Published private(set) var currentSong: Song?
    @Published private(set) var pendingSong: Song?
    @Published private(set) var isPlaying: Bool
    @Published private(set) var isLoading: Bool

    var currentSongId: Int? { currentSong?.id }

    private var cancellables: Set<AnyCancellable> = []

    private init() {
        let player = PlayerManager.shared
        currentSong = player.currentSong
        pendingSong = player.pendingPlaybackPresentationSong
        isPlaying = player.isPlaying
        isLoading = player.isLoading

        player.$currentSong
            .sink { [weak self] song in
                Task { @MainActor [weak self] in
                    self?.currentSong = song
                }
            }
            .store(in: &cancellables)

        player.$pendingPlaybackPresentationSong
            .sink { [weak self] song in
                Task { @MainActor [weak self] in
                    self?.pendingSong = song
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
    }

    func isCurrent(song: Song) -> Bool {
        Self.matches(currentSong, expected: song)
    }

    func isLoading(song: Song) -> Bool {
        Self.isLoading(song: song, currentSong: currentSong, pendingSong: pendingSong, isPlaying: isPlaying, isLoading: isLoading)
    }

    func presentation(for song: Song) -> Presentation {
        Self.presentation(for: song, currentSong: currentSong, pendingSong: pendingSong, isPlaying: isPlaying, isLoading: isLoading)
    }

    func presentationPublisher(for song: Song) -> AnyPublisher<Presentation, Never> {
        Publishers.CombineLatest4($currentSong, $pendingSong, $isPlaying, $isLoading)
            .map { current, pending, playing, loading in
                Self.presentation(for: song, currentSong: current, pendingSong: pending, isPlaying: playing, isLoading: loading)
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    static func presentation(
        for song: Song,
        currentSong: Song?,
        pendingSong: Song?,
        isPlaying: Bool,
        isLoading: Bool
    ) -> Presentation {
        let isCurrent = matches(currentSong, expected: song)
        return Presentation(
            songID: song.id,
            playbackIdentity: PlayerManager.playbackIdentityKey(for: song),
            isCurrent: isCurrent,
            isLoading: Self.isLoading(song: song, currentSong: currentSong, pendingSong: pendingSong, isPlaying: isPlaying, isLoading: isLoading),
            isPlaying: isCurrent && isPlaying
        )
    }

    private static func isLoading(
        song: Song,
        currentSong: Song?,
        pendingSong: Song?,
        isPlaying: Bool,
        isLoading: Bool
    ) -> Bool {
        guard isLoading else { return false }

        if let pendingSong {
            return Self.matches(pendingSong, expected: song)
        }

        // 首次播放没有旧曲需要保留，currentSong 会先发布；此时仍要给歌曲行加载反馈。
        return !isPlaying && Self.matches(currentSong, expected: song)
    }

    private static func matches(_ candidate: Song?, expected: Song) -> Bool {
        guard let candidate,
              candidate.id == expected.id,
              candidate.musicSource == expected.musicSource else { return false }

        if expected.isQQMusic {
            return candidate.qqMid == expected.qqMid
        }
        if expected.isQishui {
            return candidate.qishuiTrackId == expected.qishuiTrackId
        }
        return true
    }

    func playNext(song: Song) {
        PlayerManager.shared.playNext(song: song)
    }

    func addToQueue(song: Song) {
        PlayerManager.shared.addToQueue(song: song)
    }
}
