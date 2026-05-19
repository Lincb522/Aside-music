import Foundation

// MARK: - 评论相关 API

public extension QQMusicClient {

    /// 获取歌曲评论数量
    /// - Parameter bizId: 歌曲 ID
    func commentCount(bizId: String) async throws -> JSON {
        try await requestWrapped("/comment/get_comment_count", params: ["biz_id": bizId])
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
        lastSeqNo: String = ""
    ) async throws -> JSON {
        try await requestWrapped("/comment/get_hot_comments", params: [
            "biz_id": bizId,
            "page_num": String(pageNum),
            "page_size": String(pageSize),
            "last_comment_seq_no": lastSeqNo,
        ])
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
        lastSeqNo: String = ""
    ) async throws -> JSON {
        try await requestWrapped("/comment/get_new_comments", params: [
            "biz_id": bizId,
            "page_num": String(pageNum),
            "page_size": String(pageSize),
            "last_comment_seq_no": lastSeqNo,
        ])
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
        lastSeqNo: String = ""
    ) async throws -> JSON {
        try await requestWrapped("/comment/get_recommend_comments", params: [
            "biz_id": bizId,
            "page_num": String(pageNum),
            "page_size": String(pageSize),
            "last_comment_seq_no": lastSeqNo,
        ])
    }

    /// 获取时刻评论
    /// - Parameters:
    ///   - bizId: 歌曲 ID
    ///   - pageSize: 每页数量
    ///   - lastSeqNo: 上一页最后一条评论 ID
    func momentComments(
        bizId: String,
        pageSize: Int = 15,
        lastSeqNo: String = ""
    ) async throws -> JSON {
        try await requestWrapped("/comment/get_moment_comments", params: [
            "biz_id": bizId,
            "page_size": String(pageSize),
            "last_comment_seq_no": lastSeqNo,
        ])
    }
}
