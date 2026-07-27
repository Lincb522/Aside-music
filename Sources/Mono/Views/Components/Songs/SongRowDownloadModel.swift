import Combine
import SwiftUI

/// Narrow download state for song rows.
///
/// `DownloadManager.downloadingTasks` changes during progress callbacks. A row
/// only needs the completed-state badge, so keep progress churn away from every
/// visible `SongListRow`.
@MainActor
final class SongRowDownloadModel: ObservableObject {
    static let shared = SongRowDownloadModel()

    @Published private(set) var downloadedSongIds: Set<String>

    private var cancellables: Set<AnyCancellable> = []

    private init() {
        let manager = DownloadManager.shared
        downloadedSongIds = manager.downloadedSongIds

        manager.$downloadedSongIds
            .removeDuplicates()
            .sink { [weak self] ids in
                Task { @MainActor [weak self] in
                    self?.downloadedSongIds = ids
                }
            }
            .store(in: &cancellables)
    }

    func isDownloaded(song: Song) -> Bool {
        if song.isQishui, let trackId = song.qishuiTrackId {
            return downloadedSongIds.contains(DownloadManager.makeQishuiKey(trackId: trackId))
        }
        return isDownloaded(songId: song.id, isQQ: song.isQQMusic)
    }

    func isDownloaded(songId: Int) -> Bool {
        downloadedSongIds.contains("ncm_\(songId)") || downloadedSongIds.contains("qq_\(songId)")
    }

    func isDownloaded(songId: Int, isQQ: Bool) -> Bool {
        downloadedSongIds.contains(isQQ ? "qq_\(songId)" : "ncm_\(songId)")
    }

    func deleteDownload(song: Song) {
        // 清掉这首歌所有 key 变体的记录，避免历史数据 key 错配导致删不掉
        DownloadManager.shared.deleteAllDownloadRecords(for: song)
    }

    func download(song: Song) {
        if song.isQishui {
            DownloadManager.shared.downloadQishui(song: song, quality: SettingsManager.shared.defaultQishuiPlaybackQuality)
        } else if song.isQQMusic {
            DownloadManager.shared.downloadQQ(song: song, quality: DownloadManager.defaultQQDownloadQuality)
        } else {
            DownloadManager.shared.download(song: song, quality: DownloadManager.defaultNeteaseDownloadQuality)
        }
    }
}
