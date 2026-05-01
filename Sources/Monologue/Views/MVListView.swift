// MVListView.swift
// MV 发现页 + MV 列表页 + MV 卡片组件
// 完全遵循 Monologue 设计系统

import SwiftUI

// MARK: - MV ID 包装（用于 fullScreenCover(item:)）

struct MVIdItem: Identifiable {
    let id: Int
}

struct QQMVVidItem: Identifiable {
    let vid: String
    var id: String { vid }
}

private enum MVTheme {
    static var ink: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        return .monologueTextPrimary
    }

    static var inkSoft: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        return .monologueTextSecondary
    }

    static var inkMuted: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.inkMuted }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkMuted }
        return .monologueTextSecondary.opacity(0.55)
    }

    static var accent: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        return .monologueIconBackground
    }

    static var separator: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.separator }
        if NeumorphicStyle.isActive { return NeumorphicStyle.separator.opacity(0.48) }
        return .monologueSeparator
    }

    static var coverPlaceholder: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.materialPressed.opacity(0.72) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfacePressed }
        return Color.monologueTextSecondary.opacity(0.06)
    }

    static var selectedIconBackground: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.selectedWash }
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfacePressed }
        return Color.monologueSeparator
    }

    static func titleFont(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        if SequoiaStyle.isActive { return SequoiaStyle.titleFont(size, weight: weight) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.titleFont(size, weight: weight) }
        return .rounded(size: size, weight: weight)
    }

    static func bodyFont(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        if SequoiaStyle.isActive { return SequoiaStyle.bodyFont(size, weight: weight) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.bodyFont(size, weight: weight) }
        return .rounded(size: size, weight: weight)
    }

    static func labelFont(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(size, weight: weight) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(size, weight: weight) }
        return .rounded(size: size, weight: weight)
    }

    static func cardRadius(_ fallback: CGFloat = 20) -> CGFloat {
        if SequoiaStyle.isActive { return 18 }
        if NeumorphicStyle.isActive { return 18 }
        return fallback
    }
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
                            .foregroundColor(MVTheme.ink)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.clear).monologueGlassCapsule()
                            .padding(8)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(mv.name ?? String(localized: "mv_unknown_name"))
                        .font(MVTheme.bodyFont(14, weight: .semibold))
                        .foregroundColor(MVTheme.ink)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text(mv.artistName ?? String(localized: "mv_unknown_artist"))
                            .font(MVTheme.labelFont(12))
                            .foregroundColor(MVTheme.inkSoft)
                            .lineLimit(1)

                        if !mv.playCountText.isEmpty {
                            Circle()
                                .fill(MVTheme.inkMuted.opacity(0.35))
                                .frame(width: 3, height: 3)
                            Text(mv.playCountText + String(localized: "mv_play_suffix"))
                                .font(MVTheme.labelFont(11))
                                .foregroundColor(MVTheme.inkMuted)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
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
                        .font(MVTheme.labelFont(16, weight: .semibold))
                        .foregroundColor(rank <= 3 ? (SequoiaStyle.isActive ? SequoiaStyle.red : (NeumorphicStyle.isActive ? NeumorphicStyle.red : .monologueAccentRed)) : MVTheme.inkMuted.opacity(0.68))
                        .frame(width: 24)
                }

                // 封面
                ZStack(alignment: .bottomTrailing) {
                    coverImage(url: mv.coverUrl, width: 120, height: 68, cornerRadius: 12)

                    if !mv.durationText.isEmpty {
                        Text(mv.durationText)
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(MVTheme.ink)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.clear).monologueGlassCapsule()
                            .padding(6)
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(mv.name ?? String(localized: "mv_unknown_name"))
                        .font(MVTheme.bodyFont(15, weight: .semibold))
                        .foregroundColor(MVTheme.ink)
                        .lineLimit(2)

                    Text(mv.artistName ?? String(localized: "mv_unknown_artist"))
                        .font(MVTheme.labelFont(13))
                        .foregroundColor(MVTheme.inkSoft)
                        .lineLimit(1)

                    if !mv.playCountText.isEmpty {
                        HStack(spacing: 3) {
                            MonologueIcon(icon: .play, size: 9, color: MVTheme.inkMuted.opacity(0.72))
                            Text(mv.playCountText)
                                .font(MVTheme.labelFont(11))
                                .foregroundColor(MVTheme.inkMuted.opacity(0.9))
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(10)
            .themedPageSurface(cornerRadius: MVTheme.cardRadius(), elevated: false)
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))
    }
}

