// NCMClient+Misc.swift
// 其他 API 接口
// Banner、批量请求、国家编码、日历、相似推荐、FM 垃圾桶、签到、资源点赞、
// 一起听、听歌足迹、音乐人、粉丝中心、曲风、UGC、声音/播客、动态、话题、
// Mlog、乐谱、首页等

import Foundation

// MARK: - 其他 API

extension NCMClient {

    /// 获取 Banner 列表
    /// - Parameter type: Banner 客户端类型，默认 `.iphone`
    /// - Returns: API 响应，包含 Banner 列表
    public func banner(type: BannerType = .iphone) async throws -> APIResponse {
        // Node.js 原版将数字映射为字符串: 0→pc, 1→android, 2→iphone, 3→ipad
        let clientTypeMap: [BannerType: String] = [
            .pc: "pc",
            .android: "android",
            .iphone: "iphone",
            .ipad: "ipad",
        ]
        let data: [String: Any] = [
            "clientType": clientTypeMap[type] ?? "iphone",
        ]
        return try await request("/api/v2/banner/get", data: data)
    }

    /// 批量请求
    /// - Parameter requests: 请求字典，key 为 API 路径，value 为请求参数
    /// - Returns: API 响应，包含批量请求结果
    public func batch(requests: [String: [String: Any]]) async throws -> APIResponse {
        var data: [String: Any] = ["e_r": true]
        for (key, value) in requests {
            let jsonData = try JSONSerialization.data(withJSONObject: value)
            data[key] = String(data: jsonData, encoding: .utf8) ?? "{}"
        }
        return try await request("/api/batch", data: data)
    }

    /// 获取国家编码列表
    public func countriesCodeList() async throws -> APIResponse {
        return try await request("/api/lbs/countries/v1", data: [:])
    }

    /// 获取日历
    public func calendar(startTime: Int = 0, endTime: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = ["startTime": startTime, "endTime": endTime]
        return try await request("/api/mcalendar/detail", data: data,
            crypto: .weapi
        )
    }

    /// 获取相似歌单
    /// - Parameters:
    ///   - id: 歌曲 ID
    ///   - limit: 每页数量，默认 50
    ///   - offset: 偏移量，默认 0
    public func simiPlaylist(id: Int, limit: Int = 50, offset: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = ["songid": id, "limit": limit, "offset": offset]
        return try await request("/api/discovery/simiPlaylist", data: data, crypto: .weapi)
    }

    /// 获取相似歌曲
    /// - Parameters:
    ///   - id: 歌曲 ID
    ///   - limit: 每页数量，默认 50
    ///   - offset: 偏移量，默认 0
    public func simiSong(id: Int, limit: Int = 50, offset: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = ["songid": id, "limit": limit, "offset": offset]
        return try await request("/api/v1/discovery/simiSong", data: data, crypto: .weapi)
    }

    /// 获取相似 MV
    public func simiMv(mvid: Int) async throws -> APIResponse {
        let data: [String: Any] = ["mvid": mvid]
        return try await request("/api/discovery/simiMV", data: data, crypto: .weapi)
    }

    /// 获取相似用户（听歌相似）
    /// - Parameters:
    ///   - id: 歌曲 ID
    ///   - limit: 每页数量，默认 50
    ///   - offset: 偏移量，默认 0
    public func simiUser(id: Int, limit: Int = 50, offset: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = ["songid": id, "limit": limit, "offset": offset]
        return try await request("/api/discovery/simiUser", data: data, crypto: .weapi)
    }

    /// FM 垃圾桶（不喜欢该歌曲）
    /// - Parameters:
    ///   - id: 歌曲 ID
    ///   - alg: 推荐算法标识，默认 "RT"
    ///   - time: 播放时长（秒），默认 25
    public func fmTrash(id: Int, alg: String = "RT", time: Int = 25) async throws -> APIResponse {
        let data: [String: Any] = ["songId": id, "alg": alg, "time": time]
        return try await request("/api/radio/trash/add", data: data, crypto: .weapi)
    }

    /// 每日签到
    public func dailySignin(type: DailySigninType = .android) async throws -> APIResponse {
        return try await request("/api/point/dailyTask", data: ["type": type.rawValue])
    }

    /// 资源点赞/取消点赞
    public func resourceLike(id: Int, type: ResourceType, like: Bool) async throws -> APIResponse {
        let threadPrefix: String
        switch type {
        case .mv: threadPrefix = "R_MV_5_"
        case .dj: threadPrefix = "A_DJ_1_"
        case .video: threadPrefix = "R_VI_62_"
        case .event: threadPrefix = "A_EV_2_"
        }
        return try await request(
            "/api/resource/\(like ? "like" : "unlike")",
            data: ["threadId": "\(threadPrefix)\(id)"],
            crypto: .weapi
        )
    }

    // MARK: - 一起听

    /// 一起听 - 接受邀请
    public func listentogetherAccept(roomId: String, inviterId: String) async throws -> APIResponse {
        let data: [String: Any] = ["refer": "inbox_invite", "roomId": roomId, "inviterId": inviterId]
        return try await request("/api/listen/together/play/invitation/accept", data: data)
    }

