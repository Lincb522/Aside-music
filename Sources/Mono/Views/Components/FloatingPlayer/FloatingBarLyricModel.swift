import Combine

/// Lyric changes belong to lyric text, independently of dock playback and navigation state.
@MainActor
final class FloatingBarLyricModel: ObservableObject {
    static let shared = FloatingBarLyricModel()

    @Published private(set) var lineText: String?

    private var subscription: AnyCancellable?
    private var refreshTask: Task<Void, Never>?

    private init() {
        let player = PlayerManager.shared
        let lyrics = LyricViewModel.shared
        lineText = Self.currentLineText(player: player, lyrics: lyrics)

        subscription = Publishers.MergeMany([
            player.$currentSong.map { _ in () }.eraseToAnyPublisher(),
            player.$playSource.removeDuplicates().map { _ in () }.eraseToAnyPublisher(),
            lyrics.$currentLineIndex.removeDuplicates().map { _ in () }.eraseToAnyPublisher(),
            lyrics.$hasLyrics.removeDuplicates().map { _ in () }.eraseToAnyPublisher(),
            lyrics.$lyrics.map { _ in () }.eraseToAnyPublisher(),
        ])
        .sink { [weak self] _ in
            self?.scheduleRefresh()
        }
    }

    deinit {
        refreshTask?.cancel()
    }

    private func scheduleRefresh() {
        refreshTask?.cancel()
        // Published emits before assignment. Read the settled lyric state after
        // that update, coalescing the resets and replacements from the same turn.
        refreshTask = Task { @MainActor [weak self] in
            guard !Task.isCancelled, let self else { return }
            let next = Self.currentLineText(player: PlayerManager.shared, lyrics: LyricViewModel.shared)
            guard lineText != next else { return }
            lineText = next
        }
    }

    private static func currentLineText(player: PlayerManager, lyrics: LyricViewModel) -> String? {
        guard !player.playSource.isPodcast, lyrics.hasLyrics else { return nil }
        return lyrics.currentLineText
    }
}
