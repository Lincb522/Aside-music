// MVPlayerView+CommentSection.swift
// MV 播放器内嵌评论区组件

import SwiftUI

// MARK: - MV 内嵌评论区

struct MVEmbeddedCommentSection: View {
    @ObservedObject var commentVM: CommentViewModel
    var isInputFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 评论区标题
            HStack(alignment: .bottom) {
                HStack(spacing: 6) {
                    Text(String(localized: "comment_title"))
                        .font(.rounded(size: 22, weight: .bold))
                        .foregroundColor(.asideTextPrimary)
                    if commentVM.totalCount > 0 {
                        Text("\(commentVM.totalCount)")
                            .font(.rounded(size: 14, weight: .medium))
                            .foregroundColor(.asideTextSecondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 24)

            // 排序标签
            sortTabs

            if commentVM.isLoading {
                skeletonView
            } else if commentVM.comments.isEmpty && commentVM.hotComments.isEmpty {
                emptyView
            } else {
                commentList
            }
        }
    }

    // MARK: - 排序标签

    private var sortTabs: some View {
        HStack(spacing: 8) {
            ForEach(CommentSortType.allCases, id: \.rawValue) { type in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        commentVM.changeSortType(type)
                    }
                } label: {
                    Text(type.title)
                        .font(.rounded(size: 13, weight: commentVM.sortType == type ? .semibold : .medium))
                        .foregroundColor(commentVM.sortType == type ? .asideIconForeground : .asideTextSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(commentVM.sortType == type ? Color.asideIconBackground : Color.asideTextPrimary.opacity(0.05))
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - 骨架屏

    private var skeletonView: some View {
        VStack(spacing: 14) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(Color.asideTextPrimary.opacity(0.06))
                        .frame(width: 36, height: 36)
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.asideTextPrimary.opacity(0.06))
                            .frame(width: 80, height: 12)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.asideTextPrimary.opacity(0.04))
                            .frame(height: 14)
                    }
                }
                .padding(.horizontal, 14)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 24)
    }

    // MARK: - 空状态

    private var emptyView: some View {
        VStack(spacing: 12) {
            AsideIcon(icon: .comment, size: 32, color: .asideTextSecondary.opacity(0.25))
            Text(String(localized: "comment_empty"))
                .font(.rounded(size: 15))
                .foregroundColor(.asideTextSecondary)
            Text(String(localized: "comment_be_first"))
                .font(.rounded(size: 13))
                .foregroundColor(.asideTextSecondary.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    // MARK: - 评论列表

    private var commentList: some View {
        VStack(spacing: 14) {
            // 热门评论
            if !commentVM.hotComments.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        AsideIcon(icon: .sparkle, size: 14, color: .asideOrange)
                        Text(String(localized: "comment_hot"))
                            .font(.rounded(size: 14, weight: .semibold))
                            .foregroundColor(.asideTextPrimary)
                    }
                    .padding(.leading, 4)

                    VStack(spacing: 0) {
                        ForEach(Array(commentVM.hotComments.enumerated()), id: \.element.id) { index, comment in
                            CommentRow(
                                comment: comment,
                                isHot: true,
                                onLike: { commentVM.toggleLike(comment: comment, isHot: true) },
                                onReply: {
                                    commentVM.replyTarget = comment
                                    isInputFocused.wrappedValue = true
                                }
                            )
                            if index < commentVM.hotComments.count - 1 {
                                Divider().padding(.leading, 52)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.asideGlassOverlay))
                            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }

            // 全部评论
            if !commentVM.comments.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Text(String(localized: "comment_all"))
                            .font(.rounded(size: 14, weight: .semibold))
                            .foregroundColor(.asideTextPrimary)
                        if commentVM.totalCount > 0 {
                            Text("\(commentVM.totalCount)")
                                .font(.rounded(size: 12, weight: .medium))
                                .foregroundColor(.asideTextSecondary)
                        }
                    }
                    .padding(.leading, 4)

                    VStack(spacing: 0) {
                        ForEach(Array(commentVM.comments.enumerated()), id: \.element.id) { index, comment in
                            CommentRow(
                                comment: comment,
                                isHot: false,
                                onLike: { commentVM.toggleLike(comment: comment, isHot: false) },
                                onReply: {
                                    commentVM.replyTarget = comment
                                    isInputFocused.wrappedValue = true
                                }
                            )
                            if index < commentVM.comments.count - 1 {
                                Divider().padding(.leading, 52)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.asideGlassOverlay))
                            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }

            // 加载更多
            if commentVM.hasMore {
                Button {
                    commentVM.loadMore()
                } label: {
                    HStack(spacing: 8) {
                        if commentVM.isLoadingMore {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Text(String(localized: "comment_load_more"))
                                .font(.rounded(size: 14, weight: .medium))
                        }
                    }
                    .foregroundColor(.asideTextSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.asideTextPrimary.opacity(0.04))
                    )
                }
                .disabled(commentVM.isLoadingMore)
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - MV 评论输入栏

struct MVCommentInputBar: View {
    @ObservedObject var commentVM: CommentViewModel
    var isInputFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.asideSeparator)
                .frame(height: 0.5)

            // 回复提示
            if let reply = commentVM.replyTarget {
                HStack(spacing: 8) {
                    Text(String(localized: "comment_reply"))
                        .font(.rounded(size: 12))
                        .foregroundColor(.asideTextSecondary)
                    Text("@\(reply.user.nickname)")
                        .font(.rounded(size: 12, weight: .medium))
                        .foregroundColor(.asideTextPrimary)
                    Spacer()
                    Button {
                        withAnimation { commentVM.replyTarget = nil }
                    } label: {
                        AsideIcon(icon: .xmark, size: 10, color: .asideTextSecondary)
                            .padding(6)
                            .background(Circle().fill(Color.asideTextPrimary.opacity(0.06)))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    TextField(
                        commentVM.replyTarget != nil ? String(localized: "comment_reply_placeholder \(commentVM.replyTarget!.user.nickname)") : String(localized: "comment_placeholder"),
                        text: $commentVM.commentText
                    )
                    .font(.rounded(size: 15))
                    .focused(isInputFocused)

                    if !commentVM.commentText.isEmpty {
                        Button {
                            commentVM.commentText = ""
                        } label: {
                            AsideIcon(icon: .xmark, size: 10, color: .asideTextSecondary)
                                .padding(4)
                                .background(Circle().fill(Color.asideTextPrimary.opacity(0.08)))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.asideTextPrimary.opacity(0.05))
                )

                let canSend = !commentVM.commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !commentVM.isSending
                Button {
                    commentVM.sendComment()
                    isInputFocused.wrappedValue = false
                } label: {
                    ZStack {
                        Circle()
                            .fill(canSend ? Color.asideIconBackground : Color.asideTextPrimary.opacity(0.06))
                            .frame(width: 36, height: 36)
                        if commentVM.isSending {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(.asideIconForeground)
                        } else {
                            AsideIcon(
                                icon: .send,
                                size: 16,
                                color: canSend ? .asideIconForeground : .asideTextSecondary.opacity(0.4)
                            )
                        }
                    }
                }
                .disabled(!canSend)
                .buttonStyle(AsideBouncingButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .padding(.bottom, 4)
        }
        .background(.ultraThinMaterial)
    }
}
