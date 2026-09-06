import Combine

/// Download availability changes independently of in-flight byte progress.
@MainActor
final class DownloadedSongStatusModel: ObservableObject {
    static let shared = DownloadedSongStatusModel()

    @Published private var songIds: Set<String>
    private var subscription: AnyCancellable?

    private init() {
        let manager = DownloadManager.shared
        songIds = manager.downloadedSongIds
        subscription = manager.$downloadedSongIds
            .removeDuplicates()
            .sink { [weak self] ids in
                self?.songIds = ids
            }
    }

    func isDownloaded(song: Song) -> Bool {
        songIds.contains(DownloadManager.makeKey(for: song))
    }
}
