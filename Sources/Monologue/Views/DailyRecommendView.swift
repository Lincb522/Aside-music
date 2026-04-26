import SwiftUI

// MARK: - View

struct DailyRecommendView: View {
    @StateObject private var viewModel = DailyRecommendViewModel()
    @ObservedObject private var styleManager = StyleManager.shared
    @Namespace private var animationNamespace
    @State private var selectedArtistId: Int?
    @State private var showArtistDetail = false
    @State private var selectedSongForDetail: Song?
    @State private var showSongDetail = false
    @State private var selectedAlbumId: Int?
    @State private var showAlbumDetail = false
    @State private var isSelectMode = false
    @State private var selectedSongIds: Set<Int> = []
    @State private var showBatchAddToPlaylist = false
    @State private var searchText = ""
    @State private var isSearching = false

    typealias Theme = PlaylistDetailView.Theme

    var body: some View {
        ZStack(alignment: .top) {
            if MangaStyle.isActive {
                MangaRootBackdrop()
            } else if MujiStyle.isActive {
                MujiRootBackdrop()
            } else {
                MonologueBackground()
            }

            mainContent

            Group {
                if viewModel.showStyleMenu {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                viewModel.showStyleMenu = false
                            }
                        }
                        .zIndex(1)
                }

                if viewModel.showStyleMenu {
                    StyleSelectionMorphView(
                        styleManager: styleManager,
                        isPresented: $viewModel.showStyleMenu,
                        namespace: animationNamespace
                    )
                    .zIndex(2)
                }
            }
        }
        .monologueSheet(isPresented: $viewModel.showHistorySheet, preset: .standard) {
            DailyHistoryView(dates: viewModel.historyDates)
        }
        .onChange(of: viewModel.noHistoryMessage) { _, newValue in
            if let message = newValue {
                AlertManager.shared.show(
                    title: NSLocalizedString("daily_history_title", comment: ""),
                    message: message,
                    primaryButtonTitle: NSLocalizedString("daily_no_history", comment: ""),
                    primaryAction: {
                        viewModel.noHistoryMessage = nil
                    }
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showArtistDetail) {
            if let artistId = selectedArtistId {
                ArtistDetailView(artistId: artistId)

            }
        }
        .navigationDestination(isPresented: $showSongDetail) {
            if let song = selectedSongForDetail {
                SongDetailView(song: song)

            }
        }
        .navigationDestination(isPresented: $showAlbumDetail) {
            if let albumId = selectedAlbumId {
                AlbumDetailView(albumId: albumId, albumName: nil, albumCoverUrl: nil)

            }
        }
        .onChange(of: viewModel.showStyleMenu) { _, isShown in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                PlayerManager.shared.isTabBarHidden = isShown
            }
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            headerSection

            if viewModel.isLoading && viewModel.songs.isEmpty {
                Spacer()
                VStack {
                    MonologueLoadingView(text: "LOADING...")
                }
                Spacer()
            } else if let error = viewModel.errorMessage {
                errorView(msg: error)
            } else {
                songList
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var headerSection: some View {
        if MangaStyle.isActive {
            mangaHeaderSection
        } else if MujiStyle.isActive {
            mujiHeaderSection
        } else {
            VStack(spacing: 16) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(dayString)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.text)

                        Text("/ \(monthString)")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.secondaryText)
                            .padding(.bottom, 4)
                    }

                    if !viewModel.showStyleMenu {
                        HStack(spacing: 10) {
                            Button(action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    viewModel.showStyleMenu = true
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Text(styleManager.currentStyle == nil ? NSLocalizedString("daily_recommend", comment: "") : styleManager.currentStyleName)
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(Theme.secondaryText)
                                        .matchedGeometryEffect(id: "filter_text", in: animationNamespace)

                                    MonologueIcon(icon: .chevronRight, size: 12, color: Theme.secondaryText)
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.monologueSeparator)
                                        .matchedGeometryEffect(id: "filter_bg", in: animationNamespace)
                                )
                            }

                            Button(action: {
                                viewModel.loadHistoryDates()
                            }) {
                                HStack(spacing: 6) {
                                    MonologueIcon(icon: .history, size: 14, color: Theme.secondaryText)
                                    Text(LocalizedStringKey("daily_history"))
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                }
                                .foregroundColor(Theme.secondaryText)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.monologueSeparator)
                                )
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    } else {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 32)
                            .frame(width: 200, alignment: .leading)
                    }
                }

                Spacer()

                if !viewModel.songs.isEmpty {
                    Button(action: {
                        if let first = viewModel.songs.first {
                            PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                        }
                    }) {
                        HStack(spacing: 8) {
                            MonologueIcon(icon: .play, size: 14, color: .monologueIconForeground)
                            Text(LocalizedStringKey("artist_play_all"))
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.monologueIconForeground)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Theme.accent)
                        .clipShape(Capsule())
                        .shadow(color: Theme.accent.opacity(0.2), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, 16)
        .padding(.bottom, 10)
        }
    }

    private var mujiHeaderSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dayString)
                        .font(MujiStyle.titleFont(52, weight: .light))
                        .foregroundStyle(MujiStyle.ink)
                        .lineLimit(1)

                    Text("/ \(monthString)")
                        .font(MujiStyle.labelFont(12, weight: .regular))
                        .foregroundStyle(MujiStyle.inkMuted)
                }
                .frame(width: 72, alignment: .leading)

                Rectangle()
                    .fill(MujiStyle.separator)
                    .frame(width: 0.65, height: 68)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 7) {
                        MujiPill(text: String(localized: "daily_recommend"), tint: MujiStyle.clay)
                        if !viewModel.songs.isEmpty {
                            MujiPill(text: "\(viewModel.songs.count) \(String(localized: "songs_unit"))", tint: MujiStyle.tea)
                        }
                    }

                    Text(styleManager.currentStyle == nil ? NSLocalizedString("daily_recommend", comment: "") : styleManager.currentStyleName)
                        .font(MujiStyle.titleFont(24, weight: .regular))
                        .foregroundStyle(MujiStyle.ink)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                if !viewModel.songs.isEmpty {
                    Button(action: {
                        if let first = viewModel.songs.first {
                            PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                        }
                    }) {
                        MonologueIcon(icon: .play, size: 15, color: MujiStyle.paper, lineWidth: 1.5)
                            .frame(width: 42, height: 42)
                            .background(MujiStyle.clay, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
                }
            }

            if !viewModel.showStyleMenu {
                HStack(spacing: 9) {
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            viewModel.showStyleMenu = true
                        }
                    }) {
                        mujiHeaderChip(
                            text: styleManager.currentStyle == nil ? NSLocalizedString("daily_recommend", comment: "") : styleManager.currentStyleName,
                            icon: .sparkle,
                            tint: MujiStyle.indigo
                        )
                        .matchedGeometryEffect(id: "filter_bg", in: animationNamespace)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        viewModel.loadHistoryDates()
                    }) {
                        mujiHeaderChip(
                            text: NSLocalizedString("daily_history", comment: ""),
                            icon: .history,
                            tint: MujiStyle.tea
                        )
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
                }
            } else {
                Color.clear.frame(height: 34)
            }

            MujiListDivider()
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    private func mujiHeaderChip(text: String, icon: MonologueIcon.IconType, tint: Color) -> some View {
        HStack(spacing: 7) {
            MonologueIcon(icon: icon, size: 13, color: tint, lineWidth: 1.5)
            Text(text)
                .font(MujiStyle.labelFont(12, weight: .regular))
                .foregroundStyle(MujiStyle.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(MujiStyle.surface.opacity(0.84), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(MujiStyle.hairline.opacity(0.48), lineWidth: 0.6)
        )
    }

    private var mangaHeaderSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 13) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dayString)
                        .font(MangaStyle.titleFont(42, weight: .black))
                        .foregroundColor(MangaStyle.ink)
                        .lineLimit(1)

                    Text("/ \(monthString)")
                        .font(MangaStyle.labelFont(13, weight: .black))
                        .foregroundColor(MangaStyle.inkSub)
                }
                .frame(width: 64, alignment: .leading)

                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 7) {
                        MangaSectionMark(kind: .heart, tint: MangaStyle.bubblePink, size: 22)
                        MangaLabel(text: String(localized: "daily_recommend"), tint: MangaStyle.labelYellow, small: true)
                    }

                    Text(styleManager.currentStyle == nil ? NSLocalizedString("daily_recommend", comment: "") : styleManager.currentStyleName)
                        .font(MangaStyle.titleFont(24, weight: .black))
                        .foregroundColor(MangaStyle.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)

                    if !viewModel.songs.isEmpty {
                        MangaLabel(text: "\(viewModel.songs.count) \(String(localized: "songs_unit"))", tint: MangaStyle.paperCool, small: true)
                    }
                }

                Spacer(minLength: 8)

                if !viewModel.songs.isEmpty {
                    Button(action: {
                        if let first = viewModel.songs.first {
                            PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                        }
                    }) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(MangaStyle.ink)
                            .frame(width: 44, height: 44)
                            .background(MangaStyle.labelYellow, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(MangaStyle.ink, lineWidth: 1.6))
                            .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(MangaStyle.ink).offset(x: 2, y: 2))
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
                }
            }

            if !viewModel.showStyleMenu {
                HStack(spacing: 9) {
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            viewModel.showStyleMenu = true
                        }
                    }) {
                        mangaHeaderChip(
                            text: styleManager.currentStyle == nil ? NSLocalizedString("daily_recommend", comment: "") : styleManager.currentStyleName,
                            icon: .sparkle,
                            tint: MangaStyle.bubbleBlue
                        )
                        .matchedGeometryEffect(id: "filter_bg", in: animationNamespace)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        viewModel.loadHistoryDates()
                    }) {
                        mangaHeaderChip(
                            text: NSLocalizedString("daily_history", comment: ""),
                            icon: .history,
                            tint: MangaStyle.mint
                        )
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
                }
            } else {
                Color.clear.frame(height: 34)
            }
        }
        .padding(16)
        .background(MangaCardBackground(cornerRadius: 22, elevated: true, tint: MangaStyle.bubbleWhite))
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    private func mangaHeaderChip(text: String, icon: MonologueIcon.IconType, tint: Color) -> some View {
        HStack(spacing: 7) {
            MonologueIcon(icon: icon, size: 13, color: MangaStyle.ink, lineWidth: 1.7)
            Text(text)
                .font(MangaStyle.labelFont(12, weight: .black))
                .foregroundColor(MangaStyle.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.74)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Capsule().fill(tint))
        .overlay(Capsule().stroke(MangaStyle.ink, lineWidth: 1.3))
    }

    private var dailyFilteredSongs: [Song] { viewModel.songs.filtered(by: searchText) }

    private var songList: some View {
        ScrollView {
            VStack(spacing: 0) {
                PlaylistSearchBar(
                    searchText: $searchText,
                    isSearching: $isSearching,
                    isSelectMode: $isSelectMode,
                    selectedIds: $selectedSongIds,
                    songs: dailyFilteredSongs,
                    onBatchQueue: {
                        let selected = dailyFilteredSongs.filter { selectedSongIds.contains($0.id) }
                        SongBatchActionHelper.addToQueue(selected) {
                            isSelectMode = false
                            selectedSongIds.removeAll()
                        }
                    },
                    onBatchDownload: { batchDownloadSelected() },
                    onBatchCollect: { showBatchAddToPlaylist = true }
                )

                LazyVStack(spacing: 0) {
                    ForEach(Array(dailyFilteredSongs.enumerated()), id: \.element.id) { index, song in
                    SongListRow(song: song, index: index, isSelecting: isSelectMode, isSelected: selectedSongIds.contains(song.id), onArtistTap: { artistId in
                        selectedArtistId = artistId
                        showArtistDetail = true
                    }, onDetailTap: { detailSong in
                        selectedSongForDetail = detailSong
                        showSongDetail = true
                    }, onAlbumTap: { albumId in
                        selectedAlbumId = albumId
                        showAlbumDetail = true
                    }, onTap: {
                        if isSelectMode {
                            if selectedSongIds.contains(song.id) {
                                selectedSongIds.remove(song.id)
                            } else {
                                selectedSongIds.insert(song.id)
                            }
                        } else {
                            PlayerManager.shared.play(song: song, in: dailyFilteredSongs)
                        }
                    })
                    }
                }
            }
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .monologueSheet(isPresented: $showBatchAddToPlaylist, preset: .standard){
            BatchAddToPlaylistSheet(songs: dailyFilteredSongs.filter { selectedSongIds.contains($0.id) })
        }
    }

    private func batchDownloadSelected() {
        let selected = dailyFilteredSongs.filter { selectedSongIds.contains($0.id) }
        for song in selected {
            if song.isQQMusic {
                DownloadManager.shared.downloadQQ(song: song, quality: DownloadManager.defaultQQDownloadQuality)
            } else {
                DownloadManager.shared.download(song: song, quality: DownloadManager.defaultNeteaseDownloadQuality)
            }
        }
        AlertManager.shared.show(title: String(localized: "已加入下载"), message: String(localized: "已将 \(selected.count) 首歌曲加入下载队列"), primaryButtonTitle: String(localized: "确定"), primaryAction: {})
        withAnimation { isSelectMode = false; selectedSongIds.removeAll() }
    }

    private func errorView(msg: String) -> some View {
        VStack {
            Spacer()
            MonologueIcon(icon: .warning, size: 48, color: .monologueTextSecondary)
            Text(msg)
                .foregroundColor(.monologueTextSecondary)
                .padding()
            Button("Retry") {
                viewModel.loadStandardRecommend()
            }
            Spacer()
        }
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd"
        return f
    }()

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM"
        return f
    }()

    private var dayString: String {
        Self.dayFormatter.string(from: Date())
    }

    private var monthString: String {
        Self.monthFormatter.string(from: Date())
    }
}

