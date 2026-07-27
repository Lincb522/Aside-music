import SwiftUI
import Combine
@preconcurrency import QQMusicKit

extension LibraryViewModel {
    // MARK: - Charts

    func fetchTopLists() {
        if !topLists.isEmpty { return }

        if let cached = OptimizedCacheManager.shared.getObject(forKey: "top_charts_lists", type: [TopList].self), !cached.isEmpty {
            self.topLists = cached
            return
        }

        isLoadingCharts = true

        apiService.fetchTopLists()
            .sink(receiveCompletion: { [weak self] _ in
                self?.isLoadingCharts = false
            }, receiveValue: { [weak self] lists in
                self?.topLists = lists
                OptimizedCacheManager.shared.setObject(lists, forKey: "top_charts_lists")
            })
            .store(in: &cancellables)
    }

    func fetchKugouTopLists() {
        if !kugouTopLists.isEmpty { return }
        if let cached = OptimizedCacheManager.shared.getObject(forKey: "kcm_top_charts", type: [TopList].self),
           !cached.isEmpty {
            kugouTopLists = cached
            return
        }
        isLoadingKugouCharts = true
        apiService.fetchKugouTopLists()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoadingKugouCharts = false
                if case .failure(let error) = completion {
                    AppLogger.warning("KCM 榜单获取失败: \(error)")
                }
            }, receiveValue: { [weak self] lists in
                self?.kugouTopLists = lists
                OptimizedCacheManager.shared.setObject(lists, forKey: "kcm_top_charts")
            })
            .store(in: &cancellables)
    }
}
