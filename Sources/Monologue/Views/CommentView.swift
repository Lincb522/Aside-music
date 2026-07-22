// CommentView.swift
// 评论页面 - 杂志编辑风重设计

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

    private var isThemedSurface: Bool {
        NeumorphicStyle.isActive || SequoiaStyle.isActive
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
            HStack(alignment: .center, spacing: 14) {
                // 标题信息
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(String(localized: "comment_title").uppercased())
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .tracking(2.4)
                            .foregroundColor(commentSecondaryText.opacity(0.75))

                        if vm.totalCount > 0 {
                            Text(formatCount(vm.totalCount))
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(commentAccentInk)
                        }
                    }

                    Text(songName.isEmpty ? String(localized: "comment_title") : songName)
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundColor(commentText)
                        .lineLimit(1)

                    if !artistName.isEmpty {
                        Text(artistName)
                            .font(.rounded(size: 12.5))
                            .foregroundColor(commentSecondaryText)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                // 歌曲封面
                if let url = coverUrl {
                    CachedAsyncImage(url: url) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(commentControlFill)
                    }
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(commentSeparator.opacity(0.8), lineWidth: 0.8)
                    )
                    .rotationEffect(.degrees(-2.5))
                    .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
                }
                
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
            .padding(.top, 4)
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
                    .padding(.top, 14)
                    .padding(.bottom, 18)
                
                if vm.isLoading {
                    loadingView
                        .padding(.bottom, 16)
                } else if vm.comments.isEmpty && vm.hotComments.isEmpty {
                    emptyView
                } else {
                    if !vm.hotComments.isEmpty {
                        sectionMark(
                            title: String(localized: "comment_hot_section"),
                            count: vm.hotComments.count,
                            tick: .monologueOrange
                        )
                        .padding(.bottom, 6)
                        
                        ForEach(Array(vm.hotComments.enumerated()), id: \.element.id) { index, comment in
                            CommentRow(
                                comment: comment,
                                isHot: true,
                                hotRank: index + 1,
                                onLike: { vm.toggleLike(comment: comment, isHot: true) },
                                onReply: {
                                    vm.replyTarget = comment
                                    isInputFocused = true
                                }
                            )
                            
                            if comment.id != vm.hotComments.last?.id {
                                rowDivider
                            }
                        }
                        .padding(.bottom, 8)

                        Spacer().frame(height: 18)
                    }
                    
                    sectionMark(
                        title: String(localized: "comment_all_section"),
                        count: vm.totalCount,
                        tick: commentAccentInk
                    )
                    .padding(.bottom, 6)
                    
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
                            rowDivider
                        }
                    }
                    
                    if vm.hasMore {
                        loadMoreButton
                            .padding(.top, 18)
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

    private var rowDivider: some View {
        Rectangle()
            .fill(commentSeparator.opacity(0.72))
            .frame(height: 0.5)
            .padding(.leading, isThemedSurface ? 60 : 50)
    }

    // MARK: - 小节标题

    private func sectionMark(title: String, count: Int, tick: Color) -> some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(tick)
                .frame(width: 3, height: 12)

            Text(title)
                .font(.rounded(size: 14, weight: .bold))
                .foregroundColor(commentText)

            if count > 0 {
                Text(formatCount(count))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(commentSecondaryText.opacity(0.75))
            }

            Rectangle()
                .fill(commentSeparator.opacity(0.6))
                .frame(height: 0.5)
        }
        .padding(.horizontal, 2)
        .padding(.bottom, 4)
    }
    
    // MARK: - 排序标签栏
    
    private var sortTabBar: some View {
        HStack(spacing: isThemedSurface ? 8 : 20) {
            ForEach(CommentSortType.allCases, id: \.rawValue) { type in
                let isSelected = vm.sortType == type
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        vm.changeSortType(type)
                    }
                } label: {
                    if isThemedSurface {
                        Text(type.title)
                            .font(.rounded(size: 13, weight: isSelected ? .semibold : .medium))
                            .foregroundColor(sortForeground(isSelected: isSelected))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background { sortPillBackground(isSelected: isSelected) }
                    } else {
                        VStack(spacing: 5) {
                            Text(type.title)
                                .font(.rounded(size: 13.5, weight: isSelected ? .heavy : .medium))
                                .foregroundColor(isSelected ? commentText : commentSecondaryText.opacity(0.85))

                            Capsule()
                                .fill(commentAccentInk)
                                .frame(width: 16, height: 2.5)
                                .opacity(isSelected ? 1 : 0)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
        }
        .padding(.horizontal, 2)
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
                        .font(.rounded(size: 13.5, weight: .semibold))
                    MonologueIcon(icon: .chevronDown, size: 10, color: commentSecondaryText, lineWidth: 1.8)
                }
            }
            .foregroundColor(commentSecondaryText)
            .padding(.horizontal, 22)
            .padding(.vertical, 11)
            .background {
                if isThemedSurface {
                    Capsule().fill(commentControlFill)
                } else {
                    Capsule().strokeBorder(commentSeparator, lineWidth: 1)
                }
            }
        }
        .disabled(vm.isLoadingMore)
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - 加载状态
    
    private var loadingView: some View {
        VStack(spacing: 4) {
            ForEach(0..<4, id: \.self) { index in
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(commentControlFill)
                        .frame(width: 34, height: 34)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(commentControlFill)
                            .frame(width: 80, height: 11)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(commentInputFill)
                            .frame(height: 13)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(commentInputFill)
                            .frame(width: 180, height: 13)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
                .opacity(1 - Double(index) * 0.18)

                if index < 3 {
                    Rectangle()
                        .fill(commentSeparator.opacity(0.5))
                        .frame(height: 0.5)
                        .padding(.leading, 46)
                }
            }
        }
        .padding(.horizontal, 4)
        .shimmer()
    }
    
    // MARK: - 空状态
    
    private var emptyView: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 36)

            Text("“")
                .font(.system(size: 84, weight: .black, design: .serif))
                .foregroundColor(commentAccentInk.opacity(0.16))
                .frame(height: 52, alignment: .bottom)
            
            Text(LocalizedStringKey("comment_no_comments"))
                .font(.rounded(size: 17, weight: .bold))
                .foregroundColor(commentText)
                .padding(.top, 14)

            Text(LocalizedStringKey("comment_be_first_text"))
                .font(.rounded(size: 13.5))
                .foregroundColor(commentSecondaryText)
                .padding(.top, 6)

            Button {
                isInputFocused = true
            } label: {
                Text(LocalizedStringKey("comment_write"))
                    .font(.rounded(size: 13.5, weight: .semibold))
                    .foregroundColor(commentAccentForeground)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(commentAccentFill))
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
            .padding(.top, 20)
            
            Spacer().frame(height: 40)
        }
        .frame(maxWidth: .infinity)
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
                    Capsule()
                        .fill(commentAccentInk)
                        .frame(width: 3, height: 12)
                    Text(LocalizedStringKey("comment_reply_prefix"))
                        .font(.rounded(size: 12))
                        .foregroundColor(commentSecondaryText)
                    Text("@\(reply.user.nickname)")
                        .font(.rounded(size: 12, weight: .semibold))
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

    /// 用于小元素点缀的强调墨色
    private var commentAccentInk: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        return Color.monologueAccent
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

    private func formatCount(_ count: Int) -> String {
        if count >= 10000 {
            return String(format: "%.1fw", Double(count) / 10000)
        }
        return "\(count)"
    }
}


