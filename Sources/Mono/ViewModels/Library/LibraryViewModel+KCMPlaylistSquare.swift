import Foundation
import Combine

extension LibraryViewModel {
    func fetchKugouSquareData() {
        if kugouPlaylistCategories.isEmpty, !kugouCategoryRequest.isRunning {
            let request = kugouCategoryRequest.begin()
            kugouCategoryRequest.cancellable = apiService.fetchKugouPlaylistCategories()
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] completion in
                    guard let self, self.kugouCategoryRequest.isCurrent(request) else { return }
                    self.kugouCategoryRequest.finish(request)
                    if case .failure(let error) = completion {
                        AppLogger.warning("[Kugou] 歌单分类加载失败: \(error.localizedDescription)")
                    }
                }, receiveValue: { [weak self] categories in
                    guard let self, self.kugouCategoryRequest.isCurrent(request) else { return }
                    self.kugouPlaylistCategories = categories
                })
        }
        if kugouSquarePlaylists.isEmpty, !kugouSquareRequest.isRunning {
            loadKugouSquarePlaylists(reset: true)
        }
    }

    func selectKugouCategory(_ category: KCMPlaylistCategory) {
        guard selectedKugouCategoryID != category.id else { return }
        selectedKugouCategoryID = category.id
        loadKugouSquarePlaylists(reset: true)
    }

    func loadKugouSquarePlaylists(reset: Bool = false) {
        if reset {
            kugouSquareRequest.cancel()
            isLoadingKugouSquare = true
            isLoadingMoreKugouSquare = false
            kugouSquarePage = 1
            hasMoreKugouSquare = true
            kugouSquarePlaylists = []
        } else {
            guard !kugouSquareRequest.isRunning else { return }
            guard !isLoadingMoreKugouSquare, hasMoreKugouSquare else { return }
            isLoadingMoreKugouSquare = true
        }

        let page = reset ? 1 : kugouSquarePage + 1
        let request = kugouSquareRequest.begin()
        kugouSquareRequest.cancellable = apiService.fetchKugouPlaylists(
            categoryID: selectedKugouCategoryID,
            page: page,
            pageSize: 30
        )
        .receive(on: DispatchQueue.main)
        .sink(receiveCompletion: { [weak self] completion in
            guard let self, self.kugouSquareRequest.isCurrent(request) else { return }
            self.kugouSquareRequest.finish(request)
            self.isLoadingKugouSquare = false
            self.isLoadingMoreKugouSquare = false
            if case .failure(let error) = completion {
                AppLogger.warning("[Kugou] 歌单广场加载失败: \(error.localizedDescription)")
            }
        }, receiveValue: { [weak self] result in
            guard let self, self.kugouSquareRequest.isCurrent(request) else { return }
            if reset {
                self.kugouSquarePlaylists = result.playlists
            } else {
                let existingIDs = Set(self.kugouSquarePlaylists.map(\.id))
                self.kugouSquarePlaylists.append(contentsOf: result.playlists.filter { !existingIDs.contains($0.id) })
            }
            self.kugouSquarePage = page
            self.hasMoreKugouSquare = result.hasMore
        })

    }

    func loadMoreKugouSquarePlaylists() {
        loadKugouSquarePlaylists(reset: false)
    }
}
