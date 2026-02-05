import SwiftUI
import Combine

class LikeManager: ObservableObject {
    static let shared = LikeManager()
    
    @Published var likedSongIds: Set<Int> = []
    
    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared
    
    private init() {
        // Initial fetch if logged in
        if apiService.isLoggedIn, let uid = apiService.currentUserId {
            fetchLikedSongs(uid: uid)
        }
    }
    
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
                    print("Fetch liked songs failed: \(error)")
                }
            }, receiveValue: { [weak self] ids in
                self?.likedSongIds = Set(ids)
            })
            .store(in: &cancellables)
    }
    
    func isLiked(id: Int) -> Bool {
        return likedSongIds.contains(id)
    }
    
    func toggleLike(songId: Int) {
        guard apiService.isLoggedIn else {
            // Show login alert or prompt (Should be handled by UI, here we just return or log)
            print("User not logged in")
            return
        }
        
        let isCurrentlyLiked = isLiked(id: songId)
        let targetState = !isCurrentlyLiked
        
        // Optimistic UI Update
        if targetState {
            likedSongIds.insert(songId)
        } else {
            likedSongIds.remove(songId)
        }
        
        // API Call
        apiService.likeSong(id: songId, like: targetState)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    print("Toggle like failed: \(error)")
                    // Revert state on failure
                    if targetState {
                        self?.likedSongIds.remove(songId)
                    } else {
                        self?.likedSongIds.insert(songId)
                    }
                }
            }, receiveValue: { _ in
                // Success, do nothing as we already updated UI
            })
            .store(in: &cancellables)
    }
}
