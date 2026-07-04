// QQMusicDetailView.swift
// qcm歌手/专辑/歌单详情页
// 歌手：Hero 大图 + Tab（音乐/专辑/MV）
// 专辑：封面 + 歌手 + 发行信息 + 歌曲列表
// 歌单：封面 + 创建者 + 歌曲列表

import SwiftUI
import Combine
import QQMusicKit

// MARK: - qcm详情类型

enum QQDetailType {
    case artist(mid: String, name: String, coverUrl: String?)
    case album(mid: String, name: String, coverUrl: String?, artistName: String?)
    case playlist(id: Int, name: String, coverUrl: String?, creatorName: String?)
}

private enum QQDetailPalette {
    static var accent: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.ink }
        return NeumorphicStyle.isActive ? NeumorphicStyle.accent : .monologueIconBackground
    }

    static var accentForeground: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.onAccent }
        if NeumorphicStyle.isActive {
            return ThemeColorCustomization.readableForegroundColor(
                on: NeumorphicStyle.accent,
                light: Color(hex: "172026"),
                dark: .white
            )
        }
        return .monologueIconForeground
    }

    static var primaryText: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.ink }
        return NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monologueTextPrimary
    }

    static var secondaryText: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.inkSoft }
        return NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monologueTextSecondary
    }

    static var mutedText: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.inkMuted }
        return NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : .monologueTextSecondary
    }

    static var placeholderFill: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.controlGlassFill }
        return NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : .monologueGlassTint
    }

    static func pageBase(for colorScheme: ColorScheme) -> Color {
        if MinimalWhiteStyle.isActive {
            return MinimalWhiteStyle.paper
        }
        if NeumorphicStyle.isActive {
            return NeumorphicStyle.base
        }
        return colorScheme == .dark ? Color(hex: "0A0A0A") : Color(hex: "F5F5F7")
    }
}

// MARK: - 路由入口

struct QQMusicDetailView: View {
    let detailType: QQDetailType
    
    var body: some View {
        switch detailType {
        case .artist(let mid, let name, let coverUrl):
            QQArtistDetailView(mid: mid, name: name, coverUrl: coverUrl)
        case .album(let mid, let name, let coverUrl, let artistName):
            QQAlbumDetailView(mid: mid, name: name, coverUrl: coverUrl, artistName: artistName)
        case .playlist(let id, let name, let coverUrl, let creatorName):
            QQPlaylistDetailView(playlistId: id, name: name, coverUrl: coverUrl, creatorName: creatorName)
        }
    }
}


// MARK: - QQ 歌手详情 ViewModel

@MainActor
class QQArtistDetailViewModel: ObservableObject {
    @Published var songs: [Song] = []
    @Published var albums: [AlbumInfo] = []
    @Published var mvs: [QQMV] = []
    @Published var isLoading = true
    @Published var isLoadingAlbums = false
    @Published var isLoadingMVs = false
    @Published var resolvedName: String?
    @Published var resolvedCoverUrl: String?
    @Published var resolvedDesc: String?
    @Published var songCount: Int?
    @Published var albumCount: Int?
    @Published var fansCount: Int?
    
    let mid: String
    private var currentPage = 1
    private var cancellables = Set<AnyCancellable>()
    
    init(mid: String) {
        self.mid = mid
    }
    
    func loadSongs() {
        currentPage = 1
        APIService.shared.fetchQQSingerSongs(mid: mid, page: 1, num: 30)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let e) = completion { AppLogger.error("[QQArtist] 歌曲加载失败: \(e)") }
            }, receiveValue: { [weak self] songs in
                self?.songs = songs
            })
            .store(in: &cancellables)
    }
    
    func loadMoreSongs() {
        currentPage += 1
        APIService.shared.fetchQQSingerSongs(mid: mid, page: currentPage, num: 30)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] newSongs in
                guard let self else { return }
                let ids = Set(self.songs.map(\.id))
                self.songs.append(contentsOf: newSongs.filter { !ids.contains($0.id) })
            })
            .store(in: &cancellables)
    }
    
    @Published var isLoadingAll = false
    
    func loadAllSongs() {
        guard !isLoadingAll else { return }
        isLoadingAll = true
        Task { @MainActor in
            var page = self.currentPage + 1
            while true {
                let newSongs: [Song]
                do {
                    newSongs = try await withCheckedThrowingContinuation { continuation in
                        var resumed = false
                        var bag: AnyCancellable?
                        bag = APIService.shared.fetchQQSingerSongs(mid: self.mid, page: page, num: 30)
                            .sink(receiveCompletion: { completion in
                                if case .failure(let e) = completion, !resumed { resumed = true; continuation.resume(throwing: e) }
                                bag?.cancel()
                            }, receiveValue: { songs in
                                guard !resumed else { return }
                                resumed = true; continuation.resume(returning: songs); bag?.cancel()
                            })
                    }
                } catch { break }
                if newSongs.isEmpty { break }
                let ids = Set(self.songs.map(\.id))
                let unique = newSongs.filter { !ids.contains($0.id) }
                if unique.isEmpty { break }
                self.songs.append(contentsOf: unique)
                self.currentPage = page
                page += 1
            }
            self.isLoadingAll = false
        }
    }
    
    func loadInfo() {
        APIService.shared.fetchQQSingerInfo(mid: mid)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] json in
                AppLogger.debug("[QQArtist] 歌手详情: \(json)")
                self?.applyResolvedInfo(from: json)
            })
            .store(in: &cancellables)

        // singerInfo 可能不含简介，单独调用 singerDesc 获取
        APIService.shared.fetchQQSingerDesc(mid: mid)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] desc in
                guard let self, !desc.isEmpty else { return }
                if self.resolvedDesc == nil || self.resolvedDesc?.isEmpty == true {
                    self.resolvedDesc = desc
                }
            })
            .store(in: &cancellables)
    }

    private func applyResolvedInfo(from json: JSON) {
        let info = artistInfoContainer(from: json)
        let baseInfo = info["BaseInfo"] ?? info["baseInfo"]
        let singerInfo = info["Singer"] ?? info["singer"]

        if let name = firstNonEmptyString([
            baseInfo?["Name"]?.stringValue,
            singerInfo?["Name"]?.stringValue,
            json["name"]?.stringValue,
            json["singerName"]?.stringValue
        ]) {
            resolvedName = name
        }

        if let coverURL = firstNonEmptyString([
            baseInfo?["BackgroundImage"]?.stringValue,
            baseInfo?["Avatar"]?.stringValue,
            baseInfo?["BigAvatar"]?.stringValue,
            singerInfo?["SingerPic"]?.stringValue,
            json["pic"]?.stringValue,
            json["singerPic"]?.stringValue,
            json["singer_pic"]?.stringValue,
            json["headpic"]?.stringValue
        ]) {
            resolvedCoverUrl = coverURL.replacingOccurrences(of: "http://", with: "https://")
        }

        if let desc = firstNonEmptyString([
            json["desc"]?.stringValue,
            json["brief"]?.stringValue,
            json["SingerDesc"]?.stringValue
        ]) {
            resolvedDesc = desc
        }

        if let fans = firstNonNilInt([
            info["FansNum"]?["Num"]?.intValue,
            json["fans"]?.intValue,
            json["fansNum"]?.intValue,
            json["fans_num"]?.intValue
        ]) {
            fansCount = fans
        }

        if let songCountValue = firstNonNilInt([
            info["songNum"]?.intValue,
            info["SongNum"]?.intValue,
            singerInfo?["songNum"]?.intValue,
            singerInfo?["SongNum"]?.intValue,
            json["songNum"]?.intValue,
            json["song_num"]?.intValue,
            json["total"]?.intValue
        ]) {
            songCount = songCountValue
        }

        if let albumCountValue = firstNonNilInt([
            info["albumNum"]?.intValue,
            info["AlbumNum"]?.intValue,
            singerInfo?["albumNum"]?.intValue,
            singerInfo?["AlbumNum"]?.intValue,
            json["albumNum"]?.intValue,
            json["album_num"]?.intValue
        ]) {
            albumCount = albumCountValue
        }
    }

    private func artistInfoContainer(from json: JSON) -> JSON {
        if let info = json["Info"] {
            return info
        }
        if let info = json["info"] {
            return info
        }
        return json
    }

    private func firstNonEmptyString(_ candidates: [String?]) -> String? {
        for candidate in candidates {
            if let candidate, !candidate.isEmpty {
                return candidate
            }
        }
        return nil
    }

    private func firstNonNilInt(_ candidates: [Int?]) -> Int? {
        for candidate in candidates {
            if let candidate {
                return candidate
            }
        }
        return nil
    }
    
    func loadAlbums() {
        guard albums.isEmpty else { return }
        isLoadingAlbums = true
        APIService.shared.fetchQQSingerAlbums(mid: mid, num: 30, begin: 0)
            .sink(receiveCompletion: { [weak self] _ in self?.isLoadingAlbums = false },
                  receiveValue: { [weak self] list in self?.albums = list })
            .store(in: &cancellables)
    }
    
    func loadMVs() {
        guard mvs.isEmpty else { return }
        isLoadingMVs = true
        APIService.shared.fetchQQSingerMVs(mid: mid, num: 30, begin: 0)
            .sink(receiveCompletion: { [weak self] _ in self?.isLoadingMVs = false },
                  receiveValue: { [weak self] list in self?.mvs = list })
            .store(in: &cancellables)
    }
}


// MARK: - QQ 歌手详情页（Hero 大图 + Tab）

struct QQArtistDetailView: View {
    let mid: String
    let name: String
    let coverUrl: String?
    
    @StateObject private var viewModel: QQArtistDetailViewModel
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var selectedTab = 0
    @State private var selectedSongForDetail: Song?
    @State private var showSongDetail = false
    @State private var selectedQQMV: QQMVVidItem?
    @State private var selectedAlbumMid: String?
    @State private var selectedAlbumName: String?
    @State private var selectedAlbumCover: String?
    @State private var selectedAlbumArtist: String?
    @State private var showAlbumDetail = false
    @State private var showFullDescription = false
    @State private var scrollOffset: CGFloat = 0
    @State private var artistSearchText = ""
    @State private var isArtistSearching = false
    @State private var isArtistSelectMode = false
    @State private var artistSelectedIds: Set<Int> = []
    @State private var showArtistBatchPlaylist = false

