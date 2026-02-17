// QQMusicDetailView.swift
// QQ 音乐歌手/专辑/歌单详情页
// 歌手：Hero 大图 + Tab（音乐/专辑/MV）
// 专辑：封面 + 歌手 + 发行信息 + 歌曲列表
// 歌单：封面 + 创建者 + 歌曲列表

import SwiftUI
import Combine
import QQMusicKit

// MARK: - QQ 音乐详情类型

enum QQDetailType {
    case artist(mid: String, name: String, coverUrl: String?)
    case album(mid: String, name: String, coverUrl: String?, artistName: String?)
    case playlist(id: Int, name: String, coverUrl: String?, creatorName: String?)
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
    
    func loadInfo() {
        APIService.shared.fetchQQSingerInfo(mid: mid)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] json in
                AppLogger.debug("[QQArtist] 歌手详情: \(json)")
                if let name = json["name"]?.stringValue ?? json["singerName"]?.stringValue, !name.isEmpty {
                    self?.resolvedName = name
                }
                if let pic = json["pic"]?.stringValue ?? json["singerPic"]?.stringValue
                    ?? json["singer_pic"]?.stringValue ?? json["headpic"]?.stringValue, !pic.isEmpty {
                    self?.resolvedCoverUrl = pic
                }
                if let desc = json["desc"]?.stringValue ?? json["brief"]?.stringValue
                    ?? json["SingerDesc"]?.stringValue, !desc.isEmpty {
                    self?.resolvedDesc = desc
                }
                if let fans = json["fans"]?.intValue ?? json["fansNum"]?.intValue ?? json["fans_num"]?.intValue {
                    self?.fansCount = fans
                }
                if let sc = json["songNum"]?.intValue ?? json["song_num"]?.intValue ?? json["total"]?.intValue {
                    self?.songCount = sc
                }
                if let ac = json["albumNum"]?.intValue ?? json["album_num"]?.intValue {
                    self?.albumCount = ac
                }
            })
            .store(in: &cancellables)
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
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var selectedTab = 0
    @State private var selectedSongForDetail: Song?
    @State private var showSongDetail = false
    @State private var selectedQQMV: QQMVVidItem?
    // QQ 专辑详情导航
    @State private var selectedAlbumMid: String?
    @State private var selectedAlbumName: String?
    @State private var selectedAlbumCover: String?
    @State private var selectedAlbumArtist: String?
    @State private var showAlbumDetail = false
    
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
        return URL(string: "https://y.gtimg.cn/music/photo_new/T001R500x500M000\(mid).jpg")
    }
    
    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color(hex: "0A0A0A") : Color(hex: "F5F5F7"))
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                    infoSection
                        .padding(.horizontal, 24)
                        .padding(.top, -40)
                    tabBar.padding(.top, 20)
                    tabContent.padding(.top, 8).padding(.bottom, 120)
                }
            }
            .ignoresSafeArea(edges: .top)
            
            // 悬浮返回按钮
            VStack {
                HStack {
                    AsideBackButton()
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, DeviceLayout.headerTopPadding)
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $showSongDetail) {
            if let song = selectedSongForDetail { SongDetailView(song: song) }
        }
        .navigationDestination(isPresented: $showAlbumDetail) {
            if let albumMid = selectedAlbumMid {
                QQMusicDetailView(detailType: .album(
                    mid: albumMid,
                    name: selectedAlbumName ?? "",
                    coverUrl: selectedAlbumCover,
                    artistName: selectedAlbumArtist
                ))
            }
        }
        .fullScreenCover(item: $selectedQQMV) { item in
            QQMVPlayerView(vid: item.vid)
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
    
    // MARK: - Hero 大图
    
    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            if let url = displayCoverUrl {
                CachedAsyncImage(url: url) {
                    Rectangle().fill(Color.asideCardBackground)
                }
                .aspectRatio(contentMode: .fill)
                .frame(height: headerImageHeight)
                .clipped()
            } else {
                Rectangle().fill(Color.asideCardBackground).frame(height: headerImageHeight)
            }
            
            LinearGradient(
                colors: [
                    .clear, .clear,
                    (colorScheme == .dark ? Color(hex: "0A0A0A") : Color(hex: "F5F5F7")).opacity(0.6),
                    (colorScheme == .dark ? Color(hex: "0A0A0A") : Color(hex: "F5F5F7"))
                ],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: headerImageHeight)
        }
        .frame(height: headerImageHeight)
    }
    
    // MARK: - 信息区域
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom) {
                Text(displayName)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
                    .lineLimit(2)
                Spacer()
                
                // QQ 标签
                Text("QQ")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.green.opacity(0.8)))
            }
            
            // 统计信息
            HStack(spacing: 16) {
                if let fans = viewModel.fansCount, fans > 0 {
                    Text(String(format: String(localized: "qq_fans_count"), formatCount(fans)))
                        .font(.rounded(size: 13))
                        .foregroundColor(.asideTextSecondary)
                }
                if let ac = viewModel.albumCount, ac > 0 {
                    Text(String(format: String(localized: "qq_album_count"), ac))
                        .font(.rounded(size: 13))
                        .foregroundColor(.asideTextSecondary)
                }
                if let sc = viewModel.songCount, sc > 0 {
                    Text(String(format: String(localized: "qq_song_count"), sc))
                        .font(.rounded(size: 13))
                        .foregroundColor(.asideTextSecondary)
                }
            }
            
            // 简介
            if let desc = viewModel.resolvedDesc, !desc.isEmpty {
                Text(desc)
                    .font(.rounded(size: 13))
                    .foregroundColor(.asideTextSecondary)
                    .lineLimit(2)
            }
            
            // 播放全部
            HStack(spacing: 12) {
                Button(action: {
                    if let first = viewModel.songs.first {
                        PlayerManager.shared.play(song: first, in: viewModel.songs)
                    }
                }) {
                    HStack(spacing: 8) {
                        AsideIcon(icon: .play, size: 14, color: .asideIconForeground)
                        Text("qq_play_all")
                            .font(.rounded(size: 14, weight: .bold))
                            .foregroundColor(.asideIconForeground)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.asideIconBackground))
                }
                .buttonStyle(AsideBouncingButtonStyle(scale: 0.95))
                .opacity(viewModel.songs.isEmpty ? 0.5 : 1)
                .disabled(viewModel.songs.isEmpty)
                Spacer()
            }
            .padding(.top, 4)
        }
    }
    
    // MARK: - Tab 栏
    
    private var tabBar: some View {
        HStack(spacing: 28) {
            tabItem(String(localized: "qq_tab_music"), index: 0)
            tabItem(String(localized: "qq_tab_album"), index: 1)
            tabItem(String(localized: "qq_tab_video"), index: 2)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func tabItem(_ title: String, index: Int) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = index }
        }) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.rounded(size: 17, weight: selectedTab == index ? .bold : .medium))
                    .foregroundColor(selectedTab == index ? .asideTextPrimary : .asideTextSecondary)
                Capsule()
                    .fill(selectedTab == index ? Color.asideIconBackground : Color.clear)
                    .frame(width: 20, height: 3)
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
    
    private var songsTab: some View {
        Group {
            if viewModel.isLoading && viewModel.songs.isEmpty {
                loadingView
            } else if viewModel.songs.isEmpty {
                emptyView(String(localized: "qq_no_songs"))
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(viewModel.songs.enumerated()), id: \.element.id) { index, song in
                        SongListRow(song: song, index: index, onArtistTap: { _ in }, onDetailTap: { s in
                            selectedSongForDetail = s
                            showSongDetail = true
                        }, onAlbumTap: { _ in })
                        .asButton {
                            PlayerManager.shared.play(song: song, in: viewModel.songs)
                        }
                        .onAppear {
                            if index == viewModel.songs.count - 3 { viewModel.loadMoreSongs() }
                        }
                    }
                }
                .padding(.vertical, 10)
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
                .padding(.horizontal, 24)
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
                        RoundedRectangle(cornerRadius: 10).fill(Color.asideCardBackground)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.asideCardBackground)
                        .frame(width: 72, height: 72)
                        .overlay(AsideIcon(icon: .album, size: 24, color: .asideTextSecondary.opacity(0.3)))
                }
                
                VStack(alignment: .leading, spacing: 5) {
                    Text(album.name)
                        .font(.rounded(size: 16, weight: .medium))
                        .foregroundColor(.asideTextPrimary)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        if !album.publishDateText.isEmpty {
                            Text(album.publishDateText)
                                .font(.rounded(size: 12))
                                .foregroundColor(.asideTextSecondary)
                        }
                        if let size = album.size, size > 0 {
                            Text("\(size) Tracks")
                                .font(.rounded(size: 12))
                                .foregroundColor(.asideTextSecondary)
                        }
                    }
                }
                Spacer(minLength: 0)
                AsideIcon(icon: .chevronRight, size: 12, color: .asideTextSecondary.opacity(0.4))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.asideGlassOverlay))
                    .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
            )
        }
        .buttonStyle(AsideBouncingButtonStyle(scale: 0.98))
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
                .padding(.horizontal, 24)
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
                                .fill(Color.asideTextSecondary.opacity(0.06))
                        }
                        .aspectRatio(16/9, contentMode: .fill)
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.asideTextSecondary.opacity(0.06))
                            .frame(height: 100)
                    }
                    if !mv.durationText.isEmpty {
                        Text(mv.durationText)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .padding(6)
                    }
                }
                Text(mv.name)
                    .font(.rounded(size: 13, weight: .medium))
                    .foregroundColor(.asideTextPrimary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(AsideBouncingButtonStyle(scale: 0.97))
    }
    
    // MARK: - 辅助
    
    private var loadingView: some View {
        VStack {
            Spacer().frame(height: 60)
            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .asideTextSecondary))
            Spacer().frame(height: 60)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func emptyView(_ text: String) -> some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 60)
            Text(text).font(.rounded(size: 15)).foregroundColor(.asideTextSecondary)
            Spacer().frame(height: 60)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func formatCount(_ count: Int) -> String {
        if count >= 10000 {
            let wan = Double(count) / 10000.0
            return wan >= 100 ? "\(Int(wan))万" : String(format: "%.1f万", wan)
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
        
        // 名称
        let name: String? = json["name"]?.stringValue ?? json["albumName"]?.stringValue ?? json["album_name"]?.stringValue
        if let name, !name.isEmpty {
            resolvedName = name
        }
        
        // 封面
        let pic: String? = json["picUrl"]?.stringValue ?? json["pic_url"]?.stringValue ?? json["pic"]?.stringValue ?? json["cover"]?.stringValue ?? json["albumPic"]?.stringValue
        if let pic, !pic.isEmpty {
            resolvedCoverUrl = pic
        } else {
            let albumMid: String? = json["mid"]?.stringValue ?? json["album_mid"]?.stringValue ?? json["albumMID"]?.stringValue
            if let albumMid, !albumMid.isEmpty {
                resolvedCoverUrl = "https://y.gtimg.cn/music/photo_new/T002R300x300M000\(albumMid).jpg"
            } else {
                resolvedCoverUrl = "https://y.gtimg.cn/music/photo_new/T002R300x300M000\(mid).jpg"
            }
        }
        
        // 歌手
        if let singers = json["singer"]?.arrayValue ?? json["singers"]?.arrayValue {
            let names: [String] = singers.compactMap { $0["name"]?.stringValue }
            if !names.isEmpty { resolvedArtistName = names.joined(separator: " / ") }
        } else {
            let sn: String? = json["singerName"]?.stringValue ?? json["singer_name"]?.stringValue
            if let sn { resolvedArtistName = sn }
        }
        
        // 简介
        let desc: String? = json["desc"]?.stringValue ?? json["description"]?.stringValue
        if let desc, !desc.isEmpty { resolvedDesc = desc }
        
        // 发行日期
        let date: String? = json["aDate"]?.stringValue ?? json["publicTime"]?.stringValue ?? json["publish_date"]?.stringValue
        if let date, !date.isEmpty { publishDate = date }
        
        // 歌曲数
        let count: Int? = json["total_song_num"]?.intValue ?? json["song_count"]?.intValue
        if let count { songCount = count }
    }
}

