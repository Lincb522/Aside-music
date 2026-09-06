import SwiftUI
import Combine
@preconcurrency import QQMusicKit

extension LibraryViewModel {
    func fetchQQTopLists() {
        guard qqTopLists.isEmpty, !qqChartsRequest.isRunning else { return }
        let request = qqChartsRequest.begin()
        isLoadingQQCharts = true
        qqChartsRequest.task = Task { @MainActor [weak self] in
            guard !Task.isCancelled else { return }
            let cached = await OptimizedCacheManager.shared.getObjectAsync(
                forKey: "qq_top_charts", type: [QQTopListGroup].self
            )
            guard let self, !Task.isCancelled, self.qqChartsRequest.isCurrent(request) else { return }
            if let cached, !cached.isEmpty {
                self.qqTopLists = cached
                self.isLoadingQQCharts = false
                self.qqChartsRequest.finish(request)
                return
            }

            self.qqChartsRequest.cancellable = self.apiService.fetchQQTopCategory()
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] _ in
                    guard let self, self.qqChartsRequest.isCurrent(request) else { return }
                    self.qqChartsRequest.finish(request)
                    self.isLoadingQQCharts = false
                }, receiveValue: { [weak self] groups in
                    guard let self, self.qqChartsRequest.isCurrent(request) else { return }
                    self.qqTopLists = groups
                    OptimizedCacheManager.shared.setObject(groups, forKey: "qq_top_charts")
                })
        }
    }

}
