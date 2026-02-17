// MVListView.swift
// MV 发现页 + MV 列表页 + MV 卡片组件
// 完全遵循 Aside 设计系统

import SwiftUI

// MARK: - MV ID 包装（用于 fullScreenCover(item:)）

struct MVIdItem: Identifiable {
    let id: Int
}

struct QQMVVidItem: Identifiable {
    let vid: String
    var id: String { vid }
}

// MARK: - MV 网格卡片

struct MVGridCard: View {
    let mv: MV
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: 10) {
                // 封面
                ZStack(alignment: .bottomTrailing) {
                    coverImage(url: mv.coverUrl, height: 100, cornerRadius: 16)

                    // 时长角标
                    if !mv.durationText.isEmpty {
                        Text(mv.durationText)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .padding(8)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(mv.name ?? String(localized: "mv_unknown_name"))
                        .font(.rounded(size: 14, weight: .semibold))
                        .foregroundColor(.asideTextPrimary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text(mv.artistName ?? String(localized: "mv_unknown_artist"))
                            .font(.rounded(size: 12))
                            .foregroundColor(.asideTextSecondary)
                            .lineLimit(1)

                        if !mv.playCountText.isEmpty {
                            Circle()
                                .fill(Color.asideTextSecondary.opacity(0.3))
                                .frame(width: 3, height: 3)
                            Text(mv.playCountText + String(localized: "mv_play_suffix"))
                                .font(.rounded(size: 11))
                                .foregroundColor(.asideTextSecondary.opacity(0.6))
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .buttonStyle(AsideBouncingButtonStyle(scale: 0.97))
    }
}

// MARK: - MV 行卡片

struct MVRowCard: View {
    let mv: MV
    var rank: Int? = nil
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 14) {
                // 排名序号
                if let rank {
                    Text("\(rank)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(rank <= 3 ? .asideAccentRed : .asideTextSecondary.opacity(0.35))
                        .frame(width: 24)
                }

                // 封面
                ZStack(alignment: .bottomTrailing) {
                    coverImage(url: mv.coverUrl, width: 120, height: 68, cornerRadius: 12)

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

                VStack(alignment: .leading, spacing: 5) {
                    Text(mv.name ?? String(localized: "mv_unknown_name"))
                        .font(.rounded(size: 15, weight: .medium))
                        .foregroundColor(.asideTextPrimary)
                        .lineLimit(2)

                    Text(mv.artistName ?? String(localized: "mv_unknown_artist"))
                        .font(.rounded(size: 13))
                        .foregroundColor(.asideTextSecondary)
                        .lineLimit(1)

                    if !mv.playCountText.isEmpty {
                        HStack(spacing: 3) {
                            AsideIcon(icon: .play, size: 9, color: .asideTextSecondary.opacity(0.5))
                            Text(mv.playCountText)
                                .font(.rounded(size: 11))
                                .foregroundColor(.asideTextSecondary.opacity(0.5))
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.asideGlassOverlay)).shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2))
        }
        .buttonStyle(AsideBouncingButtonStyle(scale: 0.98))
    }
}

// MARK: - 封面图片辅助

@ViewBuilder
private func coverImage(url: String?, width: CGFloat? = nil, height: CGFloat, cornerRadius: CGFloat) -> some View {
    if let urlStr = url, let imageUrl = URL(string: urlStr) {
        CachedAsyncImage(url: imageUrl) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.asideTextSecondary.opacity(0.06))
        }
        .aspectRatio(16/9, contentMode: .fill)
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    } else {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.asideTextSecondary.opacity(0.06))
            .frame(width: width, height: height)
            .aspectRatio(16/9, contentMode: .fit)
    }
}


// MARK: - MV 发现页

struct MVDiscoverView: View {
    @StateObject private var viewModel = MVDiscoverViewModel()
    @State private var selectedMV: MVIdItem?
    @State private var selectedMlog: MlogItem?
    @State private var showSublist = false