    /// 一起听 - 结束房间
    public func listentogetherEnd(roomId: String) async throws -> APIResponse {
        return try await request("/api/listen/together/end/v2", data: ["roomId": roomId])
    }

    /// 一起听 - 发送心跳
    public func listentogetherHeartbeat(roomId: String, songId: String, playStatus: String, progress: Int) async throws -> APIResponse {
        let data: [String: Any] = ["roomId": roomId, "songId": songId, "playStatus": playStatus, "progress": progress]
        return try await request("/api/listen/together/heartbeat", data: data)
    }

    /// 一起听 - 发送播放状态
    public func listentogetherPlayCommand(
        roomId: String, commandType: String, progress: Int = 0,
        playStatus: String, formerSongId: String, targetSongId: String, clientSeq: String
    ) async throws -> APIResponse {
        let commandInfo = "{\"commandType\":\"\(commandType)\",\"progress\":\(progress),\"playStatus\":\"\(playStatus)\",\"formerSongId\":\"\(formerSongId)\",\"targetSongId\":\"\(targetSongId)\",\"clientSeq\":\"\(clientSeq)\"}"
        let data: [String: Any] = ["roomId": roomId, "commandInfo": commandInfo]
        return try await request("/api/listen/together/play/command/report", data: data)
    }

    /// 一起听 - 房间情况
    public func listentogetherRoomCheck(roomId: String) async throws -> APIResponse {
        return try await request("/api/listen/together/room/check", data: ["roomId": roomId])
    }

    /// 一起听 - 创建房间
    public func listentogetherRoomCreate() async throws -> APIResponse {
        return try await request("/api/listen/together/room/create", data: ["refer": "songplay_more"])
    }

    /// 一起听 - 获取状态
    public func listentogetherStatus() async throws -> APIResponse {
        return try await request("/api/listen/together/status/get", data: [:], crypto: .weapi)
    }

    /// 一起听 - 更新播放列表
    public func listentogetherSyncListCommand(
        roomId: String, commandType: String, userId: Int, version: Int,
        randomList: String, displayList: String
    ) async throws -> APIResponse {
        let playlistParam = "{\"commandType\":\"\(commandType)\",\"version\":[{\"userId\":\(userId),\"version\":\(version)}],\"anchorSongId\":\"\",\"anchorPosition\":-1,\"randomList\":[\(randomList)],\"displayList\":[\(displayList)]}"
        let data: [String: Any] = ["roomId": roomId, "playlistParam": playlistParam]
        return try await request("/api/listen/together/sync/list/command/report", data: data)
    }

    /// 一起听 - 获取当前播放列表
    public func listentogetherSyncPlaylistGet(roomId: String) async throws -> APIResponse {
        return try await request("/api/listen/together/sync/playlist/get", data: ["roomId": roomId])
    }

    // MARK: - 听歌足迹

    /// 听歌足迹 - 本周/本月收听时长
    public func listenDataRealtimeReport(type: String = "week") async throws -> APIResponse {
        return try await request("/api/content/activity/listen/data/realtime/report", data: ["type": type])
    }

    /// 听歌足迹 - 周/月/年收听报告
    public func listenDataReport(type: String = "week", endTime: String? = nil) async throws -> APIResponse {
        var data: [String: Any] = ["type": type]
        if let endTime = endTime { data["endTime"] = endTime }
        return try await request("/api/content/activity/listen/data/report", data: data)
    }

    /// 听歌足迹 - 今日收听
    public func listenDataTodaySong() async throws -> APIResponse {
        return try await request("/api/content/activity/listen/data/today/song/play/rank", data: [:])
    }

    /// 听歌足迹 - 总收听时长
    public func listenDataTotal() async throws -> APIResponse {
        return try await request("/api/content/activity/listen/data/total", data: [:])
    }

    /// 听歌足迹 - 年度听歌足迹
    public func listenDataYearReport() async throws -> APIResponse {
        return try await request("/api/content/activity/listen/data/year/report", data: [:])
    }

    // MARK: - 音乐人

    /// 获取账号云豆数
    public func musicianCloudbean() async throws -> APIResponse {
        return try await request("/api/cloudbean/get", data: [:], crypto: .weapi)
    }

    /// 领取云豆
    public func musicianCloudbeanObtain(id: Int, period: String) async throws -> APIResponse {
        let data: [String: Any] = ["userMissionId": id, "period": period]
        return try await request("/api/nmusician/workbench/mission/reward/obtain/new", data: data, crypto: .weapi)
    }

    /// 获取音乐人数据概况
    public func musicianDataOverview() async throws -> APIResponse {
        return try await request("/api/creator/musician/statistic/data/overview/get", data: [:], crypto: .weapi)
    }

    /// 获取音乐人歌曲播放趋势
    public func musicianPlayTrend(startTime: String, endTime: String) async throws -> APIResponse {
        let data: [String: Any] = ["startTime": startTime, "endTime": endTime]
        return try await request("/api/creator/musician/play/count/statistic/data/trend/get", data: data, crypto: .weapi)
    }

    /// 音乐人签到
    public func musicianSign() async throws -> APIResponse {
        return try await request("/api/creator/user/access", data: [:], crypto: .weapi)
    }

