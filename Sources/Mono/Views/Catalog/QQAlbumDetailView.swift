import SwiftUI
import Combine
import QQMusicKit

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

        // 新版 API: { album: { name, mid, desc, time_public }, singers: [...], company: {...} }
        let basicInfo = json["album"] ?? json["basicInfo"] ?? json["basic_info"] ?? json
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
            basicInfo["time_public"]?.stringValue,
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
    @State private var scrollOffset: CGFloat = 0

    /// aside(默认)分支使用歌手页风格 Hero 头部
    private var usesAsideHero: Bool { !MinimalWhiteStyle.isActive && !SignalStyle.isActive }

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
            MonoSheetAwareBackground {
                if MinimalWhiteStyle.isActive {
                    MinimalWhiteRootBackdrop()
                } else if SignalStyle.isActive {
                    SignalRootBackdrop()
                } else if SettingsManager.shared.coverBgPlaylist {
                    PlaylistColorBackground(coverUrl: displayCoverUrl?.sized(200))
                } else {
                    ThemedPageBackground()
                }
            }

            ScrollView {
                VStack(spacing: 0) {
                    if usesAsideHero {
                        headerView
                    } else {
                        headerView
                            .monoPageHeaderCollapse()
                    }
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
            .monoScrollOffset($scrollOffset)
            .ignoresSafeArea(edges: usesAsideHero ? .top : [])
            .themeRenderScrollLayer()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .monoNavigationBackButton()
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
        .monoSheet(isPresented: $showAlbumDesc, preset: .standard){
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
        } else if SignalStyle.isActive {
            signalQQAlbumHeaderView
        } else {
            AsideDetailHeroHeader(
                coverUrl: displayCoverUrl,
                title: displayName,
                subtitle: (displayArtist?.isEmpty == false) ? displayArtist : nil,
                metaItems: {
                    var items = ["QCM"]
                    if let date = viewModel.publishDate, !date.isEmpty { items.append(date) }
                    return items
                }(),
                descriptionText: viewModel.resolvedDesc,
                onDescriptionTap: viewModel.resolvedDesc == nil ? nil : { showAlbumDesc = true },
                scrollOffset: scrollOffset,
                heroHeight: displayCoverUrl == nil ? 220 : 320,
                playAllTitle: String(localized: "qq_play"),
                playAllDisabled: viewModel.songs.isEmpty,
                onPlayAll: {
                    if let first = viewModel.songs.first {
                        PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                    }
                }
            )
            .padding(.bottom, DeviceLayout.isPad ? 20 : 12)
        }
    }

    private var signalQQAlbumHeaderView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 15) {
                ZStack {
                    SignalScreenBackground(cornerRadius: 11)

                    CachedAsyncImage(url: displayCoverUrl) {
                        SignalStyle.controlPressed
                    }
                    .aspectRatio(contentMode: .fill)
                    .padding(8)

                }
                .frame(width: DeviceLayout.isPad ? 154 : 118, height: DeviceLayout.isPad ? 154 : 118)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 7) {
                        SignalPill(text: "QCM", tint: SignalStyle.accent, selected: true, compact: true)
                        SignalPill(text: "ALBUM", tint: SignalStyle.mint, compact: true)
                    }

                    Text(displayName)
                        .font(SignalStyle.titleFont(22, weight: .bold))
                        .foregroundStyle(SignalStyle.ink)
                        .lineLimit(3)

                    if let displayArtist, !displayArtist.isEmpty {
                        Text(displayArtist)
                            .font(SignalStyle.bodyFont(12, weight: .medium))
                            .foregroundStyle(SignalStyle.inkSoft)
                            .lineLimit(1)
                    }

                    if let date = viewModel.publishDate, !date.isEmpty {
                        SignalPill(text: date, tint: SignalStyle.inkSoft, compact: true)
                    }
                }
            }

            HStack(spacing: 10) {
                Button {
                    if let first = viewModel.songs.first {
                        PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                    }
                } label: {
                    SignalPlayPill(title: String(localized: "qq_play"))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.songs.isEmpty)

                Spacer(minLength: 0)

                SignalPill(
                    text: String(format: "%02d", viewModel.songCount ?? viewModel.songs.count),
                    tint: SignalStyle.inkSoft,
                    icon: .album,
                    compact: true
                )
            }
        }
        .padding(16)
        .background(SignalSurfaceBackground(cornerRadius: 14, elevated: true, fill: SignalStyle.surface))
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 10)
        .padding(.bottom, 16)
        .iPadContentWidth(900)
    }

    private var minimalWhiteQQAlbumHeaderView: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                CachedAsyncImage(url: displayCoverUrl) {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(MinimalWhiteStyle.controlGlassFill)
                        .overlay(MonoIcon(icon: .album, size: 34, color: MinimalWhiteStyle.inkMuted, lineWidth: 1.6))
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
                    MonoIcon(icon: .play, size: 13, color: MinimalWhiteStyle.onAccent)
                    Text(String(localized: "qq_play"))
                        .font(MinimalWhiteStyle.labelFont(13, weight: .semibold))
                }
                .foregroundStyle(MinimalWhiteStyle.onAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(MinimalWhiteStyle.ink, in: Capsule(style: .continuous))
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.96))
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
                MonoLoadingView(text: MinimalWhiteStyle.isActive ? nil : "LOADING TRACKS")
            } else if viewModel.songs.isEmpty {
                VStack(spacing: 14) {
                    if MinimalWhiteStyle.isActive {
                        MinimalWhiteIconBadge(icon: .musicNoteList, size: 52)
                    } else {
                        MonoIcon(icon: .musicNoteList, size: 40, color: QQDetailPalette.mutedText.opacity(0.36))
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
                                MonoIcon(icon: .chevronRight, size: 12, color: QQDetailPalette.secondaryText)
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
        .monoSheet(isPresented: $showAlbumBatchPlaylist, preset: .standard){
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
        AlertManager.shared.show(title: String(localized: "download_batch_added_title"), message: L10n.format("download_batch_queue_added_format", selected.count), primaryButtonTitle: String(localized: "common_confirm"), primaryAction: {})
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
    @Environment(\.monoSheetDismiss) private var monoSheetDismiss
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                CachedAsyncImage(url: coverUrl) {
                    RoundedRectangle(cornerRadius: MinimalWhiteStyle.isActive ? 14 : (NeumorphicStyle.isActive ? 14 : 10))
                        .fill(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.controlGlassFill : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monoGlassTint))
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
                        .foregroundColor(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.ink : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monoTextPrimary))
                        .lineLimit(1)
                    if let artist = artistName {
                        Text(artist)
                            .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.labelFont(12, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .medium) : .rounded(size: 12)))
                            .foregroundColor(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.inkMuted : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monoTextSecondary))
                    }
                }
                Spacer()
                Button(action: { dismissCurrentPresentation(systemDismiss: dismiss, monoSheetDismiss: monoSheetDismiss) }) {
                    MonoIcon(icon: .close, size: 20, color: MinimalWhiteStyle.isActive ? MinimalWhiteStyle.inkMuted : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monoTextSecondary))
                        .frame(width: 32, height: 32)
                        .background {
                            if NeumorphicStyle.isActive {
                                NeumorphicSurfaceBackground(cornerRadius: 16, elevated: false, pressed: true, lightweight: true)
                            } else if MinimalWhiteStyle.isActive {
                                MinimalWhiteCircleBackground(elevated: false)
                            } else {
                                Circle().fill(Color.monoSeparator)
                            }
                        }
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 16)
            .padding(.bottom, 16)
            
            Rectangle()
                .fill(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.hairline : (NeumorphicStyle.isActive ? NeumorphicStyle.separator.opacity(0.45) : Color.monoSeparator))
                .frame(height: 0.5)
            
            ScrollView {
                Text(desc)
                    .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.bodyFont(15, weight: .regular) : .rounded(size: 15, weight: .regular))
                    .foregroundColor(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monoTextPrimary))
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