// MARK: - History View

struct DailyHistoryView: View {
    let dates: [String]
    @Environment(\.dismiss) var dismiss
    @Environment(\.monologueSheetDismiss) private var monologueSheetDismiss
    @State private var selectedDate: String?
    @State private var songs: [Song] = []
    @State private var isLoading = false
    @State private var loadTask: Task<Void, Never>?

    typealias Theme = PlaylistDetailView.Theme

    var body: some View {
        ZStack {
            MonologueSheetAwareBackground {
                MonologueBackground()
            }

            VStack(spacing: 0) {
                headerSection

                dateSelector
                    .padding(.top, 8)

                if isLoading {
                    Spacer()
                    MonologueLoadingView(text: "LOADING")
                    Spacer()
                } else if songs.isEmpty {
                    emptyState
                } else {
                    songList
                }
            }
        }
        .onAppear {
            AppLogger.debug("DailyHistoryView appeared with \(dates.count) dates: \(dates)")
            if let first = dates.first {
                loadSongs(for: first)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Button(action: { dismissCurrentPresentation(systemDismiss: dismiss, monologueSheetDismiss: monologueSheetDismiss) }) {
                MonologueIcon(icon: .close, size: 20, color: MujiStyle.isActive ? MujiStyle.inkSoft : Theme.text)
                    .padding(10)
                    .background(MujiStyle.isActive ? MujiStyle.surfaceRaised : Color.monologueGlassTint.opacity(0.6))
                    .clipShape(Circle())
            }

            Spacer()

            VStack(spacing: 2) {
                Text(LocalizedStringKey("daily_history_title"))
                    .font(MujiStyle.isActive ? MujiStyle.titleFont(19, weight: .regular) : .system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(MujiStyle.isActive ? MujiStyle.ink : Theme.text)

                Text(LocalizedStringKey("daily_history_subtitle"))
                    .font(MujiStyle.isActive ? MujiStyle.labelFont(12, weight: .regular) : .system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(MujiStyle.isActive ? MujiStyle.inkSoft : Theme.secondaryText)
            }

            Spacer()

            if !songs.isEmpty {
                Button(action: {
                    if let first = songs.first {
                        PlayerManager.shared.playReplacingContext(song: first, in: songs)
                    }
                }) {
                    if MujiStyle.isActive {
                        MujiActionPill(title: String(localized: "artist_play_all"), icon: .play, selected: true, tint: MujiStyle.clay)
                    } else {
                        HStack(spacing: 8) {
                            MonologueIcon(icon: .play, size: 14, color: .monologueIconForeground)
                            Text(LocalizedStringKey("artist_play_all"))
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.monologueIconForeground)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Theme.accent)
                        .clipShape(Capsule())
                    }
                }
                .buttonStyle(ScaleButtonStyle())
            } else {
                Color.clear
                    .frame(width: 92, height: 40)
            }
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Date Selector

    private var dateSelector: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(dates, id: \.self) { date in
                    dateButton(for: date)
                }
            }
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
    }

    private func dateButton(for date: String) -> some View {
        let isSelected = selectedDate == date
        let displayDate = formatDateShort(date)

        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                loadSongs(for: date)
            }
        }) {
            Text(displayDate)
                .font(MujiStyle.isActive ? MujiStyle.labelFont(14, weight: isSelected ? .semibold : .regular) : .system(size: 14, weight: isSelected ? .bold : .medium, design: .rounded))
                .foregroundColor(MujiStyle.isActive ? (isSelected ? MujiStyle.paper : MujiStyle.ink) : (isSelected ? .monologueIconForeground : .monologueTextPrimary))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(MujiStyle.isActive ? (isSelected ? MujiStyle.clay : MujiStyle.surfaceRaised) : (isSelected ? Color.monologueIconBackground.opacity(0.85) : Color.monologueGlassTint))
                        .overlay(
                            Capsule()
                                .stroke(MujiStyle.isActive ? MujiStyle.hairline.opacity(isSelected ? 0 : 0.5) : Color.monologueSeparator, lineWidth: isSelected ? 0 : 1)
                        )
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Content

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            MonologueIcon(icon: .clock, size: 48, color: .monologueTextSecondary.opacity(0.5))

            Text(LocalizedStringKey("daily_select_date"))
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.monologueTextSecondary)

