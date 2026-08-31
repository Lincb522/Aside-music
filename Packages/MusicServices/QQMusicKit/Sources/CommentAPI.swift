import Foundation

// MARK: - 评论相关 API

public extension QQMusicClient {

    /// 获取歌曲评论数量
    /// - Parameters:
    ///   - bizId: 业务对象 ID
    ///   - bizType: 业务类型
    ///   - bizSubType: 业务子类型
    func commentCount(
        bizId: String,
        bizType: CommentBizType = .song,
        bizSubType: Int? = nil
    ) async throws -> JSON {
        var params = ["biz_id": bizId, "biz_type": String(bizType.rawValue)]
        if let bizSubType { params["biz_sub_type"] = String(bizSubType) }
        return try await requestWrapped("/comment/get_comment_count", params: params)
    }

    /// 获取歌曲热评
    /// - Parameters:
    ///   - bizId: 歌曲 ID
    ///   - pageNum: 页码
    ///   - pageSize: 每页数量
    ///   - lastSeqNo: 上一页最后一条评论 ID（翻页用）
    func hotComments(
        bizId: String,
        pageNum: Int = 1,
        pageSize: Int = 15,
        lastSeqNo: String = "",
        bizType: CommentBizType = .song,
        bizSubType: Int? = nil
    ) async throws -> JSON {
        var params = [
            "biz_id": bizId,
            "page_num": String(pageNum),
            "page_size": String(pageSize),
            "last_comment_seq_no": lastSeqNo,
            "biz_type": String(bizType.rawValue),
        ]
        if let bizSubType { params["biz_sub_type"] = String(bizSubType) }
        return try await requestWrapped("/comment/get_hot_comments", params: params)
    }

    /// 获取歌曲最新评论
    /// - Parameters:
    ///   - bizId: 歌曲 ID
    ///   - pageNum: 页码
    ///   - pageSize: 每页数量
    ///   - lastSeqNo: 上一页最后一条评论 ID
    func newComments(
        bizId: String,
        pageNum: Int = 1,
        pageSize: Int = 15,
        lastSeqNo: String = "",
        bizType: CommentBizType = .song,
        bizSubType: Int? = nil
    ) async throws -> JSON {
        var params = [
            "biz_id": bizId,
            "page_num": String(pageNum),
            "page_size": String(pageSize),
            "last_comment_seq_no": lastSeqNo,
            "biz_type": String(bizType.rawValue),
        ]
        if let bizSubType { params["biz_sub_type"] = String(bizSubType) }
        return try await requestWrapped("/comment/get_new_comments", params: params)
    }

    /// 获取歌曲推荐评论
    /// - Parameters:
    ///   - bizId: 歌曲 ID
    ///   - pageNum: 页码
    ///   - pageSize: 每页数量
    ///   - lastSeqNo: 上一页最后一条评论 ID
    func recommendComments(
        bizId: String,
        pageNum: Int = 1,
        pageSize: Int = 15,
        lastSeqNo: String = "",
        bizType: CommentBizType = .song,
        bizSubType: Int? = nil
    ) async throws -> JSON {
        var params = [
            "biz_id": bizId,
            "page_num": String(pageNum),
            "page_size": String(pageSize),
            "last_comment_seq_no": lastSeqNo,
            "biz_type": String(bizType.rawValue),
        ]
        if let bizSubType { params["biz_sub_type"] = String(bizSubType) }
        return try await requestWrapped("/comment/get_recommend_comments", params: params)
    }

    /// 获取时刻评论
    /// - Parameters:
    ///   - bizId: 歌曲 ID
    ///   - pageSize: 每页数量
    ///   - lastSeqNo: 上一页最后一条评论 ID
    func momentComments(
        bizId: String,
        pageSize: Int = 15,
        lastSeqNo: String = "",
        bizType: CommentBizType = .song,
        bizSubType: Int? = nil
    ) async throws -> JSON {
        var params = [
            "biz_id": bizId,
            "page_size": String(pageSize),
            "last_comment_seq_no": lastSeqNo,
            "biz_type": String(bizType.rawValue),
        ]
        if let bizSubType { params["biz_sub_type"] = String(bizSubType) }
        return try await requestWrapped("/comment/get_moment_comments", params: params)
    }
}
