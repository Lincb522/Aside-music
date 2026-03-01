// CommentView.swift
// 评论页面 - 重新设计

import SwiftUI
import NeteaseCloudMusicAPI

struct CommentView: View {
    @StateObject private var vm: CommentViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isInputFocused: Bool
    
    let songName: String
    let artistName: String
    let coverUrl: URL?
    
    init(resourceId: Int, resourceType: CommentType = .song, songName: String = "", artistName: String = "", coverUrl: URL? = nil) {
        _vm = StateObject(wrappedValue: CommentViewModel(resourceId: resourceId, resourceType: resourceType))
        self.songName = songName
        self.artistName = artistName
        self.coverUrl = coverUrl
    }
    
    @State private var showEmojiPicker = false
    
    var body: some View {
        ZStack {
            AsideBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部导航栏
                commentHeader
                
                // 评论内容
                commentContent
                
                // 表情选择器
                if showEmojiPicker {
                    NeteaseEmojiPicker { emoji in
                        vm.commentText += emoji
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // 底部输入栏
                inputBar
            }
            
            // 错误提示 Toast
            if let error = vm.errorMessage {
                VStack {
                    Spacer()
                    Text(error)
                        .font(.rounded(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.red.opacity(0.9)))
                        .glassEffect(.regular, in: .capsule)
                        .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation { vm.errorMessage = nil }
                    }
                }
            }
        }
        .onAppear { vm.loadComments() }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showEmojiPicker)
    }
    
    // MARK: - 顶部导航栏
    
    private var commentHeader: some View {
        VStack(spacing: 0) {
            // 拖拽指示器
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.asideTextSecondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 12)
            
            HStack(spacing: 14) {
                // 歌曲封面
                if let url = coverUrl {
                    CachedAsyncImage(url: url) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.asideTextSecondary.opacity(0.1))
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                
                // 歌曲信息
                VStack(alignment: .leading, spacing: 2) {
                    if !songName.isEmpty {
                        Text(songName)
                            .font(.rounded(size: 16, weight: .semibold))
                            .foregroundColor(.asideTextPrimary)
                            .lineLimit(1)
                    }
                    
                    HStack(spacing: 6) {
                        if !artistName.isEmpty {
                            Text(artistName)
                                .font(.rounded(size: 13))
                                .foregroundColor(.asideTextSecondary)
                                .lineLimit(1)
                        }
                        
                        if vm.totalCount > 0 {
                            Text("·")
                                .foregroundColor(.asideTextSecondary)
                            Text(String(format: NSLocalizedString("comment_count", comment: ""), vm.totalCount))
                                .font(.rounded(size: 13))
                                .foregroundColor(.asideTextSecondary)
                        }
                    }
                }
                
                Spacer()
                
                // 关闭按钮
                Button { dismiss() } label: {
                    ZStack {
                        Circle()
                            .fill(Color.asideTextPrimary.opacity(0.06))
                            .frame(width: 32, height: 32)
                        AsideIcon(icon: .close, size: 14, color: .asideTextSecondary)
                    }
                }
                .buttonStyle(AsideBouncingButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
            
            // 分隔线
            Rectangle()
                .fill(Color.asideSeparator)
                .frame(height: 0.5)
        }
    }

    // MARK: - 评论内容
    
    private var commentContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                sortTabBar
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                
                if vm.isLoading {
                    loadingView
                        .padding(.bottom, 16)
                } else if vm.comments.isEmpty && vm.hotComments.isEmpty {
                    emptyView
                } else {
                    if !vm.hotComments.isEmpty {
                        HStack(spacing: 6) {
                            AsideIcon(icon: .sparkle, size: 14, color: .asideOrange)
                            Text(LocalizedStringKey("comment_hot_section"))
                                .font(.rounded(size: 14, weight: .semibold))
                                .foregroundColor(.asideTextPrimary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 4)
                        .padding(.bottom, 10)
                        
                        ForEach(vm.hotComments) { comment in
                            CommentRow(
                                comment: comment,
                                isHot: true,
                                onLike: { vm.toggleLike(comment: comment, isHot: true) },
                                onReply: {
                                    vm.replyTarget = comment
                                    isInputFocused = true
                                }
                            )
                            
                            if comment.id != vm.hotComments.last?.id {
                                Divider().padding(.leading, 52)
                            }
                        }
                        .padding(.bottom, 20)
                    }
                    
                    HStack(spacing: 6) {
                        Text(LocalizedStringKey("comment_all_section"))
                            .font(.rounded(size: 14, weight: .semibold))
                            .foregroundColor(.asideTextPrimary)
                        if vm.totalCount > 0 {
                            Text("\(vm.totalCount)")
                                .font(.rounded(size: 12, weight: .medium))
                                .foregroundColor(.asideTextSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 4)
                    .padding(.bottom, 10)
                    
                    ForEach(vm.comments) { comment in
                        CommentRow(
                            comment: comment,
                            isHot: false,
                            onLike: { vm.toggleLike(comment: comment, isHot: false) },
                            onReply: {
                                vm.replyTarget = comment
                                isInputFocused = true
                            }
                        )
                        
                        if comment.id != vm.comments.last?.id {
                            Divider().padding(.leading, 52)
                        }
                    }
                    
                    if vm.hasMore {
                        loadMoreButton
                            .padding(.top, 16)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .refreshable {
            vm.loadComments()
        }
    }
    
    // MARK: - 排序标签栏
    
    private var sortTabBar: some View {
        HStack(spacing: 8) {
            ForEach(CommentSortType.allCases, id: \.rawValue) { type in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        vm.changeSortType(type)
                    }
                } label: {
                    Text(type.title)
                        .font(.rounded(size: 13, weight: vm.sortType == type ? .semibold : .medium))
                        .foregroundColor(vm.sortType == type ? .asideIconForeground : .asideTextSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(vm.sortType == type ? Color.asideIconBackground : Color.asideTextPrimary.opacity(0.05))
                        )
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
        }
    }
    
    // MARK: - 加载更多
    
    private var loadMoreButton: some View {
        Button {
            vm.loadMore()
        } label: {
            HStack(spacing: 8) {
                if vm.isLoadingMore {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text(LocalizedStringKey("comment_load_more_btn"))
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
        .disabled(vm.isLoadingMore)
        .buttonStyle(.plain)
    }
    
    // MARK: - 加载状态
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ForEach(0..<4, id: \.self) { _ in
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
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.asideTextPrimary.opacity(0.04))
                            .frame(width: 200, height: 14)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.asideGlassTint)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shimmer()
    }
    
    // MARK: - 空状态
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 40)
            
            ZStack {
                Circle()
                    .fill(Color.asideTextPrimary.opacity(0.04))
                    .frame(width: 80, height: 80)
                AsideIcon(icon: .comment, size: 36, color: .asideTextSecondary.opacity(0.4))
            }
            
            VStack(spacing: 6) {
                Text(LocalizedStringKey("comment_no_comments"))
                    .font(.rounded(size: 17, weight: .semibold))
                    .foregroundColor(.asideTextPrimary)
                Text(LocalizedStringKey("comment_be_first_text"))
                    .font(.rounded(size: 14))
                    .foregroundColor(.asideTextSecondary)
            }
            
            Spacer().frame(height: 40)
        }
    }
    
    // MARK: - 输入栏
    
    private var inputBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.asideSeparator)
                .frame(height: 0.5)
            
            // 回复提示
            if let reply = vm.replyTarget {
                HStack(spacing: 8) {
                    Text("回复")
                        .font(.rounded(size: 12))
                        .foregroundColor(.asideTextSecondary)
                    Text("@\(reply.user.nickname)")
                        .font(.rounded(size: 12, weight: .medium))
                        .foregroundColor(.asideTextPrimary)
                    Spacer()
                    Button {
                        withAnimation { vm.replyTarget = nil }
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
            
            HStack(spacing: 10) {
                // 表情按钮
                Button {
                    withAnimation { showEmojiPicker.toggle() }
                    isInputFocused = false
                } label: {
                    ZStack {
                        Circle()
                            .fill(showEmojiPicker ? Color.asideIconBackground : Color.asideTextPrimary.opacity(0.06))
                            .frame(width: 36, height: 36)
                        AsideIcon(
                            icon: .emoji,
                            size: 18,
                            color: showEmojiPicker ? .asideIconForeground : .asideTextSecondary
                        )
                    }
                }
                .buttonStyle(AsideBouncingButtonStyle())
                
                // 输入框
                HStack(spacing: 8) {
                    TextField(
                        vm.replyTarget != nil ? String(format: NSLocalizedString("comment_reply_to", comment: ""), vm.replyTarget!.user.nickname) : NSLocalizedString("comment_write", comment: ""),
                        text: $vm.commentText
                    )
                    .font(.rounded(size: 15))
                    .focused($isInputFocused)
                    .onTapGesture {
                        if showEmojiPicker {
                            withAnimation { showEmojiPicker = false }
                        }
                    }
                    
                    if !vm.commentText.isEmpty {
                        Button {
                            vm.commentText = ""
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
                
                // 发送按钮
                let canSend = !vm.commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !vm.isSending
                
                Button {
                    vm.sendComment()
                    isInputFocused = false
                    withAnimation { showEmojiPicker = false }
                } label: {
                    ZStack {
                        Circle()
                            .fill(canSend ? Color.asideIconBackground : Color.asideTextPrimary.opacity(0.06))
                            .frame(width: 36, height: 36)
                        
                        if vm.isSending {
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
        .background(.clear).glassEffect(.regular, in: .rect(cornerRadius: 16))
    }
}


// MARK: - 评论行

struct CommentRow: View {
    let comment: Comment
    var isHot: Bool = false
    let onLike: () -> Void
    let onReply: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 头像
            CachedAsyncImage(url: comment.user.avatarURL) {
                Circle().fill(Color.asideTextPrimary.opacity(0.06))
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 6) {
                // 用户名 + 时间
                HStack(spacing: 6) {
                    Text(comment.user.nickname)
                        .font(.rounded(size: 13, weight: .semibold))
                        .foregroundColor(.asideTextSecondary)
                    
                    if let location = comment.locationText {
                        Text("· \(location)")
                            .font(.rounded(size: 11))
                            .foregroundColor(.asideTextSecondary.opacity(0.5))
                    }
                }
                
                // 评论内容
                Text(comment.content)
                    .font(.rounded(size: 15))
                    .foregroundColor(.asideTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)
                
                // 被回复内容
                if let replies = comment.beReplied, let first = replies.first,
                   let user = first.user, let content = first.content {
                    HStack(alignment: .top, spacing: 0) {
                        Text("\(Text("@\(user.nickname)").font(.rounded(size: 13, weight: .medium)).foregroundColor(.asideTextSecondary))\(Text("：\(content)").font(.rounded(size: 13)).foregroundColor(.asideTextSecondary.opacity(0.8)))")
                    }
                    .lineLimit(3)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.asideTextPrimary.opacity(0.03))
                    )
                }
                
                // 时间 + 操作栏
                HStack(spacing: 0) {
                    Text(comment.formattedTime)
                        .font(.rounded(size: 12))
                        .foregroundColor(.asideTextSecondary.opacity(0.6))
                    
                    Spacer()
                    
                    // 回复
                    Button(action: onReply) {
                        HStack(spacing: 3) {
                            AsideIcon(icon: .comment, size: 14, color: .asideTextSecondary.opacity(0.5))
                        }
                    }
                    .padding(.trailing, 16)
                    
                    // 点赞
                    Button(action: onLike) {
                        HStack(spacing: 4) {
                            AsideIcon(
                                icon: comment.liked ? .liked : .like,
                                size: 14,
                                color: comment.liked ? .asideAccentRed : .asideTextSecondary.opacity(0.5)
                            )
                            if comment.likedCount > 0 {
                                Text(formatCount(comment.likedCount))
                                    .font(.rounded(size: 12))
                                    .foregroundColor(comment.liked ? .asideAccentRed : .asideTextSecondary.opacity(0.6))
                            }
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
    
    private func formatCount(_ count: Int) -> String {
        if count >= 10000 {
            return String(format: "%.1fw", Double(count) / 10000)
        }
        return "\(count)"
    }
}

// MARK: - 骨架屏闪烁效果

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.1),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 2)
                    .offset(x: -geo.size.width + phase * geo.size.width * 3)
                }
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}