// MARK: - QQ 专辑详情页

struct QQAlbumDetailView: View {
    let mid: String
    let name: String
    let coverUrl: String?
    let artistName: String?
    
    @StateObject private var viewModel: QQAlbumDetailViewModel
    @State private var selectedSongForDetail: Song?
    @State private var showSongDetail = false
    @State private var showAlbumDesc = false
    
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
        return URL(string: "https://y.gtimg.cn/music/photo_new/T002R300x300M000\(mid).jpg")
    }
    
    var body: some View {
        ZStack {
            AsideBackground()
            
            VStack(spacing: 0) {
                headerView
                
                ScrollView(showsIndicators: false) {
                    songListSection.padding(.bottom, 100)
                }
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $showSongDetail) {
            if let song = selectedSongForDetail { SongDetailView(song: song) }
        }
        .onAppear { viewModel.fetchData() }
        .sheet(isPresented: $showAlbumDesc) {
            if let desc = viewModel.resolvedDesc {
                QQAlbumDescSheet(name: displayName, coverUrl: displayCoverUrl, artistName: displayArtist, desc: desc)
            }
        }
    }
    
    // MARK: - 头部
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                AsideBackButton()
                Spacer()
                if let count = viewModel.songCount ?? (viewModel.songs.isEmpty ? nil : viewModel.songs.count), count > 0 {
                    Text(String(format: String(localized: "qq_track_count"), count))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.asideIconBackground)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.asideMilk)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.asideTextSecondary.opacity(0.2), lineWidth: 0.5))
                }
            }
            
            HStack(alignment: .top, spacing: 16) {
                CachedAsyncImage(url: displayCoverUrl) {
                    Color.gray.opacity(0.1)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 120, height: 120)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text("QQ")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 4).fill(Color.green.opacity(0.8)))
                        
                        Text(displayName)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.asideTextPrimary)
                            .lineLimit(2)
                    }
                    
                    if let artist = displayArtist, !artist.isEmpty {
                        Text(artist)
                            .font(.system(size: 13))
                            .foregroundColor(.asideTextSecondary)
                            .lineLimit(1)
                    }
                    
                    if let date = viewModel.publishDate, !date.isEmpty {
                        Text(date)
                            .font(.rounded(size: 11))
                            .foregroundColor(.asideTextSecondary.opacity(0.7))
                    }
                    
                    Spacer().frame(height: 4)
                    
                    Button(action: {
                        if let first = viewModel.songs.first {
                            PlayerManager.shared.play(song: first, in: viewModel.songs)
                        }
                    }) {
                        HStack(spacing: 6) {
                            AsideIcon(icon: .play, size: 12, color: .asideIconForeground)
                            Text(String(localized: "qq_play"))
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(.asideIconForeground)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.asideIconBackground)
                        .cornerRadius(20)
                    }
                    .buttonStyle(AsideBouncingButtonStyle(scale: 0.95))
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .padding(.top, DeviceLayout.headerTopPadding)
    }
    
    // MARK: - 歌曲列表
    
    private var songListSection: some View {
        LazyVStack(spacing: 0) {
            if viewModel.isLoading {
                AsideLoadingView(text: "LOADING TRACKS")
            } else if viewModel.songs.isEmpty {
                VStack(spacing: 14) {
                    AsideIcon(icon: .musicNoteList, size: 40, color: .asideTextSecondary.opacity(0.3))
                    Text(String(localized: "qq_no_songs")).font(.rounded(size: 15)).foregroundColor(.asideTextSecondary)
                }
                .padding(.top, 40)
            } else {
                // 专辑简介
                if let desc = viewModel.resolvedDesc, !desc.isEmpty {
                    Button(action: { showAlbumDesc = true }) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("qq_album_desc")
                                    .font(.rounded(size: 15, weight: .semibold))
                                    .foregroundColor(.asideTextPrimary)
                                Spacer()
                                AsideIcon(icon: .chevronRight, size: 12, color: .asideTextSecondary)
                            }
                            Text(desc)
                                .font(.rounded(size: 13, weight: .regular))
                                .foregroundColor(.asideTextSecondary)
                                .lineLimit(3)
                                .lineSpacing(4)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.asideGlassOverlay))
                                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                }
                
                ForEach(Array(viewModel.songs.enumerated()), id: \.element.id) { index, song in
                    SongListRow(song: song, index: index, onArtistTap: { _ in }, onDetailTap: { s in
                        selectedSongForDetail = s
                        showSongDetail = true
                    }, onAlbumTap: { _ in })
                    .asButton {
                        PlayerManager.shared.play(song: song, in: viewModel.songs)
                    }
                }
                
                NoMoreDataView()
                Color.clear.frame(height: 100)
            }
        }
    }
}