    var body: some View {
        ZStack {
            AsideBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                // 自定义头部
                HStack {
                    AsideBackButton()
                    Spacer()
                    Text("MV")
                        .font(.rounded(size: 18, weight: .bold))
                        .foregroundColor(.asideTextPrimary)
                    Spacer()
                    // 占位保持居中
                    Color.clear.frame(width: 40, height: 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, DeviceLayout.headerTopPadding)
                .padding(.bottom, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Hero 区域
                        if let heroMV = viewModel.latestMVs.first {
                            heroSection(mv: heroMV)
                        }

                        VStack(spacing: 28) {
                            // 功能入口：全部浏览 + 我的收藏
                            actionRow

                            // 最新 MV（横向滚动，跳过 Hero 已展示的第一个）
                            if viewModel.latestMVs.count > 1 {
                                mvHorizontalSection(
                                    title: String(localized: "mv_latest"),
                                    subtitle: String(localized: "mv_latest_desc"),
                                    mvs: Array(viewModel.latestMVs.dropFirst()),
                                    listType: .latest
                                )
                            }

                            // 热门排行（带排名的列表）
                            if !viewModel.topMVs.isEmpty {
                                mvRankSection(
                                    title: String(localized: "mv_top"),
                                    subtitle: String(localized: "mv_top_desc"),
                                    mvs: viewModel.topMVs,
                                    listType: .top
                                )
                            }

                            // 独家放送（双列网格）
                            if !viewModel.exclusiveMVs.isEmpty {
                                mvGridSection(
                                    title: String(localized: "mv_exclusive"),
                                    subtitle: String(localized: "mv_exclusive_desc"),
                                    mvs: viewModel.exclusiveMVs,
                                    listType: .exclusive
                                )
                            }

                            // Mlog 音乐短视频
                            if !viewModel.mlogItems.isEmpty {
                                mlogSection
                            }
                        }
                        .padding(.top, 24)
                        .padding(.bottom, 120)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if viewModel.latestMVs.isEmpty {
                viewModel.fetchAll()
            }
        }
        .navigationDestination(for: MVListDestination.self) { dest in
            MVFullListView(listType: dest.listType, title: dest.title)
        }
        .fullScreenCover(item: $selectedMV) { item in
            MVPlayerView(mvId: item.id)
        }
        .sheet(isPresented: $showSublist) {
            MVSublistSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        }
        .fullScreenCover(item: $selectedMlog) { mlog in
            MlogPlayerView(mlog: mlog)
        }
        .overlay {
            if viewModel.isLoading && viewModel.latestMVs.isEmpty {
                AsideLoadingView(text: "LOADING MV")
            }
        }
    }

    // MARK: - Hero 大图

    private func heroSection(mv: MV) -> some View {
        Button(action: {
            selectedMV = MVIdItem(id: mv.id)
        }) {
            ZStack(alignment: .bottomLeading) {
                if let urlStr = mv.coverUrl, let url = URL(string: urlStr) {
                    CachedAsyncImage(url: url) {
                        Rectangle().fill(Color.asideTextSecondary.opacity(0.06))
                    }
                    .aspectRatio(16/9, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipped()
                } else {
                    Rectangle()
                        .fill(Color.asideTextSecondary.opacity(0.06))
                        .frame(height: 220)
                }

                // 底部渐变遮罩
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "mv_latest_release"))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white)
                            .clipShape(Capsule())

                        Text(mv.name ?? String(localized: "mv_unknown_name"))
                            .font(.rounded(size: 22, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(2)

                        HStack(spacing: 8) {
                            Text(mv.artistName ?? "")
                                .font(.rounded(size: 14))
                                .foregroundColor(.white.opacity(0.8))

                            if !mv.playCountText.isEmpty {
                                Text(mv.playCountText + String(localized: "mv_play_suffix"))
                                    .font(.rounded(size: 12))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                    }

                    Spacer()

                    AsideIcon(icon: .play, size: 48, color: .white)
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                }
                .padding(20)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.1), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(AsideBouncingButtonStyle(scale: 0.98))
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    // MARK: - 功能入口行（只放区块里没有的功能）

    private var actionRow: some View {
        HStack(spacing: 12) {
            NavigationLink(value: MVListDestination(title: String(localized: "mv_all"), listType: .all)) {
                actionCard(icon: .gridSquare, title: String(localized: "mv_all"), subtitle: String(localized: "mv_browse_all"))
            }

            Button(action: { showSublist = true }) {
                actionCard(icon: .like, title: String(localized: "mv_my_collection"), subtitle: String(localized: "mv_collected_mv"))
            }
        }
        .padding(.horizontal, 24)
    }

    private func actionCard(icon: AsideIcon.IconType, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            AsideIcon(icon: icon, size: 20, color: .asideIconBackground)
                .frame(width: 40, height: 40)
                .background(Color.asideSeparator)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.rounded(size: 14, weight: .semibold))
                    .foregroundColor(.asideTextPrimary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                Text(subtitle)
                    .font(.rounded(size: 11))
                    .foregroundColor(.asideTextSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            AsideIcon(icon: .chevronRight, size: 12, color: .asideTextSecondary.opacity(0.5))
        }
        .padding(12)
        .frame(height: 64)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.asideGlassOverlay)).shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2))
    }