    /// 获取音乐人任务列表
    public func musicianTasks() async throws -> APIResponse {
        return try await request("/api/nmusician/workbench/mission/cycle/list", data: [:], crypto: .weapi)
    }

    /// 获取音乐人任务列表（新版）
    public func musicianTasksNew() async throws -> APIResponse {
        return try await request("/api/nmusician/workbench/mission/stage/list", data: [:], crypto: .weapi)
    }

    // MARK: - 粉丝中心

    /// 获取粉丝年龄比例
    public func fanscenterBasicinfoAgeGet() async throws -> APIResponse {
        return try await request("/api/fanscenter/basicinfo/age/get", data: [:])
    }

    /// 获取粉丝性别比例
    public func fanscenterBasicinfoGenderGet() async throws -> APIResponse {
        return try await request("/api/fanscenter/basicinfo/gender/get", data: [:])
    }

    /// 获取粉丝省份比例
    public func fanscenterBasicinfoProvinceGet() async throws -> APIResponse {
        return try await request("/api/fanscenter/basicinfo/province/get", data: [:])
    }

    /// 获取粉丝数量概览
    public func fanscenterOverviewGet() async throws -> APIResponse {
        return try await request("/api/fanscenter/overview/get", data: [:])
    }

    /// 获取粉丝来源趋势
    public func fanscenterTrendList(startTime: Int? = nil, endTime: Int? = nil, type: Int = 0) async throws -> APIResponse {
        let now = Int(Date().timeIntervalSince1970 * 1000)
        let data: [String: Any] = [
            "startTime": startTime ?? (now - 7 * 24 * 3600 * 1000),
            "endTime": endTime ?? now,
            "type": type,
        ]
        return try await request("/api/fanscenter/trend/list", data: data)
    }

    // MARK: - 曲风

    /// 获取曲风专辑
    public func styleAlbum(tagId: Int, cursor: Int = 0, size: Int = 20, sort: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = ["cursor": cursor, "size": size, "tagId": tagId, "sort": sort]
        return try await request("/api/style-tag/home/album", data: data, crypto: .weapi)
    }

    /// 获取曲风歌手
    public func styleArtist(tagId: Int, cursor: Int = 0, size: Int = 20) async throws -> APIResponse {
        let data: [String: Any] = ["cursor": cursor, "size": size, "tagId": tagId, "sort": 0]
        return try await request("/api/style-tag/home/artist", data: data, crypto: .weapi)
    }

    /// 获取曲风详情
    public func styleDetail(tagId: Int) async throws -> APIResponse {
        return try await request("/api/style-tag/home/head", data: ["tagId": tagId], crypto: .weapi)
    }

    /// 获取曲风列表
    public func styleList() async throws -> APIResponse {
        return try await request("/api/tag/list/get", data: [:], crypto: .weapi)
    }

    /// 获取曲风歌单
    public func stylePlaylist(tagId: Int, cursor: Int = 0, size: Int = 20) async throws -> APIResponse {
        let data: [String: Any] = ["cursor": cursor, "size": size, "tagId": tagId, "sort": 0]
        return try await request("/api/style-tag/home/playlist", data: data, crypto: .weapi)
    }

    /// 获取曲风偏好
    public func stylePreference() async throws -> APIResponse {
        return try await request("/api/tag/my/preference/get", data: [:], crypto: .weapi)
    }

    /// 获取曲风歌曲
    public func styleSong(tagId: Int, cursor: Int = 0, size: Int = 20, sort: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = ["cursor": cursor, "size": size, "tagId": tagId, "sort": sort]
        return try await request("/api/style-tag/home/song", data: data, crypto: .weapi)
    }

    // MARK: - UGC 百科

    /// 获取专辑简要百科信息
    public func ugcAlbumGet(id: Int) async throws -> APIResponse {
        return try await request("/api/rep/ugc/album/get", data: ["albumId": id])
    }

    /// 获取歌手简要百科信息
    public func ugcArtistGet(id: Int) async throws -> APIResponse {
        return try await request("/api/rep/ugc/artist/get", data: ["artistId": id])
    }

    /// 搜索歌手（UGC）
    public func ugcArtistSearch(keyword: String, limit: Int = 40, offset: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = ["keyword": keyword, "limit": limit, "offset": offset]
        return try await request("/api/rep/ugc/artist/search", data: data)
    }

    /// 获取用户贡献内容
    public func ugcDetail(type: Int = 1, auditStatus: String = "", limit: Int = 10, offset: Int = 0, order: String = "desc", sortBy: String = "createTime") async throws -> APIResponse {
        let data: [String: Any] = [
            "auditStatus": auditStatus, "limit": limit, "offset": offset,
            "order": order, "sortBy": sortBy, "type": type,
        ]
        return try await request("/api/rep/ugc/detail", data: data, crypto: .weapi)
    }

    /// 获取 MV 简要百科信息
    public func ugcMvGet(id: Int) async throws -> APIResponse {
        return try await request("/api/rep/ugc/mv/get", data: ["mvId": id])
    }

    /// 获取歌曲简要百科信息
    public func ugcSongGet(id: Int) async throws -> APIResponse {
        return try await request("/api/rep/ugc/song/get", data: ["songId": id])
    }