// MARK: - QQ 专辑简介 Sheet

struct QQAlbumDescSheet: View {
    let name: String
    let coverUrl: URL?
    let artistName: String?
    let desc: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.asideTextSecondary.opacity(0.25))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
            
            HStack(spacing: 14) {
                CachedAsyncImage(url: coverUrl) {
                    RoundedRectangle(cornerRadius: 10).fill(Color.asideCardBackground)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 48, height: 48)
                .cornerRadius(10)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(.rounded(size: 20, weight: .bold))
                        .foregroundColor(.asideTextPrimary)
                        .lineLimit(1)
                    if let artist = artistName {
                        Text(artist)
                            .font(.rounded(size: 12))
                            .foregroundColor(.asideTextSecondary)
                    }
                }
                Spacer()
                Button(action: { dismiss() }) {
                    AsideIcon(icon: .close, size: 20, color: .asideTextSecondary)
                        .frame(width: 32, height: 32)
                        .background(Color.asideSeparator)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 16)
            
            Rectangle().fill(Color.asideSeparator).frame(height: 0.5)
            
            ScrollView(showsIndicators: false) {
                Text(desc)
                    .font(.rounded(size: 15, weight: .regular))
                    .foregroundColor(.asideTextPrimary)
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.asideGlassOverlay))
                            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
            }
        }
        .background { AsideBackground() }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
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
    @State private var selectedSongForDetail: Song?
    @State private var showSongDetail = false
    
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
        ZStack {
            AsideBackground().ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    AsideBackButton()
                    Spacer()
                    Text("qq_music_title")
                        .font(.rounded(size: 18, weight: .bold))
                        .foregroundColor(.asideTextPrimary)
                    Spacer()
                    Color.clear.frame(width: 40, height: 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, DeviceLayout.headerTopPadding)
                .padding(.bottom, 8)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        headerSection
                        if !viewModel.songs.isEmpty { playAllButton }
                        songsList
                    }
                    .padding(.bottom, 120)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if viewModel.songs.isEmpty {
                viewModel.fetchSongs()
                viewModel.fetchDetail()
            }
        }
        .navigationDestination(isPresented: $showSongDetail) {
            if let song = selectedSongForDetail { SongDetailView(song: song) }
        }
        .overlay {
            if viewModel.isLoading && viewModel.songs.isEmpty {
                AsideLoadingView(text: "LOADING")
            }
        }
    }
    
    private var headerSection: some View {
        HStack(spacing: 16) {
            if let url = displayCoverUrl {
                CachedAsyncImage(url: url) {
                    RoundedRectangle(cornerRadius: 16).fill(Color.asideCardBackground)
                }
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.asideCardBackground)
                    .frame(width: 100, height: 100)
                    .overlay { AsideIcon(icon: .musicNote, size: 32, color: .asideTextSecondary.opacity(0.3)) }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(displayName)
                    .font(.rounded(size: 20, weight: .bold))
                    .foregroundColor(.asideTextPrimary)
                    .lineLimit(2)
                if let creator = creatorName {
                    Text("by \(creator)")
                        .font(.rounded(size: 14))
                        .foregroundColor(.asideTextSecondary)
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    Text("QQ")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.green.opacity(0.8)))
                    if !viewModel.songs.isEmpty {
                        Text(String(localized: "qq_songs_count", defaultValue: "\(viewModel.songs.count)首歌曲"))
                            .font(.rounded(size: 12))
                            .foregroundColor(.asideTextSecondary)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
    
    private var playAllButton: some View {
        Button(action: {
            if let first = viewModel.songs.first {
                PlayerManager.shared.play(song: first, in: viewModel.songs)
            }
        }) {
            HStack(spacing: 8) {
                AsideIcon(icon: .play, size: 16, color: .asideTextPrimary)
                Text("qq_play_all")
                    .font(.rounded(size: 15, weight: .semibold))
                    .foregroundColor(.asideTextPrimary)
                Text("\(viewModel.songs.count)")
                    .font(.rounded(size: 13))
                    .foregroundColor(.asideTextSecondary)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var songsList: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(viewModel.songs.enumerated()), id: \.element.id) { index, song in
                SongListRow(song: song, index: index, onArtistTap: { _ in }, onDetailTap: { s in
                    selectedSongForDetail = s
                    showSongDetail = true
                }, onAlbumTap: { _ in })
                .asButton {
                    PlayerManager.shared.play(song: song, in: viewModel.songs)
                }
                .onAppear {
                    if index == viewModel.songs.count - 3 { viewModel.loadMore() }
                }
            }
            
            if viewModel.isLoadingMore {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.8)
                    Text("qq_loading_more").font(.rounded(size: 13)).foregroundColor(.asideTextSecondary)
                }
                .padding(.vertical, 14)
            }
            
            if !viewModel.hasMore && !viewModel.songs.isEmpty {
                NoMoreDataView()
            }
        }
    }
}
