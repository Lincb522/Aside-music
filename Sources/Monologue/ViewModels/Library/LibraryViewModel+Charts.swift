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
}