    // MARK: - 横向滚动区块

    private func mvHorizontalSection(title: String, subtitle: String, mvs: [MV], listType: MVListViewModel.ListType) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: title, subtitle: subtitle, listType: listType)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(mvs.prefix(8)) { mv in
                        Button(action: { selectedMV = MVIdItem(id: mv.id) }) {
                            VStack(alignment: .leading, spacing: 8) {
                                ZStack(alignment: .bottomTrailing) {
                                    coverImage(url: mv.coverUrl, width: 200, height: 112, cornerRadius: 16)

                                    if !mv.durationText.isEmpty {
                                        Text(mv.durationText)
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(.ultraThinMaterial)
                                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                            .padding(8)
                                    }
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(mv.name ?? String(localized: "mv_unknown_name"))
                                        .font(.rounded(size: 14, weight: .semibold))
                                        .foregroundColor(.asideTextPrimary)
                                        .lineLimit(1)
                                    Text(mv.artistName ?? String(localized: "mv_unknown_artist"))
                                        .font(.rounded(size: 12))
                                        .foregroundColor(.asideTextSecondary)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 2)
                            }
                            .frame(width: 200)
                        }
                        .buttonStyle(AsideBouncingButtonStyle(scale: 0.97))
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - 双列网格区块

    private func mvGridSection(title: String, subtitle: String, mvs: [MV], listType: MVListViewModel.ListType) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: title, subtitle: subtitle, listType: listType)

            let columns = [
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14)
            ]
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(mvs.prefix(6)) { mv in
                    MVGridCard(mv: mv) {
                        selectedMV = MVIdItem(id: mv.id)
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - 排行榜区块

    private func mvRankSection(title: String, subtitle: String, mvs: [MV], listType: MVListViewModel.ListType) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: title, subtitle: subtitle, listType: listType)

            VStack(spacing: 10) {
                ForEach(Array(mvs.prefix(5).enumerated()), id: \.element.id) { index, mv in
                    MVRowCard(mv: mv, rank: index + 1) {
                        selectedMV = MVIdItem(id: mv.id)
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Mlog 音乐短视频

    private var mlogSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey("mlog_title"))
                        .font(.rounded(size: 22, weight: .bold))
                        .foregroundColor(.asideTextPrimary)
                    Text(LocalizedStringKey("mlog_subtitle"))
                        .font(.rounded(size: 14))
                        .foregroundColor(.asideTextSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(viewModel.mlogItems) { mlog in
                        Button(action: { selectedMlog = mlog }) {
                            VStack(alignment: .leading, spacing: 8) {
                                ZStack(alignment: .bottomTrailing) {
                                    if let url = mlog.coverURL {
                                        CachedAsyncImage(url: url) {
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(Color.asideTextSecondary.opacity(0.06))
                                        }
                                        .aspectRatio(9/16, contentMode: .fill)
                                        .frame(width: 140, height: 200)
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    } else {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(Color.asideTextSecondary.opacity(0.06))
                                            .frame(width: 140, height: 200)
                                    }

                                    // 时长角标
                                    if !mlog.durationText.isEmpty {
                                        Text(mlog.durationText)
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(.ultraThinMaterial)
                                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                            .padding(8)
                                    }

                                    // 播放图标
                                    AsideIcon(icon: .play, size: 28, color: .white)
                                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                }
                                .frame(width: 140, height: 200)

                                Text(mlog.text)
                                    .font(.rounded(size: 13, weight: .medium))
                                    .foregroundColor(.asideTextPrimary)
                                    .lineLimit(2)
                                    .frame(width: 140, alignment: .leading)

                                if let song = mlog.song {
                                    HStack(spacing: 4) {
                                        AsideIcon(icon: .musicNote, size: 10, color: .asideTextSecondary)
                                        Text(song.name)
                                            .font(.rounded(size: 11))
                                            .foregroundColor(.asideTextSecondary)
                                            .lineLimit(1)
                                    }
                                    .frame(width: 140, alignment: .leading)
                                }
                            }
                        }
                        .buttonStyle(AsideBouncingButtonStyle(scale: 0.97))
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - 区块标题

    private func sectionHeader(title: String, subtitle: String, listType: MVListViewModel.ListType) -> some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.rounded(size: 22, weight: .bold))
                    .foregroundColor(.asideTextPrimary)
                Text(subtitle)
                    .font(.rounded(size: 14))
                    .foregroundColor(.asideTextSecondary)
            }

            Spacer()

            NavigationLink(value: MVListDestination(title: title, listType: listType)) {
                HStack(spacing: 4) {
                    Text("mv_more_section")
                        .font(.rounded(size: 14, weight: .medium))
                        .foregroundColor(.asideTextSecondary)
                    AsideIcon(icon: .chevronRight, size: 12, color: .asideTextSecondary)
                }
            }
        }
        .padding(.horizontal, 24)
    }
}