    private let headerImageHeight: CGFloat = 320
    
    init(mid: String, name: String, coverUrl: String?) {
        self.mid = mid
        self.name = name
        self.coverUrl = coverUrl
        _viewModel = StateObject(wrappedValue: QQArtistDetailViewModel(mid: mid))
    }
    
    private var displayName: String { viewModel.resolvedName ?? name }
    
    private var displayCoverUrl: URL? {
        if let resolved = viewModel.resolvedCoverUrl, let url = URL(string: resolved) { return url }
        if let c = coverUrl, let url = URL(string: c) { return url }
        return nil
    }
    
    var body: some View {
        let _ = settings.globalThemeRevision

        ZStack {
            if MinimalWhiteStyle.isActive {
                MinimalWhiteRootBackdrop()
            } else if NeumorphicStyle.isActive {
                ThemeRenderBackdrop(theme: .neumorphic)
            } else if ThemedPageStyle.isActive {
                ThemedPageBackground()
                    .ignoresSafeArea()
            } else {
                QQDetailPalette.pageBase(for: colorScheme)
                    .ignoresSafeArea()
            }

            ScrollView {
                if NeumorphicStyle.isActive {
                    neumorphicQQArtistDetailBody
                        .iPadContentWidth(900)
                } else if MinimalWhiteStyle.isActive {
                    minimalWhiteQQArtistDetailBody
                        .iPadContentWidth(900)
                } else {
                    VStack(spacing: 0) {
                        heroSection

                        infoSection
                            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                            .padding(.top, -40)

                        tabBar
                            .padding(.top, 20)

                        tabContent
                            .padding(.top, 8)
                            .padding(.bottom, 120)
                    }
                    .iPadContentWidth(900)
                }
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
            .monologueScrollOffset($scrollOffset)
            .ignoresSafeArea(edges: .top)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showSongDetail) {
            if let song = selectedSongForDetail {
                SongDetailView(song: song)
            } else {
                EmptyView()
            }
        }
        .navigationDestination(isPresented: $showAlbumDetail) {
            if let albumMid = selectedAlbumMid {
                QQMusicDetailView(detailType: .album(
                    mid: albumMid,
                    name: selectedAlbumName ?? "",
                    coverUrl: selectedAlbumCover,
                    artistName: selectedAlbumArtist
                ))
            } else {
                EmptyView()
            }
        }
        .fullScreenCover(item: $selectedQQMV) { item in
            QQMVPlayerView(vid: item.vid)
        }
        .monologueSheet(isPresented: $showFullDescription, preset: .standard){
            if let desc = viewModel.resolvedDesc {
                QQArtistBioSheet(name: displayName, coverUrl: displayCoverUrl, desc: desc)
            }
        }
        .monologueSheet(isPresented: $showArtistBatchPlaylist, preset: .standard){
            BatchAddToPlaylistSheet(songs: artistFilteredSongs.filter { artistSelectedIds.contains($0.id) })
        }
        .onAppear {
            viewModel.loadSongs()
            viewModel.loadInfo()
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab == 1 { viewModel.loadAlbums() }
            if newTab == 2 { viewModel.loadMVs() }
        }
    }

    private var minimalWhiteQQArtistDetailBody: some View {
        VStack(spacing: 24) {
            minimalWhiteQQArtistHeroCard
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.top, DeviceLayout.headerTopPadding + 16)

            tabBar

            tabContent
                .padding(.top, 2)
                .padding(.bottom, 120)
        }
    }

    private var minimalWhiteQQArtistHeroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 18) {
                CachedAsyncImage(url: displayCoverUrl) {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(MinimalWhiteStyle.controlGlassFill)
                        .overlay(MonologueIcon(icon: .profile, size: 38, color: MinimalWhiteStyle.inkMuted, lineWidth: 1.6))
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: DeviceLayout.isPad ? 168 : 132, height: DeviceLayout.isPad ? 168 : 132)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(MinimalWhiteStyle.hairline, lineWidth: MinimalWhiteStyle.strokeWidth)
                )

                VStack(alignment: .leading, spacing: 12) {
                    PlatformBadgeLabel(text: "QCM", source: .qqmusic, fontSize: 10)

                    Text(displayName)
                        .font(MinimalWhiteStyle.titleFont(DeviceLayout.isPad ? 30 : 26, weight: .semibold))
                        .foregroundStyle(MinimalWhiteStyle.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.86)

                    HStack(spacing: 8) {
                        if let fans = viewModel.fansCount, fans > 0 {
                            minimalWhiteQQPill(String(format: String(localized: "qq_fans_count"), formatCount(fans)))
                        }
                        if let ac = viewModel.albumCount, ac > 0 {
                            minimalWhiteQQPill(String(format: String(localized: "qq_album_count"), ac))
                        }
                        if let sc = viewModel.songCount, sc > 0 {
                            minimalWhiteQQPill(String(format: String(localized: "qq_song_count"), sc))
                        }
                    }
                    .lineLimit(1)

                    Spacer(minLength: 0)
                }
            }

            if let desc = viewModel.resolvedDesc, !desc.isEmpty {
                Button(action: { showFullDescription = true }) {
                    HStack(spacing: 8) {
                        Text(desc)
                            .font(MinimalWhiteStyle.bodyFont(13, weight: .regular))
                            .foregroundStyle(MinimalWhiteStyle.inkMuted)
                            .lineLimit(1)

                        MinimalWhiteDisclosureGlyph()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }

            Button(action: {
                if let first = viewModel.songs.first {
                    PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                }
            }) {
                HStack(spacing: 8) {
                    MonologueIcon(icon: .play, size: 14, color: MinimalWhiteStyle.onAccent)
                    Text("qq_play_all")
                        .font(MinimalWhiteStyle.labelFont(14, weight: .semibold))
                }
                .foregroundStyle(MinimalWhiteStyle.onAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(MinimalWhiteStyle.ink, in: Capsule(style: .continuous))
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
            .opacity(viewModel.songs.isEmpty ? 0.45 : 1)
            .disabled(viewModel.songs.isEmpty)
        }
        .padding(18)
        .background(
            MinimalWhiteSurfaceBackground(
                cornerRadius: MinimalWhiteStyle.chromeRadius,
                elevated: true,
                tint: MinimalWhiteStyle.glassStrongFill
            )
        )
    }

    private func minimalWhiteQQPill(_ text: String) -> some View {
        Text(text)
            .font(MinimalWhiteStyle.labelFont(11, weight: .regular))
            .foregroundStyle(MinimalWhiteStyle.inkMuted)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(MinimalWhiteCapsuleBackground())
    }

    // MARK: - 新拟物 QCM 歌手详情

    private var neumorphicQQArtistDetailBody: some View {
        VStack(spacing: 15) {
            neumorphicQQArtistConsole
            neumorphicQQArtistTabDock
            tabContent
                .padding(.top, 2)
        }
        .padding(.top, DeviceLayout.headerTopPadding + 18)
        .padding(.bottom, 120)
    }

    private var neumorphicQQArtistConsole: some View {
        VStack(alignment: .leading, spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 15) {
                    neumorphicQQArtistIdentityBlock
                    neumorphicQQArtistPortrait
                        .frame(width: DeviceLayout.isPad ? 150 : 122)
                }

                VStack(alignment: .leading, spacing: 14) {
                    neumorphicQQArtistPortrait
                        .frame(maxWidth: .infinity, alignment: .center)
                    neumorphicQQArtistIdentityBlock
                }
            }

            neumorphicQQArtistMetricGrid
        }
        .padding(15)
        .background(
            NeumorphicSurfaceBackground(
                cornerRadius: 32,
                elevated: true,
                tint: NeumorphicStyle.sage.opacity(0.052),
                lightweight: true
            )
        )
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
    }

    private var neumorphicQQArtistIdentityBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                NeumorphicPill(text: "QCM", tint: NeumorphicStyle.sage, icon: .headphones, selected: true, compact: true)
                NeumorphicPill(text: "ARTIST", tint: NeumorphicStyle.accent, compact: true)
            }

            Text(displayName)
                .font(NeumorphicStyle.titleFont(DeviceLayout.isPad ? 34 : 29, weight: .semibold))
                .foregroundStyle(NeumorphicStyle.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if let desc = viewModel.resolvedDesc, !desc.isEmpty {
                Button(action: { showFullDescription = true }) {
                    HStack(spacing: 8) {
                        Text(desc)
                            .font(NeumorphicStyle.bodyFont(13, weight: .medium))
                            .foregroundStyle(NeumorphicStyle.inkSoft)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)

                        MonologueIcon(icon: .chevronRight, size: 10, color: NeumorphicStyle.inkMuted, lineWidth: 1.6)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        NeumorphicSurfaceBackground(
                            cornerRadius: 17,
                            elevated: false,
                            pressed: true,
                            tint: NeumorphicStyle.surfacePressed,
                            lightweight: true
                        )
                    )
                }
                .buttonStyle(.plain)
            }

            Button(action: {
                if let first = viewModel.songs.first {
                    PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                }
            }) {
                NeumorphicPlayPill(title: String(localized: "qq_play_all"), tint: NeumorphicStyle.sage)
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
            .opacity(viewModel.songs.isEmpty ? 0.5 : 1)
            .disabled(viewModel.songs.isEmpty)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var neumorphicQQArtistPortrait: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(NeumorphicStyle.surfacePressed)
                .frame(width: DeviceLayout.isPad ? 150 : 122, height: DeviceLayout.isPad ? 150 : 122)
                .background(
                    NeumorphicSurfaceBackground(
                        cornerRadius: DeviceLayout.isPad ? 75 : 61,
                        elevated: true,
                        tint: NeumorphicStyle.surfaceRaised,
                        lightweight: true
                    )
                )

            CachedAsyncImage(url: displayCoverUrl?.sized(700)) {
                Circle()
                    .fill(NeumorphicStyle.surfacePressed)
                    .overlay(MonologueIcon(icon: .personCircle, size: 32, color: NeumorphicStyle.inkMuted.opacity(0.5), lineWidth: 1.8))
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: DeviceLayout.isPad ? 132 : 106, height: DeviceLayout.isPad ? 132 : 106)
            .clipShape(Circle())
            .overlay(Circle().stroke(NeumorphicStyle.separator.opacity(0.36), lineWidth: 0.7))

            HStack(spacing: 4) {
                Capsule().fill(NeumorphicStyle.sage.opacity(0.82)).frame(width: 10, height: 4)
                Capsule().fill(NeumorphicStyle.accent.opacity(0.65)).frame(width: 18, height: 4)
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(
                NeumorphicSurfaceBackground(
                    cornerRadius: 13,
                    elevated: true,
                    tint: NeumorphicStyle.sage.opacity(0.12),
                    lightweight: true
                )
            )
            .offset(x: 4, y: 3)
        }
        .frame(height: DeviceLayout.isPad ? 160 : 132)
    }

    private var neumorphicQQArtistMetricGrid: some View {
        let songCount = viewModel.songCount ?? (viewModel.songs.isEmpty ? nil : viewModel.songs.count)

        return LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 9),
            GridItem(.flexible(), spacing: 9),
            GridItem(.flexible(), spacing: 9)
        ], spacing: 9) {
            if let songCount, songCount > 0 {
                neumorphicQQArtistMetricTile(
                    title: String(localized: "qq_tab_music"),
                    value: "\(songCount)",
                    icon: .musicNoteList,
                    tint: NeumorphicStyle.sage
                )
            }

            if let albumCount = viewModel.albumCount, albumCount > 0 {
                neumorphicQQArtistMetricTile(
                    title: String(localized: "qq_tab_album"),
                    value: "\(albumCount)",
                    icon: .album,
                    tint: NeumorphicStyle.accent
                )
            }

            if let fans = viewModel.fansCount, fans > 0 {
                neumorphicQQArtistMetricTile(
                    title: String(localized: "粉丝"),
                    value: formatCount(fans),
                    icon: .like,
                    tint: NeumorphicStyle.warm
                )
            }
        }
    }

    private func neumorphicQQArtistMetricTile(title: String, value: String, icon: MonologueIcon.IconType, tint: Color) -> some View {
        HStack(spacing: 9) {
            MonologueIcon(icon: icon, size: 14, color: tint, lineWidth: 1.65)
                .frame(width: 30, height: 30)
                .background(
                    NeumorphicSurfaceBackground(
                        cornerRadius: 13,
                        elevated: false,
                        pressed: true,
                        tint: tint.opacity(0.1),
                        lightweight: true
                    )
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(NeumorphicStyle.labelFont(13, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(title)
                    .font(NeumorphicStyle.labelFont(10, weight: .medium))
                    .foregroundStyle(NeumorphicStyle.inkMuted)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(NeumorphicSurfaceBackground(cornerRadius: 18, elevated: false, pressed: true, lightweight: true))
    }

    private var neumorphicQQArtistTabDock: some View {
        HStack(spacing: 7) {
            neumorphicQQArtistTabDockItem(String(localized: "qq_tab_music"), index: 0, icon: .musicNoteList, tint: NeumorphicStyle.sage)
            neumorphicQQArtistTabDockItem(String(localized: "qq_tab_album"), index: 1, icon: .album, tint: NeumorphicStyle.accent)
            neumorphicQQArtistTabDockItem(String(localized: "qq_tab_video"), index: 2, icon: .mv, tint: NeumorphicStyle.warm)
        }
        .padding(6)
        .background(NeumorphicSurfaceBackground(cornerRadius: 23, elevated: true, lightweight: true))
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
    }

    private func neumorphicQQArtistTabDockItem(_ title: String, index: Int, icon: MonologueIcon.IconType, tint: Color) -> some View {
        let selected = selectedTab == index

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                selectedTab = index
            }
        } label: {
            HStack(spacing: 7) {
                MonologueIcon(icon: icon, size: 14, color: selected ? tint : NeumorphicStyle.inkMuted, lineWidth: 1.65)
                Text(title)
                    .font(NeumorphicStyle.labelFont(11, weight: selected ? .semibold : .medium))
                    .foregroundStyle(selected ? NeumorphicStyle.ink : NeumorphicStyle.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(
                NeumorphicSurfaceBackground(
                    cornerRadius: 17,
                    elevated: selected,
                    pressed: !selected,
                    tint: selected ? tint.opacity(0.14) : NeumorphicStyle.surface,
                    lightweight: true
                )
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Hero 大图

    private var heroSection: some View {
        let stretchHeight = headerImageHeight - scrollOffset

        return ZStack(alignment: .bottom) {
            if let url = displayCoverUrl {
                CachedAsyncImage(url: url) {
                    Rectangle().fill(QQDetailPalette.placeholderFill)
                }
                .aspectRatio(contentMode: .fill)
                .frame(height: stretchHeight)
                .clipped()
                .monologueBackgroundExtension()
            } else {
                Rectangle()
                    .fill(QQDetailPalette.placeholderFill)
                    .frame(height: stretchHeight)
            }

            let pageBase = QQDetailPalette.pageBase(for: colorScheme)
            LinearGradient(
                colors: [
                    .clear, .clear,
                    pageBase.opacity(0.62),
                    pageBase
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: stretchHeight)
        }
        .frame(height: stretchHeight)
        .padding(.bottom, scrollOffset)
        .offset(y: scrollOffset)
    }
    
    // MARK: - 信息区域
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom) {
                Text(displayName)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(QQDetailPalette.primaryText)
                    .lineLimit(2)
                Spacer()
                
                PlatformBadgeLabel(text: "QCM", source: .qqmusic, fontSize: 11)
            }
            
            // 统计信息
            HStack(spacing: 16) {
                if let fans = viewModel.fansCount, fans > 0 {
                    Text(String(format: String(localized: "qq_fans_count"), formatCount(fans)))
                        .font(.rounded(size: 13))
                        .foregroundColor(QQDetailPalette.secondaryText)
                }
                if let ac = viewModel.albumCount, ac > 0 {
                    Text(String(format: String(localized: "qq_album_count"), ac))
                        .font(.rounded(size: 13))
                        .foregroundColor(QQDetailPalette.secondaryText)
                }
                if let sc = viewModel.songCount, sc > 0 {
                    Text(String(format: String(localized: "qq_song_count"), sc))
                        .font(.rounded(size: 13))
                        .foregroundColor(QQDetailPalette.secondaryText)
                }
            }
            
            // 简介（可点击展开）
            if let desc = viewModel.resolvedDesc, !desc.isEmpty {
                Button(action: { showFullDescription = true }) {
                    HStack(spacing: 4) {
                        Text(desc)
                            .font(.rounded(size: 13))
                            .foregroundColor(QQDetailPalette.secondaryText)
                            .lineLimit(1)
                        MonologueIcon(icon: .chevronRight, size: 10, color: QQDetailPalette.secondaryText)
                    }
                }
            }
            
            // 播放全部
            HStack(spacing: 12) {
                Button(action: {
                    if let first = viewModel.songs.first {
                        PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                    }
                }) {
                    HStack(spacing: 8) {
                        MonologueIcon(icon: .play, size: 14, color: QQDetailPalette.accentForeground)
                        Text("qq_play_all")
                            .font(.rounded(size: 14, weight: .bold))
                            .foregroundColor(QQDetailPalette.accentForeground)
                    }
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(QQDetailPalette.accent))
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
                .opacity(viewModel.songs.isEmpty ? 0.5 : 1)
                .disabled(viewModel.songs.isEmpty)
                Spacer()
            }
            .padding(.top, 4)
        }
    }
    
    // MARK: - Tab 栏
    
    private var tabBar: some View {
        HStack(spacing: MinimalWhiteStyle.isActive ? 4 : 28) {
            tabItem(String(localized: "qq_tab_music"), index: 0)
            tabItem(String(localized: "qq_tab_album"), index: 1)
            tabItem(String(localized: "qq_tab_video"), index: 2)
        }
        .padding(.horizontal, MinimalWhiteStyle.isActive ? 6 : DeviceLayout.viewHorizontalPadding)
        .padding(.vertical, MinimalWhiteStyle.isActive ? 6 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if MinimalWhiteStyle.isActive {
                MinimalWhiteSurfaceBackground(
                    cornerRadius: MinimalWhiteStyle.chromeRadius,
                    elevated: false,
                    tint: MinimalWhiteStyle.glassFill
                )
            }
        }
        .padding(.horizontal, MinimalWhiteStyle.isActive ? DeviceLayout.viewHorizontalPadding : 0)
    }
    
    private func tabItem(_ title: String, index: Int) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = index }
        }) {
            if MinimalWhiteStyle.isActive {
                Text(title)
                    .font(MinimalWhiteStyle.labelFont(13, weight: selectedTab == index ? .semibold : .regular))
                    .foregroundStyle(selectedTab == index ? MinimalWhiteStyle.ink : MinimalWhiteStyle.inkMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background {
                        if selectedTab == index {
                            MinimalWhiteCapsuleBackground(selected: true)
                        }
                    }
            } else {
                VStack(spacing: 6) {
                    Text(title)
                        .font(.rounded(size: 17, weight: selectedTab == index ? .bold : .medium))
                        .foregroundColor(selectedTab == index ? QQDetailPalette.primaryText : QQDetailPalette.secondaryText)
                    Capsule()
                        .fill(selectedTab == index ? QQDetailPalette.accent : Color.clear)
                        .frame(width: 20, height: 3)
                }
            }
        }
    }
    
    // MARK: - Tab 内容
    
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0: songsTab
        case 1: albumsTab
        case 2: mvsTab
        default: EmptyView()
        }
    }
    
    private var artistFilteredSongs: [Song] {
        viewModel.songs.filtered(by: artistSearchText)
    }
    
    private var songsTab: some View {
        Group {
            if viewModel.isLoading && viewModel.songs.isEmpty {
                loadingView
            } else if viewModel.songs.isEmpty {
                emptyView(String(localized: "qq_no_songs"))
            } else {
                VStack(spacing: 0) {
                    PlaylistSearchBar(
                        searchText: $artistSearchText,
                        isSearching: $isArtistSearching,
                        onSearchActivated: { viewModel.loadAllSongs() },
                        isSelectMode: $isArtistSelectMode,
                        selectedIds: $artistSelectedIds,
                        songs: artistFilteredSongs,
                        onBatchQueue: {
                            let selected = artistFilteredSongs.filter { artistSelectedIds.contains($0.id) }
                            SongBatchActionHelper.addToQueue(selected) {
                                isArtistSelectMode = false
                                artistSelectedIds.removeAll()
                            }
                        },
                        onBatchDownload: { batchDownload(from: artistFilteredSongs, ids: artistSelectedIds, reset: { isArtistSelectMode = false; artistSelectedIds.removeAll() }) },
                        onBatchCollect: { showArtistBatchPlaylist = true }
                    )
                    
                    LazyVStack(spacing: 0) {
                        ForEach(Array(artistFilteredSongs.enumerated()), id: \.element.id) { index, song in
                            SongListRow(song: song, index: index, isSelecting: isArtistSelectMode, isSelected: artistSelectedIds.contains(song.id), onArtistTap: { _ in }, onDetailTap: { s in
                                selectedSongForDetail = s
                                showSongDetail = true
                            }, onAlbumTap: { _ in }, onTap: {
                                if isArtistSelectMode {
                                    if artistSelectedIds.contains(song.id) {
                                        artistSelectedIds.remove(song.id)
                                    } else {
                                        artistSelectedIds.insert(song.id)
                                    }
                                } else {
                                    PlayerManager.shared.play(song: song, in: artistFilteredSongs)
                                }
                            })
                            .onAppear {
                                if !isArtistSearching && index == viewModel.songs.count - 3 { viewModel.loadMoreSongs() }
                            }
                        }
                    }
                }
                .padding(.vertical, MinimalWhiteStyle.isActive ? 8 : 10)
                .background {
                    if MinimalWhiteStyle.isActive {
                        MinimalWhiteSurfaceBackground(
                            cornerRadius: MinimalWhiteStyle.chromeRadius,
                            elevated: false,
                            tint: MinimalWhiteStyle.glassFill
                        )
                    }
                }
                .padding(.horizontal, MinimalWhiteStyle.isActive ? DeviceLayout.viewHorizontalPadding : 0)
            }
        }
    }
    
    private var albumsTab: some View {
        Group {
            if viewModel.isLoadingAlbums && viewModel.albums.isEmpty {
                loadingView
            } else if viewModel.albums.isEmpty {
                emptyView(String(localized: "qq_no_albums"))
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.albums) { album in
                        qqAlbumRow(album)
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.top, 8)
            }
        }
    }
    
    private func qqAlbumRow(_ album: AlbumInfo) -> some View {
        Button(action: {
            // 从 picUrl 反推 mid（格式: ...M000{mid}.jpg）
            let albumMid = extractMidFromPicUrl(album.picUrl)
            selectedAlbumMid = albumMid
            selectedAlbumName = album.name
            selectedAlbumCover = album.picUrl
            selectedAlbumArtist = album.artistName
            showAlbumDetail = true
        }) {
            HStack(spacing: 14) {
                if let coverUrl = album.coverUrl {
                    CachedAsyncImage(url: coverUrl) {
                        RoundedRectangle(cornerRadius: 10).fill(QQDetailPalette.placeholderFill)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(QQDetailPalette.placeholderFill)
                        .frame(width: 72, height: 72)
                        .overlay(MonologueIcon(icon: .album, size: 24, color: QQDetailPalette.mutedText.opacity(0.36)))
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(album.name)
                        .font(.rounded(size: 16, weight: .medium))
                        .foregroundColor(QQDetailPalette.primaryText)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        if !album.publishDateText.isEmpty {
                            Text(album.publishDateText)
                                .font(.rounded(size: 12))
                                .foregroundColor(QQDetailPalette.secondaryText)
                        }
                        if let size = album.size, size > 0 {
                            Text("\(size) Tracks")
                                .font(.rounded(size: 12))
                                .foregroundColor(QQDetailPalette.secondaryText)
                        }
                    }
                }
                Spacer(minLength: 0)
                MonologueIcon(icon: .chevronRight, size: 12, color: QQDetailPalette.mutedText.opacity(0.5))
            }
            .padding(12)
            .background(
                Group {
                    if MinimalWhiteStyle.isActive {
                        MinimalWhiteSurfaceBackground(
                            cornerRadius: MinimalWhiteStyle.cardRadius,
                            elevated: false,
                            tint: MinimalWhiteStyle.glassFill
                        )
                    } else {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(QQDetailPalette.placeholderFill)
                            .monologueGlass(cornerRadius: 20)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))
    }
    
    private var mvsTab: some View {
        Group {
            if viewModel.isLoadingMVs && viewModel.mvs.isEmpty {
                loadingView
            } else if viewModel.mvs.isEmpty {
                emptyView(String(localized: "qq_no_videos"))
            } else {
                let columns = [
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14)
                ]
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.mvs) { mv in
                        qqMVCard(mv: mv)
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.top, 8)
            }
        }
    }
    
    private func qqMVCard(mv: QQMV) -> some View {
        Button(action: {
            selectedQQMV = QQMVVidItem(vid: mv.vid)
        }) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    if let urlStr = mv.coverUrl, let url = URL(string: urlStr) {
                        CachedAsyncImage(url: url) {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(QQDetailPalette.placeholderFill)
                        }
                        .aspectRatio(16/9, contentMode: .fill)
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(QQDetailPalette.placeholderFill)
                            .frame(height: 100)
                    }
                    if !mv.durationText.isEmpty {
                        Text(mv.durationText)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.clear).monologueGlass(cornerRadius: 16)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .padding(6)
                    }
                }
                Text(mv.name)
                    .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.labelFont(13, weight: .medium) : .rounded(size: 13, weight: .medium))
                    .foregroundColor(QQDetailPalette.primaryText)
                    .lineLimit(1)
            }
            .padding(MinimalWhiteStyle.isActive ? 8 : 0)
            .background {
                if MinimalWhiteStyle.isActive {
                    MinimalWhiteSurfaceBackground(
                        cornerRadius: MinimalWhiteStyle.cardRadius,
                        elevated: false,
                        tint: MinimalWhiteStyle.glassFill
                    )
                }
            }
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
    }
    
    // MARK: - 辅助
    
    private var loadingView: some View {
        VStack {
            Spacer().frame(height: 60)
            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: QQDetailPalette.secondaryText))
            Spacer().frame(height: 60)
        }
        .frame(maxWidth: .infinity)
        .background {
            if MinimalWhiteStyle.isActive {
                MinimalWhiteSurfaceBackground(
                    cornerRadius: MinimalWhiteStyle.cardRadius,
                    elevated: false,
                    tint: MinimalWhiteStyle.glassFill
                )
            }
        }
        .padding(.horizontal, MinimalWhiteStyle.isActive ? DeviceLayout.viewHorizontalPadding : 0)
    }
    
    private func emptyView(_ text: String) -> some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 60)
            if MinimalWhiteStyle.isActive {
                MinimalWhiteIconBadge(icon: .musicNoteList, size: 52)
            }
            Text(text)
                .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.labelFont(14, weight: .medium) : .rounded(size: 15))
                .foregroundColor(QQDetailPalette.secondaryText)
            Spacer().frame(height: 60)
        }
        .frame(maxWidth: .infinity)
        .background {
            if MinimalWhiteStyle.isActive {
                MinimalWhiteSurfaceBackground(
                    cornerRadius: MinimalWhiteStyle.cardRadius,
                    elevated: false,
                    tint: MinimalWhiteStyle.glassFill
                )
            }
        }
        .padding(.horizontal, MinimalWhiteStyle.isActive ? DeviceLayout.viewHorizontalPadding : 0)
    }
    
    private func formatCount(_ count: Int) -> String {
        if count >= 10000 {
            let wan = Double(count) / 10000.0
            return wan >= 100 ? String(localized: "\(Int(wan))万") : String(format: String(localized: "%.1f万"), wan)
        }
        return "\(count)"
    }
    
    /// 从 picUrl 中提取 mid（格式: ...M000{mid}.jpg）
    private func extractMidFromPicUrl(_ picUrl: String?) -> String {
        guard let url = picUrl else { return "" }
        // 匹配 M000 后面到 .jpg 之间的字符串
        if let range = url.range(of: "M000") {
            let afterM000 = url[range.upperBound...]
            if let dotRange = afterM000.range(of: ".") {
                return String(afterM000[..<dotRange.lowerBound])
            }
        }
        return ""
    }
    
    private func batchDownload(from songs: [Song], ids: Set<Int>, reset: @escaping () -> Void) {
        let selected = songs.filter { ids.contains($0.id) }
        for song in selected {
            if song.isQQMusic {
                DownloadManager.shared.downloadQQ(song: song, quality: DownloadManager.defaultQQDownloadQuality)
            } else {
                DownloadManager.shared.download(song: song, quality: DownloadManager.defaultNeteaseDownloadQuality)
            }
        }
        AlertManager.shared.show(title: String(localized: "已加入下载"), message: String(localized: "已将 \(selected.count) 首歌曲加入下载队列"), primaryButtonTitle: String(localized: "确定"), primaryAction: {})
        withAnimation { reset() }
    }
}


