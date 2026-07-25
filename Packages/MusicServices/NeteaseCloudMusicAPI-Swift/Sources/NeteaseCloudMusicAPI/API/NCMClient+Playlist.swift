// NCMClient+Playlist.swift
// 歌单相关 API 接口
// 歌单创建、删除、更新、详情、曲目管理、收藏、分类等

import Foundation

// MARK: - 歌单 API

extension NCMClient {

    /// 创建歌单
    /// - Parameters:
    ///   - name: 歌单名称
    ///   - privacy: 隐私设置，0 为普通歌单，10 为隐私歌单，默认 0
    ///   - type: 歌单类型，默认 "NORMAL"（可选 "VIDEO"、"SHARED"）
    /// - Returns: API 响应
    public func playlistCreate(
        name: String,
        privacy: Int = 0,
        type: String = "NORMAL"
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "name": name,
            "privacy": privacy,
            "type": type,
        ]
        return try await request(
            "/api/playlist/create",
            data: data,
            crypto: .weapi
        )
    }

    /// 删除歌单
    /// - Parameter ids: 歌单 ID 数组
    /// - Returns: API 响应
    public func playlistDelete(ids: [Int]) async throws -> APIResponse {
        let data: [String: Any] = [
            "ids": "[" + ids.map { String($0) }.joined(separator: ",") + "]",
        ]
        return try await request(
            "/api/playlist/remove",
            data: data,
            crypto: .weapi
        )
    }

    /// 更新歌单信息（批量更新名称、描述、标签）
    /// - Parameters:
    ///   - id: 歌单 ID
    ///   - name: 歌单名称
    ///   - desc: 歌单描述
    ///   - tags: 歌单标签
    /// - Returns: API 响应
    public func playlistUpdate(
        id: Int,
        name: String,
        desc: String,
        tags: String
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "/api/playlist/desc/update": "{\"id\":\(id),\"desc\":\"\(desc)\"}",
            "/api/playlist/tags/update": "{\"id\":\(id),\"tags\":\"\(tags)\"}",
            "/api/playlist/update/name": "{\"id\":\(id),\"name\":\"\(name)\"}",
        ]
        return try await request(
            "/api/batch",
            data: data
        )
    }

    /// 获取歌单详情
    /// - Parameters:
    ///   - id: 歌单 ID
    ///   - s: 收藏者数量，默认 8
    /// - Returns: API 响应，包含歌单详细信息
    public func playlistDetail(id: Int, s: Int = 8) async throws -> APIResponse {
        let data: [String: Any] = [
            "id": id,
            "n": 100000,
            "s": s,
        ]
        return try await request(
            "/api/v6/playlist/detail",
            data: data
        )
    }

    /// 获取歌单动态信息
    /// - Parameter id: 歌单 ID
    /// - Returns: API 响应，包含歌单动态信息（播放量、收藏量等）
    public func playlistDetailDynamic(id: Int) async throws -> APIResponse {
        let data: [String: Any] = [
            "id": id,
            "n": 100000,
            "s": 8,
        ]
        return try await request(
            "/api/playlist/detail/dynamic",
            data: data
        )
    }

    /// 添加/删除歌单曲目
    /// - Parameters:
    ///   - op: 操作类型，"add" 添加，"del" 删除
    ///   - pid: 歌单 ID
    ///   - trackIds: 歌曲 ID 数组
    /// - Returns: API 响应
    public func playlistTracks(
        op: String,
        pid: Int,
        trackIds: [Int]
    ) async throws -> APIResponse {
        let trackIdsJson = try JSONSerialization.data(withJSONObject: trackIds)
        let trackIdsString = String(data: trackIdsJson, encoding: .utf8) ?? "[]"
        let data: [String: Any] = [
            "op": op,
            "pid": pid,
            "trackIds": trackIdsString,
            "imme": "true",
        ]
        return try await request(
            "/api/playlist/manipulate/tracks",
            data: data
        )
    }

    /// 获取歌单所有曲目
    /// - Parameters:
    ///   - id: 歌单 ID
    ///   - limit: 每页数量，默认 10
    ///   - offset: 偏移量，默认 0
    /// - Returns: API 响应，包含歌曲详情列表
    public func playlistTrackAll(
        id: Int,
        limit: Int = 10,
        offset: Int = 0
    ) async throws -> APIResponse {
        // 先获取歌单详情拿到 trackIds，再批量获取歌曲详情
        let detailData: [String: Any] = [
            "id": id,
            "n": 100000,
            "s": 8,
        ]
        let detailRes = try await request(
            "/api/v6/playlist/detail",
            data: detailData
        )
        // 从歌单详情中提取 trackIds
        guard let playlist = detailRes.body["playlist"] as? [String: Any],
              let trackIds = playlist["trackIds"] as? [[String: Any]] else {
            return detailRes
        }
        // 根据 offset 和 limit 截取
        let sliced = trackIds.dropFirst(offset).prefix(limit)
        let c = "[" + sliced.map { item -> String in
            let trackId = item["id"] as? Int ?? 0
            return "{\"id\":\(trackId)}"
        }.joined(separator: ",") + "]"
        let songData: [String: Any] = [
            "c": c,
        ]
        return try await request(
            "/api/v3/song/detail",
            data: songData
        )
    }

    /// 收藏/取消收藏歌单
    /// - Parameters:
    ///   - id: 歌单 ID
    ///   - action: 操作类型（`.sub` 收藏，`.unsub` 取消收藏）
    ///   - checkToken: 可选校验 token（部分场景需要）
    /// - Returns: API 响应
    public func playlistSubscribe(
        id: Int,
        action: SubAction,
        checkToken: String? = nil
    ) async throws -> APIResponse {
        let path = action == .sub ? "subscribe" : "unsubscribe"
        var data: [String: Any] = [
            "id": id,
        ]
        if let checkToken = checkToken {
            data["checkToken"] = checkToken
        }
        return try await request(
            "/api/playlist/\(path)",
            data: data,
            crypto: .eapi
        )
    }

    /// 获取歌单收藏者
    /// - Parameters:
    ///   - id: 歌单 ID
    ///   - limit: 每页数量，默认 20
    ///   - offset: 偏移量，默认 0
    /// - Returns: API 响应，包含收藏者列表
    public func playlistSubscribers(
        id: Int,
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "id": id,
            "limit": limit,
            "offset": offset,
        ]
        return try await request(
            "/api/playlist/subscribers",
            data: data
        )
    }

    /// 获取歌单分类列表
    /// - Returns: API 响应，包含所有歌单分类
    public func playlistCatlist() async throws -> APIResponse {
        return try await request(
            "/api/playlist/catalogue",
            data: [:],
            crypto: .eapi
        )
    }

    /// 获取热门歌单分类
    /// - Returns: API 响应，包含热门歌单分类标签
    public func playlistHot() async throws -> APIResponse {
        return try await request(
            "/api/playlist/hottags",
            data: [:],
            crypto: .weapi
        )
    }

    /// 获取歌单列表（分类歌单）
    /// - Parameters:
    ///   - cat: 分类标签，默认 "全部"
    ///   - limit: 每页数量，默认 50
    ///   - offset: 偏移量，默认 0
    ///   - order: 排序方式，默认 `.hot`
    /// - Returns: API 响应，包含歌单列表
    public func topPlaylist(
        cat: String = "全部",
        limit: Int = 50,
        offset: Int = 0,
        order: ListOrder = .hot
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "cat": cat,
            "order": order.rawValue,
            "limit": limit,
            "offset": offset,
            "total": true,
        ]
        return try await request(
            "/api/playlist/list",
            data: data,
            crypto: .weapi
        )
    }

    /// 获取精品歌单
    /// - Parameters:
    ///   - cat: 分类标签，默认 "全部"
    ///   - limit: 每页数量，默认 50
    ///   - lasttime: 上一页最后一个歌单的 updateTime，默认 0
    /// - Returns: API 响应，包含精品歌单列表
    public func topPlaylistHighquality(
        cat: String = "全部",
        limit: Int = 50,
        offset: Int = 0,
        lasttime: Int = 0
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "cat": cat,
            "limit": limit,
            "offset": offset,
            "lasttime": lasttime,
            "total": true,
        ]
        return try await request(
            "/api/playlist/highquality/list",
            data: data,
            crypto: .weapi
        )
    }

    // MARK: - 以下为补充接口

    /// 获取歌单分类列表（新版）
    /// - Parameters:
    ///   - cat: 分类标签，默认 "全部"
    ///   - limit: 每页数量，默认 24
    /// - Returns: API 响应
    public func playlistCategoryList(cat: String = "全部", limit: Int = 24, offset: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = [
            "cat": cat,
            "limit": limit,
            "offset": offset,
            "newStyle": true,
        ]
        return try await request("/api/playlist/category/list", data: data)
    }

    /// 更新歌单描述
    /// - Parameters:
    ///   - id: 歌单 ID
    ///   - desc: 新描述
    /// - Returns: API 响应
    public func playlistDescUpdate(id: Int, desc: String) async throws -> APIResponse {
        let data: [String: Any] = ["id": id, "desc": desc]
        return try await request("/api/playlist/desc/update", data: data)
    }

    /// 获取相关歌单推荐
    /// - Parameter id: 歌单 ID
    /// - Returns: API 响应
    public func playlistDetailRcmdGet(id: Int) async throws -> APIResponse {
        let data: [String: Any] = [
            "scene": "playlist_head",
            "playlistId": id,
            "newStyle": "true",
        ]
        return try await request("/api/playlist/detail/rcmd/get", data: data)
    }

    /// 获取精品歌单标签
    /// - Returns: API 响应
    public func playlistHighqualityTags() async throws -> APIResponse {
        return try await request("/api/playlist/highquality/tags", data: [:], crypto: .weapi)
    }

    /// 歌单导入（文字/链接/元数据）
    /// - Parameters:
    ///   - playlistName: 歌单名称
    ///   - songs: 歌曲 JSON 字符串
    ///   - importStarPlaylist: 是否导入我喜欢的音乐，默认 false
    /// - Returns: API 响应
    public func playlistImportNameTaskCreate(
        playlistName: String = "",
        songs: String = "",
        importStarPlaylist: Bool = false
    ) async throws -> APIResponse {
        var data: [String: Any] = [
            "importStarPlaylist": importStarPlaylist,
            "playlistName": playlistName,
            "taskIdForLog": "",
            "songs": songs,
        ]
        if playlistName.isEmpty {
            data.removeValue(forKey: "playlistName")
        }
        return try await request("/api/playlist/import/name/task/create", data: data)
    }

    /// 获取歌单导入任务状态
    /// - Parameter id: 任务 ID
    /// - Returns: API 响应
    public func playlistImportTaskStatus(id: String) async throws -> APIResponse {
        let data: [String: Any] = [
            "taskIds": "[\"\(id)\"]",
        ]
        return try await request("/api/playlist/import/task/status/v2", data: data)
    }

    /// 获取我喜欢的歌单（mlog）
    /// - Parameters:
    ///   - time: 时间戳，默认 "-1"
    ///   - limit: 每页数量，默认 12
    /// - Returns: API 响应
    public func playlistMylike(time: String = "-1", limit: Int = 12, offset: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = [
            "time": time,
            "limit": limit,
            "offset": offset,
        ]
        return try await request("/api/mlog/playlist/mylike/bytime/get", data: data, crypto: .weapi)
    }

    /// 更新歌单名称
    /// - Parameters:
    ///   - id: 歌单 ID
    ///   - name: 新名称
    /// - Returns: API 响应
    public func playlistNameUpdate(id: Int, name: String) async throws -> APIResponse {
        let data: [String: Any] = ["id": id, "name": name]
        return try await request("/api/playlist/update/name", data: data)
    }

    /// 编辑歌单顺序
    /// - Parameter ids: 歌单 ID 排序字符串
    /// - Returns: API 响应
    public func playlistOrderUpdate(ids: String) async throws -> APIResponse {
        let data: [String: Any] = ["ids": ids]
        return try await request("/api/playlist/order/update", data: data, crypto: .weapi)
    }

    /// 公开隐私歌单
    /// - Parameter id: 歌单 ID
    /// - Returns: API 响应
    public func playlistPrivacy(id: Int) async throws -> APIResponse {
        let data: [String: Any] = ["id": id, "privacy": 0]
        return try await request("/api/playlist/update/privacy", data: data)
    }

    /// 更新歌单标签
    /// - Parameters:
    ///   - id: 歌单 ID
    ///   - tags: 标签字符串
    /// - Returns: API 响应
    public func playlistTagsUpdate(id: Int, tags: String) async throws -> APIResponse {
        let data: [String: Any] = ["id": id, "tags": tags]
        return try await request("/api/playlist/tags/update", data: data)
    }

    /// 添加歌曲到歌单（新版）
    /// - Parameters:
    ///   - pid: 歌单 ID
    ///   - ids: 歌曲 ID 数组
    /// - Returns: API 响应
    public func playlistTrackAdd(pid: Int, ids: [Int]) async throws -> APIResponse {
        let tracks = ids.map { "{\"type\":3,\"id\":\($0)}" }.joined(separator: ",")
        let data: [String: Any] = [
            "id": pid,
            "tracks": "[\(tracks)]",
        ]
        return try await request("/api/playlist/track/add", data: data, crypto: .weapi)
    }

    /// 从歌单删除歌曲（新版）
    /// - Parameters:
    ///   - id: 歌单 ID
    ///   - ids: 歌曲 ID 数组
    /// - Returns: API 响应
    public func playlistTrackDelete(id: Int, ids: [Int]) async throws -> APIResponse {
        let tracks = ids.map { "{\"type\":3,\"id\":\($0)}" }.joined(separator: ",")
        let data: [String: Any] = [
            "id": id,
            "tracks": "[\(tracks)]",
        ]
        return try await request("/api/playlist/track/delete", data: data, crypto: .weapi)
    }

    /// 歌单打卡（更新播放次数）
    /// - Parameter id: 歌单 ID
    /// - Returns: API 响应
    public func playlistUpdatePlaycount(id: Int) async throws -> APIResponse {
        let data: [String: Any] = ["id": id]
        return try await request("/api/playlist/update/playcount", data: data)
    }

    /// 获取最近播放的视频歌单
    /// - Returns: API 响应
    public func playlistVideoRecent() async throws -> APIResponse {
        return try await request("/api/playlist/video/recent", data: [:], crypto: .weapi)
    }
}