    /// 获取用户贡献条目、积分、云贝数量
    public func ugcUserDevote() async throws -> APIResponse {
        return try await request("/api/rep/ugc/user/devote", data: [:])
    }

    // MARK: - 声音/播客

    /// 删除声音
    public func voiceDelete(ids: String) async throws -> APIResponse {
        return try await request("/api/content/voice/delete", data: ["ids": ids])
    }

    /// 获取声音详情
    public func voiceDetail(id: Int) async throws -> APIResponse {
        return try await request("/api/voice/workbench/voice/detail", data: ["id": id])
    }

    /// 获取声音歌词
    public func voiceLyric(id: Int) async throws -> APIResponse {
        return try await request("/api/voice/lyric/get", data: ["programId": id])
    }

    /// 获取声音列表详情
    public func voicelistDetail(id: Int) async throws -> APIResponse {
        return try await request("/api/voice/workbench/voicelist/detail", data: ["id": id])
    }

    /// 获取声音列表中的声音
    public func voicelistList(voiceListId: Int, limit: Int = 200, offset: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = ["limit": limit, "offset": offset, "voiceListId": voiceListId]
        return try await request("/api/voice/workbench/voices/by/voicelist", data: data)
    }

    /// 搜索声音列表中的声音
    public func voicelistListSearch(
        voiceListId: Int, name: String? = nil, displayStatus: String? = nil,
        type: String? = nil, voiceFeeType: String? = nil, limit: Int = 200, offset: Int = 0
    ) async throws -> APIResponse {
        var data: [String: Any] = ["limit": limit, "offset": offset, "radioId": voiceListId]
        if let name = name { data["name"] = name }
        if let displayStatus = displayStatus { data["displayStatus"] = displayStatus }
        if let type = type { data["type"] = type }
        if let voiceFeeType = voiceFeeType { data["voiceFeeType"] = voiceFeeType }
        return try await request("/api/voice/workbench/voice/list", data: data)
    }

    /// 搜索播客
    public func voicelistSearch(keyword: String = "", limit: Int = 10, offset: Int = 30) async throws -> APIResponse {
        let data: [String: Any] = [
            "keyword": keyword,
            "scene": "normal",
            "limit": limit,
            "offset": offset,
            "e_r": true,
        ]
        return try await request("/api/search/voicelist/get", data: data)
    }

    /// 播客节目排序
    public func voicelistTrans(radioId: Int, programId: Int = 0, position: Int = 1, limit: Int = 200, offset: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = [
            "limit": limit, "offset": offset, "radioId": radioId,
            "programId": programId, "position": position,
        ]
        return try await request("/api/voice/workbench/radio/program/trans", data: data)
    }

    // MARK: - 广播电台

    /// 广播电台 - 分类/地区信息
    public func broadcastCategoryRegionGet() async throws -> APIResponse {
        return try await request("/api/voice/broadcast/category/region/get", data: [:])
    }

    /// 广播电台 - 我的收藏
    public func broadcastChannelCollectList(limit: Int = 99999, offset: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = [
            "contentType": "BROADCAST", "limit": limit, "offset": offset,
            "timeReverseOrder": "true", "startDate": "4762584922000",
        ]
        return try await request("/api/content/channel/collect/list", data: data)
    }

    /// 广播电台 - 电台信息
    public func broadcastChannelCurrentinfo(id: String) async throws -> APIResponse {
        return try await request("/api/voice/broadcast/channel/currentinfo", data: ["channelId": id])
    }

    /// 广播电台 - 全部电台
    public func broadcastChannelList(categoryId: String = "0", regionId: String = "0", limit: Int = 20, offset: Int = 0, lastId: String = "0", score: String = "-1") async throws -> APIResponse {
        let data: [String: Any] = [
            "categoryId": categoryId, "regionId": regionId,
            "limit": limit, "offset": offset, "lastId": lastId, "score": score,
        ]
        return try await request("/api/voice/broadcast/channel/list", data: data)
    }

    /// 广播电台 - 收藏/取消收藏
    public func broadcastSub(id: String, sub: Bool) async throws -> APIResponse {
        let data: [String: Any] = [
            "contentType": "BROADCAST", "contentId": id,
            "cancelCollect": sub ? "false" : "true",
        ]
        return try await request("/api/content/interact/collect", data: data)
    }

    // MARK: - 动态

    /// 获取动态列表
    public func event(pagesize: Int = 20, lasttime: Int = -1) async throws -> APIResponse {
        let data: [String: Any] = ["pagesize": pagesize, "lasttime": lasttime]
        return try await request("/api/v1/event/get", data: data, crypto: .weapi)
    }

    /// 删除动态
    public func eventDel(evId: Int) async throws -> APIResponse {
        return try await request("/api/event/delete", data: ["id": evId], crypto: .weapi)
    }

    /// 转发动态
    public func eventForward(evId: Int, uid: Int, forwards: String) async throws -> APIResponse {
        let data: [String: Any] = ["forwards": forwards, "id": evId, "eventUserId": uid]
        return try await request("/api/event/forward", data: data)
    }

    // MARK: - 话题

    /// 获取话题详情
    public func topicDetail(actid: Int) async throws -> APIResponse {
        return try await request("/api/act/detail", data: ["actid": actid], crypto: .weapi)
    }

