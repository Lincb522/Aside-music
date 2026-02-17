// APIService+Social.swift
// 社交相关接口 - 私信、Mlog、听歌识曲

import Foundation
import Combine
import NeteaseCloudMusicAPI

// MARK: - 私信接口

extension APIService {

    /// 获取私信列表
    func fetchPrivateMessages(limit: Int = 30, offset: Int = 0) -> AnyPublisher<[PrivateMessage], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.msgPrivate(limit: limit, offset: offset)
            guard let msgsArray = response.body["msgs"] as? [[String: Any]] else {
                return [PrivateMessage]()
            }
            var result: [PrivateMessage] = []
            for msg in msgsArray {
                let fromUser = msg["fromUser"] as? [String: Any]
                let _ = msg["toUser"] as? [String: Any]
                let rawLastMsg = msg["lastMsg"] as? String ?? ""
                let lastMsgTime = msg["lastMsgTime"] as? Int ?? 0
                let newMsgCount = msg["newMsgCount"] as? Int ?? 0
                
                let userId = fromUser?["userId"] as? Int ?? 0
                let nickname = fromUser?["nickname"] as? String ?? ""
                let avatarUrl = fromUser?["avatarUrl"] as? String
                
                // 解析消息内容 — API 返回的 lastMsg 是 JSON 字符串
                let displayMsg = Self.parseMessageContent(rawLastMsg)
                
                result.append(PrivateMessage(
                    userId: userId, nickname: nickname, avatarUrl: avatarUrl,
                    lastMsg: displayMsg, lastMsgTime: lastMsgTime, newMsgCount: newMsgCount
                ))
            }
            return result
        }
    }

    /// 获取私信历史记录
    func fetchPrivateHistory(uid: Int, limit: Int = 30, before: Int = 0) -> AnyPublisher<[ChatMessage], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.msgPrivateHistory(uid: uid, limit: limit, before: before)
            guard let msgsArray = response.body["msgs"] as? [[String: Any]] else {
                return [ChatMessage]()
            }
            var result: [ChatMessage] = []
            for msg in msgsArray {
                let fromUser = msg["fromUser"] as? [String: Any]
                let rawMsg = msg["msg"] as? String ?? ""
                let time = msg["time"] as? Int ?? 0
                let fromUserId = fromUser?["userId"] as? Int ?? 0
                let fromNickname = fromUser?["nickname"] as? String ?? ""
                let fromAvatar = fromUser?["avatarUrl"] as? String
                
                // 解析消息内容 — API 返回的 msg 是 JSON 字符串
                let displayMsg = Self.parseMessageContent(rawMsg)
                
                result.append(ChatMessage(
                    fromUserId: fromUserId, fromNickname: fromNickname,
                    fromAvatarUrl: fromAvatar, msg: displayMsg, time: time
                ))
            }
            return result
        }
    }

    /// 发送文本私信
    func sendTextMessage(userIds: [Int], msg: String) -> AnyPublisher<SimpleResponse, Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.sendText(userIds: userIds, msg: msg)
            return SimpleResponse(
                code: response.body["code"] as? Int ?? 200,
                message: nil
            )
        }
    }

    /// 解析私信消息内容（API 返回的 msg 是 JSON 字符串）
    /// 支持的消息类型：文本、歌曲分享、专辑分享、歌单分享等
    static func parseMessageContent(_ raw: String) -> String {
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // 不是 JSON，直接返回原文
            return raw
        }
        
        // 纯文本消息
        if let msg = json["msg"] as? String, !msg.isEmpty {
            // 附带歌曲/专辑名称
            if let song = json["song"] as? [String: Any], let songName = song["name"] as? String {
                return "\(msg) [\(songName)]"
            }
            if let album = json["album"] as? [String: Any], let albumName = album["name"] as? String {
                return "\(msg) [\(albumName)]"
            }
            return msg
        }
        
        // 歌曲分享（无 msg 文本）
        if let song = json["song"] as? [String: Any], let name = song["name"] as? String {
            let artist = (song["artists"] as? [[String: Any]])?.first?["name"] as? String ?? ""
            return artist.isEmpty ? "[歌曲] \(name)" : "[歌曲] \(name) - \(artist)"
        }
        
        // 专辑分享
        if let album = json["album"] as? [String: Any], let name = album["name"] as? String {
            return "[专辑] \(name)"
        }
        
        // 歌单分享
        if let playlist = json["playlist"] as? [String: Any], let name = playlist["name"] as? String {
            return "[歌单] \(name)"
        }
        
        // 图片消息
        if json["picUrl"] as? String != nil {
            return "[图片]"
        }
        
        // 其他未知类型
        return "[消息]"
    }

    /// 发送歌曲私信
    func sendSongMessage(userIds: [Int], songId: Int, msg: String = "") -> AnyPublisher<SimpleResponse, Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.sendSong(userIds: userIds, id: songId, msg: msg)
            return SimpleResponse(
                code: response.body["code"] as? Int ?? 200,
                message: nil
            )
        }
    }

    /// 获取通知列表
    func fetchNotices(limit: Int = 30, lasttime: Int = -1) -> AnyPublisher<[NoticeItem], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.msgNotices(limit: limit, lasttime: lasttime)
            guard let noticesArray = response.body["notices"] as? [[String: Any]] else {
                return [NoticeItem]()
            }
            var result: [NoticeItem] = []
            for notice in noticesArray {
                let id = notice["id"] as? Int ?? 0
                let time = notice["time"] as? Int ?? 0
                let noticeType = notice["type"] as? Int ?? 0
                var content = ""
                if let jsonStr = notice["notice"] as? String {
                    content = jsonStr
                } else if let noticeDict = notice["notice"] as? [String: Any] {
                    content = noticeDict["content"] as? String ?? ""
                }
                result.append(NoticeItem(id: id, time: time, type: noticeType, content: content))
            }
            return result
        }
    }
}

