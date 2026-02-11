// CommentViewModel.swift
// 评论系统视图模型

import Foundation
import Combine
import NeteaseCloudMusicAPI

class CommentViewModel: ObservableObject {
    // MARK: - 属性
    
    let resourceId: Int
    let resourceType: CommentType
    
    @Published var comments: [Comment] = []
    @Published var hotComments: [Comment] = []
    @Published var totalCount: Int = 0
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMore = true
    @Published var sortType: CommentSortType = .recommended
    @Published var errorMessage: String?
    
    // 发送评论
    @Published var commentText = ""
    @Published var isSending = false
    @Published var replyTarget: Comment?
    
    private var currentPage = 1
    private var cursor = ""
    private let pageSize = 20
    private var cancellables = Set<AnyCancellable>()
    private let api = APIService.shared
    
    // MARK: - 初始化
    
    init(resourceId: Int, resourceType: CommentType = .song) {
        self.resourceId = resourceId
        self.resourceType = resourceType
    }
    
    // MARK: - 加载评论
    
    func loadComments() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        currentPage = 1
        cursor = ""
        
        // 同时加载热评和普通评论
        let hotPublisher = api.fetchHotComments(type: resourceType, id: resourceId, limit: 5)
        let commentsPublisher = api.fetchComments(
            type: resourceType, id: resourceId,
            pageNo: 1, pageSize: pageSize,
            sortType: sortType.rawValue
        )
        
        Publishers.Zip(hotPublisher, commentsPublisher)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = "加载评论失败: \(error.localizedDescription)"
                }
            } receiveValue: { [weak self] hotResult, commentData in
                guard let self else { return }
                self.hotComments = hotResult
                self.comments = commentData.comments ?? []
                self.totalCount = commentData.totalCount ?? 0
                self.hasMore = commentData.hasMore ?? false
                self.cursor = commentData.cursor ?? ""
                self.currentPage = 2
            }
            .store(in: &cancellables)
    }
    
    /// 加载更多评论
    func loadMore() {
        guard !isLoadingMore, hasMore else { return }
        isLoadingMore = true
        
        api.fetchComments(
            type: resourceType, id: resourceId,
            pageNo: currentPage, pageSize: pageSize,
            sortType: sortType.rawValue,
            cursor: sortType == .latest ? cursor : ""
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] completion in
            self?.isLoadingMore = false
            if case .failure(let error) = completion {
                AppLogger.error("加载更多评论失败: \(error)")
            }
        } receiveValue: { [weak self] data in
            guard let self else { return }
            self.comments.append(contentsOf: data.comments ?? [])
            self.hasMore = data.hasMore ?? false
            self.cursor = data.cursor ?? ""
            self.currentPage += 1
        }
        .store(in: &cancellables)
    }
    
    /// 切换排序方式
    func changeSortType(_ type: CommentSortType) {
        guard type != sortType else { return }
        sortType = type
        loadComments()
    }
    
    // MARK: - 点赞
    
    func toggleLike(comment: Comment, isHot: Bool) {
        let newLiked = !comment.liked
        
        api.likeComment(type: resourceType, id: resourceId, commentId: comment.commentId, like: newLiked)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    AppLogger.error("点赞失败: \(error)")
                }
            } receiveValue: { [weak self] _ in
                guard let self else { return }
                // 更新本地状态
                if isHot {
                    if let idx = self.hotComments.firstIndex(where: { $0.commentId == comment.commentId }) {
                        self.updateCommentLike(in: &self.hotComments, at: idx, liked: newLiked)
                    }
                } else {
                    if let idx = self.comments.firstIndex(where: { $0.commentId == comment.commentId }) {
                        self.updateCommentLike(in: &self.comments, at: idx, liked: newLiked)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateCommentLike(in list: inout [Comment], at index: Int, liked: Bool) {
        let old = list[index]
        let newCount = liked ? old.likedCount + 1 : max(0, old.likedCount - 1)
        // 重建 Comment（struct 不可变）
        let updated = Comment(
            commentId: old.commentId, content: old.content, time: old.time,
            likedCount: newCount, liked: liked, user: old.user,
            beReplied: old.beReplied, ipLocation: old.ipLocation,
            timeStr: old.timeStr, parentCommentId: old.parentCommentId
        )
        list[index] = updated
    }
    
    // MARK: - 发送评论
    
    func sendComment() {
        let text = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        isSending = true
        
        let publisher: AnyPublisher<SimpleResponse, Error>
        if let reply = replyTarget {
            publisher = api.replyComment(type: resourceType, id: resourceId, content: text, commentId: reply.commentId)
        } else {
            publisher = api.postComment(type: resourceType, id: resourceId, content: text)
        }
        
        publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isSending = false
                if case .failure(let error) = completion {
                    self?.errorMessage = "发送失败: \(error.localizedDescription)"
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                if response.code == 200 {
                    self.commentText = ""
                    self.replyTarget = nil
                    // 重新加载评论
                    self.loadComments()
                } else {
                    self.errorMessage = response.message ?? "发送失败"
                }
            }
            .store(in: &cancellables)
    }
}