// MARK: - 封面图片辅助

@MainActor
@ViewBuilder
private func coverImage(url: String?, width: CGFloat? = nil, height: CGFloat, cornerRadius: CGFloat) -> some View {
    if let urlStr = url, let imageUrl = URL(string: urlStr) {
        CachedAsyncImage(url: imageUrl) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(MVTheme.coverPlaceholder)
        }
        .aspectRatio(16/9, contentMode: .fill)
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            if NeumorphicStyle.isActive || SequoiaStyle.isActive {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(MVTheme.separator, lineWidth: 0.7)
            }
        }
    } else {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(MVTheme.coverPlaceholder)
            .frame(width: width, height: height)
            .aspectRatio(16/9, contentMode: .fit)
            .overlay {
                if NeumorphicStyle.isActive || SequoiaStyle.isActive {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(MVTheme.separator, lineWidth: 0.7)
                }
            }
    }
}


// MARK: - MV 发现页

struct MVDiscoverView: View {
    @State private var viewModel = MVDiscoverViewModel()
    @ObservedObject private var settings = SettingsManager.shared
    @State private var selectedMV: MVIdItem?
    @State private var selectedMlog: MlogItem?
    @State private var showSublist = false

    var body: some View {
        let _ = settings.globalThemeRevision

        ZStack {
            MonologueSheetAwareBackground {
                ThemedPageBackground().ignoresSafeArea()
            }

            VStack(spacing: 0) {
                ScrollView {
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
                .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
            }
        }
        .themedNavigationChrome(title: "MV", eyebrow: "VIDEO", icon: .mv)
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
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
        .monologueSheet(isPresented: $showSublist, preset: .standard){
            MVSublistSheet()

        }
        .fullScreenCover(item: $selectedMlog) { mlog in
            MlogPlayerView(mlog: mlog)
        }
        .overlay {
            if viewModel.isLoading && viewModel.latestMVs.isEmpty {
                MonologueLoadingView(text: "LOADING MV")
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
                        Rectangle().fill(MVTheme.coverPlaceholder)
                    }
                    .aspectRatio(16/9, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipped()
                } else {
                    Rectangle()
                        .fill(MVTheme.coverPlaceholder)
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

                    MonologueIcon(icon: .play, size: 48, color: .white)
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                }
                .padding(20)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity((NeumorphicStyle.isActive || SequoiaStyle.isActive) ? 0.04 : 0.1), radius: SequoiaStyle.isActive ? 12 : 16, x: 0, y: 8)
            .overlay {
                if NeumorphicStyle.isActive || SequoiaStyle.isActive {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(MVTheme.separator, lineWidth: 0.6)
                }
            }
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))
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

    private func actionCard(icon: MonologueIcon.IconType, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            MonologueIcon(icon: icon, size: 20, color: MVTheme.accent)
                .frame(width: 40, height: 40)
                .background(MVTheme.selectedIconBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(MVTheme.bodyFont(14, weight: .semibold))
                    .foregroundColor(MVTheme.ink)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                Text(subtitle)
                    .font(MVTheme.labelFont(11))
                    .foregroundColor(MVTheme.inkSoft)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            MonologueIcon(icon: .chevronRight, size: 12, color: MVTheme.accent.opacity(0.78))
        }
        .padding(12)
        .frame(height: 64)
        .frame(maxWidth: .infinity)
        .themedPageSurface(cornerRadius: MVTheme.cardRadius(), elevated: false)
    }

    // MARK: - 横向滚动区块

