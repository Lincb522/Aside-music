import Foundation

// MARK: - 专辑相关 API

public extension QQMusicClient {

    /// 获取专辑详情
    /// - Parameter value: 专辑 id 或 mid
    func albumDetail(value: String) async throws -> JSON {
        try await requestWrapped("/album/get_detail", params: ["value": value])
    }

    /// 获取专辑歌曲列表
    /// - Parameters:
    ///   - value: 专辑 id 或 mid
    ///   - num: 返回数量
    ///   - page: 页码
    func albumSongs(value: String, num: Int = 10, page: Int = 1) async throws -> [JSON] {
        try await requestWrapped("/album/get_song", params: [
            "value": value,
            "num": String(num),
            "page": String(page),
        ])
    }

    /// 获取专辑封面链接（专用路由）
    /// - Parameters:
    ///   - mid: 专辑 mid
    ///   - size: 封面尺寸（150/300/500/800）
    /// - Returns: 封面图片 URL
    static func albumCoverURL(mid: String, size: Int = 300) -> URL? {
        URL(string: "https://y.gtimg.cn/music/photo_new/T002R\(size)x\(size)M000\(mid).jpg")
    }
}
