import Foundation
import Combine
import SwiftUI

class StyleManager: ObservableObject {
    static let shared = StyleManager()
    
    // MARK: - State
    
    /// Current selected style. Nil means "Default" (Standard Daily Recommend).
    @Published var currentStyle: APIService.StyleTag? {
        didSet {
            saveCurrentStyle()
        }
    }
    
    /// List of available styles (User Preferences or Fallback).
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
        // Notification could be posted here if needed, but @Published should suffice for SwiftUI
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
            print("DEBUG: StyleManager - Restored style: \(style.finalName)")
        }
    }
    
    func loadStylePreferences() {
        isLoadingStyles = true
        
        // 1. Try to fetch user preference
        api.fetchStylePreference()
            .flatMap { [weak self] (styles) -> AnyPublisher<[APIService.StyleTag], Error> in
                guard let self = self else { return Empty().eraseToAnyPublisher() }
                
                if !styles.isEmpty {
                    print("DEBUG: StyleManager - Found \(styles.count) preference styles")
                    return Just(styles).setFailureType(to: Error.self).eraseToAnyPublisher()
                } else {
                    print("DEBUG: StyleManager - Preference empty, fallback to full list")
                    // 2. If empty, fallback to full list
                    return self.api.fetchStyleList()
                }
            }
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    print("DEBUG: StyleManager - Load Error: \(error)")
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
