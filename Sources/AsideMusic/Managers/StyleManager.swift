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
    private let stylePersistenceKey = "selected_style_preference"
    
    private init() {
        restoreStyle()
        loadStylePreferences()
    }
    
    // MARK: - Actions
    
    func selectStyle(_ style: APIService.StyleTag?) {
        currentStyle = style
    }
    
    // MARK: - Persistence
    
    private func saveCurrentStyle() {
        if let style = currentStyle {
            if let data = try? JSONEncoder().encode(style) {
                UserDefaults.standard.set(data, forKey: stylePersistenceKey)
            }
        } else {
            UserDefaults.standard.removeObject(forKey: stylePersistenceKey)
        }
    }
    
    private func restoreStyle() {
        if let data = UserDefaults.standard.data(forKey: stylePersistenceKey),
           let style = try? JSONDecoder().decode(APIService.StyleTag.self, from: data) {
            currentStyle = style
            AppLogger.debug("StyleManager - Restored style: \(style.finalName)")
        }
    }
    
    func loadStylePreferences() {
        isLoadingStyles = true
        
        // 1. Try to fetch user preference
        api.fetchStylePreference()
            .flatMap { [weak self] (styles) -> AnyPublisher<[APIService.StyleTag], Error> in
                guard let self = self else { return Empty().eraseToAnyPublisher() }
                
                if !styles.isEmpty {
                    AppLogger.debug("StyleManager - Found \(styles.count) preference styles")
                    return Just(styles).setFailureType(to: Error.self).eraseToAnyPublisher()
                } else {
                    AppLogger.debug("StyleManager - Preference empty, fallback to full list")
        // 偏好为空，回退到完整列表
                    return self.api.fetchStyleList()
                }
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
        return currentStyle?.finalName ?? "Default"
    }
}
