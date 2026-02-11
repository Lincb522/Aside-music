// MVPlayerView.swift
// MV 播放器 — 上方视频 + 下方信息 + 内嵌评论，遵循 Aside 设计系统

import SwiftUI
import AVKit
import NeteaseCloudMusicAPI

struct MVPlayerView: View {
    let mvId: Int
    @StateObject private var viewModel: MVPlayerViewModel
    @StateObject private var commentVM: CommentViewModel
    @ObservedObject private var player = PlayerManager.shared
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isInputFocused: Bool

    @State private var avPlayer: AVPlayer?
    @State private var isPlaying = true
    @State private var showSimiSheet = false
    @State private var isFullscreen = false

    init(mvId: Int) {
        self.mvId = mvId
        _viewModel = StateObject(wrappedValue: MVPlayerViewModel(mvId: mvId))
        _commentVM = StateObject(wrappedValue: CommentViewModel(resourceId: mvId, resourceType: .mv))
    }

    var body: some View {
        ZStack {
            if isFullscreen {
                // 全屏横屏模式
                fullscreenView
            } else {
                // 正常竖屏模式
                normalView
            }
        }
        .onAppear {
            player.isTabBarHidden = true
            if player.isPlaying { player.togglePlayPause() }
            viewModel.fetchData()
            commentVM.loadComments()
        }
        .onDisappear {
            avPlayer?.pause()
            avPlayer = nil
            player.isTabBarHidden = false
            // 确保退出时恢复竖屏
            if isFullscreen {
                OrientationManager.shared.exitLandscape()
            }
        }
        .onChange(of: viewModel.videoUrl) { _, url in
            if let url, let videoURL = URL(string: url) {
                avPlayer = AVPlayer(url: videoURL)
                avPlayer?.play()
                isPlaying = true
            }
        }
        .statusBar(hidden: isFullscreen)
        .sheet(isPresented: $showSimiSheet) {
            simiSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        }
    }

    // MARK: - 全屏横屏视图

    private var fullscreenView: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let avPlayer {
                VideoPlayer(player: avPlayer)
                    .ignoresSafeArea()
                    .onTapGesture { togglePlayback() }
            }

