import Foundation
import Combine
import NeteaseCloudMusicAPI
import QQMusicKit

// MARK: - 评论接口

extension APIService {

    func fetchPlatformComments(
        resource: CommentResource,
        page: Int,
        pageSize: Int,
        sortType: CommentSortType,
        cursor: String = ""
    ) -> AnyPublisher<PlatformCommentPage, Error> {
        switch resource.source {
        case .netease:
            guard let id = resource.numericID,
                  let type = CommentType(rawValue: resource.type.rawValue) else {
                return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
            }
            return fetchComments(
                type: type,
                id: id,
                pageNo: page,
                pageSize: pageSize,
                sortType: sortType.rawValue,
                cursor: cursor
            )
            .map { data in
                PlatformCommentPage(
                    comments: data.comments ?? [],
                    totalCount: data.totalCount ?? 0,
                    hasMore: data.hasMore ?? false,
                    cursor: data.cursor ?? ""
                )
            }
            .eraseToAnyPublisher()
        case .qqmusic:
            return asyncToPublisher { [qqClient] in
                let result: JSON
                switch sortType {
                case .latest:
                    result = try await qqClient.newComments(
                        bizId: resource.platformID,
                        pageNum: page,
                        pageSize: pageSize,
                        lastSeqNo: cursor
                    )
                case .hot:
                    result = try await qqClient.hotComments(
                        bizId: resource.platformID,
                        pageNum: page,
                        pageSize: pageSize,
                        lastSeqNo: cursor
                    )
                case .recommended:
                    result = try await qqClient.recommendComments(
                        bizId: resource.platformID,
                        pageNum: page,
                        pageSize: pageSize,
                        lastSeqNo: cursor
                    )
                }
                return Self.qqCommentPage(from: result, pageSize: pageSize)
            }
        case .kugou:
            return asyncToPublisher {
                try await KCMMusicService.shared.fetchSongComments(
                    mixSongID: resource.platformID,
                    page: page,
                    pageSize: pageSize
                )
            }
        case .qishui, .appleMusic, .local:
            return Fail(error: URLError(.unsupportedURL)).eraseToAnyPublisher()
        }
    }

    func fetchPlatformHotComments(
        resource: CommentResource,
        limit: Int
    ) -> AnyPublisher<[Comment], Error> {
        switch resource.source {
        case .netease:
            guard let id = resource.numericID,
                  let type = CommentType(rawValue: resource.type.rawValue) else {
                return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
            }
            return fetchHotComments(type: type, id: id, limit: limit)
        case .qqmusic:
            return asyncToPublisher { [qqClient] in
                let json = try await qqClient.hotComments(
                    bizId: resource.platformID,
                    pageNum: 1,
                    pageSize: limit
                )
                return Self.qqCommentPage(from: json, pageSize: limit).comments
            }
        case .kugou, .qishui, .appleMusic, .local:
            return Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
        }
    }

    private static func qqCommentPage(from json: JSON, pageSize: Int) -> PlatformCommentPage {
        let root = qqCommentPayload(in: json)
        let items = qqCommentItems(in: root)
        let comments = items.compactMap(qqComment(from:))
        let total = qqFirstInt(in: root, keys: ["total", "total_num", "comment_total", "total_count", "count"])
            ?? comments.count
        let cursor = qqFirstString(in: root, keys: ["last_comment_seq_no", "last_seq_no", "cursor", "next_cursor"])
            ?? items.last.flatMap { qqFirstString(in: $0, keys: ["comment_seq_no", "seq_no", "cm_id", "id"]) }
            ?? ""
        let explicitMore = qqFirstBool(in: root, keys: ["has_more", "hasMore", "more"])
        return PlatformCommentPage(
            comments: comments,
            totalCount: total,
            hasMore: explicitMore ?? (comments.count >= pageSize && (total <= comments.count || comments.count < total)),
            cursor: cursor
        )
    }

    private static func qqCommentPayload(in json: JSON) -> JSON {
        for key in ["data", "result", "comment", "comments"] {
            if let value = json[key], value.objectValue != nil { return qqCommentPayload(in: value) }
        }
        return json
    }

    private static func qqCommentItems(in json: JSON) -> [JSON] {
        for key in ["comment_list", "comments", "list", "items", "commentlist", "vec_comment"] {
            if let values = json[key]?.arrayValue { return values }
        }
        guard let object = json.objectValue else { return [] }
        for value in object.values {
            if let result = value.arrayValue, !result.isEmpty,
               result.first?["content"] != nil || result.first?["rootcommentcontent"] != nil {
                return result
            }
            if value.objectValue != nil {
                let result = qqCommentItems(in: value)
                if !result.isEmpty { return result }
            }
        }
        return []
    }