// MARK: - QQ 专辑详情 ViewModel

@MainActor
class QQAlbumDetailViewModel: ObservableObject {
    @Published var songs: [Song] = []
    @Published var isLoading = true
    @Published var resolvedName: String?
    @Published var resolvedCoverUrl: String?
    @Published var resolvedArtistName: String?
    @Published var resolvedDesc: String?
    @Published var publishDate: String?
    @Published var songCount: Int?
    
    let mid: String
    private var cancellables = Set<AnyCancellable>()
    
    init(mid: String) {
        self.mid = mid
    }
    
    func fetchData() {
        // 获取歌曲
        APIService.shared.fetchQQAlbumSongs(albumMid: mid, page: 1, num: 100)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let e) = completion { AppLogger.error("[QQAlbum] 歌曲加载失败: \(e)") }
            }, receiveValue: { [weak self] songs in
                self?.songs = songs
                if self?.songCount == nil || self?.songCount == 0 {
                    self?.songCount = songs.count
                }
            })
            .store(in: &cancellables)
        
        // 获取详情
        APIService.shared.fetchQQAlbumDetail(albumMid: mid)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] json in
                self?.handleAlbumDetail(json)
            })
            .store(in: &cancellables)
    }
    
    private func handleAlbumDetail(_ json: JSON) {
        AppLogger.debug("[QQAlbum] 专辑详情: \(json)")

        let basicInfo = json["basicInfo"] ?? json["basic_info"] ?? json
        let singerList = json["singer"]?["singerList"]?.arrayValue
            ?? json["singer"]?["list"]?.arrayValue
            ?? json["singerList"]?.arrayValue
            ?? json["singer"]?.arrayValue
            ?? json["singers"]?.arrayValue

        if let name = firstNonEmptyString([
            basicInfo["albumName"]?.stringValue,
            basicInfo["album_name"]?.stringValue,
            basicInfo["name"]?.stringValue,
            json["albumName"]?.stringValue,
            json["album_name"]?.stringValue,
            json["name"]?.stringValue
        ]) {
            resolvedName = name
        }

        if let directCover = firstNonEmptyString([
            basicInfo["picUrl"]?.stringValue,
            basicInfo["pic_url"]?.stringValue,
            basicInfo["pic"]?.stringValue,
            basicInfo["cover"]?.stringValue,
            basicInfo["albumPic"]?.stringValue,
            json["picUrl"]?.stringValue,
            json["pic_url"]?.stringValue,
            json["pic"]?.stringValue,
            json["cover"]?.stringValue,
            json["albumPic"]?.stringValue
        ]) {
            resolvedCoverUrl = directCover.replacingOccurrences(of: "http://", with: "https://")
        } else {
            let resolvedAlbumMid = firstNonEmptyString([
                basicInfo["albumMid"]?.stringValue,
                basicInfo["albumMID"]?.stringValue,
                basicInfo["album_mid"]?.stringValue,
                basicInfo["mid"]?.stringValue,
                json["albumMid"]?.stringValue,
                json["albumMID"]?.stringValue,
                json["album_mid"]?.stringValue,
                json["mid"]?.stringValue,
                mid
            ]) ?? mid
            resolvedCoverUrl = "https://y.gtimg.cn/music/photo_new/T002R300x300M000\(resolvedAlbumMid).jpg"
        }

        if let singers = singerList, !singers.isEmpty {
            let names = singers.compactMap {
                $0["name"]?.stringValue
                    ?? $0["singerName"]?.stringValue
                    ?? $0["title"]?.stringValue
            }
            if !names.isEmpty {
                resolvedArtistName = names.joined(separator: " / ")
            }
        } else if let artistName = firstNonEmptyString([
            basicInfo["singerName"]?.stringValue,
            basicInfo["singer_name"]?.stringValue,
            json["singerName"]?.stringValue,
            json["singer_name"]?.stringValue
        ]) {
            resolvedArtistName = artistName
        }

        if let desc = firstNonEmptyString([
            basicInfo["desc"]?.stringValue,
            basicInfo["description"]?.stringValue,
            json["desc"]?.stringValue,
            json["description"]?.stringValue
        ]) {
            resolvedDesc = desc
        }

        if let date = firstNonEmptyString([
            basicInfo["publishDate"]?.stringValue,
            basicInfo["aDate"]?.stringValue,
            basicInfo["publicTime"]?.stringValue,
            basicInfo["publish_date"]?.stringValue,
            json["publishDate"]?.stringValue,
            json["aDate"]?.stringValue,
            json["publicTime"]?.stringValue,
            json["publish_date"]?.stringValue
        ]) {
            publishDate = date
        }

        if let count = firstNonNilInt([
            json["totalNum"]?.intValue,
            json["total_song_num"]?.intValue,
            json["song_count"]?.intValue,
            basicInfo["totalNum"]?.intValue,
            basicInfo["total_song_num"]?.intValue,
            basicInfo["song_count"]?.intValue
        ]) {
            songCount = count
        }
    }

    private func firstNonEmptyString(_ candidates: [String?]) -> String? {
        for candidate in candidates {
            if let candidate, !candidate.isEmpty {
                return candidate
            }
        }
        return nil
    }

    private func firstNonNilInt(_ candidates: [Int?]) -> Int? {
        for candidate in candidates {
            if let candidate {
                return candidate
            }
        }
        return nil
    }
}

