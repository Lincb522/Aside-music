import Foundation
import Combine
import SwiftUI

@MainActor
class StyleManager: ObservableObject {
    static let shared = StyleManager()
    
    // MARK: - State
    
    /// 当前选中的风格，nil 表示默认（标准每日推荐）
    @Published var currentStyle: APIService.StyleTag? {
        didSet {
            saveCurrentStyle()
        }
    }
    
    /// 可用风格列表
    @Published var availableStyles: [APIService.StyleTag] = []
    
    @Published var isLoadingStyles = false
    
    private var cancellables = Set<AnyCancellable>()
    private let api = APIService.shared
    
    private init() {
        restoreStyle()
        loadStylePreferences()
    }
    
    // MARK: - Actions
    
    func selectStyle(_ style: APIService.StyleTag?) {
        currentStyle = style?.isDefaultRecommendTag == true ? nil : style
    }
    
    // MARK: - Persistence
    
    private func saveCurrentStyle() {
        if let style = currentStyle {
            if let data = try? JSONEncoder().encode(style) {
                UserDefaults.standard.set(data, forKey: AppConfig.StorageKeys.selectedStylePreference)
            }
        } else {
            UserDefaults.standard.removeObject(forKey: AppConfig.StorageKeys.selectedStylePreference)
        }
    }
    
    private func restoreStyle() {
        if let data = UserDefaults.standard.data(forKey: AppConfig.StorageKeys.selectedStylePreference),
           let style = try? JSONDecoder().decode(APIService.StyleTag.self, from: data) {
            if style.isDefaultRecommendTag {
                currentStyle = nil
                UserDefaults.standard.removeObject(forKey: AppConfig.StorageKeys.selectedStylePreference)
                AppLogger.debug("StyleManager - Restored default style")
            } else {
                currentStyle = style
                AppLogger.debug("StyleManager - Restored style: \(style.finalName)")
            }
        }
    }
    
    func loadStylePreferences() {
        isLoadingStyles = true
        
        // 1. Try to fetch user preference, then use the full tag list for the picker.
        api.fetchStylePreference()
            .flatMap { [weak self] (styles) -> AnyPublisher<[APIService.StyleTag], Error> in
                guard let self = self else { return Empty().eraseToAnyPublisher() }

                return self.api.fetchStyleList()
                    .map { fullList in
                        Self.mergeStyleTags(preferred: styles, fullList: fullList)
                    }
                    .catch { error -> AnyPublisher<[APIService.StyleTag], Error> in
                        AppLogger.error("StyleManager - Full list fallback failed: \(error)")
                        return Just(styles).setFailureType(to: Error.self).eraseToAnyPublisher()
                    }
                    .eraseToAnyPublisher()
            }
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    AppLogger.error("StyleManager - Load Error: \(error)")
                    self?.isLoadingStyles = false
                }
            }, receiveValue: { [weak self] styles in
                self?.availableStyles = styles
                self?.isLoadingStyles = false
            })
            .store(in: &cancellables)
    }
    
    // MARK: - Helpers
    
    var currentStyleName: String {
        return currentStyle?.localizedDisplayName ?? String(localized: "style_default")
    }

    private static func mergeStyleTags(
        preferred: [APIService.StyleTag],
        fullList: [APIService.StyleTag]
    ) -> [APIService.StyleTag] {
        var seen = Set<Int>()
        var merged: [APIService.StyleTag] = []

        for style in preferred + fullList where style.finalId > 0 && !style.isDefaultRecommendTag && !seen.contains(style.id) {
            seen.insert(style.id)
            merged.append(style)
        }

        return merged
    }
}