    /// 获取话题热门动态
    public func topicDetailEventHot(actid: Int) async throws -> APIResponse {
        return try await request("/api/act/event/hot", data: ["actid": actid], crypto: .weapi)
    }

    /// 获取收藏的专栏
    public func topicSublist(limit: Int = 50, offset: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = ["limit": limit, "offset": offset, "total": true]
        return try await request("/api/topic/sublist", data: data, crypto: .weapi)
    }

    /// 获取热门话题
    public func hotTopic(limit: Int = 20, offset: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = ["limit": limit, "offset": offset]
        return try await request("/api/act/hot", data: data, crypto: .weapi)
    }

    // MARK: - Mlog

    /// 获取歌曲相关视频（Mlog）
    public func mlogMusicRcmd(songid: Int, mvid: Int = 0, limit: Int = 10, offset: Int = 0) async throws -> APIResponse {
        let data: [String: Any] = [
            "id": mvid, "type": 2, "rcmdType": 20,
            "limit": limit, "offset": offset, "extInfo": "{\"songId\":\(songid)}",
        ]
        return try await request("/api/mlog/rcmd/feed/list", data: data)
    }

    /// 将 Mlog ID 转为 Video ID
    public func mlogToVideo(id: String) async throws -> APIResponse {
        return try await request("/api/mlog/video/convert/id", data: ["mlogId": id], crypto: .weapi)
    }

    /// 获取 Mlog 链接
    public func mlogUrl(id: String, res: Int = 1080) async throws -> APIResponse {
        let data: [String: Any] = ["id": id, "resolution": res, "type": 1]
        return try await request("/api/mlog/detail/v1", data: data, crypto: .weapi)
    }

    // MARK: - 乐谱

    /// 获取乐谱列表
    public func sheetList(id: Int, ab: String = "b") async throws -> APIResponse {
        let data: [String: Any] = ["id": id, "abTest": ab]
        return try await request("/api/music/sheet/list/v1", data: data)
    }

    /// 获取乐谱预览
    public func sheetPreview(id: Int) async throws -> APIResponse {
        return try await request("/api/music/sheet/preview/info", data: ["id": id])
    }

    // MARK: - 首页

    /// 首页发现 Block Page
    public func homepageBlockPage(refresh: Bool = false, cursor: String? = nil) async throws -> APIResponse {
        var data: [String: Any] = ["refresh": refresh]
        if let cursor = cursor { data["cursor"] = cursor }
        return try await request("/api/homepage/block/page", data: data, crypto: .weapi)
    }

    /// 首页发现 Dragon Ball（入口图标）
    public func homepageDragonBall() async throws -> APIResponse {
        return try await request("/api/homepage/dragon/ball/static", data: [:])
    }

    // MARK: - 其他杂项

    /// 初始化用户名
    public func activateInitProfile(nickname: String) async throws -> APIResponse {
        return try await request("/api/activate/initProfile", data: ["nickname": nickname])
    }

    /// 私人 DJ 推荐
    public func aidjContentRcmd(latitude: Double? = nil, longitude: Double? = nil) async throws -> APIResponse {
        var extInfo: [String: Any] = [
            "noAidjToAidj": false,
            "lastRequestTimestamp": Int(Date().timeIntervalSince1970 * 1000),
            "listenedTs": false,
        ]
        if let lat = latitude, let lon = longitude {
            extInfo["lbsInfoList"] = [["lat": lat, "lon": lon, "time": Int(Date().timeIntervalSince1970)]]
        }
        let extInfoData = try JSONSerialization.data(withJSONObject: extInfo)
        let extInfoStr = String(data: extInfoData, encoding: .utf8) ?? "{}"
        return try await request("/api/aidj/content/rcmd/info", data: ["extInfo": extInfoStr])
    }

    /// 检测手机号码是否已注册
    public func cellphoneExistenceCheck(phone: String, countrycode: String = "86") async throws -> APIResponse {
        let data: [String: Any] = ["cellphone": phone, "countrycode": countrycode]
        return try await request("/api/cellphone/existence/check", data: data)
    }

    /// 获取达人用户信息
    public func creatorAuthinfoGet() async throws -> APIResponse {
        return try await request("/api/user/creator/authinfo/get", data: [:])
    }

    /// 通过昵称获取用户 ID
    public func getUserids(nicknames: String) async throws -> APIResponse {
        return try await request("/api/user/getUserIds", data: ["nicknames": nicknames], crypto: .weapi)
    }

    /// 抱一抱评论
    public func hugComment(uid: Int, cid: Int, sid: Int, type: Int = 0) async throws -> APIResponse {
        let prefix: String
        switch type {
        case 1: prefix = "R_MV_5_"
        case 2: prefix = "A_PL_0_"
        case 3: prefix = "R_AL_3_"
        case 4: prefix = "A_DJ_1_"
        case 5: prefix = "R_VI_62_"
        case 6: prefix = "A_EV_2_"
        default: prefix = "R_SO_4_"
        }
        let data: [String: Any] = ["targetUserId": uid, "commentId": cid, "threadId": "\(prefix)\(sid)"]
        return try await request("/api/v2/resource/comments/hug/listener", data: data)
    }