// MARK: - 导航目标

struct MVListDestination: Hashable {
    let title: String
    let listType: MVListViewModel.ListType

    func hash(into hasher: inout Hasher) {
        hasher.combine(title)
    }

    static func == (lhs: MVListDestination, rhs: MVListDestination) -> Bool {
        lhs.title == rhs.title
    }
}

// MARK: - MV 完整列表页

struct MVFullListView: View {
    @StateObject private var viewModel: MVListViewModel
    @State private var selectedMV: MVIdItem?

    let title: String

    init(listType: MVListViewModel.ListType, title: String) {
        _viewModel = StateObject(wrappedValue: MVListViewModel(listType: listType))
        self.title = title
    }

    var body: some View {
        ZStack {
            AsideBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                // 自定义头部
                HStack {
                    AsideBackButton()
                    Spacer()
                    Text(title)
                        .font(.rounded(size: 18, weight: .bold))
                        .foregroundColor(.asideTextPrimary)
                    Spacer()
                    Color.clear.frame(width: 40, height: 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, DeviceLayout.headerTopPadding)
                .padding(.bottom, 8)

                ScrollView(showsIndicators: false) {
                    let columns = [
                        GridItem(.flexible(), spacing: 14),
                        GridItem(.flexible(), spacing: 14)
                    ]
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.mvs) { mv in
                            MVGridCard(mv: mv) {
                                selectedMV = MVIdItem(id: mv.id)
                            }

                            if mv.id == viewModel.mvs.last?.id {
                                Color.clear.frame(height: 1)
                                    .onAppear { viewModel.loadMore() }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                    if viewModel.isLoadingMore {
                        HStack(spacing: 8) {
                            ProgressView().scaleEffect(0.8)
                            Text("mv_loading_more")
                                .font(.rounded(size: 13))
                                .foregroundColor(.asideTextSecondary)
                        }
                        .padding(.vertical, 14)
                    }

                    if !viewModel.hasMore && !viewModel.mvs.isEmpty {
                        NoMoreDataView()
                    }

                    Color.clear.frame(height: 100)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if viewModel.mvs.isEmpty {
                viewModel.fetchInitial()
            }
        }
        .overlay {
            if viewModel.isLoading && viewModel.mvs.isEmpty {
                AsideLoadingView(text: "LOADING")
            }
        }
        .fullScreenCover(item: $selectedMV) { item in
            MVPlayerView(mvId: item.id)
        }
    }
}


// MARK: - 已收藏 MV Sheet

struct MVSublistSheet: View {
    @StateObject private var viewModel = MVSublistViewModel()
    @State private var selectedMV: MVIdItem?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // 拖拽指示条
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.asideTextSecondary.opacity(0.25))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            // 头部
            HStack {
                Text("mv_my_collection")
                    .font(.rounded(size: 20, weight: .bold))
                    .foregroundColor(.asideTextPrimary)
                Spacer()
                if !viewModel.items.isEmpty {
                    Text(String(format: String(localized: "mv_mv_count"), viewModel.items.count))
                        .font(.rounded(size: 13))
                        .foregroundColor(.asideTextSecondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 14)

            Rectangle()
                .fill(Color.asideSeparator)
                .frame(height: 0.5)

            if viewModel.isLoading && viewModel.items.isEmpty {
                Spacer()
                AsideLoadingView(text: "LOADING")
                Spacer()
            } else if viewModel.items.isEmpty {
                Spacer()
                VStack(spacing: 14) {
                    AsideIcon(icon: .like, size: 40, color: .asideTextSecondary.opacity(0.25))
                    Text("mv_no_collection")
                        .font(.rounded(size: 15))
                        .foregroundColor(.asideTextSecondary)
                }
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.items) { item in
                            sublistRow(item: item)

                            if item.id == viewModel.items.last?.id {
                                Color.clear.frame(height: 1)
                                    .onAppear { viewModel.loadMore() }
                            }
                        }

                        if viewModel.isLoadingMore {
                            HStack(spacing: 8) {
                                ProgressView().scaleEffect(0.8)
                                Text("mv_loading_more")
                                    .font(.rounded(size: 13))
                                    .foregroundColor(.asideTextSecondary)
                            }
                            .padding(.vertical, 14)
                        }

                        if !viewModel.hasMore && !viewModel.items.isEmpty {
                            NoMoreDataView()
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 14)
                    .padding(.bottom, 30)
                }
            }
        }
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color.asideCardBackground.opacity(0.55))
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            viewModel.fetchInitial()
        }
        .fullScreenCover(item: $selectedMV) { item in
            MVPlayerView(mvId: item.id)
        }
    }

    private func sublistRow(item: MVSubItem) -> some View {
        Button(action: {
            if let vid = item.vid, let mvId = Int(vid) {
                selectedMV = MVIdItem(id: mvId)
            }
        }) {
            HStack(spacing: 14) {
                // 封面
                ZStack(alignment: .bottomTrailing) {
                    coverImage(url: item.coverUrl, width: 120, height: 68, cornerRadius: 12)

                    if !item.durationText.isEmpty {
                        Text(item.durationText)
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            .padding(6)
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(item.title ?? String(localized: "mv_unknown_name"))
                        .font(.rounded(size: 15, weight: .medium))
                        .foregroundColor(.asideTextPrimary)
                        .lineLimit(1)

                    if let artist = item.artistName {
                        Text(artist)
                            .font(.rounded(size: 13))
                            .foregroundColor(.asideTextSecondary)
                            .lineLimit(1)
                    }

                    if !item.playCountText.isEmpty {
                        HStack(spacing: 3) {
                            AsideIcon(icon: .play, size: 9, color: .asideTextSecondary.opacity(0.5))
                            Text(item.playCountText)
                                .font(.rounded(size: 11))
                                .foregroundColor(.asideTextSecondary.opacity(0.5))
                                .lineLimit(1)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(height: 88)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.asideGlassOverlay)).shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2))
        }
        .buttonStyle(AsideBouncingButtonStyle(scale: 0.98))
    }
}