            // 播放/暂停（暂停时显示）
            if avPlayer != nil && !isPlaying {
                Button(action: togglePlayback) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 64, height: 64)
                        AsideIcon(icon: .play, size: 28, color: .white)
                            .offset(x: 2)
                    }
                }
                .buttonStyle(AsideBouncingButtonStyle(scale: 0.9))
                .transition(.opacity)
            }

            // 顶部：缩小按钮
            VStack {
                HStack {
                    Button(action: exitFullscreen) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.4))
                                .frame(width: 40, height: 40)
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(AsideBouncingButtonStyle())
                    .padding(.leading, 20)
                    .padding(.top, 12)

                    Spacer()
                }
                Spacer()
            }
        }
    }

    // MARK: - 正常竖屏视图

    private var normalView: some View {
        ZStack {
            AsideBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部栏
                topBar
                    .padding(.top, DeviceLayout.headerTopPadding)

                // 视频区域
                videoSection

                // 下方信息 + 评论区域
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // MV 信息
                        infoSection

                        // 互动按钮
                        actionRow

                        // 统计
                        statsRow

                        // 相关推荐预览
                        if !viewModel.simiMVs.isEmpty || !viewModel.relatedMVs.isEmpty {
                            relatedPreview
                        }

                        // 内嵌评论区
                        embeddedCommentSection
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 80)
                }

                // 底部评论输入栏
                commentInputBar
            }

            // 加载 / 错误覆盖
            if viewModel.isLoading && viewModel.detail == nil {
                loadingOverlay
            }
        }
    }

    // MARK: - 顶部栏

    private var topBar: some View {
        HStack {
            AsideBackButton(style: .dismiss)
            Spacer()
            Text("MV")
                .font(.rounded(size: 18, weight: .bold))
                .foregroundColor(.asideTextPrimary)
            Spacer()
            // 占位
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }

    // MARK: - 视频区域

    private var videoSection: some View {
        ZStack {
            // 视频背景
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black)

            if let avPlayer {
                VideoPlayer(player: avPlayer)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .onTapGesture { togglePlayback() }
            } else if let error = viewModel.errorMessage, viewModel.videoUrl == nil {
                // 错误状态
                VStack(spacing: 14) {
                    AsideIcon(icon: .warning, size: 32, color: .white.opacity(0.4))
                    Text(error)
                        .font(.rounded(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Button("重试") { viewModel.fetchData() }
                        .font(.rounded(size: 14, weight: .medium))
                        .foregroundColor(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
            } else {
                // 占位
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }

            // 播放/暂停按钮（视频暂停时显示）
            if avPlayer != nil && !isPlaying {
                Button(action: togglePlayback) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 56, height: 56)
                        AsideIcon(icon: .play, size: 24, color: .white)
                            .offset(x: 2)
                    }
                }
                .buttonStyle(AsideBouncingButtonStyle(scale: 0.9))
                .transition(.opacity)
            }

            // 右下角全屏按钮
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: enterFullscreen) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.4))
                                .frame(width: 34, height: 34)
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(AsideBouncingButtonStyle())
                    .padding(10)
                }
            }
        }
        .aspectRatio(16/9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
        .padding(.horizontal, 24)
    }

    // MARK: - MV 信息

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let detail = viewModel.detail {
                Text(detail.name ?? "未知MV")
                    .font(.rounded(size: 22, weight: .bold))
                    .foregroundColor(.asideTextPrimary)
                    .lineLimit(2)

                Text(detail.displayArtistName)
                    .font(.rounded(size: 15))
                    .foregroundColor(.asideTextSecondary)
            } else {
                // 骨架占位
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.asideTextSecondary.opacity(0.08))
                    .frame(height: 22)
                    .frame(maxWidth: 200)
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.asideTextSecondary.opacity(0.06))
                    .frame(height: 16)
                    .frame(maxWidth: 120)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }

    // MARK: - 互动按钮行

    private var actionRow: some View {
        HStack(spacing: 0) {
            // 收藏
            mvActionButton(
                icon: viewModel.isSubscribed ? .liked : .like,
                text: viewModel.isSubscribed ? "已收藏" : "收藏",
                highlighted: viewModel.isSubscribed
            ) {
                viewModel.toggleSubscribe()
            }

            Spacer()

            // 点赞
            if let info = viewModel.detailInfo, let count = info.likedCount, count > 0 {
                mvActionButton(icon: .like, text: formatCount(count)) {}
            }

            Spacer()

            // 评论（显示数量，评论区已内嵌在下方）
            let commentCount = commentVM.totalCount > 0 ? commentVM.totalCount : (viewModel.detailInfo?.commentCount ?? viewModel.detail?.commentCount ?? 0)
            mvActionButton(icon: .comment, text: commentCount > 0 ? formatCount(commentCount) : "评论") {}

            Spacer()

            // 相关推荐
            let totalRecs = viewModel.simiMVs.count + viewModel.relatedMVs.count
            if totalRecs > 0 {
                mvActionButton(icon: .list, text: "推荐") {
                    showSimiSheet = true
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.asideCardBackground)
                .shadow(color: .black.opacity(0.03), radius: 6, x: 0, y: 2)
        )
        .padding(.horizontal, 24)
    }

    private func mvActionButton(icon: AsideIcon.IconType, text: String, highlighted: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                AsideIcon(
                    icon: icon,
                    size: 22,
                    color: highlighted ? .asideAccentRed : .asideTextPrimary
                )
                Text(text)
                    .font(.rounded(size: 11))
                    .foregroundColor(.asideTextSecondary)
            }
            .frame(minWidth: 56)
        }
        .buttonStyle(AsideBouncingButtonStyle())
    }

    // MARK: - 统计信息

    private var statsRow: some View {
        HStack(spacing: 16) {
            if let count = viewModel.detail?.playCount {
                statChip(icon: .play, text: formatCount(count) + "播放")
            }
            if let time = viewModel.detail?.publishTime, !time.isEmpty {
                statChip(icon: .clock, text: time)
            }
            if let detail = viewModel.detail, !detail.durationText.isEmpty {
                statChip(icon: .musicNote, text: detail.durationText)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func statChip(icon: AsideIcon.IconType, text: String) -> some View {
        HStack(spacing: 5) {
            AsideIcon(icon: icon, size: 12, color: .asideTextSecondary.opacity(0.5))
            Text(text)
                .font(.rounded(size: 12))
                .foregroundColor(.asideTextSecondary)
        }
    }

    // MARK: - 相关推荐预览

    private var relatedPreview: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("相关推荐")
                    .font(.rounded(size: 18, weight: .bold))
                    .foregroundColor(.asideTextPrimary)
                Spacer()
                let total = viewModel.simiMVs.count + viewModel.relatedMVs.count
                if total > 3 {
                    Button(action: { showSimiSheet = true }) {
                        HStack(spacing: 4) {
                            Text("更多")
                                .font(.rounded(size: 14, weight: .medium))
                                .foregroundColor(.asideTextSecondary)
                            AsideIcon(icon: .chevronRight, size: 12, color: .asideTextSecondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)

            // 横向滚动展示
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    let allRelated = viewModel.simiMVs + viewModel.relatedMVs
                    ForEach(allRelated.prefix(8)) { mv in
                        Button(action: { switchToMV(mv.id) }) {
                            VStack(alignment: .leading, spacing: 6) {
                                ZStack(alignment: .bottomTrailing) {
                                    if let urlStr = mv.coverUrl, let url = URL(string: urlStr) {
                                        CachedAsyncImage(url: url) {
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(Color.asideTextSecondary.opacity(0.06))
                                        }
                                        .aspectRatio(16/9, contentMode: .fill)
                                        .frame(width: 180, height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    } else {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(Color.asideTextSecondary.opacity(0.06))
                                            .frame(width: 180, height: 100)
                                    }

                                    if !mv.durationText.isEmpty {
                                        Text(mv.durationText)
                                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(.ultraThinMaterial)
                                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                            .padding(6)
                                    }
                                }

                                Text(mv.name ?? "未知MV")
                                    .font(.rounded(size: 13, weight: .medium))
                                    .foregroundColor(.asideTextPrimary)
                                    .lineLimit(1)
                                Text(mv.artistName ?? "")
                                    .font(.rounded(size: 11))
                                    .foregroundColor(.asideTextSecondary)
                                    .lineLimit(1)
                            }
                            .frame(width: 180)
                        }
                        .buttonStyle(AsideBouncingButtonStyle(scale: 0.97))
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - 加载覆盖

    private var loadingOverlay: some View {
        ZStack {
            Color.asideBackground.opacity(0.6).ignoresSafeArea()
            AsideLoadingView(text: "加载MV中...")
        }
    }

    // MARK: - 内嵌评论区

    private var embeddedCommentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 评论区标题
            HStack(alignment: .bottom) {
                HStack(spacing: 6) {
                    Text("评论")
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

            if commentVM.isLoading {
                // 骨架屏
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
            } else if commentVM.comments.isEmpty && commentVM.hotComments.isEmpty {
                // 空状态
                VStack(spacing: 12) {
                    AsideIcon(icon: .comment, size: 32, color: .asideTextSecondary.opacity(0.25))
                    Text("暂无评论")
                        .font(.rounded(size: 15))
                        .foregroundColor(.asideTextSecondary)
                    Text("来发表第一条评论吧")
                        .font(.rounded(size: 13))
                        .foregroundColor(.asideTextSecondary.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                VStack(spacing: 14) {
                    // 热门评论
                    if !commentVM.hotComments.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                AsideIcon(icon: .sparkle, size: 14, color: .asideOrange)
                                Text("热门评论")
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
                                            isInputFocused = true
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
                                    .fill(Color.asideCardBackground)
                                    .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }

                    // 全部评论
                    if !commentVM.comments.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                Text("全部评论")
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
                                            isInputFocused = true
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
                                    .fill(Color.asideCardBackground)
                                    .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
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
                                    Text("加载更多评论")
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
    }

    // MARK: - 底部评论输入栏

    private var commentInputBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.asideSeparator)
                .frame(height: 0.5)

            // 回复提示
            if let reply = commentVM.replyTarget {
                HStack(spacing: 8) {
                    Text("回复")
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
                        commentVM.replyTarget != nil ? "回复 @\(commentVM.replyTarget!.user.nickname)..." : "写评论...",
                        text: $commentVM.commentText
                    )
                    .font(.rounded(size: 15))
                    .focused($isInputFocused)

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
                    isInputFocused = false
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

    // MARK: - 辅助方法

    private func enterFullscreen() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isFullscreen = true
        }
        OrientationManager.shared.enterLandscape()
    }

    private func exitFullscreen() {
        OrientationManager.shared.exitLandscape()
        withAnimation(.easeInOut(duration: 0.3)) {
            isFullscreen = false
        }
    }

    private func togglePlayback() {
        if let avPlayer {
            if isPlaying { avPlayer.pause() } else { avPlayer.play() }
            withAnimation(.easeInOut(duration: 0.2)) {
                isPlaying.toggle()
            }
        }
    }

    private func switchToMV(_ newId: Int) {
        avPlayer?.pause()
        avPlayer = nil
        viewModel.simiMVs = []
        viewModel.relatedMVs = []
        viewModel.detail = nil
        viewModel.videoUrl = nil
        viewModel.detailInfo = nil
        dismiss()
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 100_000_000 {
            return String(format: "%.1f亿", Double(count) / 100_000_000)
        } else if count >= 10_000 {
            return String(format: "%.1f万", Double(count) / 10_000)
        }
        return "\(count)"
    }

    // MARK: - 相似推荐 Sheet

    private var simiSheet: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.asideTextSecondary.opacity(0.25))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            HStack {
                Text("相关推荐")
                    .font(.rounded(size: 20, weight: .bold))
                    .foregroundColor(.asideTextPrimary)
                Spacer()
                let total = viewModel.simiMVs.count + viewModel.relatedMVs.count
                Text("\(total)个")
                    .font(.rounded(size: 13))
                    .foregroundColor(.asideTextSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 14)

            Rectangle()
                .fill(Color.asideSeparator)
                .frame(height: 0.5)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 10) {
                    if !viewModel.simiMVs.isEmpty {
                        simiSectionLabel("相似MV")
                        ForEach(viewModel.simiMVs) { mv in
                            MVRowCard(mv: mv) {
                                showSimiSheet = false
                                switchToMV(mv.id)
                            }
                        }
                    }

                    if !viewModel.relatedMVs.isEmpty {
                        simiSectionLabel("相关视频")
                        ForEach(viewModel.relatedMVs) { mv in
                            MVRowCard(mv: mv) {
                                showSimiSheet = false
                                switchToMV(mv.id)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 14)
                .padding(.bottom, 30)
            }
        }
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color.asideCardBackground.opacity(0.55))
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func simiSectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.rounded(size: 14, weight: .semibold))
            .foregroundColor(.asideTextSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
    }
}