    private func mvHorizontalSection(title: String, subtitle: String, mvs: [MV], listType: MVListViewModel.ListType) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: title, subtitle: subtitle, listType: listType)

            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(mvs.prefix(8)) { mv in
                        Button(action: { selectedMV = MVIdItem(id: mv.id) }) {
                            VStack(alignment: .leading, spacing: 8) {
                                ZStack(alignment: .bottomTrailing) {
                                    coverImage(url: mv.coverUrl, width: 200, height: 112, cornerRadius: 16)

                                    if !mv.durationText.isEmpty {
                                        Text(mv.durationText)
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            .foregroundColor(MVTheme.ink)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(.clear).monologueGlassCapsule()
                                            .padding(8)
                                    }
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(mv.name ?? String(localized: "mv_unknown_name"))
                                        .font(MVTheme.bodyFont(14, weight: .semibold))
                                        .foregroundColor(MVTheme.ink)
                                        .lineLimit(1)
                                    Text(mv.artistName ?? String(localized: "mv_unknown_artist"))
                                        .font(MVTheme.labelFont(12))
                                        .foregroundColor(MVTheme.inkSoft)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 2)
                            }
                            .frame(width: 200)
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
                    }
                }
                .padding(.horizontal, 24)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
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
                        .font(MVTheme.titleFont(22, weight: .semibold))
                        .foregroundColor(MVTheme.ink)
                    Text(LocalizedStringKey("mlog_subtitle"))
                        .font(MVTheme.labelFont(14))
                        .foregroundColor(MVTheme.inkSoft)
                }
                Spacer()
            }
            .padding(.horizontal, 24)

            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(viewModel.mlogItems) { mlog in
                        Button(action: { selectedMlog = mlog }) {
                            VStack(alignment: .leading, spacing: 8) {
                                ZStack(alignment: .bottomTrailing) {
                                    if let url = mlog.coverURL {
                                        CachedAsyncImage(url: url) {
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(MVTheme.coverPlaceholder)
                                        }
                                        .aspectRatio(9/16, contentMode: .fill)
                                        .frame(width: 140, height: 200)
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    } else {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(MVTheme.coverPlaceholder)
                                            .frame(width: 140, height: 200)
                                    }

                                    // 时长角标
                                    if !mlog.durationText.isEmpty {
                                        Text(mlog.durationText)
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            .foregroundColor(MVTheme.ink)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(.clear).monologueGlassCapsule()
                                            .padding(8)
                                    }

                                    // 播放图标
                                    MonologueIcon(icon: .play, size: 28, color: .white)
                                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                }
                                .frame(width: 140, height: 200)

                                Text(mlog.text)
                                    .font(MVTheme.bodyFont(13, weight: .semibold))
                                    .foregroundColor(MVTheme.ink)
                                    .lineLimit(2)
                                    .frame(width: 140, alignment: .leading)

                                if let song = mlog.song {
                                    HStack(spacing: 4) {
                                        MonologueIcon(icon: .musicNote, size: 10, color: MVTheme.inkMuted)
                                        Text(song.name)
                                            .font(MVTheme.labelFont(11))
                                            .foregroundColor(MVTheme.inkSoft)
                                            .lineLimit(1)
                                    }
                                    .frame(width: 140, alignment: .leading)
                                }
                            }
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
                    }
                }
                .padding(.horizontal, 24)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
    }

    // MARK: - 区块标题

    private func sectionHeader(title: String, subtitle: String, listType: MVListViewModel.ListType) -> some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(MVTheme.titleFont(22, weight: .semibold))
                    .foregroundColor(MVTheme.ink)
                Text(subtitle)
                    .font(MVTheme.labelFont(14))
                    .foregroundColor(MVTheme.inkSoft)
            }

            Spacer()

            NavigationLink(value: MVListDestination(title: title, listType: listType)) {
                HStack(spacing: 4) {
                    Text("mv_more_section")
                        .font(MVTheme.labelFont(14, weight: .semibold))
                        .foregroundColor(MVTheme.accent)
                    MonologueIcon(icon: .chevronRight, size: 12, color: MVTheme.accent)
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
    @State private var viewModel: MVListViewModel
    @State private var selectedMV: MVIdItem?

    let title: String

    init(listType: MVListViewModel.ListType, title: String) {
        _viewModel = State(initialValue: MVListViewModel(listType: listType))
        self.title = title
    }

    var body: some View {
        ZStack {
            MonologueSheetAwareBackground {
                ThemedPageBackground().ignoresSafeArea()
            }

            VStack(spacing: 0) {
                ScrollView {
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
                                .font(MVTheme.labelFont(13))
                                .foregroundColor(MVTheme.inkSoft)
                        }
                        .padding(.vertical, 14)
                    }

                    if !viewModel.hasMore && !viewModel.mvs.isEmpty {
                        NoMoreDataView()
                    }

                    FloatingBarBottomSpacer()
                }
                .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
            }
        }
        .themedNavigationChrome(title: title, eyebrow: "MV", icon: .mv)
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            if viewModel.mvs.isEmpty {
                viewModel.fetchInitial()
            }
        }
        .overlay {
            if viewModel.isLoading && viewModel.mvs.isEmpty {
                MonologueLoadingView(text: "LOADING")
            }
        }
        .fullScreenCover(item: $selectedMV) { item in
            MVPlayerView(mvId: item.id)
        }
    }
}


