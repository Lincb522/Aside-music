// NCMClient+Cloud.swift
// 云盘相关 API 接口
// 云盘歌曲列表、详情、删除、匹配、导入等

import Foundation

// MARK: - 云盘 API

extension NCMClient {

    /// 获取云盘歌曲列表
    /// - Parameters:
    ///   - limit: 每页数量，默认 30
    ///   - offset: 偏移量，默认 0
    /// - Returns: API 响应，包含云盘歌曲列表
    public func userCloud(
        limit: Int = 30,
        offset: Int = 0
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "limit": limit,
            "offset": offset,
        ]
        return try await request(
            "/api/v1/cloud/get",
            data: data,
            crypto: .weapi
        )
    }

    /// 获取云盘歌曲详情
    /// - Parameter ids: 歌曲 ID 数组
    /// - Returns: API 响应，包含云盘歌曲详细信息
    public func userCloudDetail(ids: [Int]) async throws -> APIResponse {
        let songIds = ids.map { ["id": $0] }
        let songIdsData = try JSONSerialization.data(withJSONObject: songIds)
        let songIdsStr = String(data: songIdsData, encoding: .utf8) ?? "[]"
        let data: [String: Any] = [
            "songIds": songIdsStr,
        ]
        return try await request(
            "/api/v1/cloud/get/byids",
            data: data,
            crypto: .weapi
        )
    }

    /// 删除云盘歌曲
    /// - Parameter ids: 歌曲 ID 数组
    /// - Returns: API 响应
    public func userCloudDel(ids: [Int]) async throws -> APIResponse {
        let data: [String: Any] = [
            "songIds": ids,
        ]
        return try await request(
            "/api/cloud/del",
            data: data,
            crypto: .weapi
        )
    }

    /// 云盘歌曲匹配
    /// - Parameters:
    ///   - uid: 用户 ID
    ///   - sid: 云盘歌曲 ID
    ///   - asid: 匹配目标歌曲 ID
    /// - Returns: API 响应
    public func cloudMatch(uid: Int, sid: Int, asid: Int) async throws -> APIResponse {
        let data: [String: Any] = [
            "userId": uid,
            "songId": sid,
            "adjustSongId": asid,
        ]
        return try await request(
            "/api/cloud/user/song/match",
            data: data,
            crypto: .weapi
        )
    }

    /// 云盘歌曲导入（两步操作：先检查再导入）
    /// - Parameters:
    ///   - md5: 文件 MD5
    ///   - songId: 歌曲 ID，默认 -2
    ///   - bitrate: 码率
    ///   - fileSize: 文件大小
    ///   - song: 歌曲名
    ///   - artist: 歌手名，默认 "未知"
    ///   - album: 专辑名，默认 "未知"
    ///   - fileType: 文件类型（如 "mp3"、"flac"）
    /// - Returns: API 响应
    public func cloudImport(
        md5: String,
        songId: Int = -2,
        bitrate: Int,
        fileSize: Int,
        song: String,
        artist: String = "未知",
        album: String = "未知",
        fileType: String = "mp3"
    ) async throws -> APIResponse {
        // 第一步：检查文件
        let checkData: [String: Any] = [
            "uploadType": 0,
            "songs": "[{\"md5\":\"\(md5)\",\"songId\":\(songId),\"bitrate\":\(bitrate),\"fileSize\":\(fileSize)}]",
        ]
        let checkRes = try await request("/api/cloud/upload/check/v2", data: checkData)

        // 从检查结果中获取 songId
        let resultSongId: Int
        if let dataArr = checkRes.body["data"] as? [[String: Any]],
           let first = dataArr.first,
           let sid = first["songId"] as? Int {
            resultSongId = sid
        } else {
            resultSongId = songId
        }

        // 第二步：导入歌曲
        let importData: [String: Any] = [
            "uploadType": 0,
            "songs": "[{\"songId\":\(resultSongId),\"bitrate\":\(bitrate),\"song\":\"\(song)\",\"artist\":\"\(artist)\",\"album\":\"\(album)\",\"fileName\":\"\(song).\(fileType)\"}]",
        ]
        return try await request("/api/cloud/user/song/import", data: importData)
    }

    // MARK: - 以下为补充接口

    /// 获取云盘歌词
    /// - Parameters:
    ///   - uid: 用户 ID
    ///   - sid: 歌曲 ID
    /// - Returns: API 响应
    public func cloudLyricGet(uid: Int, sid: Int) async throws -> APIResponse {
        let data: [String: Any] = [
            "userId": uid,
            "songId": sid,
            "lv": -1,
            "kv": -1,
        ]
        return try await request("/api/cloud/lyric/get", data: data, crypto: .eapi)
    }
}