            Spacer()
        }
    }

    private var songList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if let date = selectedDate {
                    HStack {
                        Text(formatFullDate(date))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.secondaryText)

                        Spacer()

                        Text(String(format: NSLocalizedString("daily_song_count", comment: ""), songs.count))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.secondaryText.opacity(0.7))
                    }
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.vertical, 12)
                }

                ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                    SongListRow(song: song, index: index, onTap: {
                        PlayerManager.shared.play(song: song, in: songs)
                    })
                }
            }
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Helpers

    private func loadSongs(for date: String) {
        selectedDate = date
        isLoading = true
        songs = []
        loadTask?.cancel()

        AppLogger.debug("Loading history songs for date: \(date)")
        loadTask = Task {
            do {
                let loadedSongs = try await APIService.shared.fetchHistoryRecommendSongs(date: date).async()
                guard !Task.isCancelled else { return }
                AppLogger.debug("Received \(loadedSongs.count) history songs")
                songs = loadedSongs
            } catch {
                guard !Task.isCancelled else { return }
                AppLogger.error("History songs load error: \(error)")
            }
            isLoading = false
        }
    }

    private func formatDateShort(_ dateString: String) -> String {
        let components = dateString.split(separator: "-")
        if components.count >= 3 {
            return "\(components[1])/\(components[2])"
        }
        return dateString
    }

    private func formatDate(_ dateString: String) -> (day: String, month: String) {
        let components = dateString.split(separator: "-")
        if components.count >= 3 {
            let day = String(components[2])
            let monthNum = Int(components[1]) ?? 1
            let months = ["", String(localized: "一月"), String(localized: "二月"), String(localized: "三月"), String(localized: "四月"), String(localized: "五月"), String(localized: "六月"),
                         String(localized: "七月"), String(localized: "八月"), String(localized: "九月"), String(localized: "十月"), String(localized: "十一月"), String(localized: "十二月")]
            let month = months[min(monthNum, 12)]
            return (day, month)
        }
        return (dateString, "")
    }

    private func formatFullDate(_ dateString: String) -> String {
        let components = dateString.split(separator: "-")
        if components.count >= 3 {
            return String(localized: "\(components[0])年\(components[1])月\(components[2])日 推荐")
        }
        return dateString
    }
}