// MARK: - 已收藏 MV Sheet

struct MVSublistSheet: View {
    @State private var viewModel = MVSublistViewModel()
    @State private var selectedMV: MVIdItem?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.monologueSheetDismiss) private var monologueSheetDismiss

    var body: some View {
        VStack(spacing: 0) {
            // 头部
            HStack {
                Text("mv_my_collection")
                    .font(MVTheme.titleFont(20, weight: .semibold))
                    .foregroundColor(MVTheme.ink)
                Spacer()
                if !viewModel.items.isEmpty {
                    Text(String(format: String(localized: "mv_mv_count"), viewModel.items.count))
                        .font(MVTheme.labelFont(13))
                        .foregroundColor(MVTheme.inkSoft)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 14)

            Rectangle()
                .fill(MVTheme.separator)
                .frame(height: 0.5)

            if viewModel.isLoading && viewModel.items.isEmpty {
                Spacer()
                MonologueLoadingView(text: "LOADING")
                Spacer()
            } else if viewModel.items.isEmpty {
                Spacer()
                VStack(spacing: 14) {
                    MonologueIcon(icon: .like, size: 40, color: MVTheme.inkMuted.opacity(0.34))
                    Text("mv_no_collection")
                        .font(MVTheme.bodyFont(15))
                        .foregroundColor(MVTheme.inkSoft)
                }
                Spacer()
            } else {
                ScrollView {
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
                                    .font(MVTheme.labelFont(13))
                                    .foregroundColor(MVTheme.inkSoft)
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
                .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
            }
        }
        .background {
            Rectangle()
                .fill(SequoiaStyle.isActive ? SequoiaStyle.materialFloating : (NeumorphicStyle.isActive ? NeumorphicStyle.surface : Color.monologueGlassTint))
                .monologueGlass(cornerRadius: 20)
                .overlay(SequoiaStyle.isActive ? SequoiaStyle.materialChrome.opacity(0.5) : (NeumorphicStyle.isActive ? NeumorphicStyle.surface.opacity(0.38) : Color.monologueGlassTint.opacity(0.55)))
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
                            .foregroundColor(MVTheme.ink)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.clear).monologueGlassCapsule()
                            .padding(6)
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(item.title ?? String(localized: "mv_unknown_name"))
                        .font(MVTheme.bodyFont(15, weight: .semibold))
                        .foregroundColor(MVTheme.ink)
                        .lineLimit(1)

                    if let artist = item.artistName {
                        Text(artist)
                            .font(MVTheme.labelFont(13))
                            .foregroundColor(MVTheme.inkSoft)
                            .lineLimit(1)
                    }

                    if !item.playCountText.isEmpty {
                        HStack(spacing: 3) {
                            MonologueIcon(icon: .play, size: 9, color: MVTheme.inkMuted.opacity(0.72))
                            Text(item.playCountText)
                                .font(MVTheme.labelFont(11))
                                .foregroundColor(MVTheme.inkMuted.opacity(0.9))
                                .lineLimit(1)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(height: 88)
            .padding(10)
            .themedPageSurface(cornerRadius: MVTheme.cardRadius(), elevated: false)
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))
    }
}
