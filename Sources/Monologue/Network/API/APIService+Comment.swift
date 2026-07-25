import Foundation
import Combine
import NeteaseCloudMusicAPI

// MARK: - 评论接口

extension APIService {

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
