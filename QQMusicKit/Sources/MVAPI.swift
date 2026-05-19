import Foundation

// MARK: - MV 相关 API

public extension QQMusicClient {

    /// 获取 MV 详情
    /// - Parameter vids: vid 列表，逗号分隔
    func mvDetail(vids: String) async throws -> JSON {
        try await requestWrapped("/mv/get_detail", params: ["vids": vids])
    }

    /// 获取 MV 播放链接
    /// - Parameter vids: vid 列表，逗号分隔
    /// - Returns: vid -> {mp4: {}, hls: {}} 的映射
    func mvURLs(vids: String) async throws -> JSON {
        try await requestWrapped("/mv/get_mv_urls", params: ["vids": vids])
    }
}
