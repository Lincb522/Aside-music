import Foundation

// MARK: - 歌单相关 API

public extension QQMusicClient {

    /// 获取歌单详情及歌曲
    /// - Parameters:
    ///   - songlistId: 歌单 ID
    ///   - dirid: 歌单 dirid
    ///   - num: 返回数量
    ///   - page: 页码
    ///   - onlySong: 是否仅返回歌曲信息
    ///   - tag: 是否返回标签
    func songlistDetail(
        songlistId: Int,
        dirid: Int = 0,
        num: Int = 10,
        page: Int = 1,
        onlySong: Bool = false,
        tag: Bool = true
    ) async throws -> JSON {
        try await requestWrapped("/songlist/get_detail", params: [
            "songlist_id": String(songlistId),
            "dirid": String(dirid),
            "num": String(num),
            "page": String(page),
            "onlysong": String(onlySong),
            "tag": String(tag),
        ])
    }

    /// 创建歌单（需要登录）
    /// - Parameter name: 歌单名称
    func createSonglist(name: String) async throws -> JSON {
        try await requestWrapped("/songlist/create", params: ["dirname": name])
    }

    /// 删除歌单（需要登录）
    /// - Parameter dirid: 歌单 dirid
    func deleteSonglist(dirid: Int) async throws -> JSON {
        try await requestWrapped("/songlist/delete", params: ["dirid": String(dirid)])
    }

    /// 添加歌曲到歌单（需要登录）
    /// - Parameters:
    ///   - dirid: 歌单 dirid
    ///   - songIds: 歌曲 ID 列表，逗号分隔
    func addSongsToSonglist(dirid: Int, songIds: String) async throws -> JSON {
        try await requestWrapped("/songlist/add_songs", params: [
            "dirid": String(dirid),
            "song_ids": songIds,
        ])
    }

    /// 从歌单删除歌曲（需要登录）
    /// - Parameters:
    ///   - dirid: 歌单 dirid
    ///   - songIds: 歌曲 ID 列表，逗号分隔
    func deleteSongsFromSonglist(dirid: Int, songIds: String) async throws -> JSON {
        try await requestWrapped("/songlist/del_songs", params: [
            "dirid": String(dirid),
            "song_ids": songIds,
        ])
    }
}