    /// 回忆坐标
    public func musicFirstListenInfo(id: Int) async throws -> APIResponse {
        return try await request("/api/content/activity/music/first/listen/info", data: ["songId": id])
    }

    /// 检查昵称是否重复
    public func nicknameCheck(nickname: String) async throws -> APIResponse {
        return try await request("/api/nickname/duplicated", data: ["nickname": nickname], crypto: .weapi)
    }

    /// 获取私信和通知数量
    public func plCount() async throws -> APIResponse {
        return try await request("/api/pl/count", data: [:], crypto: .weapi)
    }

    /// 智能播放列表
    public func playmodeIntelligenceList(id: Int, pid: Int, sid: Int? = nil, count: Int = 1) async throws -> APIResponse {
        let data: [String: Any] = [
            "songId": id, "type": "fromPlayOne",
            "playlistId": pid, "startMusicId": sid ?? id, "count": count,
        ]
        return try await request("/api/playmode/intelligence/list", data: data)
    }

    /// 云随机播放
    public func playmodeSongVector(ids: String) async throws -> APIResponse {
        return try await request("/api/playmode/song/vector/get", data: ["ids": ids])
    }

    /// 获取最近听歌列表
    public func recentListenList() async throws -> APIResponse {
        return try await request("/api/pc/recent/listen/list", data: [:])
    }

    /// 获取最近播放 - 专辑
    public func recordRecentAlbum(limit: Int = 100, offset: Int = 0) async throws -> APIResponse {
        return try await request("/api/play-record/album/list", data: ["limit": limit, "offset": offset], crypto: .weapi)
    }

    /// 获取最近播放 - 电台
    public func recordRecentDj(limit: Int = 100, offset: Int = 0) async throws -> APIResponse {
        return try await request("/api/play-record/djradio/list", data: ["limit": limit, "offset": offset], crypto: .weapi)
    }

    /// 获取最近播放 - 歌单
    public func recordRecentPlaylist(limit: Int = 100, offset: Int = 0) async throws -> APIResponse {
        return try await request("/api/play-record/playlist/list", data: ["limit": limit, "offset": offset], crypto: .weapi)
    }

    /// 获取最近播放 - 歌曲
    public func recordRecentSong(limit: Int = 100, offset: Int = 0) async throws -> APIResponse {
        return try await request("/api/play-record/song/list", data: ["limit": limit, "offset": offset], crypto: .weapi)
    }

    /// 获取最近播放 - 视频
    public func recordRecentVideo(limit: Int = 100, offset: Int = 0) async throws -> APIResponse {
        return try await request("/api/play-record/newvideo/list", data: ["limit": limit, "offset": offset], crypto: .weapi)
    }

    /// 获取最近播放 - 声音
    public func recordRecentVoice(limit: Int = 100, offset: Int = 0) async throws -> APIResponse {
        return try await request("/api/play-record/voice/list", data: ["limit": limit, "offset": offset], crypto: .weapi)
    }

    /// 分享资源到动态
    public func shareResource(type: String = "song", id: String = "", msg: String = "") async throws -> APIResponse {
        let data: [String: Any] = ["type": type, "msg": msg, "id": id]
        return try await request("/api/share/friends/resource", data: data)
    }

    /// 获取签到快乐信息
    public func signHappyInfo() async throws -> APIResponse {
        return try await request("/api/sign/happy/info", data: [:], crypto: .weapi)
    }

    /// 获取签到进度
    public func signinProgress(moduleId: String = "1207signin-1207signin") async throws -> APIResponse {
        return try await request("/api/act/modules/signin/v2/progress", data: ["moduleId": moduleId], crypto: .weapi)
    }

    /// 云村星评馆 - 简要评论列表
    public func starpickCommentsSummary() async throws -> APIResponse {
        let cursorJson = "{\"offset\":0,\"blockCodeOrderList\":[\"HOMEPAGE_BLOCK_NEW_HOT_COMMENT\"],\"refresh\":true}"
        return try await request("/api/homepage/block/page", data: ["cursor": cursorJson])
    }

    /// 年度听歌报告
    public func summaryAnnual(year: String) async throws -> APIResponse {
        let key = ["2017", "2018", "2019"].contains(year) ? "userdata" : "data"
        return try await request("/api/activity/summary/annual/\(year)/\(key)", data: [:])
    }

    /// 获取达人达标信息
    public func thresholdDetailGet() async throws -> APIResponse {
        return try await request("/api/influencer/web/apply/threshold/detail/get", data: [:])
    }

    /// 验证二维码获取
    public func verifyGetQr(vid: String, type: Int, token: String, evid: String, sign: String) async throws -> APIResponse {
        let params = "{\"event_id\":\"\(evid)\",\"sign\":\"\(sign)\"}"
        let data: [String: Any] = [
            "verifyConfigId": vid, "verifyType": type,
            "token": token, "params": params, "size": 150,
        ]
        return try await request("/api/frontrisk/verify/getqrcode", data: data, crypto: .weapi)
    }

    /// 验证二维码状态
    public func verifyQrcodestatus(qr: String) async throws -> APIResponse {
        return try await request("/api/frontrisk/verify/qrcodestatus", data: ["qrCode": qr], crypto: .weapi)
    }

