import SwiftUI
import Combine
@preconcurrency import QQMusicKit

extension LibraryViewModel {
    // MARK: - QQ Charts

    func fetchQQTopLists() {
        if !qqTopLists.isEmpty { return }

        if let cached = OptimizedCacheManager.shared.getObject(forKey: "qq_top_charts", type: [QQTopListGroup].self), !cached.isEmpty {
            self.qqTopLists = cached
            return
        }

        isLoadingQQCharts = true
        apiService.fetchQQTopCategory()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] _ in
                self?.isLoadingQQCharts = false
            }, receiveValue: { [weak self] groups in
                self?.qqTopLists = groups
                OptimizedCacheManager.shared.setObject(groups, forKey: "qq_top_charts")
            })
            .store(in: &cancellables)
    }
}
