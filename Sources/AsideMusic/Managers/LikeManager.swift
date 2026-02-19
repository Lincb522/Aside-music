import SwiftUI
import Combine

@MainActor
class LikeManager: ObservableObject {
    static let shared = LikeManager()
    
    /// 网易云喜欢列表（从服务器同步）
    @Published var likedSongIds: Set<Int> = []
    /// QQ 音乐本地收藏列表（本地持久化）
    @Published var localLikedSongIds: Set<Int> = []
    
    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared
    private let localLikeKey = "qq_music_local_likes"
    
    private init() {
        // 加载 QQ 音乐本地收藏
        loadLocalLikes()
        // 加载网易云喜欢列表
        if apiService.isLoggedIn, let uid = apiService.currentUserId {
            fetchLikedSongs(uid: uid)
        }
    }
    
    // MARK: - 本地收藏持久化（QQ 音乐）
    
    private func loadLocalLikes() {
        let ids = UserDefaults.standard.array(forKey: localLikeKey) as? [Int] ?? []
        localLikedSongIds = Set(ids)
    }
    
    private func saveLocalLikes() {
        UserDefaults.standard.set(Array(localLikedSongIds), forKey: localLikeKey)
    }
    
    // MARK: - 网易云喜欢列表
    
    func refreshLikes() {
        if apiService.isLoggedIn, let uid = apiService.currentUserId {
            fetchLikedSongs(uid: uid)
        } else {
            likedSongIds = []
        }
    }
    
    func fetchLikedSongs(uid: Int) {
        apiService.fetchLikedSongs(uid: uid)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    AppLogger.error("Fetch liked songs failed: \(error)")
                }
            }, receiveValue: { [weak self] ids in
                self?.likedSongIds = Set(ids)
            })
            .store(in: &cancellables)
    }
    
    // MARK: - 分源查询
    
    func isLiked(id: Int, isQQMusic: Bool = false) -> Bool {
        if isQQMusic {
            return localLikedSongIds.contains(id)
        }
        return likedSongIds.contains(id)
    }
    
    // MARK: - 分源切换喜欢
    
    func toggleLike(songId: Int, isQQMusic: Bool = false) {
        if isQQMusic {
            toggleLocalLike(songId: songId)
        } else {
            toggleNeteaseLike(songId: songId)
        }
    }
    
    /// QQ 音乐：本地收藏
    private func toggleLocalLike(songId: Int) {
        if localLikedSongIds.contains(songId) {
            localLikedSongIds.remove(songId)
        } else {
            localLikedSongIds.insert(songId)
        }
        saveLocalLikes()
    }
    
    /// 网易云：调用服务器接口
    private func toggleNeteaseLike(songId: Int) {
        guard apiService.isLoggedIn else {
            AppLogger.debug("User not logged in")
            return
        }
        
        let isCurrentlyLiked = likedSongIds.contains(songId)
        let targetState = !isCurrentlyLiked
        
        if targetState {
            likedSongIds.insert(songId)
        } else {
            likedSongIds.remove(songId)
        }
        
        apiService.likeSong(id: songId, like: targetState)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    AppLogger.error("Toggle like failed: \(error)")
                    if targetState {
                        self?.likedSongIds.remove(songId)
                    } else {
                        self?.likedSongIds.insert(songId)
                    }
                }
            }, receiveValue: { _ in })
            .store(in: &cancellables)
    }
}