    /// 操作记录（Weblog）
    public func weblog(data: [String: Any] = [:]) async throws -> APIResponse {
        return try await request("/api/feedback/weblog", data: data, crypto: .weapi)
    }

    /// 获取用户设置
    public func setting() async throws -> APIResponse {
        return try await request("/api/user/setting", data: [:], crypto: .weapi)
    }

    /// 听歌识曲
    /// - Parameters:
    ///   - duration: 音频时长（毫秒）
    ///   - audioFP: 音频指纹数据
    /// - Returns: API 响应，包含匹配到的歌曲信息
    /// - Note: 此接口直接请求公开 API，不走加密通道
    public func audioMatch(duration: Int, audioFP: String) async throws -> APIResponse {
        let encodedFP = audioFP.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? audioFP
        let urlStr = "https://interface.music.163.com/api/music/audio/match?sessionId=0123456789abcdef&algorithmCode=shazam_v2&duration=\(duration)&rawdata=\(encodedFP)&times=1&decrypt=1"
        guard let url = URL(string: urlStr) else {
            return APIResponse(status: 400, body: ["code": 400, "msg": "无效的 URL"], cookies: [])
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 200
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        return APIResponse(status: statusCode, body: ["code": 200, "data": json["data"] ?? [:]], cookies: [])
    }

    /// 匿名注册
    /// - Returns: API 响应，包含匿名用户 Cookie
    /// - Note: 内部生成随机 deviceId 并进行 XOR + MD5 + Base64 编码
    public func registerAnonimous() async throws -> APIResponse {
        let deviceId = generateDeviceId()
        let xorKey = "3go8&$8*3*3h0k(2)2"
        // XOR 编码
        var xored = ""
        for (i, char) in deviceId.enumerated() {
            let keyChar = xorKey[xorKey.index(xorKey.startIndex, offsetBy: i % xorKey.count)]
            let xorValue = char.asciiValue! ^ keyChar.asciiValue!
            xored.append(Character(UnicodeScalar(xorValue)))
        }
        // MD5 + Base64
        let md5Hex = CryptoEngine.md5(xored)
        // 将 MD5 hex 字符串转为 Data 再 Base64
        var md5Data = Data()
        var hexStr = md5Hex
        while hexStr.count >= 2 {
            let byteStr = String(hexStr.prefix(2))
            hexStr = String(hexStr.dropFirst(2))
            if let byte = UInt8(byteStr, radix: 16) {
                md5Data.append(byte)
            }
        }
        let md5Base64 = md5Data.base64EncodedString()
        // 拼接 deviceId + 空格 + md5Base64，再整体 Base64
        let combined = "\(deviceId) \(md5Base64)"
        let encodedId = Data(combined.utf8).base64EncodedString()
        let data: [String: Any] = ["username": encodedId]
        return try await request("/api/register/anonimous", data: data, crypto: .weapi)
    }

    /// 获取相关歌单（HTML 解析）
    /// - Parameter id: 歌单 ID
    /// - Returns: API 响应，包含相关歌单列表
    /// - Note: 此接口通过抓取网页 HTML 并正则解析获取数据
    public func relatedPlaylist(id: Int) async throws -> APIResponse {
        let urlStr = "https://music.163.com/playlist?id=\(id)"
        guard let url = URL(string: urlStr) else {
            return APIResponse(status: 400, body: ["code": 400, "msg": "无效的 URL"], cookies: [])
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        let html = String(data: data, encoding: .utf8) ?? ""
        // 正则匹配相关歌单
        let pattern = #"<div class="cver u-cover u-cover-3">[\s\S]*?<img src="([^"]+)">[\s\S]*?<a class="sname f-fs1 s-fc0" href="([^"]+)"[^>]*>([^<]+?)</a>[\s\S]*?<a class="nm nm f-thide s-fc3" href="([^"]+)"[^>]*>([^<]+?)</a>"#
        var playlists: [[String: Any]] = []
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
            for match in matches {
                guard match.numberOfRanges == 6 else { continue }
                func str(_ i: Int) -> String {
                    guard let range = Range(match.range(at: i), in: html) else { return "" }
                    return String(html[range])
                }
                let coverUrl = str(1).components(separatedBy: "?param=").first ?? str(1)
                let playlistId = str(2).replacingOccurrences(of: "/playlist?id=", with: "")
                let name = str(3)
                let userId = str(4).replacingOccurrences(of: "/user/home?id=", with: "")
                let nickname = str(5)
                playlists.append([
                    "creator": ["userId": userId, "nickname": nickname],
                    "coverImgUrl": coverUrl,
                    "name": name,
                    "id": playlistId,
                ])
            }
        }
        return APIResponse(status: 200, body: ["code": 200, "playlists": playlists], cookies: [])
    }

    // MARK: - 上传相关（拆分步骤）

    /// 分配 NOS 上传令牌
    /// - Parameters:
    ///   - bucket: 存储桶名称
    ///   - ext: 文件扩展名
    ///   - filename: 文件名
    ///   - nosProduct: NOS 产品类型（0 图片，3 音频）
    ///   - type: 文件类型（"other" 或 "audio"）
    ///   - md5: 文件 MD5（音频上传时需要）
    /// - Returns: API 响应，包含 objectKey、token、docId 等
    public func nosTokenAlloc(
        bucket: String, ext: String, filename: String,
        nosProduct: Int = 0, type: String = "other", md5: String? = nil
    ) async throws -> APIResponse {
        var data: [String: Any] = [
            "bucket": bucket, "ext": ext, "filename": filename,
            "local": false, "nos_product": nosProduct, "type": type,
        ]
        if let md5 = md5 { data["md5"] = md5 }
        return try await request("/api/nos/token/alloc", data: data, crypto: .weapi)
    }

    /// 更新用户头像（第二步：确认上传）
    /// - Parameter imgId: 图片 docId（由 nosTokenAlloc 返回）
    /// - Returns: API 响应
    /// - Note: 使用前需先调用 nosTokenAlloc 获取 token 并自行上传图片到 NOS
    public func avatarUpload(imgId: String) async throws -> APIResponse {
        let data: [String: Any] = ["imgid": imgId]
        return try await request("/api/user/avatar/upload/v1", data: data)
    }

    /// 更新歌单封面（第二步：确认上传）
    /// - Parameters:
    ///   - id: 歌单 ID
    ///   - coverImgId: 封面图片 docId（由 nosTokenAlloc 返回）
    /// - Returns: API 响应
    /// - Note: 使用前需先调用 nosTokenAlloc 获取 token 并自行上传图片到 NOS
    public func playlistCoverUpdate(id: Int, coverImgId: String) async throws -> APIResponse {
        let data: [String: Any] = ["id": id, "coverImgId": coverImgId]
        return try await request("/api/playlist/cover/update", data: data, crypto: .weapi)
    }

    /// 云盘上传检查
    /// - Parameters:
    ///   - md5: 文件 MD5
    ///   - length: 文件大小（字节）
    ///   - ext: 文件扩展名
    ///   - bitrate: 码率，默认 999000
    /// - Returns: API 响应，包含 songId 和 needUpload 标志
    public func cloudUploadCheck(md5: String, length: Int, ext: String = "", bitrate: Int = 999000) async throws -> APIResponse {
        let data: [String: Any] = [
            "bitrate": String(bitrate), "ext": ext,
            "length": length, "md5": md5, "songId": "0", "version": 1,
        ]
        return try await request("/api/cloud/upload/check", data: data)
    }

    /// 云盘上传信息提交
    /// - Parameters:
    ///   - md5: 文件 MD5
    ///   - songId: 歌曲 ID（由 cloudUploadCheck 返回）
    ///   - filename: 文件名
    ///   - song: 歌曲名
    ///   - album: 专辑名，默认 "未知专辑"
    ///   - artist: 歌手名，默认 "未知艺术家"
    ///   - bitrate: 码率，默认 999000
    ///   - resourceId: 资源 ID（由 nosTokenAlloc 返回）
    /// - Returns: API 响应
    public func cloudUploadInfo(
        md5: String, songId: String, filename: String,
        song: String, album: String = "未知专辑", artist: String = "未知艺术家",
        bitrate: Int = 999000, resourceId: Int
    ) async throws -> APIResponse {
        let data: [String: Any] = [
            "md5": md5, "songid": songId, "filename": filename,
            "song": song, "album": album, "artist": artist,
            "bitrate": String(bitrate), "resourceId": resourceId,
        ]
        return try await request("/api/upload/cloud/info/v2", data: data)
    }

    /// 云盘歌曲发布
    /// - Parameter songId: 歌曲 ID（由 cloudUploadInfo 返回）
    /// - Returns: API 响应
    public func cloudPub(songId: String) async throws -> APIResponse {
        return try await request("/api/cloud/pub/v2", data: ["songid": songId])
    }

    /// 声音上传预检查
    /// - Parameters:
    ///   - voiceData: 声音数据 JSON 字符串
    ///   - dupkey: 去重 key（UUID 格式）
    /// - Returns: API 响应
    public func voiceUploadPreCheck(voiceData: String, dupkey: String? = nil) async throws -> APIResponse {
        let key = dupkey ?? UUID().uuidString.lowercased()
        let data: [String: Any] = ["dupkey": key, "voiceData": voiceData]
        return try await request("/api/voice/workbench/voice/batch/upload/preCheck", data: data)
    }

    /// 声音上传确认
    /// - Parameters:
    ///   - voiceData: 声音数据 JSON 字符串
    ///   - dupkey: 去重 key（UUID 格式）
    /// - Returns: API 响应
    public func voiceUpload(voiceData: String, dupkey: String? = nil) async throws -> APIResponse {
        let key = dupkey ?? UUID().uuidString.lowercased()
        let data: [String: Any] = ["dupkey": key, "voiceData": voiceData]
        return try await request("/api/voice/workbench/voice/batch/upload/v2", data: data,
            crypto: .weapi
        )
    }

    // MARK: - 私有辅助方法

    /// 生成随机 52 位十六进制 DeviceId
    private func generateDeviceId() -> String {
        let hexChars = "0123456789ABCDEF"
        return String((0..<52).map { _ in hexChars.randomElement()! })
    }
}