// MARK: - QQ 专辑详情页

struct QQAlbumDetailView: View {
    let mid: String
    let name: String
    let coverUrl: String?
    let artistName: String?
    
    @StateObject private var viewModel: QQAlbumDetailViewModel
    @ObservedObject private var settings = SettingsManager.shared
    @State private var selectedSongForDetail: Song?
    @State private var showSongDetail = false
    @State private var showAlbumDesc = false
    @State private var albumSearchText = ""
    @State private var isAlbumSearching = false
    @State private var isAlbumSelectMode = false
    @State private var albumSelectedIds: Set<Int> = []
    @State private var showAlbumBatchPlaylist = false
    
    init(mid: String, name: String, coverUrl: String?, artistName: String?) {
        self.mid = mid
        self.name = name
        self.coverUrl = coverUrl
        self.artistName = artistName
        _viewModel = StateObject(wrappedValue: QQAlbumDetailViewModel(mid: mid))
    }
    
    private var displayName: String { viewModel.resolvedName ?? name }
    private var displayArtist: String? { viewModel.resolvedArtistName ?? artistName }
    
    private var displayCoverUrl: URL? {
        if let resolved = viewModel.resolvedCoverUrl, let url = URL(string: resolved) { return url }
        if let c = coverUrl, let url = URL(string: c) { return url }
        return nil
    }
    
    var body: some View {
        let _ = settings.globalThemeRevision

        ZStack {
            MonologueSheetAwareBackground {
                if MinimalWhiteStyle.isActive {
                    MinimalWhiteRootBackdrop()
                } else if SettingsManager.shared.coverBgPlaylist {
                    PlaylistColorBackground(coverUrl: displayCoverUrl?.sized(200))
                } else {
                    ThemedPageBackground()
                }
            }

            VStack(spacing: 0) {
                headerView
                
                ScrollView {
                    VStack(spacing: 0) {
                        PlaylistSearchBar(
                            searchText: $albumSearchText,
                            isSearching: $isAlbumSearching,
                            isSelectMode: $isAlbumSelectMode,
                            selectedIds: $albumSelectedIds,
                            songs: viewModel.songs.filtered(by: albumSearchText),
                            onBatchQueue: {
                                let selected = viewModel.songs.filtered(by: albumSearchText).filter { albumSelectedIds.contains($0.id) }
                                SongBatchActionHelper.addToQueue(selected) {
                                    isAlbumSelectMode = false
                                    albumSelectedIds.removeAll()
                                }
                            },
                            onBatchDownload: { batchDownload(from: viewModel.songs.filtered(by: albumSearchText), ids: albumSelectedIds, reset: { isAlbumSelectMode = false; albumSelectedIds.removeAll() }) },
                            onBatchCollect: { showAlbumBatchPlaylist = true }
                        )
                        songListSection
                    }
                    .padding(.bottom, 100)
                }
                .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let count = viewModel.songCount ?? (viewModel.songs.isEmpty ? nil : viewModel.songs.count), count > 0 {
                    Text(String(format: String(localized: "qq_track_count"), count))
                        .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.labelFont(12, weight: .medium) : .system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(QQDetailPalette.secondaryText)
                        .padding(.horizontal, MinimalWhiteStyle.isActive ? 10 : 0)
                        .padding(.vertical, MinimalWhiteStyle.isActive ? 6 : 0)
                        .background {
                            if MinimalWhiteStyle.isActive {
                                MinimalWhiteCapsuleBackground()
                            }
                        }
                }
            }
        }
        .navigationDestination(isPresented: $showSongDetail) {
            if let song = selectedSongForDetail { SongDetailView(song: song) }
        }
        .onAppear {
            viewModel.fetchData()
        }
        .monologueSheet(isPresented: $showAlbumDesc, preset: .standard){
            if let desc = viewModel.resolvedDesc {
                QQAlbumDescSheet(name: displayName, coverUrl: displayCoverUrl, artistName: displayArtist, desc: desc)
            }
        }
    }
    
    // MARK: - 头部
    
