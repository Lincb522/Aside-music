// NewSongExpressViewModel.swift
// 新歌速递 ViewModel

import Foundation
import Combine

@MainActor
class NewSongExpressViewModel: ObservableObject {
    // type: 0=全部, 7=华语, 96=欧美, 16=韩国, 8=日本
    struct SongType: Identifiable, Hashable {
        let id: Int
        let nameKey: String
    }
    
    static let songTypes: [SongType] = [
        SongType(id: 0, nameKey: "new_song_all"),
        SongType(id: 7, nameKey: "new_song_chinese"),
        SongType(id: 96, nameKey: "new_song_western"),
        SongType(id: 16, nameKey: "new_song_korean"),
        SongType(id: 8, nameKey: "new_song_japanese"),
    ]
    
    @Published var songs: [Song] = []
    @Published var isLoading = false
    @Published var selectedType: Int = 0
    
    private var cancellables = Set<AnyCancellable>()
    private var currentRequest: AnyCancellable?
    private var cache: [Int: [Song]] = [:]
    
    func loadSongs(type: Int) {
        selectedType = type
        
        // 缓存命中
        if let cached = cache[type] {
            songs = cached
            return
        }
        
        // 取消上一个请求
        currentRequest?.cancel()
        
        // 清空旧数据，显示 loading
        songs = []
        isLoading = true
        
        currentRequest = APIService.shared.fetchTopSongs(type: type)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    AppLogger.error("新歌速递加载失败: \(error)")
                }
            }, receiveValue: { [weak self] songs in
                guard let self, self.selectedType == type else { return }
                self.songs = songs
                self.cache[type] = songs
            })
    }
}