// MARK: - 评论行

struct CommentRow: View {
    let comment: Comment
    var isHot: Bool = false
    var hotRank: Int? = nil
    let onLike: () -> Void
    let onReply: () -> Void

    private var isThemedSurface: Bool {
        NeumorphicStyle.isActive || SequoiaStyle.isActive
    }

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

    private var quoteBar: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.separator }
        if NeumorphicStyle.isActive { return NeumorphicStyle.separator }
        return .monologueTextPrimary.opacity(0.14)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 头像
            CachedAsyncImage(url: comment.user.avatarURL) {
                Circle().fill(rowFill)
            }
            .frame(width: 34, height: 34)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 6) {
                // 排名 + 用户名 + 地点 + 时间
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if let rank = hotRank {
                        Text(String(format: "%02d", rank))
                            .font(.system(size: 10.5, weight: .heavy, design: .monospaced))
                            .foregroundColor(.monologueOrange.opacity(0.9))
                    }

                    Text(comment.user.nickname)
                        .font(.rounded(size: 13, weight: .semibold))
                        .foregroundColor(secondaryText)
                        .lineLimit(1)
                    
                    if let location = comment.locationText {
                        Text(location)
                            .font(.rounded(size: 10.5))
                            .foregroundColor(mutedText.opacity(0.76))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 6)

                    Text(comment.formattedTime)
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .foregroundColor(mutedText.opacity(0.85))
                        .lineLimit(1)
                }
                
                // 评论内容
                Text(comment.content)
                    .font(.rounded(size: 15))
                    .foregroundColor(text)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3.5)
                
                // 被回复内容（编辑部引文样式）
                if let replies = comment.beReplied, let first = replies.first,
                   let user = first.user, let content = first.content {
                    HStack(alignment: .top, spacing: 8) {
                        Capsule()
                            .fill(quoteBar)
                            .frame(width: 2)

                        Text("\(Text("@\(user.nickname)").font(.rounded(size: 12.5, weight: .semibold)).foregroundColor(secondaryText))\(Text("：\(content)").font(.rounded(size: 12.5)).foregroundColor(secondaryText.opacity(0.8)))")
                            .lineLimit(3)
                            .lineSpacing(2.5)
                    }
                    .padding(.top, 2)
                    .fixedSize(horizontal: false, vertical: true)
                }
                
                // 操作栏
                HStack(spacing: 0) {
                    Spacer()
                    
                    // 回复
                    Button(action: onReply) {
                        MonologueIcon(icon: .comment, size: 14, color: mutedText.opacity(0.78))
                            .padding(.vertical, 2)
                    }
                    .padding(.trailing, 18)
                    
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
                                    .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                                    .foregroundColor(comment.liked ? .monologueAccentRed : mutedText)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .padding(.horizontal, isThemedSurface ? (DeviceLayout.isPad ? 20 : 14) : 4)
        .padding(.vertical, 13)
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