    @ViewBuilder
    private var headerView: some View {
        if MinimalWhiteStyle.isActive {
            minimalWhiteQQAlbumHeaderView
        } else {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                CachedAsyncImage(url: displayCoverUrl) {
                    QQDetailPalette.placeholderFill
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: DeviceLayout.detailCoverSize, height: DeviceLayout.detailCoverSize)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        PlatformBadgeLabel(text: "QCM", source: .qqmusic, fontSize: 10)
                        
                        Text(displayName)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(QQDetailPalette.primaryText)
                            .lineLimit(2)
                    }
                    
                    if let artist = displayArtist, !artist.isEmpty {
                        Text(artist)
                            .font(.system(size: 13))
                            .foregroundColor(QQDetailPalette.secondaryText)
                            .lineLimit(1)
                    }
                    
                    if let date = viewModel.publishDate, !date.isEmpty {
                        Text(date)
                            .font(.rounded(size: 11))
                            .foregroundColor(QQDetailPalette.mutedText.opacity(0.78))
                    }
                    
                    Spacer().frame(height: 4)
                    
                    Button(action: {
                        if let first = viewModel.songs.first {
                                PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                        }
                    }) {
                        HStack(spacing: 6) {
                            MonologueIcon(icon: .play, size: 12, color: QQDetailPalette.accentForeground)
                            Text(String(localized: "qq_play"))
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(QQDetailPalette.accentForeground)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(QQDetailPalette.accent)
                        .cornerRadius(20)
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
                }
            }
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.bottom, 24)
        .padding(.top, 16)
        }
    }

    private var minimalWhiteQQAlbumHeaderView: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                CachedAsyncImage(url: displayCoverUrl) {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(MinimalWhiteStyle.controlGlassFill)
                        .overlay(MonologueIcon(icon: .album, size: 34, color: MinimalWhiteStyle.inkMuted, lineWidth: 1.6))
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: DeviceLayout.isPad ? 150 : 118, height: DeviceLayout.isPad ? 150 : 118)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(MinimalWhiteStyle.hairline, lineWidth: MinimalWhiteStyle.strokeWidth)
                )

                VStack(alignment: .leading, spacing: 10) {
                    PlatformBadgeLabel(text: "QCM", source: .qqmusic, fontSize: 10)

                    Text(displayName)
                        .font(MinimalWhiteStyle.titleFont(24, weight: .semibold))
                        .foregroundStyle(MinimalWhiteStyle.ink)
                        .lineLimit(2)

                    if let artist = displayArtist, !artist.isEmpty {
                        Text(artist)
                            .font(MinimalWhiteStyle.bodyFont(13, weight: .regular))
                            .foregroundStyle(MinimalWhiteStyle.inkSoft)
                            .lineLimit(1)
                    }

                    if let date = viewModel.publishDate, !date.isEmpty {
                        minimalWhiteQQPill(date)
                    }
                }
            }

            Button(action: {
                if let first = viewModel.songs.first {
                    PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                }
            }) {
                HStack(spacing: 8) {
                    MonologueIcon(icon: .play, size: 13, color: MinimalWhiteStyle.onAccent)
                    Text(String(localized: "qq_play"))
                        .font(MinimalWhiteStyle.labelFont(13, weight: .semibold))
                }
                .foregroundStyle(MinimalWhiteStyle.onAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(MinimalWhiteStyle.ink, in: Capsule(style: .continuous))
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
            .disabled(viewModel.songs.isEmpty)
            .opacity(viewModel.songs.isEmpty ? 0.45 : 1)
        }
        .padding(18)
        .background(
            MinimalWhiteSurfaceBackground(
                cornerRadius: MinimalWhiteStyle.chromeRadius,
                elevated: true,
                tint: MinimalWhiteStyle.glassStrongFill
            )
        )
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 12)
        .padding(.bottom, 18)
    }

    private func minimalWhiteQQPill(_ text: String) -> some View {
        Text(text)
            .font(MinimalWhiteStyle.labelFont(11, weight: .regular))
            .foregroundStyle(MinimalWhiteStyle.inkMuted)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(MinimalWhiteCapsuleBackground())
    }
    
    // MARK: - 歌曲列表
    
    private var songListSection: some View {
        LazyVStack(spacing: 0) {
            if viewModel.isLoading {
                MonologueLoadingView(text: MinimalWhiteStyle.isActive ? nil : "LOADING TRACKS")
            } else if viewModel.songs.isEmpty {
                VStack(spacing: 14) {
                    if MinimalWhiteStyle.isActive {
                        MinimalWhiteIconBadge(icon: .musicNoteList, size: 52)
                    } else {
                        MonologueIcon(icon: .musicNoteList, size: 40, color: QQDetailPalette.mutedText.opacity(0.36))
                    }
                    Text(String(localized: "qq_no_songs"))
                        .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.labelFont(14, weight: .medium) : .rounded(size: 15))
                        .foregroundColor(QQDetailPalette.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 44)
                .background {
                    if MinimalWhiteStyle.isActive {
                        MinimalWhiteSurfaceBackground(
                            cornerRadius: MinimalWhiteStyle.cardRadius,
                            elevated: false,
                            tint: MinimalWhiteStyle.glassFill
                        )
                    }
                }
                .padding(.horizontal, MinimalWhiteStyle.isActive ? DeviceLayout.viewHorizontalPadding : 0)
            } else {
                // 专辑简介
                if let desc = viewModel.resolvedDesc, !desc.isEmpty {
                    Button(action: { showAlbumDesc = true }) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("qq_album_desc")
                                    .font(.rounded(size: 15, weight: .semibold))
                                    .foregroundColor(QQDetailPalette.primaryText)
                                Spacer()
                                MonologueIcon(icon: .chevronRight, size: 12, color: QQDetailPalette.secondaryText)
                            }
                            Text(desc)
                                .font(.rounded(size: 13, weight: .regular))
                                .foregroundColor(QQDetailPalette.secondaryText)
                                .lineLimit(3)
                                .lineSpacing(4)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background {
                            if MinimalWhiteStyle.isActive {
                                MinimalWhiteSurfaceBackground(
                                    cornerRadius: MinimalWhiteStyle.cardRadius,
                                    elevated: false,
                                    tint: MinimalWhiteStyle.glassFill
                                )
                            } else {
                                Color.clear
                                    .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.vertical, 12)
                }
                
                let albumDisplaySongs = viewModel.songs.filtered(by: albumSearchText)
                ForEach(Array(albumDisplaySongs.enumerated()), id: \.element.id) { index, song in
                    SongListRow(song: song, index: index, isSelecting: isAlbumSelectMode, isSelected: albumSelectedIds.contains(song.id), onArtistTap: { _ in }, onDetailTap: { s in
                        selectedSongForDetail = s
                        showSongDetail = true
                    }, onAlbumTap: { _ in }, onTap: {
                        if isAlbumSelectMode {
                            if albumSelectedIds.contains(song.id) {
                                albumSelectedIds.remove(song.id)
                            } else {
                                albumSelectedIds.insert(song.id)
                            }
                        } else {
                            PlayerManager.shared.play(song: song, in: albumDisplaySongs)
                        }
                    })
                }
                .background {
                    if MinimalWhiteStyle.isActive {
                        MinimalWhiteSurfaceBackground(
                            cornerRadius: MinimalWhiteStyle.cardRadius,
                            elevated: false,
                            tint: MinimalWhiteStyle.glassFill
                        )
                    }
                }
                
                if !isAlbumSearching {
                    NoMoreDataView()
                }
                FloatingBarBottomSpacer()
            }
        }
        .monologueSheet(isPresented: $showAlbumBatchPlaylist, preset: .standard){
            BatchAddToPlaylistSheet(songs: viewModel.songs.filter { albumSelectedIds.contains($0.id) })
        }
    }
    
    private func batchDownload(from songs: [Song], ids: Set<Int>, reset: @escaping () -> Void) {
        let selected = songs.filter { ids.contains($0.id) }
        for song in selected {
            if song.isQQMusic {
                DownloadManager.shared.downloadQQ(song: song, quality: DownloadManager.defaultQQDownloadQuality)
            } else {
                DownloadManager.shared.download(song: song, quality: DownloadManager.defaultNeteaseDownloadQuality)
            }
        }
        AlertManager.shared.show(title: String(localized: "已加入下载"), message: String(localized: "已将 \(selected.count) 首歌曲加入下载队列"), primaryButtonTitle: String(localized: "确定"), primaryAction: {})
        withAnimation { reset() }
    }
}

// MARK: - QQ 专辑简介 Sheet

struct QQAlbumDescSheet: View {
    let name: String
    let coverUrl: URL?
    let artistName: String?
    let desc: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.monologueSheetDismiss) private var monologueSheetDismiss
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                CachedAsyncImage(url: coverUrl) {
                    RoundedRectangle(cornerRadius: MinimalWhiteStyle.isActive ? 14 : (NeumorphicStyle.isActive ? 14 : 10))
                        .fill(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.controlGlassFill : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monologueGlassTint))
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: MinimalWhiteStyle.isActive ? 14 : (NeumorphicStyle.isActive ? 14 : 10), style: .continuous))
                .overlay {
                    if NeumorphicStyle.isActive {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(NeumorphicStyle.separator.opacity(0.35), lineWidth: 0.7)
                    } else if MinimalWhiteStyle.isActive {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(MinimalWhiteStyle.hairline, lineWidth: MinimalWhiteStyle.strokeWidth)
                    }
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.titleFont(20, weight: .semibold) : (NeumorphicStyle.isActive ? NeumorphicStyle.titleFont(20, weight: .semibold) : .rounded(size: 20, weight: .bold)))
                        .foregroundColor(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.ink : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monologueTextPrimary))
                        .lineLimit(1)
                    if let artist = artistName {
                        Text(artist)
                            .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.labelFont(12, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .medium) : .rounded(size: 12)))
                            .foregroundColor(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.inkMuted : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monologueTextSecondary))
                    }
                }
                Spacer()
                Button(action: { dismissCurrentPresentation(systemDismiss: dismiss, monologueSheetDismiss: monologueSheetDismiss) }) {
                    MonologueIcon(icon: .close, size: 20, color: MinimalWhiteStyle.isActive ? MinimalWhiteStyle.inkMuted : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monologueTextSecondary))
                        .frame(width: 32, height: 32)
                        .background {
                            if NeumorphicStyle.isActive {
                                NeumorphicSurfaceBackground(cornerRadius: 16, elevated: false, pressed: true, lightweight: true)
                            } else if MinimalWhiteStyle.isActive {
                                MinimalWhiteCircleBackground(elevated: false)
                            } else {
                                Circle().fill(Color.monologueSeparator)
                            }
                        }
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 16)
            .padding(.bottom, 16)
            
            Rectangle()
                .fill(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.hairline : (NeumorphicStyle.isActive ? NeumorphicStyle.separator.opacity(0.45) : Color.monologueSeparator))
                .frame(height: 0.5)
            
            ScrollView {
                Text(desc)
                    .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.bodyFont(15, weight: .regular) : .rounded(size: 15, weight: .regular))
                    .foregroundColor(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monologueTextPrimary))
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(
                        Group {
                            if NeumorphicStyle.isActive {
                                NeumorphicSurfaceBackground(cornerRadius: 22, elevated: false)
                            } else if MinimalWhiteStyle.isActive {
                                MinimalWhiteSurfaceBackground(
                                    cornerRadius: MinimalWhiteStyle.cardRadius,
                                    elevated: false,
                                    tint: MinimalWhiteStyle.glassFill
                                )
                            } else {
                                Color.clear
                                    .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                            }
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: NeumorphicStyle.isActive ? 22 : 16, style: .continuous))
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
    }
}


