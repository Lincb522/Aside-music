// CommentView.swift
// 评论页面 - 重新设计

import SwiftUI
import NeteaseCloudMusicAPI

struct CommentView: View {
    @StateObject private var vm: CommentViewModel
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.monologueSheetDismiss) private var monologueSheetDismiss
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
    
    var body: some View {
        let _ = settings.globalThemeRevision

        ZStack {
            ThemedPageBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部导航栏
                commentHeader
                
                // 评论内容
                commentContent
                
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
                        .monologueGlassCapsule()
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
    }
    
    // MARK: - 顶部导航栏
    
    private var commentHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // 歌曲封面
                if let url = coverUrl {
                    CachedAsyncImage(url: url) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.monologueTextSecondary.opacity(0.1))
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                
                // 歌曲信息
                VStack(alignment: .leading, spacing: 2) {
                    if !songName.isEmpty {
                        Text(songName)
                            .font(.rounded(size: 16, weight: .semibold))
                            .foregroundColor(commentText)
                            .lineLimit(1)
                    }
                    
                    HStack(spacing: 6) {
                        if !artistName.isEmpty {
                            Text(artistName)
                                .font(.rounded(size: 13))
                                .foregroundColor(commentSecondaryText)
                                .lineLimit(1)
                        }
                        
                        if vm.totalCount > 0 {
                            Text("·")
                                .foregroundColor(commentSecondaryText)
                            Text(String(format: NSLocalizedString("comment_count", comment: ""), vm.totalCount))
                                .font(.rounded(size: 13))
                                .foregroundColor(commentSecondaryText)
                        }
                    }
                }
                
                Spacer()
                
                // 关闭按钮
                Button { dismissCurrentPresentation(systemDismiss: dismiss, monologueSheetDismiss: monologueSheetDismiss) } label: {
                    ZStack {
                        Circle()
                            .fill(commentControlFill)
                            .frame(width: 32, height: 32)
                        MonologueIcon(icon: .close, size: 14, color: commentSecondaryText)
                    }
                }
                .buttonStyle(MonologueBouncingButtonStyle())
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.bottom, 14)
            
            // 分隔线
            Rectangle()
                .fill(commentSeparator)
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
                            MonologueIcon(icon: .sparkle, size: 14, color: .monologueOrange)
                            Text(LocalizedStringKey("comment_hot_section"))
                                .font(.rounded(size: 14, weight: .semibold))
                                .foregroundColor(commentText)
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
                            .foregroundColor(commentText)
                        if vm.totalCount > 0 {
                            Text("\(vm.totalCount)")
                                .font(.rounded(size: 12, weight: .medium))
                                .foregroundColor(commentSecondaryText)
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
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
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
                        .foregroundColor(sortForeground(isSelected: vm.sortType == type))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background { sortPillBackground(isSelected: vm.sortType == type) }
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
            .foregroundColor(commentSecondaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(commentControlFill)
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
                        .fill(commentControlFill)
                        .frame(width: 36, height: 36)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(commentControlFill)
                            .frame(width: 80, height: 12)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(commentInputFill)
                            .frame(height: 14)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(commentInputFill)
                            .frame(width: 200, height: 14)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
        .padding(.vertical, 4)
        .themedPageSurface(cornerRadius: 16, elevated: false, mangaTint: MangaStyle.bubbleWhite)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shimmer()
    }
    
    // MARK: - 空状态
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 40)
            
            ZStack {
                Circle()
                    .fill(commentControlFill)
                    .frame(width: 80, height: 80)
                MonologueIcon(icon: .comment, size: 36, color: commentSecondaryText.opacity(0.46))
            }
            
            VStack(spacing: 6) {
                Text(LocalizedStringKey("comment_no_comments"))
                    .font(.rounded(size: 17, weight: .semibold))
                    .foregroundColor(commentText)
                Text(LocalizedStringKey("comment_be_first_text"))
                    .font(.rounded(size: 14))
                    .foregroundColor(commentSecondaryText)
            }
            
            Spacer().frame(height: 40)
        }
    }
    
    // MARK: - 输入栏
    
    private var inputBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(commentSeparator)
                .frame(height: 0.5)
            
            // 回复提示
            if let reply = vm.replyTarget {
                HStack(spacing: 8) {
                    Text("回复")
                        .font(.rounded(size: 12))
                        .foregroundColor(commentSecondaryText)
                    Text("@\(reply.user.nickname)")
                        .font(.rounded(size: 12, weight: .medium))
                        .foregroundColor(commentText)
                    Spacer()
                    Button {
                        withAnimation { vm.replyTarget = nil }
                    } label: {
                        MonologueIcon(icon: .xmark, size: 10, color: commentSecondaryText)
                            .padding(6)
                            .background(Circle().fill(commentControlFill))
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.top, 10)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            HStack(spacing: 10) {
                // 输入框
                HStack(spacing: 8) {
                    TextField(
                        vm.replyTarget != nil ? String(format: NSLocalizedString("comment_reply_to", comment: ""), vm.replyTarget!.user.nickname) : NSLocalizedString("comment_write", comment: ""),
                        text: $vm.commentText
                    )
                    .font(.rounded(size: 15))
                    .monologueTextInputBehavior()
                    .focused($isInputFocused)
                    
                    if !vm.commentText.isEmpty {
                        Button {
                            vm.commentText = ""
                        } label: {
                            MonologueIcon(icon: .xmark, size: 10, color: commentSecondaryText)
                                .padding(4)
                                .background(Circle().fill(commentControlFill))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(commentInputFill)
                )
                
                // 发送按钮
                let canSend = !vm.commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !vm.isSending
                
                Button {
                    vm.sendComment()
                    isInputFocused = false
                } label: {
                    ZStack {
                        Circle()
                            .fill(canSend ? commentAccentFill : commentControlFill)
                            .frame(width: 36, height: 36)
                        
                        if vm.isSending {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(commentAccentForeground)
                        } else {
                            MonologueIcon(
                                icon: .send,
                                size: 16,
                                color: canSend ? commentAccentForeground : commentSecondaryText.opacity(0.4)
                            )
                        }
                    }
                }
                .disabled(!canSend)
                .buttonStyle(MonologueBouncingButtonStyle())
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.vertical, 10)
            .padding(.bottom, 4)
        }
        .background(
            commentBarBackground
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var commentSeparator: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.separator }
        return NeumorphicStyle.isActive ? NeumorphicStyle.separator.opacity(0.5) : Color.monologueSeparator
    }

    private var commentControlFill: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.materialPressed.opacity(0.78) }
        return NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monologueTextPrimary.opacity(0.06)
    }

    private var commentInputFill: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.materialList.opacity(0.74) }
        return NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monologueTextPrimary.opacity(0.05)
    }

    private var commentAccentFill: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        return NeumorphicStyle.isActive ? NeumorphicStyle.accent : Color.monologueIconBackground
    }

    private var commentAccentForeground: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.onAccent }
        if NeumorphicStyle.isActive { return Color(light: .white, dark: .black) }
        return Color.monologueIconForeground
    }

    private var commentText: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        return Color.monologueTextPrimary
    }

    private var commentSecondaryText: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        return Color.monologueTextSecondary
    }

    private var commentBarBackground: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.materialFloating.opacity(0.96) }
        return NeumorphicStyle.isActive ? NeumorphicStyle.surface.opacity(0.96) : Color(UIColor.systemBackground)
    }

    private func sortForeground(isSelected: Bool) -> Color {
        if SequoiaStyle.isActive {
            return isSelected ? SequoiaStyle.onAccent : SequoiaStyle.inkSoft
        }
        if NeumorphicStyle.isActive {
            return isSelected ? NeumorphicStyle.accent : NeumorphicStyle.inkSoft
        }
        return isSelected ? .monologueIconForeground : .monologueTextSecondary
    }

    @ViewBuilder
    private func sortPillBackground(isSelected: Bool) -> some View {
        if SequoiaStyle.isActive {
            Capsule()
                .fill(isSelected ? SequoiaStyle.accent : SequoiaStyle.materialList.opacity(0.66))
                .overlay(Capsule().stroke(isSelected ? SequoiaStyle.accent.opacity(0.18) : SequoiaStyle.separator, lineWidth: 0.55))
        } else if NeumorphicStyle.isActive {
            NeumorphicSurfaceBackground(
                cornerRadius: 15,
                elevated: isSelected,
                pressed: !isSelected,
                tint: isSelected ? NeumorphicStyle.accent.opacity(0.22) : NeumorphicStyle.surface
            )
        } else {
            Capsule()
                .fill(isSelected ? Color.monologueIconBackground : Color.monologueTextPrimary.opacity(0.05))
        }
    }
}


