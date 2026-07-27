import Foundation
import Combine

extension LibraryViewModel {
    func fetchKugouSquareData() {
        if kugouPlaylistCategories.isEmpty {
            apiService.fetchKugouPlaylistCategories()
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        AppLogger.warning("[Kugou] 歌单分类加载失败: \(error.localizedDescription)")
                    }
                }, receiveValue: { [weak self] categories in
                    self?.kugouPlaylistCategories = categories
                })
                .store(in: &cancellables)
        }
        if kugouSquarePlaylists.isEmpty {
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
            guard !isLoadingKugouSquare else { return }
            isLoadingKugouSquare = true
            isLoadingMoreKugouSquare = false
            kugouSquarePage = 1
            hasMoreKugouSquare = true
            kugouSquarePlaylists = []
        } else {
            guard !isLoadingMoreKugouSquare, hasMoreKugouSquare else { return }
            isLoadingMoreKugouSquare = true
        }

        let page = reset ? 1 : kugouSquarePage + 1
        apiService.fetchKugouPlaylists(
            categoryID: selectedKugouCategoryID,
            page: page,
            pageSize: 30
        )
        .receive(on: DispatchQueue.main)
        .sink(receiveCompletion: { [weak self] completion in
            self?.isLoadingKugouSquare = false
            self?.isLoadingMoreKugouSquare = false
            if case .failure(let error) = completion {
                AppLogger.warning("[Kugou] 歌单广场加载失败: \(error.localizedDescription)")
            }
        }, receiveValue: { [weak self] result in
            guard let self else { return }
            if reset {
                self.kugouSquarePlaylists = result.playlists
            } else {
                let existingIDs = Set(self.kugouSquarePlaylists.map(\.id))
                self.kugouSquarePlaylists.append(contentsOf: result.playlists.filter { !existingIDs.contains($0.id) })
            }
            self.kugouSquarePage = page
            self.hasMoreKugouSquare = result.hasMore
        })
        .store(in: &cancellables)
    }

    func loadMoreKugouSquarePlaylists() {
        loadKugouSquarePlaylists(reset: false)
    }
}