// MARK: - QQ 歌手简介 Sheet

struct QQArtistBioSheet: View {
    let name: String
    let coverUrl: URL?
    let desc: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.monologueSheetDismiss) private var monologueSheetDismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                CachedAsyncImage(url: coverUrl) {
                    Circle().fill(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.controlGlassFill : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monologueGlassTint))
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 48, height: 48)
                .clipShape(Circle())
                .overlay {
                    if NeumorphicStyle.isActive {
                        Circle()
                            .stroke(NeumorphicStyle.separator.opacity(0.35), lineWidth: 0.7)
                    } else if MinimalWhiteStyle.isActive {
                        Circle()
                            .stroke(MinimalWhiteStyle.hairline, lineWidth: MinimalWhiteStyle.strokeWidth)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.titleFont(20, weight: .semibold) : (NeumorphicStyle.isActive ? NeumorphicStyle.titleFont(20, weight: .semibold) : .rounded(size: 20, weight: .bold)))
                        .foregroundColor(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.ink : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monologueTextPrimary))
                        .lineLimit(1)
                    PlatformBadgeLabel(text: "QCM", source: .qqmusic, fontSize: 10)
                }

                Spacer()

                Button(action: { dismissCurrentPresentation(systemDismiss: dismiss, monologueSheetDismiss: monologueSheetDismiss) }) {
                    MonologueIcon(icon: .close, size: 20, color: MinimalWhiteStyle.isActive ? MinimalWhiteStyle.inkMuted : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monologueTextSecondary))
                        .frame(width: 32, height: 32)
                        .background {
                            if NeumorphicStyle.isActive {
                                NeumorphicSurfaceBackground(cornerRadius: 16, elevated: false, pressed: true, lightweight: true)
                            } else if MinimalWhiteStyle.isActive {
                                MinimalWhiteCircleBackground(elevated: false)
                            } else {
                                Circle().fill(Color.monologueSeparator)
                            }
                        }
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 16)
            .padding(.bottom, 16)

            Rectangle()
                .fill(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.hairline : (NeumorphicStyle.isActive ? NeumorphicStyle.separator.opacity(0.45) : Color.monologueSeparator))
                .frame(height: 0.5)

            ScrollView {
                Text(desc)
                    .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.bodyFont(15, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(15, weight: .regular) : .rounded(size: 15, weight: .regular)))
                    .foregroundColor(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monologueTextPrimary))
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background {
                        if MinimalWhiteStyle.isActive {
                            MinimalWhiteSurfaceBackground(
                                cornerRadius: MinimalWhiteStyle.cardRadius,
                                elevated: false,
                                tint: MinimalWhiteStyle.glassFill
                            )
                        }
                    }
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding - 16)
                    .padding(.top, 4)
                    .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
    }
}


// MARK: - QQ 歌单详情 ViewModel

@MainActor
class QQPlaylistDetailViewModel: ObservableObject {
    @Published var songs: [Song] = []
    @Published var isLoading = true
    @Published var isLoadingMore = false
    @Published var hasMore = true
    @Published var resolvedCoverUrl: String?
    @Published var resolvedName: String?
    
    let playlistId: Int
    private var currentPage = 1
    private var cancellables = Set<AnyCancellable>()
    
    init(playlistId: Int) {
        self.playlistId = playlistId
    }
    
    func fetchSongs() {
        currentPage = 1
        APIService.shared.fetchQQPlaylistSongs(playlistId: playlistId, page: 1, num: 50)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let e) = completion { AppLogger.error("[QQPlaylist] 加载失败: \(e)") }
            }, receiveValue: { [weak self] songs in
                self?.songs = songs
                self?.hasMore = songs.count >= 20
            })
            .store(in: &cancellables)
    }
    
    func loadMore() {
        guard !isLoadingMore, hasMore else { return }
        isLoadingMore = true
        currentPage += 1
        APIService.shared.fetchQQPlaylistSongs(playlistId: playlistId, page: currentPage, num: 50)
            .sink(receiveCompletion: { [weak self] _ in self?.isLoadingMore = false },
                  receiveValue: { [weak self] newSongs in
                guard let self else { return }
                let ids = Set(self.songs.map(\.id))
                self.songs.append(contentsOf: newSongs.filter { !ids.contains($0.id) })
                self.hasMore = newSongs.count >= 20
            })
            .store(in: &cancellables)
    }
    
    @Published var isLoadingAll = false
    
    func loadAllSongs(appendToQueue: Bool = false) {
        Task { @MainActor in
            await loadAllSongsAsync(appendToQueue: appendToQueue)
        }
    }
    
    @discardableResult
    func loadAllSongsAsync(appendToQueue: Bool = false) async -> [Song] {
        guard !isLoadingAll, hasMore else { return songs }
        isLoadingAll = true
        while self.hasMore {
            self.currentPage += 1
            let newSongs: [Song]
            do {
                newSongs = try await withCheckedThrowingContinuation { continuation in
                    var resumed = false
                    var bag: AnyCancellable?
                    bag = APIService.shared.fetchQQPlaylistSongs(playlistId: self.playlistId, page: self.currentPage, num: 50)
                        .sink(receiveCompletion: { completion in
                            if case .failure(let e) = completion, !resumed { resumed = true; continuation.resume(throwing: e) }
                            bag?.cancel()
                        }, receiveValue: { songs in
                            guard !resumed else { return }
                            resumed = true; continuation.resume(returning: songs); bag?.cancel()
                        })
                }
            } catch { break }
            if newSongs.isEmpty || newSongs.count < 20 { self.hasMore = false }
            let ids = Set(self.songs.map(\.id))
            let unique = newSongs.filter { !ids.contains($0.id) }
            self.songs.append(contentsOf: unique)
            if appendToQueue, !unique.isEmpty {
                PlayerManager.shared.appendContext(songs: unique)
            }
        }
        self.isLoadingAll = false
        return songs
    }
    
    func fetchDetail() {
        APIService.shared.fetchQQPlaylistDetail(playlistId: playlistId)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] json in
                if let logo = json["logo"]?.stringValue ?? json["dirpicurl"]?.stringValue
                    ?? json["coverImgUrl"]?.stringValue ?? json["cover"]?.stringValue, !logo.isEmpty {
                    self?.resolvedCoverUrl = logo
                }
                if let name = json["dissname"]?.stringValue ?? json["title"]?.stringValue
                    ?? json["name"]?.stringValue, !name.isEmpty {
                    self?.resolvedName = name
                }
            })
            .store(in: &cancellables)
    }
}

// MARK: - QQ 歌单详情页

struct QQPlaylistDetailView: View {
    let playlistId: Int
    let name: String
    let coverUrl: String?
    let creatorName: String?
    
    @StateObject private var viewModel: QQPlaylistDetailViewModel
    @ObservedObject private var settings = SettingsManager.shared
    @State private var selectedSongForDetail: Song?
    @State private var showSongDetail = false
    @State private var isCollectedLocally = false
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var isPlaylistSelectMode = false
    @State private var playlistSelectedIds: Set<Int> = []
    @State private var showPlaylistBatchPlaylist = false
    
    init(playlistId: Int, name: String, coverUrl: String?, creatorName: String?) {
        self.playlistId = playlistId
        self.name = name
        self.coverUrl = coverUrl
        self.creatorName = creatorName
        _viewModel = StateObject(wrappedValue: QQPlaylistDetailViewModel(playlistId: playlistId))
    }
    
    private var displayName: String { viewModel.resolvedName ?? name }
    
    private var displayCoverUrl: URL? {
        if let resolved = viewModel.resolvedCoverUrl, let url = URL(string: resolved) { return url }
        if let c = coverUrl, let url = URL(string: c) { return url }
        return nil
    }
    
