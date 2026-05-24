// NCMClient+Enhanced433.swift
// NeteaseCloudMusicApiEnhanced 4.33.0 新增接口与 Monologue 本地增强接口

import Foundation

// MARK: - Enhanced 4.33.0 APIs

extension NCMClient {

    /// 获取指定维度音乐排行榜详情。
    public func chartDetail(
        chartCode: String,
        targetId: String? = nil,
        targetType: String? = nil
    ) async throws -> APIResponse {
        var data: [String: Any] = ["chartCode": chartCode]
        if let targetId { data["targetId"] = targetId }
        if let targetType { data["targetType"] = targetType }
        return try await request("/api/chart/detail", data: data)
    }

    /// 获取指定维度音乐排行榜歌曲列表。
    public func chartSongDetail(
        chartCode: String,
        targetId: String? = nil,
        targetType: String? = nil
    ) async throws -> APIResponse {
        var data: [String: Any] = ["chartCode": chartCode]
        if let targetId { data["targetId"] = targetId }
        if let targetType { data["targetType"] = targetType }
        return try await request("/api/chart/song/detail", data: data)
    }

    /// 获取云盘上传 token、上传地址和资源信息。
    public func cloudUploadToken(
        md5: String,
        fileSize: Int,
        filename: String,
        bitrate: Int = 999000
    ) async throws -> APIResponse {
        return try await backendRoute("/cloud/upload/token", data: [
            "md5": md5,
            "fileSize": fileSize,
            "filename": filename,
            "bitrate": bitrate,
        ])
    }

    /// 云盘上传完成后提交歌曲信息并发布。
    public func cloudUploadComplete(
        songId: String,
        resourceId: String,
        md5: String,
        filename: String,
        song: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        bitrate: Int = 999000
    ) async throws -> APIResponse {
        var data: [String: Any] = [
            "songId": songId,
            "resourceId": resourceId,
            "md5": md5,
            "filename": filename,
            "bitrate": bitrate,
        ]
        if let song { data["song"] = song }
        if let artist { data["artist"] = artist }
        if let album { data["album"] = album }
        return try await backendRoute("/cloud/upload/complete", data: data)
    }

    /// 批量获取资源评论统计数据。
    public func commentInfoList(
        type: CommentType,
        ids: [Int]
    ) async throws -> APIResponse {
        return try await request("/api/resource/commentInfo/list", data: [
            "type": type.rawValue,
            "ids": ids.map(String.init).joined(separator: ","),
        ], crypto: .weapi)
    }

    /// 举报歌曲评论。
    public func commentReport(
        songId: Int,
        commentId: Int,
        reason: String
    ) async throws -> APIResponse {
        return try await request("/api/report/reportcomment", data: [
            "id": songId,
            "cid": commentId,
            "reason": reason,
        ])
    }

    /// DIFM 电台分类。
    public func djDifmAllStyleChannel(sources: String = "[0]") async throws -> APIResponse {
        return try await request("/api/dj/difm/all/style/channel/v2", data: ["sources": sources])
    }

    /// 收藏 DIFM 频道。
    public func djDifmChannelSubscribe(id: String) async throws -> APIResponse {
        return try await request("/api/dj/difm/channel/subscribe", data: ["id": id])
    }

    /// 取消收藏 DIFM 频道。
    public func djDifmChannelUnsubscribe(id: String) async throws -> APIResponse {
        return try await request("/api/dj/difm/channel/unsubscribe", data: ["id": id])
    }

    /// DIFM 电台播放列表。
    public func djDifmPlayingTracksList(
        channelId: String,
        limit: Int = 5,
        source: Int = 0
    ) async throws -> APIResponse {
        return try await request("/api/dj/difm/playing/tracks/list", data: [
            "channelId": channelId,
            "limit": limit,
            "source": source,
        ])
    }

    /// DIFM 已收藏频道列表。
    public func djDifmSubscribeChannelsGet(sources: String = "[0]") async throws -> APIResponse {
        return try await request("/api/dj/difm/subscribe/channels/get/v2", data: ["sources": sources])
    }

    /// 多级行政区划数据。
    public func lbsCityCode(bizCode: String = "") async throws -> APIResponse {
        return try await request("/api/lbs/city/code", data: ["bizCode": bizCode])
    }

    /// 获取音乐人 VIP 任务。
    public func musicianVipTasks() async throws -> APIResponse {
        return try await request("/api/nmusician/workbench/special/right/vip/info", data: [:])
    }

    /// 跑步漫游。
    public func radioSportGet(bpm: Int = 50) async throws -> APIResponse {
        return try await request("/api/radio/sport/get", data: ["bpm": bpm])
    }

