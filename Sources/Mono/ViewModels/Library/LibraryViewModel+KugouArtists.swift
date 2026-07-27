import Combine
import Foundation

extension LibraryViewModel {
    func fetchKugouArtistData(reset: Bool = false) {
        guard kugouArtistSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if !reset, !kugouArtists.isEmpty { return }

        if reset { kugouArtists = [] }
        isSearchingKugouArtists = false
        isLoadingKugouArtists = true

        apiService.fetchKugouArtists(type: kugouArtistType, sex: kugouArtistSex)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoadingKugouArtists = false
                if case .failure(let error) = completion {
                    AppLogger.warning("[KCM] 歌手列表加载失败: \(error.localizedDescription)")
                }
            }, receiveValue: { [weak self] page in
                self?.kugouArtists = page.artists
            })
            .store(in: &cancellables)
    }

    func searchKugouArtists(keyword: String) {
        let query = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            fetchKugouArtistData(reset: true)
            return
        }

        isSearchingKugouArtists = true
        isLoadingKugouArtists = true
        apiService.searchKugouArtists(keyword: query, page: 1, pageSize: 100)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoadingKugouArtists = false
                if case .failure(let error) = completion {
                    AppLogger.warning("[KCM] 歌手搜索失败: \(error.localizedDescription)")
                }
            }, receiveValue: { [weak self] page in
                self?.kugouArtists = page.artists
            })
            .store(in: &cancellables)
    }
}
