import Foundation

// MARK: - QQMusicApi 0.7.2 APIs

public extension QQMusicClient {

    /// 获取新碟上架列表。
    func newAlbums(area: Int = 1, num: Int = 20, page: Int = 1) async throws -> JSON {
        try await module("album", function: "get_new_album", parameters: [
            "area": area,
            "num": num,
            "page": page,
        ])
    }

    /// 收藏专辑。
    func favoriteAlbums(_ albumIDs: [Int]) async throws -> JSON {
        try await module("album", function: "fav_album", parameters: ["album_id": albumIDs])
    }

    /// 取消收藏专辑。
    func unfavoriteAlbums(_ albumIDs: [Int]) async throws -> JSON {
        try await module("album", function: "del_fav_album", parameters: ["album_id": albumIDs])
    }

    /// 发表评论或回复指定评论。
    func postComment(
        songID: Int,
        content: String,
        replyCommentID: String? = nil,
        bizType: CommentBizType = .song,
        bizSubType: Int? = nil
    ) async throws -> JSON {
        var parameters: [String: Any] = [
            "biz_id": songID,
            "content": content,
            "biz_type": bizType.rawValue,
        ]
        if let replyCommentID {
            parameters["reply_cmt_id"] = replyCommentID
        }
        if let bizSubType {
            parameters["biz_sub_type"] = bizSubType
        }
        return try await module("comment", function: "add_comment", parameters: parameters)
    }

    /// 删除评论。
    func removeComment(commentID: String) async throws -> Bool {
        try await module("comment", function: "delete_comment", parameters: ["cm_id": commentID])
    }

    /// 获取 MV 分类列表。
    func mvList(
        area: Int = 15,
        version: Int = 7,
        order: Int = 0,
        num: Int = 10,
        page: Int = 1
    ) async throws -> JSON {
        try await module("mv", function: "get_mv_list", parameters: [
            "area": area,
            "version": version,
            "order": order,
            "num": num,
            "page": page,
        ])
    }

    /// 检查歌曲是否有曲谱。
    func songHasSheet(mid: String) async throws -> JSON {
        try await module("song", function: "has_sheet", parameters: ["mid": mid])
    }

    /// 将歌曲加入“我喜欢”。每项为 `[歌曲 ID, 歌曲类型]`，普通歌曲类型使用 `0`。
    func likeSongs(_ songInfo: [[Int]]) async throws -> Bool {
        try await module("songlist", function: "like_song", parameters: ["song_info": songInfo])
    }

    /// 从“我喜欢”移除歌曲。每项为 `[歌曲 ID, 歌曲类型]`。
    func unlikeSongs(_ songInfo: [[Int]]) async throws -> Bool {
        try await module("songlist", function: "unlike_song", parameters: ["song_info": songInfo])
    }

    /// 收藏他人的公开歌单。
    func favoriteSonglist(_ songlistID: Int) async throws -> Bool {
        try await module("user", function: "fav_songlist", parameters: ["songlist_id": songlistID])
    }

    /// 取消收藏歌单。
    func unfavoriteSonglist(_ songlistID: Int) async throws -> Bool {
        try await module("user", function: "unfav_songlist", parameters: ["songlist_id": songlistID])
    }

    /// 获取不喜欢列表。`cmd`：2=歌手，3=歌曲，4=风格。
    func dislikeList(cmd: Int = 3, page: Int = 1, lastID: Int = 0) async throws -> JSON {
        try await module("user", function: "get_dislike_list", parameters: [
            "cmd": cmd,
            "page": page,
            "lastid": lastID,
        ])
    }

    /// 添加不喜欢项。`type`：1=歌曲，2=歌手，3=风格。
    func addDislikes(type: Int, values: [Int]) async throws -> Bool {
        try await module("user", function: "add_dislike", parameters: [
            "id_type": type,
            "values": values,
        ])
    }

    /// 取消不喜欢项。`type`：1=歌曲，2=歌手，3=风格。
    func removeDislikes(type: Int, values: [Int]) async throws -> Bool {
        try await module("user", function: "cancel_dislike", parameters: [
            "id_type": type,
            "values": values,
        ])
    }

    /// 清空所有不喜欢歌曲。
    func removeAllDislikedSongs() async throws -> Bool {
        try await module("user", function: "cancel_all_dislike_song")
    }

    /// 初始化 COS 上传并获取临时凭证。
    func initializeUpload(busID: String, files: [[String: Any]]) async throws -> JSON {
        try await module("helper", function: "init_upload", parameters: [
            "bus_id": busID,
            "files": files,
        ])
    }

    /// 提交上传结果。
    func finishUpload(busID: String, results: [[String: Any]]) async throws -> JSON {
        try await module("helper", function: "finish_upload", parameters: [
            "bus_id": busID,
            "results": results,
        ])
    }

    /// 获取私信会话列表。
    func privateMessageSessions(
        lastID: String = "",
        order: Int = 1,
        size: Int = 20,
        lastTime: Int = 0,
        from: Int = 0,
        fansFlag: Int? = 1,
        encryptFromUin: String? = nil
    ) async throws -> JSON {
        var parameters: [String: Any] = [
            "last_id": lastID,
            "order": order,
            "size": size,
            "last_time": lastTime,
            "from_": from,
        ]
        if let encryptFromUin {
            parameters["encrypt_from_uin"] = encryptFromUin
        } else if let fansFlag {
            parameters["fans_flag"] = fansFlag
        }
        return try await module("private_message", function: "get_sessions", parameters: parameters)
    }

    /// 删除私信会话。
    func deletePrivateMessageSession(sessionID: String, superMessageFlag: Int = 0) async throws -> JSON {
        try await module("private_message", function: "delete_session", parameters: [
            "session_id": sessionID,
            "super_msg_flag": superMessageFlag,
        ])
    }