// MARK: - Mlog 接口

extension APIService {

    /// 获取 Mlog 推荐音乐
    func fetchMlogMusicRcmd(songid: Int, limit: Int = 10) -> AnyPublisher<[MlogItem], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.mlogMusicRcmd(songid: songid, limit: limit)
            guard let dataDict = response.body["data"] as? [String: Any],
                  let feedsArray = dataDict["feeds"] as? [[String: Any]] else {
                return [MlogItem]()
            }
            var result: [MlogItem] = []
            for feed in feedsArray {
                guard let resource = feed["resource"] as? [String: Any],
                      let mlogBaseData = resource["mlogBaseData"] as? [String: Any] else { continue }
                let id = mlogBaseData["id"] as? String ?? ""
                let text = mlogBaseData["text"] as? String ?? ""
                let coverUrl = mlogBaseData["coverUrl"] as? String
                let duration = mlogBaseData["duration"] as? Int ?? 0
                // 提取关联歌曲
                var song: Song? = nil
                if let songData = resource["songData"] as? [String: Any],
                   let songDetail = songData["songDetail"] as? [String: Any] {
                    let songJsonData = try JSONSerialization.data(withJSONObject: songDetail)
                    song = try? JSONDecoder().decode(Song.self, from: songJsonData)
                }
                result.append(MlogItem(id: id, text: text, coverUrl: coverUrl, duration: duration, song: song))
            }
            return result
        }
    }

    /// 获取 Mlog 播放链接
    func fetchMlogUrl(id: String, resolution: Int = 1080) -> AnyPublisher<String?, Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.mlogUrl(id: id, res: resolution)
            if let dataDict = response.body["data"] as? [String: Any],
               let resource = dataDict["resource"] as? [String: Any],
               let content = resource["content"] as? [String: Any],
               let video = content["video"] as? [String: Any],
               let urlInfo = video["urlInfo"] as? [String: Any],
               let url = urlInfo["url"] as? String {
                return url
            }
            return nil
        }
    }
}

// MARK: - 电台补充接口

extension APIService {

    /// 获取电台 Banner
    func fetchDJBanner() -> AnyPublisher<[Banner], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.djBanner()
            guard let dataArray = response.body["data"] as? [[String: Any]] else {
                return [Banner]()
            }
            let data = try JSONSerialization.data(withJSONObject: dataArray)
            return try JSONDecoder().decode([Banner].self, from: data)
        }
    }

    /// 获取付费精品电台
    func fetchDJPaygift(limit: Int = 30, offset: Int = 0) -> AnyPublisher<[RadioStation], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.djPaygift(limit: limit, offset: offset)
            guard let dataDict = response.body["data"] as? [String: Any],
                  let listArray = dataDict["list"] as? [[String: Any]] else {
                return [RadioStation]()
            }
            let data = try JSONSerialization.data(withJSONObject: listArray)
            return try JSONDecoder().decode([RadioStation].self, from: data)
        }
    }

    /// 获取电台新人榜
    func fetchDJToplistNewcomer(limit: Int = 30, offset: Int = 0) -> AnyPublisher<[RadioStation], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.djToplistNewcomer(limit: limit, offset: offset)
            guard let dataDict = response.body["data"] as? [String: Any],
                  let listArray = dataDict["list"] as? [[String: Any]] else {
                return [RadioStation]()
            }
            let data = try JSONSerialization.data(withJSONObject: listArray)
            return try JSONDecoder().decode([RadioStation].self, from: data)
        }
    }

    /// 获取电台节目榜
    func fetchDJProgramToplist(limit: Int = 30, offset: Int = 0) -> AnyPublisher<[RadioProgram], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.djProgramToplist(limit: limit, offset: offset)
            guard let toplistArray = response.body["toplist"] as? [[String: Any]] else {
                return [RadioProgram]()
            }
            // 节目榜返回的是包含 program 的对象
            var programs: [RadioProgram] = []
            for item in toplistArray {
                if let programDict = item["program"] as? [String: Any] {
                    let data = try JSONSerialization.data(withJSONObject: programDict)
                    if let program = try? JSONDecoder().decode(RadioProgram.self, from: data) {
                        programs.append(program)
                    }
                }
            }
            return programs
        }
    }

    /// 获取今日优选电台
    func fetchDJTodayPerfered(page: Int = 0) -> AnyPublisher<[RadioStation], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.djTodayPerfered(page: page)
            guard let dataArray = response.body["data"] as? [[String: Any]] else {
                return [RadioStation]()
            }
            let data = try JSONSerialization.data(withJSONObject: dataArray)
            return try JSONDecoder().decode([RadioStation].self, from: data)
        }
    }
}

// MARK: - 听歌识曲

extension APIService {

    /// 听歌识曲
    func audioMatch(duration: Int, audioFP: String) -> AnyPublisher<AudioMatchResult, Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.audioMatch(duration: duration, audioFP: audioFP)
            guard let dataDict = response.body["data"] as? [String: Any] else {
                return AudioMatchResult(songs: [])
            }
            // 解析匹配结果
            var songs: [Song] = []
            if let resultArray = dataDict["result"] as? [[String: Any]] {
                for item in resultArray {
                    if let songDict = item["song"] as? [String: Any] {
                        let songData = try JSONSerialization.data(withJSONObject: songDict)
                        if let song = try? JSONDecoder().decode(Song.self, from: songData) {
                            songs.append(song)
                        }
                    }
                }
            }
            return AudioMatchResult(songs: songs)
        }
    }
}
