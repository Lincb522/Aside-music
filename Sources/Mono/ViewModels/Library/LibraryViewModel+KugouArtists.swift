import Combine
import Foundation

extension LibraryViewModel {
    func fetchKugouArtistData(reset: Bool = false) {
        guard kugouArtistSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if !reset, !kugouArtists.isEmpty { return }

        if reset {
            kugouArtistRequest.cancel()
            kugouArtists = []
        }
        guard !kugouArtistRequest.isRunning else { return }
        isSearchingKugouArtists = false
        isLoadingKugouArtists = true

        let request = kugouArtistRequest.begin()
        kugouArtistRequest.cancellable = apiService.fetchKugouArtists(type: kugouArtistType, sex: kugouArtistSex)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self, self.kugouArtistRequest.isCurrent(request) else { return }
                self.kugouArtistRequest.finish(request)
                self.isLoadingKugouArtists = false
                if case .failure(let error) = completion {
                    AppLogger.warning("[KCM] 歌手列表加载失败: \(error.localizedDescription)")
                }
            }, receiveValue: { [weak self] page in
                guard let self, self.kugouArtistRequest.isCurrent(request) else { return }
                self.kugouArtists = page.artists
            })
    }

    func searchKugouArtists(keyword: String) {
        let query = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            fetchKugouArtistData(reset: true)
            return
        }

        isSearchingKugouArtists = true
        isLoadingKugouArtists = true
        let request = kugouArtistRequest.begin()
        kugouArtistRequest.cancellable = apiService.searchKugouArtists(keyword: query, page: 1, pageSize: 100)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self, self.kugouArtistRequest.isCurrent(request) else { return }
                self.kugouArtistRequest.finish(request)
                self.isLoadingKugouArtists = false
                if case .failure(let error) = completion {
                    AppLogger.warning("[KCM] 歌手搜索失败: \(error.localizedDescription)")
                }
            }, receiveValue: { [weak self] page in
                guard let self, self.kugouArtistRequest.isCurrent(request) else { return }
                self.kugouArtists = page.artists
            })
    }
}
