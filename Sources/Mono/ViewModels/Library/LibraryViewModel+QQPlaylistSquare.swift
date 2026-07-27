import SwiftUI
import Combine
@preconcurrency import QQMusicKit

extension LibraryViewModel {
    // MARK: - QQ Playlist Square

    func fetchQQSquareData() {
        // 加载分类（只加载一次）
        if qqPlaylistCategories.isEmpty {
            fetchQQCategories()
        }
        // 加载歌单
        if !qqSquarePlaylists.isEmpty { return }
        loadQQSquarePlaylists(reset: true)
    }

    func refreshQQSquare() {
        loadQQSquarePlaylists(reset: true)
    }
    
    func fetchQQCategories() {
        apiService.fetchQQPlaylistCategories()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] categories in
                self?.qqPlaylistCategories = categories
            })
            .store(in: &cancellables)
    }
    
    func loadQQSquarePlaylists(categoryId: Int? = nil, reset: Bool = false) {
        let catId = categoryId ?? selectedQQCategoryId
        
        if reset {
            qqSquarePlaylists = []
            qqSquarePage = 0
            hasMoreQQSquare = true
            isLoadingQQSquare = true
        } else {
            guard hasMoreQQSquare, !isLoadingMoreQQSquare else { return }
            isLoadingMoreQQSquare = true
        }
        
        apiService.fetchQQPlaylistsByCategory(
            categoryId: catId,
            sortId: qqSquareSortId,
            page: qqSquarePage,
            size: 30
        )
        .receive(on: DispatchQueue.main)
        .sink(receiveCompletion: { [weak self] _ in
            self?.isLoadingQQSquare = false
            self?.isLoadingMoreQQSquare = false
        }, receiveValue: { [weak self] result in
            guard let self = self else { return }
            if reset {
                self.qqSquarePlaylists = result.playlists
            } else {
                self.qqSquarePlaylists.append(contentsOf: result.playlists)
            }
            self.hasMoreQQSquare = result.hasMore
            self.qqSquarePage += 1
            let cacheKey = "qq_square_playlists_\(catId)"
            OptimizedCacheManager.shared.setObject(self.qqSquarePlaylists, forKey: cacheKey)
        })
        .store(in: &cancellables)
    }
    
    func loadMoreQQSquarePlaylists() {
        loadQQSquarePlaylists(reset: false)
    }
    
    func selectQQCategory(id: Int, name: String) {
        guard id != selectedQQCategoryId else { return }
        selectedQQCategoryId = id
        selectedQQCategoryName = name
        loadQQSquarePlaylists(categoryId: id, reset: true)
    }
}
