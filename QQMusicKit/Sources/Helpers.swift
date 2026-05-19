import Foundation

// MARK: - 便捷工具

public extension QQMusicClient {

    /// 生成专辑封面链接
    /// - Parameters:
    ///   - albumMid: 专辑 mid
    ///   - size: 尺寸（150/300/500/800）
    static func coverURL(albumMid: String, size: Int = 300) -> URL? {
        URL(string: "https://y.gtimg.cn/music/photo_new/T002R\(size)x\(size)M000\(albumMid).jpg")
    }

    /// 生成歌手头像链接
    /// - Parameters:
    ///   - singerMid: 歌手 mid
    ///   - size: 尺寸（150/300/500/800）
    static func singerAvatarURL(singerMid: String, size: Int = 300) -> URL? {
        URL(string: "https://y.gtimg.cn/music/photo_new/T001R\(size)x\(size)M000\(singerMid).jpg")
    }
}

// MARK: - JSON 便捷扩展

public extension JSON {

    /// 从 JSON 数组中提取指定字段的字符串值
    /// - Parameter key: 字段名
    /// - Returns: 字符串数组
    func pluck(_ key: String) -> [String] {
        guard let arr = arrayValue else { return [] }
        return arr.compactMap { $0[key]?.stringValue }
    }

    /// 是否为空（null、空数组、空字典）
    var isEmpty: Bool {
        switch self {
        case .null: return true
        case .array(let v): return v.isEmpty
        case .object(let v): return v.isEmpty
        case .string(let v): return v.isEmpty
        default: return false
        }
    }
}

// MARK: - 从搜索结果提取歌曲信息的便捷方法

/// 从搜索结果 JSON 中提取常用歌曲字段
public struct SongInfo {
    /// 歌曲 mid
    public let mid: String
    /// 歌曲名
    public let title: String
    /// 歌手名（多个用 / 分隔）
    public let artist: String
    /// 专辑名
    public let albumName: String
    /// 专辑 mid（用于封面）
    public let albumMid: String

    /// 专辑封面链接
    public var coverURL: URL? {
        QQMusicClient.coverURL(albumMid: albumMid)
    }

    /// 从搜索结果 JSON 解析
    public init?(from json: JSON) {
        guard let obj = json.objectValue else { return nil }
        self.mid = obj["mid"]?.stringValue ?? obj["songmid"]?.stringValue ?? ""
        self.title = obj["title"]?.stringValue ?? obj["name"]?.stringValue ?? ""

        // 解析歌手
        if let singers = obj["singer"]?.arrayValue {
            self.artist = singers.compactMap { $0["name"]?.stringValue ?? $0["title"]?.stringValue }.joined(separator: " / ")
        } else {
            self.artist = ""
        }

        // 解析专辑
        self.albumName = obj["album"]?["name"]?.stringValue ?? obj["album"]?["title"]?.stringValue ?? ""
        self.albumMid = obj["album"]?["mid"]?.stringValue ?? obj["album"]?["pmid"]?.stringValue ?? ""

        if mid.isEmpty { return nil }
    }
}

public extension Array where Element == JSON {
    /// 将搜索结果转换为 SongInfo 数组
    var asSongs: [SongInfo] {
        compactMap { SongInfo(from: $0) }
    }
}
