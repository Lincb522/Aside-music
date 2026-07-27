import Foundation

// MARK: - 播放 URL 解析缓存

/// 已解析播放地址的短时内存缓存：
/// 点播 → 出声的主要延迟之一是播放 URL API 往返。
/// 手动切歌 / 上一首 / 来回重播时，同一首歌短时间内会反复解析同一个地址，
/// 这里按 (来源, 歌曲, 音质) 缓存成功结果，命中即跳过整个 API 往返。
///
/// 安全性：
/// · 只缓存成功结果，TTL 8 分钟（CDN 带签名地址普遍有效 30 分钟以上）；
/// · 播放失败重试（网络断流 / 音质切换超时）会先失效该曲目，
///   保证重试永远拿新鲜地址。
@MainActor
final class PlaybackURLCache {
    static let shared = PlaybackURLCache()

    private struct Entry {
        let result: APIService.SongUrlResult
        let fetchedAt: Date
    }

    private struct KugouEntry {
        let result: KCMPlaybackURLResult
        let fetchedAt: Date
    }

    /// 命中窗口：超过该时长视为可能过期，不再使用
    static let freshTTL: TimeInterval = 8 * 60
    /// 清扫窗口：写入时顺手清掉太老的条目
    private static let purgeTTL: TimeInterval = 20 * 60
    private static let maxEntries = 64

    private var store: [String: Entry] = [:]
    private var kugouStore: [String: KugouEntry] = [:]

    private init() {}

    // MARK: - Key

    static func neteaseKey(id: Int, level: String?, isPodcast: Bool = false) -> String {
        "ncm:\(id):\(level ?? "auto")\(isPodcast ? ":pc" : "")"
    }

    static func qqKey(mid: String, quality: String?) -> String {
        "qq:\(mid):\(quality ?? "auto")"
    }

    static func kugouKey(hash: String, quality: String?) -> String {
        "kcm:\(hash):\(quality ?? "auto")"
    }

    // MARK: - 读写

    func store(_ result: APIService.SongUrlResult, forKey key: String) {
        guard !result.url.isEmpty else { return }
        store[key] = Entry(result: result, fetchedAt: Date())
        purgeIfNeeded()
    }

    /// 取仍在新鲜期内的结果；过期条目顺手移除
    func fresh(forKey key: String, maxAge: TimeInterval = PlaybackURLCache.freshTTL) -> APIService.SongUrlResult? {
        guard let entry = store[key] else { return nil }
        guard Date().timeIntervalSince(entry.fetchedAt) < maxAge else {
            store.removeValue(forKey: key)
            return nil
        }
        return entry.result
    }

    func storeKugou(_ result: KCMPlaybackURLResult, forKey key: String) {
        kugouStore[key] = KugouEntry(result: result, fetchedAt: Date())
        purgeIfNeeded()
    }

    func freshKugou(
        forKey key: String,
        maxAge: TimeInterval = PlaybackURLCache.freshTTL
    ) -> KCMPlaybackURLResult? {
        guard let entry = kugouStore[key] else { return nil }
        guard Date().timeIntervalSince(entry.fetchedAt) < maxAge else {
            kugouStore.removeValue(forKey: key)
            return nil
        }
        return entry.result
    }

    // MARK: - 失效

    /// 失效某首歌的全部缓存（所有音质档位）。播放失败重试前调用。
    func invalidate(song: Song) {
        var prefixes = ["ncm:\(song.id):"]
        if let mid = song.qqMid {
            prefixes.append("qq:\(mid):")
        }
        if let hash = song.kugouHash, !hash.isEmpty {
            prefixes.append("kcm:\(hash):")
        }
        store = store.filter { key, _ in
            !prefixes.contains { key.hasPrefix($0) }
        }
        kugouStore = kugouStore.filter { key, _ in
            !prefixes.contains { key.hasPrefix($0) }
        }
    }

    func invalidateAll() {
        store.removeAll()
        kugouStore.removeAll()
    }

    private func purgeIfNeeded() {
        if store.count > Self.maxEntries {
            let sorted = store.sorted { $0.value.fetchedAt > $1.value.fetchedAt }
            store = Dictionary(uniqueKeysWithValues: Array(sorted.prefix(Self.maxEntries)))
        }
        if kugouStore.count > Self.maxEntries {
            let sorted = kugouStore.sorted { $0.value.fetchedAt > $1.value.fetchedAt }
            kugouStore = Dictionary(uniqueKeysWithValues: Array(sorted.prefix(Self.maxEntries)))
        }
        let cutoff = Date().addingTimeInterval(-Self.purgeTTL)
        store = store.filter { $0.value.fetchedAt > cutoff }
        kugouStore = kugouStore.filter { $0.value.fetchedAt > cutoff }
    }
}