    private static func qqComment(from json: JSON) -> Comment? {
        let payload = json["comment"] ?? json
        guard let content = qqFirstString(
            in: payload,
            keys: ["content", "rootcommentcontent", "comment_content", "text"]
        ), !content.isEmpty else { return nil }
        let rawCommentID = qqFirstString(in: payload, keys: ["cm_id", "comment_id", "commentid", "id", "comment_seq_no"])
            ?? "qcm:\(content)"
        let userJSON = payload["user"] ?? payload["userinfo"] ?? payload["user_info"] ?? payload
        let rawUserID = qqFirstString(in: userJSON, keys: ["uin", "user_id", "userid", "id"])
            ?? qqFirstString(in: payload, keys: ["uin", "user_id", "userid"])
            ?? "qcm:anonymous"
        let nickname = qqFirstString(in: userJSON, keys: ["nick", "nickname", "user_name", "name"])
            ?? String(localized: "匿名用户")
        let avatar = qqFirstString(in: userJSON, keys: ["avatar", "avatarurl", "avatar_url", "headurl", "pic"])
        let timestamp = qqTimestamp(
            qqFirstString(in: payload, keys: ["time", "add_time", "create_time", "ctime", "comment_time"]),
            fallback: qqFirstInt(in: payload, keys: ["time", "add_time", "create_time", "ctime"])
        )
        return Comment(
            commentId: stableCommentID(rawCommentID),
            content: content,
            time: timestamp,
            likedCount: qqFirstInt(in: payload, keys: ["praisenum", "like_count", "liked_count", "like_num", "praise_num"]) ?? 0,
            liked: qqFirstBool(in: payload, keys: ["is_praise", "liked", "is_liked", "has_like"]) ?? false,
            user: CommentUser(
                userId: stableCommentID(rawUserID),
                nickname: nickname,
                avatarUrl: avatar,
                vipType: qqFirstInt(in: userJSON, keys: ["vip_type", "viptype"])
            ),
            beReplied: nil,
            ipLocation: IPLocation(location: qqFirstString(in: payload, keys: ["location", "ip_location"])),
            timeStr: qqFirstString(in: payload, keys: ["time_str", "time_text"]),
            parentCommentId: nil
        )
    }

    private static func qqFirstString(in json: JSON, keys: [String]) -> String? {
        for key in keys {
            if let value = json[key]?.stringValue, !value.isEmpty { return value }
        }
        return nil
    }

    private static func qqFirstInt(in json: JSON, keys: [String]) -> Int? {
        for key in keys {
            if let value = json[key]?.intValue { return value }
        }
        return nil
    }

    private static func qqFirstBool(in json: JSON, keys: [String]) -> Bool? {
        for key in keys {
            if let value = json[key]?.boolValue { return value }
            if let value = json[key]?.intValue { return value != 0 }
        }
        return nil
    }

    private static func qqTimestamp(_ string: String?, fallback: Int?) -> Int {
        if let fallback {
            return fallback > 10_000_000_000 ? fallback : fallback * 1_000
        }
        guard let string else { return Int(Date().timeIntervalSince1970 * 1_000) }
        if let value = Int(string) { return value > 10_000_000_000 ? value : value * 1_000 }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ssZ"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: string) {
                return Int(date.timeIntervalSince1970 * 1_000)
            }
        }
        return Int(Date().timeIntervalSince1970 * 1_000)
    }

    static func stableCommentID(_ value: String) -> Int {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Int(hash & 0x7fff_ffff)
    }

    /// 获取评论列表（新版接口，支持排序和分页）
    func fetchComments(type: CommentType, id: Int, pageNo: Int = 1, pageSize: Int = 20, sortType: Int = 99, cursor: String = "") -> AnyPublisher<CommentNewData, Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.commentNew(
                type: type, id: id,
                pageNo: pageNo, pageSize: pageSize,
                sortType: sortType, cursor: cursor
            )
            guard let dataDict = response.body["data"] as? [String: Any] else {
                return CommentNewData(totalCount: 0, hasMore: false, cursor: "", comments: [], sortType: sortType)
            }
            let data = try JSONSerialization.data(withJSONObject: dataDict)
            return try JSONDecoder().decode(CommentNewData.self, from: data)
        }
    }

    /// 获取热门评论
    func fetchHotComments(type: CommentType, id: Int, limit: Int = 20, offset: Int = 0) -> AnyPublisher<[Comment], Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.commentHot(type: type, id: id, limit: limit, offset: offset)
            guard let arr = response.body["hotComments"] as? [[String: Any]] else {
                return [Comment]()
            }
            let data = try JSONSerialization.data(withJSONObject: arr)
            return try JSONDecoder().decode([Comment].self, from: data)
        }
    }

    /// 评论点赞/取消点赞
    func likeComment(type: CommentType, id: Int, commentId: Int, like: Bool) -> AnyPublisher<SimpleResponse, Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.commentLike(type: type, id: id, commentId: commentId, like: like)
            return SimpleResponse(
                code: response.body["code"] as? Int ?? 200,
                message: nil
            )
        }
    }

    /// 发表评论
    func postComment(type: CommentType, id: Int, content: String) -> AnyPublisher<SimpleResponse, Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.comment(action: .add, type: type, id: id, content: content)
            return SimpleResponse(
                code: response.body["code"] as? Int ?? 200,
                message: nil
            )
        }
    }

    /// 回复评论
    func replyComment(type: CommentType, id: Int, content: String, commentId: Int) -> AnyPublisher<SimpleResponse, Error> {
        ncm.publisher { [ncm] in
            let response = try await ncm.comment(action: .reply, type: type, id: id, content: content, commentId: commentId)
            return SimpleResponse(
                code: response.body["code"] as? Int ?? 200,
                message: nil
            )
        }
    }
}
