import Foundation
import SwiftData

/// 历史记录仓库
@MainActor
final class HistoryRepository {
    private let context: ModelContext
    
    init(context: ModelContext = DatabaseManager.shared.context) {
        self.context = context
    }
    
    // MARK: - 播放历史
    
    /// 添加播放记录
    func addPlayHistory(song: Song, duration: Int = 0, completed: Bool = false) {
        let history = PlayHistory(from: song, duration: duration, completed: completed)
        context.insert(history)
        
        // 限制历史记录数量
        trimPlayHistory(maxCount: 500)
        
        try? context.save()
    }
    
    /// 获取播放历史
    func getPlayHistory(limit: Int = 100) -> [PlayHistory] {
        var descriptor = FetchDescriptor<PlayHistory>(
            sortBy: [SortDescriptor(\.playedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("❌ 获取播放历史失败: \(error)")
            return []
        }
    }
    
    /// 获取某首歌的播放历史
    func getPlayHistory(songId: Int) -> [PlayHistory] {
        let predicate = #Predicate<PlayHistory> { $0.songId == songId }
        let descriptor = FetchDescriptor<PlayHistory>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.playedAt, order: .reverse)]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            return []
        }
    }
    
    /// 清理播放历史（保留最近 N 条）
    private func trimPlayHistory(maxCount: Int) {
        let descriptor = FetchDescriptor<PlayHistory>(
            sortBy: [SortDescriptor(\.playedAt, order: .reverse)]
        )
        
        do {
            let allHistory = try context.fetch(descriptor)
            if allHistory.count > maxCount {
                for history in allHistory.dropFirst(maxCount) {
                    context.delete(history)
                }
            }
        } catch {
            print("❌ 清理播放历史失败: \(error)")
        }
    }
    
    /// 清空播放历史
    func clearPlayHistory() {
        do {
            try context.delete(model: PlayHistory.self)
            try context.save()
        } catch {
            print("❌ 清空播放历史失败: \(error)")
        }
    }
    
    // MARK: - 搜索历史
    
    /// 添加搜索记录
    func addSearchHistory(keyword: String, resultCount: Int = 0) {
        // 先删除相同关键词的旧记录
        let predicate = #Predicate<SearchHistory> { $0.keyword == keyword }
        try? context.delete(model: SearchHistory.self, where: predicate)
        
        // 添加新记录
        let history = SearchHistory(keyword: keyword, resultCount: resultCount)
        context.insert(history)
        
        // 限制搜索历史数量
        trimSearchHistory(maxCount: 50)
        
        try? context.save()
    }
    
    /// 获取搜索历史
    func getSearchHistory(limit: Int = 20) -> [SearchHistory] {
        var descriptor = FetchDescriptor<SearchHistory>(
            sortBy: [SortDescriptor(\.searchedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("❌ 获取搜索历史失败: \(error)")
            return []
        }
    }
    
    /// 删除搜索记录
    func deleteSearchHistory(keyword: String) {
        let predicate = #Predicate<SearchHistory> { $0.keyword == keyword }
        do {
            try context.delete(model: SearchHistory.self, where: predicate)
            try context.save()
        } catch {
            print("❌ 删除搜索记录失败: \(error)")
        }
    }
    
    /// 清理搜索历史（保留最近 N 条）
    private func trimSearchHistory(maxCount: Int) {
        let descriptor = FetchDescriptor<SearchHistory>(
            sortBy: [SortDescriptor(\.searchedAt, order: .reverse)]
        )
        
        do {
            let allHistory = try context.fetch(descriptor)
            if allHistory.count > maxCount {
                for history in allHistory.dropFirst(maxCount) {
                    context.delete(history)
                }
            }
        } catch {
            print("❌ 清理搜索历史失败: \(error)")
        }
    }
    
    /// 清空搜索历史
    func clearSearchHistory() {
        do {
            try context.delete(model: SearchHistory.self)
            try context.save()
        } catch {
            print("❌ 清空搜索历史失败: \(error)")
        }
    }
    
    // MARK: - 歌词缓存
    
    /// 保存歌词
    func saveLyrics(songId: Int, lyrics: String, translated: String? = nil) {
        // 先删除旧的
        let predicate = #Predicate<CachedLyrics> { $0.songId == songId }
        try? context.delete(model: CachedLyrics.self, where: predicate)
        
        // 添加新的
        let cached = CachedLyrics(songId: songId, lyrics: lyrics, translatedLyrics: translated)
        context.insert(cached)
        
        try? context.save()
    }
    
    /// 获取歌词
    func getLyrics(songId: Int) -> CachedLyrics? {
        let predicate = #Predicate<CachedLyrics> { $0.songId == songId }
        let descriptor = FetchDescriptor<CachedLyrics>(predicate: predicate)
        
        do {
            return try context.fetch(descriptor).first
        } catch {
            return nil
        }
    }
}