    /// 获取私信消息列表。
    func privateMessages(
        sessionID: String = "",
        userID: String = "",
        lastID: String = "",
        wnsID: String = "",
        order: Int = 1,
        size: Int = 50,
        flag: Int = 0,
        locationID: String? = nil,
        updateTime: Int? = nil
    ) async throws -> JSON {
        var parameters: [String: Any] = [
            "session_id": sessionID,
            "user_id": userID,
            "last_id": lastID,
            "wns_id": wnsID,
            "order": order,
            "size": size,
            "flag": flag,
        ]
        if let locationID { parameters["location_id"] = locationID }
        if let updateTime { parameters["update_time"] = updateTime }
        return try await module("private_message", function: "get_messages", parameters: parameters)
    }

    /// 发送私信。`metaData` 为上游定义的消息元数据对象。
    func sendPrivateMessage(
        userID: String,
        messageType: Int,
        sessionID: String = "",
        lastID: String = "",
        lastMessageSequence: Int = 0,
        metaData: [String: Any]? = nil,
        entrance: Int = 0,
        clientKey: String = "",
        sourceFlag: Int? = nil,
        messageID: String? = nil,
        userInput: String? = nil,
        superMessageFlag: Int? = 0,
        starSend: Bool = false
    ) async throws -> JSON {
        var parameters: [String: Any] = [
            "user_id": userID,
            "msg_type": messageType,
            "session_id": sessionID,
            "last_id": lastID,
            "last_msg_seq": lastMessageSequence,
            "entrance": entrance,
            "client_key": clientKey,
            "star_send": starSend,
        ]
        if let metaData { parameters["meta_data"] = metaData }
        if let sourceFlag { parameters["source_flag"] = sourceFlag }
        if let messageID { parameters["msg_id"] = messageID }
        if let userInput { parameters["user_input"] = userInput }
        if let superMessageFlag { parameters["super_msg_flag"] = superMessageFlag }
        return try await module("private_message", function: "send_message", parameters: parameters)
    }

    /// 删除单条私信消息。
    func deletePrivateMessage(sessionID: String, messageID: String, superMessageFlag: Int = 0) async throws -> JSON {
        try await module("private_message", function: "delete_message", parameters: [
            "session_id": sessionID,
            "msg_id": messageID,
            "super_msg_flag": superMessageFlag,
        ])
    }

    /// 清空私信会话。
    func clearPrivateMessageSession(sessionID: String, superMessageFlag: Int = 0) async throws -> JSON {
        try await module("private_message", function: "clear_session", parameters: [
            "session_id": sessionID,
            "super_msg_flag": superMessageFlag,
        ])
    }

    /// 写入私信配置。
    func setPrivateMessageConfig(type: Int, value: String) async throws -> JSON {
        try await module("private_message", function: "set_config", parameters: [
            "config_type": type,
            "config_value": value,
        ])
    }

    /// 读取私信配置。
    func privateMessageConfig(type: Int, value: String = "") async throws -> JSON {
        try await module("private_message", function: "get_config", parameters: [
            "config_type": type,
            "config_value": value,
        ])
    }

    /// 获取音乐人私信卡片。
    func musicianMessageCard(encryptedUin: String) async throws -> JSON {
        try await module("private_message", function: "get_musician_message_card", parameters: ["enc_uin": encryptedUin])
    }

    /// 上报私信卡片操作。
    func reportMessageCardAction(
        targetUserID: String,
        messageType: Int,
        confirm: Int,
        messageID: String,
        extensionData: [String: Any]? = nil
    ) async throws -> JSON {
        var parameters: [String: Any] = [
            "target_user_id": targetUserID,
            "msg_type": messageType,
            "confirm": confirm,
            "msg_id": messageID,
        ]
        if let extensionData { parameters["ext"] = extensionData }
        return try await module("private_message", function: "report_card_message_action", parameters: parameters)
    }

    /// 获取私信聊天页入口。
    func privateMessageChatEntries(
        scenes: [Int],
        fromUserType: Int? = nil,
        userID: String? = nil,
        extensionData: [String: String]? = nil
    ) async throws -> JSON {
        var parameters: [String: Any] = ["scenes": scenes]
        if let fromUserType { parameters["from_user_type"] = fromUserType }
        if let userID { parameters["user_id"] = userID }
        if let extensionData { parameters["ext"] = extensionData }
        return try await module("private_message", function: "get_chat_entries", parameters: parameters)
    }

    /// 获取图片或视频私信详情。
    func privateMediaMessageDetails(sessionID: String, messageIDs: [String]) async throws -> JSON {
        try await module("private_message", function: "get_media_message_details", parameters: [
            "session_id": sessionID,
            "msg_ids": messageIDs,
        ])
    }

    /// 将私信全部标记为已读。
    func markAllPrivateMessagesRead(commandFlag: Int, encryptedUin: String) async throws -> JSON {
        try await module("private_message", function: "mark_all_messages_read", parameters: [
            "cmd_flag": commandFlag,
            "encrypt_uin": encryptedUin,
        ])
    }

    /// 获取私信安全提示。
    func privateMessageSafetyHint(encryptedUin: String, close: Int = 0) async throws -> JSON {
        try await module("private_message", function: "get_safety_hint", parameters: [
            "enc_uin": encryptedUin,
            "close": close,
        ])
    }

    /// 获取聊天页好友浮标。
    func friendshipBadge(targetEncryptedUin: String) async throws -> JSON {
        try await module("private_message", function: "get_friendship_badge", parameters: [
            "target_enc_uin": targetEncryptedUin,
        ])
    }
}