// MARK: - 评论行

struct CommentRow: View {
    let comment: Comment
    var isHot: Bool = false
    let onLike: () -> Void
    let onReply: () -> Void

    private var text: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        return .monologueTextPrimary
    }

    private var secondaryText: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        return .monologueTextSecondary
    }

    private var mutedText: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.inkMuted }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkMuted }
        return .monologueTextSecondary.opacity(0.6)
    }

    private var rowFill: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.materialPressed.opacity(0.62) }
        return Color.monologueTextPrimary.opacity(0.06)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 头像
            CachedAsyncImage(url: comment.user.avatarURL) {
                Circle().fill(rowFill)
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 6) {
                // 用户名 + 时间
                HStack(spacing: 6) {
                    Text(comment.user.nickname)
                        .font(.rounded(size: 13, weight: .semibold))
                        .foregroundColor(secondaryText)
                    
                    if let location = comment.locationText {
                        Text("· \(location)")
                            .font(.rounded(size: 11))
                            .foregroundColor(mutedText.opacity(0.76))
                    }
                }
                
                // 评论内容
                Text(comment.content)
                    .font(.rounded(size: 15))
                    .foregroundColor(text)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)
                
                // 被回复内容
                if let replies = comment.beReplied, let first = replies.first,
                   let user = first.user, let content = first.content {
                    HStack(alignment: .top, spacing: 0) {
                        Text("\(Text("@\(user.nickname)").font(.rounded(size: 13, weight: .medium)).foregroundColor(secondaryText))\(Text("：\(content)").font(.rounded(size: 13)).foregroundColor(secondaryText.opacity(0.8)))")
                    }
                    .lineLimit(3)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(SequoiaStyle.isActive ? SequoiaStyle.materialList.opacity(0.54) : Color.monologueTextPrimary.opacity(0.03))
                    )
                }
                
                // 时间 + 操作栏
                HStack(spacing: 0) {
                    Text(comment.formattedTime)
                        .font(.rounded(size: 12))
                        .foregroundColor(mutedText)
                    
                    Spacer()
                    
                    // 回复
                    Button(action: onReply) {
                        HStack(spacing: 3) {
                            MonologueIcon(icon: .comment, size: 14, color: mutedText.opacity(0.78))
                        }
                    }
                    .padding(.trailing, 16)
                    
                    // 点赞
                    Button(action: onLike) {
                        HStack(spacing: 4) {
                            MonologueIcon(
                                icon: comment.liked ? .liked : .like,
                                size: 14,
                                color: comment.liked ? .monologueAccentRed : mutedText.opacity(0.78)
                            )
                            if comment.likedCount > 0 {
                                Text(formatCount(comment.likedCount))
                                    .font(.rounded(size: 12))
                                    .foregroundColor(comment.liked ? .monologueAccentRed : mutedText)
                            }
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, DeviceLayout.isPad ? 20 : 14)
        .padding(.vertical, 12)
        .background {
            if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 18, elevated: false)
            } else if SequoiaStyle.isActive {
                SequoiaSurfaceBackground(cornerRadius: 16, elevated: false, role: .list)
            }
        }
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