    /// 助眠解压：获取标签下资源列表。
    public func satiResourceList(tag: String) async throws -> APIResponse {
        return try await request("/api/voice/sati/resource/list", data: [
            "tag": tag,
            "firstQuery": false,
        ])
    }

    /// 助眠解压：查看同类推荐。
    public func satiResourceListMore(id: String) async throws -> APIResponse {
        return try await request("/api/voice/sati/resource/list/more/v1", data: ["id": id])
    }

    /// 助眠解压：收藏或取消收藏资源。
    public func satiResourceSub(id: String, cancel: Bool = false) async throws -> APIResponse {
        return try await request("/api/voice/sati/resource/sub", data: [
            "id": id,
            "cancel": cancel,
        ])
    }

    /// 助眠解压：收藏列表。
    public func satiResourceSubList() async throws -> APIResponse {
        return try await request("/api/voice/sati/resource/sub/list", data: [:])
    }

    /// 助眠解压：标签列表。
    public func satiTagList() async throws -> APIResponse {
        return try await request("/api/voice/sati/tag/list", data: [:])
    }

    /// 助眠解压：特定时间场景推荐资源。
    public func satiTimesceneResourcesGet() async throws -> APIResponse {
        return try await request("/api/voice/sati/timescene/resources/get", data: [
            "firstQuery": false,
        ])
    }

    /// PC 端搜索建议。
    public func searchSuggestPC(keyword: String = "") async throws -> APIResponse {
        return try await request("/api/search/pc/suggest/keyword/get", data: ["keyword": keyword])
    }

    /// 灰色歌曲的其他版本推荐。
    public func songCopyrightRcmd(id: Int) async throws -> APIResponse {
        return try await request("/api/song/copyright/rcmd", data: ["songid": id])
    }

    /// 歌曲创作者信息。
    public func songCreators(id: Int) async throws -> APIResponse {
        return try await request("/api/song/creators", data: ["songId": id])
    }

    /// 新版喜欢歌曲接口。
    public func songLike(id: Int, uid: Int? = nil, like: Bool = true) async throws -> APIResponse {
        var data: [String: Any] = [
            "trackId": id,
            "like": like,
        ]
        if let uid { data["userid"] = uid }
        return try await request("/api/song/like", data: data)
    }

    /// 302 形式获取歌曲 v1 下载链接。
    public func songUrlV1302(id: Int, level: SoundQualityType = .exhigh) async throws -> APIResponse {
        return try await backendRoute("/song/url/v1/302", data: [
            "id": id,
            "level": level.rawValue,
        ])
    }

    /// 获取用户收藏歌单列表。
    public func userPlaylistCollect(
        uid: Int,
        limit: Int = 100,
        offset: Int = 0
    ) async throws -> APIResponse {
        return try await request("/api/user/playlist/collect", data: [
            "uid": uid,
            "limit": limit,
            "offset": offset,
        ])
    }

    /// 获取用户创建歌单列表。
    public func userPlaylistCreate(
        uid: Int,
        limit: Int = 100,
        offset: Int = 0
    ) async throws -> APIResponse {
        return try await request("/api/user/playlist/create", data: [
            "uid": uid,
            "limit": limit,
            "offset": offset,
        ])
    }

    /// 我创建的播客声音。
    public func voicelistMyCreated(limit: Int = 20) async throws -> APIResponse {
        return try await request("/api/social/my/created/voicelist/v1", data: ["limit": limit], crypto: .weapi)
    }
}

// MARK: - Monologue Backend Extensions

extension NCMClient {

    /// Monologue 本地增强：旧版 banner 兜底。
    public func bannerBackup(type: BannerType = .iphone) async throws -> APIResponse {
        return try await backendRoute("/banner/backup", data: ["type": type.rawValue])
    }

    /// Monologue 本地增强：播客首页组合 Tab。
    public func podcastHomeTab() async throws -> APIResponse {
        return try await backendRoute("/podcast/home/tab")
    }

    /// Monologue 本地增强：查询歌曲可用音质。
    public func songQualities(id: Int) async throws -> APIResponse {
        return try await backendRoute("/song/qualities", data: ["id": id])
    }

    /// Monologue 本地增强：GD 音源兜底链接。
    public func songUrlNcmget(id: Int, br: Int = 320) async throws -> APIResponse {
        return try await backendRoute("/song/url/ncmget", data: [
            "id": id,
            "br": br,
        ])
    }

    /// Monologue 本地增强：生成播放短链。
    public func playShorten(url: String) async throws -> APIResponse {
        return try await backendRoute("/play/shorten", data: ["url": url])
    }
}