    var body: some View {
        let _ = settings.globalThemeRevision

        ZStack {
            MonologueSheetAwareBackground {
                if MinimalWhiteStyle.isActive {
                    MinimalWhiteRootBackdrop()
                } else if SettingsManager.shared.coverBgPlaylist {
                    PlaylistColorBackground(coverUrl: displayCoverUrl?.sized(200))
                        .ignoresSafeArea()
                } else {
                    ThemedPageBackground().ignoresSafeArea()
                }
            }
            
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        headerSection
                        PlaylistSearchBar(
                            searchText: $searchText,
                            isSearching: $isSearching,
                            onSearchActivated: { viewModel.loadAllSongs() },
                            isSelectMode: $isPlaylistSelectMode,
                            selectedIds: $playlistSelectedIds,
                            songs: viewModel.songs.filtered(by: searchText),
                            onBatchQueue: {
                                let selected = qqFilteredSongs.filter { playlistSelectedIds.contains($0.id) }
                                SongBatchActionHelper.addToQueue(selected) {
                                    isPlaylistSelectMode = false
                                    playlistSelectedIds.removeAll()
                                }
                            },
                            onBatchDownload: { qqPlaylistBatchDownload() },
                            onBatchCollect: { showPlaylistBatchPlaylist = true }
                        )
                        songsList
                    }
                    .padding(.bottom, 120)
                }
                .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            if viewModel.songs.isEmpty {
                viewModel.fetchSongs()
                viewModel.fetchDetail()
            }
            isCollectedLocally = LocalPlaylistManager.shared.playlists.contains { $0.name == displayName }
        }
        .onChange(of: viewModel.resolvedName) { _, _ in
            isCollectedLocally = LocalPlaylistManager.shared.playlists.contains { $0.name == displayName }
        }
        .navigationDestination(isPresented: $showSongDetail) {
            if let song = selectedSongForDetail { SongDetailView(song: song) }
        }
        .overlay {
            if viewModel.isLoading && viewModel.songs.isEmpty {
                MonologueLoadingView(text: MinimalWhiteStyle.isActive ? nil : "LOADING")
            }
        }
    }
    
    @ViewBuilder
    private var headerSection: some View {
        if MinimalWhiteStyle.isActive {
            minimalWhiteQQPlaylistHeaderSection
        } else {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                Group {
                    if let url = displayCoverUrl {
                        CachedAsyncImage(url: url) {
                            QQDetailPalette.placeholderFill
                        }
                        .aspectRatio(contentMode: .fill)
                    } else {
                        ZStack {
                            QQDetailPalette.placeholderFill
                            MonologueIcon(icon: .musicNote, size: 32, color: QQDetailPalette.mutedText.opacity(0.36))
                        }
                    }
                }
                .frame(width: DeviceLayout.isPad ? 180 : 120, height: DeviceLayout.isPad ? 180 : 120)
                .cornerRadius(DeviceLayout.isPad ? 20 : 16)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(displayName)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(QQDetailPalette.primaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if let creator = creatorName {
                        Text("by \(creator)")
                            .font(.system(size: 13))
                            .foregroundColor(QQDetailPalette.secondaryText)
                            .lineLimit(1)
                    }
                    
                    HStack(spacing: 6) {
                        PlatformBadgeLabel(text: "QCM", source: .qqmusic, fontSize: 10)
                    }
                    
                    Spacer().frame(height: 4)
                    
                    HStack(spacing: 8) {
                        Button(action: {
                            if let first = viewModel.songs.first {
                                PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                                viewModel.loadAllSongs(appendToQueue: true)
                            }
                        }) {
                            HStack(spacing: 6) {
                                MonologueIcon(icon: .play, size: 12, color: QQDetailPalette.accentForeground)
                                Text(LocalizedStringKey("play_now"))
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundColor(QQDetailPalette.accentForeground)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(QQDetailPalette.accent)
                            .cornerRadius(20)
                            .monologueGlassCapsule()
                            .shadow(color: QQDetailPalette.accent.opacity(0.2), radius: 5, x: 0, y: 2)
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
                        
                        SubscribeButton(
                            isSubscribed: isCollectedLocally,
                            action: {
                                guard !isCollectedLocally, !viewModel.songs.isEmpty else { return }
                                Task {
                                    let allSongs = await viewModel.loadAllSongsAsync()
                                    LocalPlaylistManager.shared.importPlaylist(name: displayName, songs: allSongs)
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        isCollectedLocally = true
                                    }
                                }
                            }
                        )
                        .disabled(isCollectedLocally || viewModel.songs.isEmpty)
                    }
                }
            }
        }
        .padding(.horizontal, DeviceLayout.isPad ? 40 : 24)
        .padding(.top, DeviceLayout.isPad ? 24 : 16)
        .padding(.bottom, DeviceLayout.isPad ? 32 : 24)
        .iPadContentWidth(900)
        }
    }

    private var minimalWhiteQQPlaylistHeaderSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                Group {
                    if let url = displayCoverUrl {
                        CachedAsyncImage(url: url) {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(MinimalWhiteStyle.controlGlassFill)
                                .overlay(MonologueIcon(icon: .musicNote, size: 34, color: MinimalWhiteStyle.inkMuted, lineWidth: 1.6))
                        }
                        .aspectRatio(contentMode: .fill)
                    } else {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(MinimalWhiteStyle.controlGlassFill)
                            .overlay(MonologueIcon(icon: .musicNote, size: 34, color: MinimalWhiteStyle.inkMuted, lineWidth: 1.6))
                    }
                }
                .frame(width: DeviceLayout.isPad ? 150 : 118, height: DeviceLayout.isPad ? 150 : 118)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(MinimalWhiteStyle.hairline, lineWidth: MinimalWhiteStyle.strokeWidth)
                )

                VStack(alignment: .leading, spacing: 10) {
                    PlatformBadgeLabel(text: "QCM", source: .qqmusic, fontSize: 10)

                    Text(displayName)
                        .font(MinimalWhiteStyle.titleFont(24, weight: .semibold))
                        .foregroundStyle(MinimalWhiteStyle.ink)
                        .lineLimit(2)

                    if let creator = creatorName {
                        Text(creator)
                            .font(MinimalWhiteStyle.bodyFont(13, weight: .regular))
                            .foregroundStyle(MinimalWhiteStyle.inkMuted)
                            .lineLimit(1)
                    }
                }
            }

            HStack(spacing: 10) {
                Button(action: {
                    if let first = viewModel.songs.first {
                        PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                        viewModel.loadAllSongs(appendToQueue: true)
                    }
                }) {
                    HStack(spacing: 8) {
                        MonologueIcon(icon: .play, size: 13, color: MinimalWhiteStyle.onAccent)
                        Text(LocalizedStringKey("play_now"))
                            .font(MinimalWhiteStyle.labelFont(13, weight: .semibold))
                    }
                    .foregroundStyle(MinimalWhiteStyle.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(MinimalWhiteStyle.ink, in: Capsule(style: .continuous))
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
                .disabled(viewModel.songs.isEmpty)
                .opacity(viewModel.songs.isEmpty ? 0.45 : 1)

                SubscribeButton(
                    isSubscribed: isCollectedLocally,
                    action: {
                        guard !isCollectedLocally, !viewModel.songs.isEmpty else { return }
                        Task {
                            let allSongs = await viewModel.loadAllSongsAsync()
                            LocalPlaylistManager.shared.importPlaylist(name: displayName, songs: allSongs)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isCollectedLocally = true
                            }
                        }
                    }
                )
                .disabled(isCollectedLocally || viewModel.songs.isEmpty)
            }
        }
        .padding(18)
        .background(
            MinimalWhiteSurfaceBackground(
                cornerRadius: MinimalWhiteStyle.chromeRadius,
                elevated: true,
                tint: MinimalWhiteStyle.glassStrongFill
            )
        )
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 12)
        .padding(.bottom, 18)
    }
    
    private var qqFilteredSongs: [Song] {
        viewModel.songs.filtered(by: searchText)
    }
    
    private var songsList: some View {
        LazyVStack(spacing: 0) {
            if !viewModel.isLoading && qqFilteredSongs.isEmpty {
                VStack(spacing: 14) {
                    if MinimalWhiteStyle.isActive {
                        MinimalWhiteIconBadge(icon: .musicNoteList, size: 52)
                    } else {
                        MonologueIcon(icon: .musicNoteList, size: 40, color: QQDetailPalette.mutedText.opacity(0.36))
                    }
                    Text(String(localized: "qq_no_songs"))
                        .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.labelFont(14, weight: .medium) : .rounded(size: 15))
                        .foregroundColor(QQDetailPalette.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 44)
                .background {
                    if MinimalWhiteStyle.isActive {
                        MinimalWhiteSurfaceBackground(
                            cornerRadius: MinimalWhiteStyle.cardRadius,
                            elevated: false,
                            tint: MinimalWhiteStyle.glassFill
                        )
                    }
                }
                .padding(.horizontal, MinimalWhiteStyle.isActive ? DeviceLayout.viewHorizontalPadding : 0)
            }

            ForEach(Array(qqFilteredSongs.enumerated()), id: \.element.id) { index, song in
                SongListRow(song: song, index: index, isSelecting: isPlaylistSelectMode, isSelected: playlistSelectedIds.contains(song.id), onArtistTap: { _ in }, onDetailTap: { s in
                    selectedSongForDetail = s
                    showSongDetail = true
                }, onAlbumTap: { _ in }, onTap: {
                    if isPlaylistSelectMode {
                        if playlistSelectedIds.contains(song.id) {
                            playlistSelectedIds.remove(song.id)
                        } else {
                            playlistSelectedIds.insert(song.id)
                        }
                    } else {
                        PlayerManager.shared.play(song: song, in: qqFilteredSongs)
                    }
                })
                .onAppear {
                    if !isSearching && index == viewModel.songs.count - 3 { viewModel.loadMore() }
                }
            }
            .background {
                if MinimalWhiteStyle.isActive && !qqFilteredSongs.isEmpty {
                    MinimalWhiteSurfaceBackground(
                        cornerRadius: MinimalWhiteStyle.cardRadius,
                        elevated: false,
                        tint: MinimalWhiteStyle.glassFill
                    )
                }
            }
            
            if !isSearching {
                if viewModel.isLoadingMore {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.8)
                        Text("qq_loading_more").font(.rounded(size: 13)).foregroundColor(QQDetailPalette.secondaryText)
                    }
                    .padding(.vertical, 14)
                }
                
                if !viewModel.hasMore && !viewModel.songs.isEmpty {
                    NoMoreDataView()
                }
            }
        }
        .monologueSheet(isPresented: $showPlaylistBatchPlaylist, preset: .standard){
            BatchAddToPlaylistSheet(songs: qqFilteredSongs.filter { playlistSelectedIds.contains($0.id) })
        }
    }
    
    private func qqPlaylistBatchDownload() {
        let selected = qqFilteredSongs.filter { playlistSelectedIds.contains($0.id) }
        for song in selected {
            if song.isQQMusic {
                DownloadManager.shared.downloadQQ(song: song, quality: DownloadManager.defaultQQDownloadQuality)
            } else {
                DownloadManager.shared.download(song: song, quality: DownloadManager.defaultNeteaseDownloadQuality)
            }
        }
        AlertManager.shared.show(title: String(localized: "已加入下载"), message: String(localized: "已将 \(selected.count) 首歌曲加入下载队列"), primaryButtonTitle: String(localized: "确定"), primaryAction: {})
        withAnimation { isPlaylistSelectMode = false; playlistSelectedIds.removeAll() }
    }
}
