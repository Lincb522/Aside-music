import SwiftUI
import Combine

@MainActor
class LikeManager: ObservableObject {
    static let shared = LikeManager()
    
    /// ncm喜欢列表（从服务器同步，仅用于同步状态显示）
    @Published var neteaseLikedIds: Set<Int> = []
    
    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared
    
    private init() {
        if apiService.isLoggedIn, let uid = apiService.currentUserId {
            fetchNeteaseLikedSongs(uid: uid)
        }
    }
    
    // MARK: - 统一查询
    
    /// 是否已喜欢（统一查本地「我喜欢」歌单）
    func isLiked(id: Int, isQQMusic: Bool = false) -> Bool {
        LocalPlaylistManager.shared.isFavorite(songId: id)
    }
    
    // MARK: - 统一切换喜欢
    
    /// 喜欢时是否需要弹出歌单选择器（仅在新歌 + 开关开启时触发）
    @Published var showPlaylistPicker = false
    @Published var pendingLikeSong: Song?
    
    /// 点喜欢 → 统一添加到本地「我喜欢」歌单
    /// 如果是ncm歌曲且开启了同步开关，同时调用ncm API
    func toggleLike(songId: Int, isQQMusic: Bool = false, song: Song? = nil) {
        let manager = LocalPlaylistManager.shared
        let currentlyLiked = manager.isFavorite(songId: songId)
        
        if currentlyLiked {
            manager.removeFromFavorite(songId: songId)
        } else if let song = song {
            if SettingsManager.shared.likeToChoosePlaylist {
                pendingLikeSong = song
                showPlaylistPicker = true
                manager.addToFavorite(song)
            } else {
                manager.addToFavorite(song)
            }
        }
        
        objectWillChange.send()
        
        if !isQQMusic && SettingsManager.shared.syncLikeToNetease {
            syncToNetease(songId: songId, like: !currentlyLiked)
        }
    }
    
    // MARK: - ncm同步
    
    func refreshLikes() {
        if apiService.isLoggedIn, let uid = apiService.currentUserId {
            fetchNeteaseLikedSongs(uid: uid)
        } else {
            neteaseLikedIds = []
        }
    }
    
    func fetchNeteaseLikedSongs(uid: Int) {
        apiService.fetchLikedSongs(uid: uid)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    AppLogger.error("Fetch liked songs failed: \(error)")
                }
            }, receiveValue: { [weak self] ids in
                self?.neteaseLikedIds = Set(ids)
            })
            .store(in: &cancellables)
    }
    
    /// 同步喜欢状态到ncm
    private func syncToNetease(songId: Int, like: Bool) {
        guard apiService.isLoggedIn else { return }
        
        if like {
            neteaseLikedIds.insert(songId)
        } else {
            neteaseLikedIds.remove(songId)
        }
        
        var bag: AnyCancellable?
        bag = apiService.likeSong(id: songId, like: like)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    AppLogger.error("Sync like to Netease failed: \(error)")
                    if like {
                        self?.neteaseLikedIds.remove(songId)
                    } else {
                        self?.neteaseLikedIds.insert(songId)
                    }
                }
                bag?.cancel()
                bag = nil
            }, receiveValue: { _ in })
    }
}
