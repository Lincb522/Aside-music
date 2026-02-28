import SwiftUI
import Combine
import UniformTypeIdentifiers

// MARK: - Main View
struct LibraryView: View {
    @StateObject private var viewModel = LibraryViewModel()

    typealias Theme = PlaylistDetailView.Theme
    
    /// 当前标签索引（用于滑动手势）
    @State private var tabIndex: Int = 0
    /// 拖拽偏移量
    @State private var dragOffset: CGFloat = 0

    private let allTabs = LibraryViewModel.LibraryTab.allCases

    var body: some View {
        NavigationStack(path: $viewModel.navigationPath) {
            ZStack {
                AsideBackground()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    headerView

                    // 用 GeometryReader + offset 替代 page-style TabView
                    GeometryReader { geo in
                        let width = geo.size.width
                        HStack(spacing: 0) {
                            MyPlaylistsContainerView(viewModel: viewModel)
                                .frame(width: width)
                            PlaylistSquareView(viewModel: viewModel)
                                .frame(width: width)
                            ArtistLibraryView(viewModel: viewModel)
                                .frame(width: width)
                            ChartsLibraryView(viewModel: viewModel)
                                .frame(width: width)
                        }
                        .offset(x: -CGFloat(tabIndex) * width + dragOffset)
                        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: tabIndex)
                        .gesture(
                            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                                .onChanged { value in
                                    // 只响应水平方向为主的拖拽
                                    if abs(value.translation.width) > abs(value.translation.height) {
                                        dragOffset = value.translation.width
                                    }
                                }
                                .onEnded { value in
                                    let threshold: CGFloat = width * 0.2
                                    var newIndex = tabIndex
                                    if value.translation.width < -threshold || value.predictedEndTranslation.width < -width * 0.4 {
                                        newIndex = min(tabIndex + 1, allTabs.count - 1)
                                    } else if value.translation.width > threshold || value.predictedEndTranslation.width > width * 0.4 {
                                        newIndex = max(tabIndex - 1, 0)
                                    }
                                    dragOffset = 0
                                    tabIndex = newIndex
                                    viewModel.currentTab = allTabs[newIndex]
                                }
                        )
                    }
                    .clipped()
                }
                .ignoresSafeArea(edges: .bottom)
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: LibraryViewModel.NavigationDestination.self) { destination in
                switch destination {
                case .playlist(let playlist):
                    PlaylistDetailView(playlist: playlist)
                case .artist(let id):
                    ArtistDetailView(artistId: id)
                case .artistInfo(let artist):
                    if artist.source == .qqmusic, let mid = artist.qqMid {
                        QQMusicDetailView(detailType: .artist(
                            mid: mid,
                            name: artist.name,
                            coverUrl: artist.picUrl ?? artist.img1v1Url
                        ))
                    } else {
                        ArtistDetailView(artistId: artist.id)
                    }
                case .qqArtist(let mid, let name, let coverUrl):
                    QQMusicDetailView(detailType: .artist(mid: mid, name: name, coverUrl: coverUrl))
                case .radioDetail(let id):
                    RadioDetailView(radioId: id)
                case .localPlaylist(let id):
                    LocalPlaylistDetailView(playlistId: id)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .init("SwitchToLibrarySquare"))) { _ in
                switchToTab(.square)
            }
            .onChange(of: viewModel.currentTab) { _, newTab in
                if let idx = allTabs.firstIndex(of: newTab), idx != tabIndex {
                    tabIndex = idx
                }
                if newTab == .square {
                    if viewModel.squareSource == .qq {
                        viewModel.fetchQQSquareData()
                    } else {
                        viewModel.fetchSquareData()
                    }
                } else if newTab == .artists {
                    if viewModel.artistSource == .qq {
                        viewModel.fetchQQArtistData()
                    } else {
                        viewModel.fetchArtistData()
                    }
                } else if newTab == .charts {
                    if viewModel.chartsSource == .qq {
                        viewModel.fetchQQTopLists()
                    } else {
                        viewModel.fetchTopLists()
                    }
                }
            }
        }
    }
    
    private func switchToTab(_ tab: LibraryViewModel.LibraryTab) {
        guard let idx = allTabs.firstIndex(of: tab) else { return }
        tabIndex = idx
        viewModel.currentTab = tab
    }

    private var headerView: some View {
        VStack(spacing: 20) {
            HStack {
                Text(LocalizedStringKey("tab_library"))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.text)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, DeviceLayout.headerTopPadding)

            // 标签栏 — 滑动下划线
            HStack(spacing: 0) {
                ForEach(Array(allTabs.enumerated()), id: \.element) { index, tab in
                    Button(action: {
                        switchToTab(tab)
                    }) {
                        VStack(spacing: 6) {
                            Text(tab.localizedKey)
                                .font(.system(size: 16, weight: tabIndex == index ? .bold : .medium, design: .rounded))
                                .foregroundColor(tabIndex == index ? Theme.text : Theme.secondaryText)
                                .animation(.none, value: tabIndex)

                            Capsule()
                                .fill(Theme.text)
                                .frame(width: 24, height: 3)
                                .opacity(tabIndex == index ? 1 : 0)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: tabIndex)
        }
        .padding(.bottom, 10)
        .background(
            Rectangle()
                .fill(Color.clear)
                .ignoresSafeArea()
        )
    }
}

// MARK: - Subviews

struct MyPlaylistsContainerView: View {
    @ObservedObject var viewModel: LibraryViewModel
    @State private var selectedSubTab: Int = 0
    typealias Theme = PlaylistDetailView.Theme

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                subTabButton(title: String(localized: "lib_netease_playlists"), index: 0)
                subTabButton(title: String(localized: "lib_local_playlists"), index: 1)
                subTabButton(title: String(localized: "lib_my_podcasts"), index: 2)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            ZStack {
                NetEasePlaylistsView(viewModel: viewModel)
                    .opacity(selectedSubTab == 0 ? 1 : 0)
                    .allowsHitTesting(selectedSubTab == 0)
                
                LocalPlaylistsView(viewModel: viewModel)
                    .opacity(selectedSubTab == 1 ? 1 : 0)
                    .allowsHitTesting(selectedSubTab == 1)
                
                MyPodcastsView()
                    .opacity(selectedSubTab == 2 ? 1 : 0)
                    .allowsHitTesting(selectedSubTab == 2)
            }
        }
        .background(Color.clear)
    }

    private func subTabButton(title: String, index: Int) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedSubTab = index
            }
        }) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 15, weight: selectedSubTab == index ? .bold : .medium, design: .rounded))
                    .foregroundColor(selectedSubTab == index ? Theme.text : Theme.secondaryText)
                    .animation(.none, value: selectedSubTab)

                Capsule()
                    .fill(selectedSubTab == index ? Theme.text : Color.clear)
                    .frame(width: 20, height: 3)
            }
            .padding(.trailing, 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 本地歌单列表

struct LocalPlaylistsView: View {
    @ObservedObject var viewModel: LibraryViewModel
    @ObservedObject private var manager = LocalPlaylistManager.shared
    @State private var showCreateAlert = false
    @State private var newPlaylistName = ""
    @State private var playlistToDelete: LocalPlaylist?
    @State private var showDeleteAlert = false
    @State private var showFileImporter = false
    @State private var isImporting = false
    @State private var importError: String?
    @State private var showImportError = false
    typealias Theme = PlaylistDetailView.Theme
    
    var body: some View {
        Group {
            if manager.playlists.isEmpty {
                ScrollView {
                    VStack(spacing: 16) {
                        AsideIcon(icon: .musicNoteList, size: 40, color: .asideTextSecondary.opacity(0.3))
                        Text(LocalizedStringKey("lib_no_local_playlists"))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.secondaryText)
                        
                        Button(action: { showCreateAlert = true }) {
                            HStack(spacing: 6) {
                                AsideIcon(icon: .add, size: 14, color: .asideIconForeground)
                                Text(LocalizedStringKey("lib_create_playlist"))
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(.asideIconForeground)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.asideIconBackground)
                            .cornerRadius(20)
                        }
                        .buttonStyle(AsideBouncingButtonStyle())
                        
                        Button(action: { showFileImporter = true }) {
                            HStack(spacing: 6) {
                                AsideIcon(icon: .download, size: 14, color: Theme.secondaryText)
                                Text(LocalizedStringKey("lib_import_playlist"))
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(Theme.secondaryText)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.asideGlassTint)
                            .cornerRadius(20)
                        }
                        .buttonStyle(AsideBouncingButtonStyle())
                    }
                    .padding(.top, 50)
                }
                .scrollIndicators(.hidden)
            } else {
                List {
                    // 新建歌单按钮
                    Button(action: { showCreateAlert = true }) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.asideIconBackground)
                                    .frame(width: 60, height: 60)
                                AsideIcon(icon: .add, size: 22, color: .asideIconForeground)
                            }
                            Text(LocalizedStringKey("lib_create_playlist"))
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.text)
                            Spacer()
                        }
                        .padding(16)
                        .glassEffect(.regular, in: .rect(cornerRadius: 20))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(AsideBouncingButtonStyle())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 24, bottom: 8, trailing: 24))
                    
                    // 导入歌单按钮
                    Button(action: { showFileImporter = true }) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.asideGlassTint)
                                    .frame(width: 60, height: 60)
                                AsideIcon(icon: .download, size: 22, color: Theme.secondaryText)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(LocalizedStringKey("lib_import_playlist"))
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.text)
                                Text(LocalizedStringKey("lib_import_from_json"))
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(Theme.secondaryText)
                            }
                            Spacer()
                            if isImporting {
                                ProgressView()
                            }
                        }
                        .padding(16)
                        .glassEffect(.regular, in: .rect(cornerRadius: 20))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(AsideBouncingButtonStyle())
                    .disabled(isImporting)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 24, bottom: 8, trailing: 24))
                    
                    ForEach(manager.playlists, id: \.id) { playlist in
                        ZStack {
                            NavigationLink(value: LibraryViewModel.NavigationDestination.localPlaylist(playlist.id)) {
                                EmptyView()
                            }
                            .opacity(0)
                            
                            LocalPlaylistRow(playlist: playlist)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                playlistToDelete = playlist
                                showDeleteAlert = true
                            } label: {
                                Label(String(localized: "lib_delete"), systemImage: "trash")
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 24, bottom: 8, trailing: 24))
                    }
                    
                    Color.clear.frame(height: 120)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
            }
        }
        .alert(String(localized: "lib_create_playlist"), isPresented: $showCreateAlert) {
            TextField(String(localized: "lib_playlist_name"), text: $newPlaylistName)
            Button(String(localized: "alert_cancel"), role: .cancel) { newPlaylistName = "" }
            Button(String(localized: "lib_create")) {
                guard !newPlaylistName.isEmpty else { return }
                manager.createPlaylist(name: newPlaylistName)
                newPlaylistName = ""
            }
        }
        .alert(String(localized: "lib_delete_playlist"), isPresented: $showDeleteAlert) {
            Button(String(localized: "alert_cancel"), role: .cancel) { playlistToDelete = nil }
            Button(String(localized: "lib_delete"), role: .destructive) {
                if let p = playlistToDelete {
                    withAnimation { manager.deletePlaylist(p) }
                }
                playlistToDelete = nil
            }
        } message: {
            if let p = playlistToDelete {
                Text(String(format: String(localized: "lib_confirm_delete"), p.name))
            }
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                importPlaylistFromFile(url: url)
            case .failure(let error):
                importError = error.localizedDescription
                showImportError = true
            }
        }
        .alert(String(localized: "lib_import_failed"), isPresented: $showImportError) {
            Button(String(localized: "lib_confirm"), role: .cancel) {}
        } message: {
            Text(importError ?? String(localized: "lib_unknown_error"))
        }
    }
    
    // MARK: - 导入逻辑
    
    private func importPlaylistFromFile(url: URL) {
        isImporting = true
        
        // 获取文件访问权限
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        
        do {
            let parsed = try LocalPlaylistManager.parseExportFile(url: url)
            let ids = parsed.songIds
            let name = parsed.name
            
            if ids.isEmpty {
                importError = String(localized: "lib_import_no_songs")
                showImportError = true
                isImporting = false
                return
            }
            
            // 分批获取歌曲详情（每批 50 首）
            Task {
                var allSongs: [Song] = []
                let batchSize = 50
                for i in stride(from: 0, to: ids.count, by: batchSize) {
                    let batch = Array(ids[i..<min(i + batchSize, ids.count)])
                    do {
                        let songs: [Song] = try await withCheckedThrowingContinuation { continuation in
                            var cancellable: AnyCancellable?
                            cancellable = APIService.shared.fetchSongDetails(ids: batch)
                                .sink(receiveCompletion: { completion in
                                    if case .failure(let error) = completion {
                                        continuation.resume(throwing: error)
                                    }
                                    cancellable?.cancel()
                                }, receiveValue: { songs in
                                    continuation.resume(returning: songs)
                                })
                        }
                        allSongs.append(contentsOf: songs)
                    } catch {
                        AppLogger.error("导入歌单批次获取失败: \(error)")
                    }
                }
                
                await MainActor.run {
                    if allSongs.isEmpty {
                        importError = String(localized: "lib_import_fetch_failed")
                        showImportError = true
                    } else {
                        manager.importPlaylist(name: name, songs: allSongs)
                    }
                    isImporting = false
                }
            }
        } catch {
            importError = error.localizedDescription
            showImportError = true
            isImporting = false
        }
    }
}

struct LocalPlaylistRow: View {
    let playlist: LocalPlaylist
    typealias Theme = PlaylistDetailView.Theme
    
    var body: some View {
        HStack(spacing: 16) {
            Group {
                if let url = playlist.displayCoverUrl {
                    CachedAsyncImage(url: url.sized(200)) {
                        localCoverPlaceholder
                    }
                    .aspectRatio(contentMode: .fill)
                } else {
                    localCoverPlaceholder
                }
            }
            .frame(width: 60, height: 60)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(playlist.name)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.text)
                    .lineLimit(1)
                
                Text(String(format: String(localized: "songs_count_format"), playlist.trackCount))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.secondaryText)
            }
            
            Spacer()
            
            AsideIcon(icon: .chevronRight, size: 14, color: Theme.secondaryText)
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
    
    private var localCoverPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.asideGlassTint)
            AsideIcon(icon: .musicNoteList, size: 24, color: .asideTextSecondary.opacity(0.3))
        }
    }
}

// MARK: - 我的播客（订阅的播客列表）

struct MyPodcastsView: View {
    typealias Theme = PlaylistDetailView.Theme
    @ObservedObject private var subManager = SubscriptionManager.shared
    @State private var radioToRemove: RadioStation?
    @State private var showUnsubAlert = false

    var body: some View {
        Group {
            if subManager.isLoadingRadios && subManager.subscribedRadios.isEmpty {
                ScrollView {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text(LocalizedStringKey("lib_loading"))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.secondaryText)
                    }
                    .padding(.top, 50)
                }
                .scrollIndicators(.hidden)
            } else if subManager.subscribedRadios.isEmpty {
                ScrollView {
                    VStack(spacing: 16) {
                        AsideIcon(icon: .radio, size: 40, color: .asideTextSecondary.opacity(0.3))
                        Text(LocalizedStringKey("lib_no_podcasts"))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.secondaryText)
                        Text(LocalizedStringKey("lib_discover_podcasts"))
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(Theme.secondaryText.opacity(0.6))
                    }
                    .padding(.top, 50)
                }
                .scrollIndicators(.hidden)
            } else {
                List {
                    ForEach(subManager.subscribedRadios) { radio in
                        ZStack {
                            NavigationLink(value: LibraryViewModel.NavigationDestination.radioDetail(radio.id)) {
                                EmptyView()
                            }
                            .opacity(0)
                            
                            podcastRow(radio: radio)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                radioToRemove = radio
                                showUnsubAlert = true
                            } label: {
                                Label(String(localized: "lib_unsubscribe"), systemImage: "heart.slash")
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                radioToRemove = radio
                                showUnsubAlert = true
                            } label: {
                                Label(String(localized: "lib_unsubscribe"), systemImage: "heart.slash")
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 24, bottom: 8, trailing: 24))
                    }

                    Color.clear.frame(height: 120)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .refreshable {
                    subManager.fetchSubscribedRadios()
                }
            }
        }
        .onAppear {
            if subManager.subscribedRadios.isEmpty {
                subManager.fetchSubscribedRadios()
            }
        }
        .alert(String(localized: "lib_unsubscribe"), isPresented: $showUnsubAlert) {
            Button(String(localized: "alert_cancel"), role: .cancel) {
                radioToRemove = nil
            }
            Button(String(localized: "lib_unsubscribe"), role: .destructive) {
                guard let radio = radioToRemove else { return }
                withAnimation {
                    subManager.unsubscribeRadio(radio) { _ in }
                }
                radioToRemove = nil
            }
        } message: {
            if let radio = radioToRemove {
                Text(String(format: String(localized: "lib_confirm_unsubscribe"), radio.name))
            }
        }
    }

    private func podcastRow(radio: RadioStation) -> some View {
        HStack(spacing: 14) {
            CachedAsyncImage(url: radio.coverUrl) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.asideGlassTint)
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(radio.name)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let dj = radio.dj?.nickname {
                        Text(dj)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.asideTextSecondary)
                    }
                    if let count = radio.programCount, count > 0 {
                        Text("·")
                            .foregroundColor(.asideTextSecondary)
                        Text(String(format: String(localized: "lib_episode_count"), count))
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.asideTextSecondary)
                    }
                }
            }

            Spacer()

            AsideIcon(icon: .chevronRight, size: 14, color: .asideTextSecondary)
        }
        .padding(.vertical, 6)
    }
}

struct NetEasePlaylistsView: View {
    @ObservedObject var viewModel: LibraryViewModel
    @ObservedObject private var subManager = SubscriptionManager.shared
    @State private var playlistToRemove: Playlist?
    @State private var showRemoveAlert = false
    @State private var isOwnPlaylist = false
    typealias Theme = PlaylistDetailView.Theme

    var body: some View {
        Group {
            if viewModel.userPlaylists.isEmpty {
                ScrollView {
                    VStack(spacing: 16) {
                        AsideIcon(icon: .musicNoteList, size: 40, color: .asideTextSecondary.opacity(0.3))
                        Text(LocalizedStringKey("library_playlists_empty"))
                            .font(.rounded(size: 14, weight: .medium))
                            .foregroundColor(.asideTextSecondary)
                    }
                    .padding(.top, 50)
                }
                .scrollIndicators(.hidden)
            } else {
                List {
                    ForEach(viewModel.userPlaylists) { playlist in
                        ZStack {
                            NavigationLink(value: LibraryViewModel.NavigationDestination.playlist(playlist)) {
                                EmptyView()
                            }
                            .opacity(0)
                            
                            LibraryPlaylistRow(playlist: playlist)
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                playlistToRemove = playlist
                                isOwnPlaylist = isUserCreated(playlist)
                                showRemoveAlert = true
                            } label: {
                                Label(isUserCreated(playlist) ? String(localized: "lib_delete_playlist") : String(localized: "lib_uncollect"),
                                      systemImage: isUserCreated(playlist) ? "trash" : "heart.slash")
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 24, bottom: 8, trailing: 24))
                    }

                    Color.clear.frame(height: 120)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .refreshable {
                    viewModel.fetchPlaylists(force: true)
                }
            }
        }
        .background(Color.clear)
        .onAppear {
            if viewModel.userPlaylists.isEmpty {
                viewModel.fetchPlaylists()
            }
        }
        .alert(isOwnPlaylist ? String(localized: "lib_delete_playlist") : String(localized: "lib_uncollect"), isPresented: $showRemoveAlert) {
            Button(String(localized: "alert_cancel"), role: .cancel) {
                playlistToRemove = nil
            }
            Button(isOwnPlaylist ? String(localized: "lib_delete") : String(localized: "lib_uncollect"), role: .destructive) {
                guard let playlist = playlistToRemove else { return }
                let playlistId = playlist.id
                // 立即从本地列表移除，不等网络返回
                withAnimation {
                    viewModel.userPlaylists.removeAll { $0.id == playlistId }
                }
                // 清除本地缓存
                OptimizedCacheManager.shared.setObject(viewModel.userPlaylists, forKey: "user_playlists")
                if isOwnPlaylist {
                    subManager.deletePlaylist(id: playlistId) { success in
                        if !success {
                            // 失败时重新拉取恢复
                            viewModel.fetchPlaylists(force: true)
                        }
                    }
                } else {
                    subManager.unsubscribePlaylist(id: playlistId) { success in
                        if !success {
                            viewModel.fetchPlaylists(force: true)
                        }
                    }
                }
                playlistToRemove = nil
            }
        } message: {
            if let playlist = playlistToRemove {
                Text(isOwnPlaylist ? String(format: String(localized: "lib_confirm_delete"), playlist.name) : String(format: String(localized: "lib_confirm_uncollect"), playlist.name))
            }
        }
    }

    /// 判断歌单是否为用户自己创建的
    private func isUserCreated(_ playlist: Playlist) -> Bool {
        guard let uid = APIService.shared.currentUserId,
              let creatorId = playlist.creator?.userId else {
            return false
        }
        return creatorId == uid
    }
}

// MARK: - 音源切换器

struct MusicSourcePicker: View {
    @Binding var source: LibraryViewModel.MusicSource
    @Namespace private var ns
    typealias Theme = PlaylistDetailView.Theme

    var body: some View {
        HStack(spacing: 4) {
            ForEach(LibraryViewModel.MusicSource.allCases, id: \.self) { s in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        source = s
                    }
                } label: {
                    Text(s == .ncm ? "网易云" : "QQ音乐")
                        .font(.system(size: 13, weight: source == s ? .bold : .medium, design: .rounded))
                        .foregroundColor(source == s ? .asideIconForeground : Theme.text.opacity(0.6))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background {
                            if source == s {
                                Capsule()
                                    .fill(Color.asideIconBackground)
                                    .matchedGeometryEffect(id: "sourcePill", in: ns)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.asideTextPrimary.opacity(0.06)))
    }
}

struct PlaylistSquareView: View {
    @ObservedObject var viewModel: LibraryViewModel
    typealias Theme = PlaylistDetailView.Theme
    @Namespace private var categoryNS

    private struct MosaicRow: Identifiable {
        let id: Int
        let playlists: [Playlist]
        let isWide: Bool
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                MusicSourcePicker(source: $viewModel.squareSource)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .onChange(of: viewModel.squareSource) { _, newSource in
                if newSource == .qq {
                    viewModel.fetchQQSquareData()
                } else {
                    viewModel.fetchSquareData()
                }
            }

            if viewModel.squareSource == .ncm {
                ncmContent
            } else {
                qqContent
            }
        }
        .background(Color.clear)
    }

    // MARK: - NCM Content

    private var ncmContent: some View {
        VStack(spacing: 0) {
            categoryBar

            ScrollView {
                if viewModel.isLoadingSquare && viewModel.squarePlaylists.isEmpty {
                    AsideLoadingView()
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(buildRows(from: viewModel.squarePlaylists)) { row in
                            if row.isWide, let playlist = row.playlists.first {
                                NavigationLink(value: LibraryViewModel.NavigationDestination.playlist(playlist)) {
                                    CinematicCard(playlist: playlist, height: 220)
                                }
                                .buttonStyle(CinematicPressStyle())
                                .modifier(CinematicStaggerIn(order: row.id))
                                .onAppear { loadMoreIfLast(playlist) }
                            } else {
                                HStack(spacing: 12) {
                                    ForEach(row.playlists) { p in
                                        NavigationLink(value: LibraryViewModel.NavigationDestination.playlist(p)) {
                                            CinematicCard(playlist: p, height: 175)
                                        }
                                        .buttonStyle(CinematicPressStyle())
                                        .onAppear { loadMoreIfLast(p) }
                                    }
                                }
                                .modifier(CinematicStaggerIn(order: row.id))
                            }
                        }

                        if viewModel.isLoadingMoreSquare && viewModel.hasMoreSquarePlaylists {
                            AsideLoadingView(centered: false).padding()
                        }
                        if !viewModel.hasMoreSquarePlaylists && !viewModel.squarePlaylists.isEmpty {
                            NoMoreDataView()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }

                Color.clear.frame(height: 120)
            }
            .scrollIndicators(.hidden)
            .scrollContentBackground(.hidden)
        }
    }

    // MARK: - QQ Content

    private var qqContent: some View {
        VStack(spacing: 0) {
            qqCategoryBar

            ScrollView {
                if viewModel.isLoadingQQSquare && viewModel.qqSquarePlaylists.isEmpty {
                    AsideLoadingView()
                } else if viewModel.qqSquarePlaylists.isEmpty {
                    VStack(spacing: 16) {
                        AsideIcon(icon: .musicNoteList, size: 50, color: Theme.secondaryText.opacity(0.5))
                        Text("暂无QQ音乐推荐歌单")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.secondaryText)
                    }
                    .padding(.top, 50)
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(buildRows(from: viewModel.qqSquarePlaylists)) { row in
                            if row.isWide, let playlist = row.playlists.first {
                                NavigationLink(value: LibraryViewModel.NavigationDestination.playlist(playlist)) {
                                    CinematicCard(playlist: playlist, height: 220)
                                }
                                .buttonStyle(CinematicPressStyle())
                                .modifier(CinematicStaggerIn(order: row.id))
                                .onAppear { loadMoreQQIfLast(playlist) }
                            } else {
                                HStack(spacing: 12) {
                                    ForEach(row.playlists) { p in
                                        NavigationLink(value: LibraryViewModel.NavigationDestination.playlist(p)) {
                                            CinematicCard(playlist: p, height: 175)
                                        }
                                        .buttonStyle(CinematicPressStyle())
                                        .onAppear { loadMoreQQIfLast(p) }
                                    }
                                }
                                .modifier(CinematicStaggerIn(order: row.id))
                            }
                        }

                        if viewModel.isLoadingMoreQQSquare && viewModel.hasMoreQQSquare {
                            AsideLoadingView(centered: false).padding()
                        }
                        if !viewModel.hasMoreQQSquare && !viewModel.qqSquarePlaylists.isEmpty {
                            NoMoreDataView()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }

                Color.clear.frame(height: 120)
            }
            .scrollIndicators(.hidden)
            .scrollContentBackground(.hidden)
            .refreshable {
                viewModel.refreshQQSquare()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    // MARK: - QQ Category Bar

    private var qqCategoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                let hiddenCategories: Set<String> = ["全部", "AI歌单", "私藏", "音乐人在听", "chill vibes", "AI 歌单"]
                ForEach(viewModel.qqPlaylistCategories.filter { !hiddenCategories.contains($0.name) }, id: \.id) { cat in
                    let selected = viewModel.selectedQQCategoryId == cat.id
                    Button {
                        guard !selected else { return }
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                            viewModel.selectQQCategory(id: cat.id, name: cat.name)
                        }
                    } label: {
                        Text(cat.name)
                            .font(.system(size: 14, weight: selected ? .bold : .medium, design: .rounded))
                            .foregroundColor(selected ? .asideIconForeground : Theme.text.opacity(0.6))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background {
                                if selected {
                                    Capsule()
                                        .fill(Color.asideIconBackground)
                                        .matchedGeometryEffect(id: "qqCatPill", in: categoryNS)
                                }
                            }
                            .background(Capsule().fill(Color.asideTextPrimary.opacity(selected ? 0 : 0.05)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }

    // MARK: - Animated Category Selector

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(viewModel.playlistCategories, id: \.idString) { cat in
                    let selected = viewModel.selectedCategory == cat.name
                    Button {
                        guard !selected else { return }
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                            viewModel.selectedCategory = cat.name
                            viewModel.loadSquarePlaylists(cat: cat.name, reset: true)
                        }
                    } label: {
                        Text(cat.name)
                            .font(.system(size: 14, weight: selected ? .bold : .medium, design: .rounded))
                            .foregroundColor(selected ? .asideIconForeground : Theme.text.opacity(0.6))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background {
                                if selected {
                                    Capsule()
                                        .fill(Color.asideIconBackground)
                                        .matchedGeometryEffect(id: "squareCatPill", in: categoryNS)
                                }
                            }
                            .background(Capsule().fill(Color.asideTextPrimary.opacity(selected ? 0 : 0.05)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }

    // MARK: - Mosaic Layout (Hero → Duo → Duo → repeat)

    private func buildRows(from items: [Playlist]) -> [MosaicRow] {
        var rows: [MosaicRow] = []
        var i = 0
        while i < items.count {
            if rows.count % 3 == 0 {
                rows.append(.init(id: rows.count, playlists: [items[i]], isWide: true))
                i += 1
            } else if i + 1 < items.count {
                rows.append(.init(id: rows.count, playlists: [items[i], items[i + 1]], isWide: false))
                i += 2
            } else {
                rows.append(.init(id: rows.count, playlists: [items[i]], isWide: true))
                i += 1
            }
        }
        return rows
    }

    private func loadMoreIfLast(_ playlist: Playlist) {
        if playlist.id == viewModel.squarePlaylists.last?.id {
            viewModel.loadMoreSquarePlaylists()
        }
    }

    private func loadMoreQQIfLast(_ playlist: Playlist) {
        if playlist.id == viewModel.qqSquarePlaylists.last?.id {
            viewModel.loadMoreQQSquarePlaylists()
        }
    }
}

// MARK: - Cinematic Full-Bleed Card

private struct CinematicCard: View {
    let playlist: Playlist
    let height: CGFloat

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            CachedAsyncImage(url: playlist.coverUrl?.sized(height > 200 ? 1200 : 800)) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.asideSeparator)
            }
            .aspectRatio(contentMode: .fill)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipped()

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.3),
                    .init(color: .black.opacity(0.25), location: 0.55),
                    .init(color: .black.opacity(0.82), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(playlist.name)
                        .font(.system(size: height > 200 ? 18 : 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .shadow(color: .black.opacity(0.5), radius: 4)

                    if let count = playlist.playCount, count > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 7))
                            Text(cinematicFormatCount(count))
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(.white.opacity(0.75))
                    }
                }

                Spacer()

                if height > 200 {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(13)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
    }
}

private func cinematicFormatCount(_ count: Int) -> String {
    let lang = Locale.current.language.languageCode?.identifier
    if lang == "zh" {
        if count >= 100_000_000 { return String(format: NSLocalizedString("count_hundred_million", comment: ""), Double(count) / 100_000_000) }
        if count >= 10_000 { return String(format: NSLocalizedString("count_ten_thousand", comment: ""), Double(count) / 10_000) }
    } else {
        if count >= 1_000_000_000 { return String(format: "%.1fB", Double(count) / 1_000_000_000) }
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000) }
    }
    return "\(count)"
}

// MARK: - Staggered Entrance Animation

private struct CinematicStaggerIn: ViewModifier {
    let order: Int
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 28)
            .scaleEffect(visible ? 1 : 0.92, anchor: .bottom)
            .onAppear {
                guard !visible else { return }
                let delay = order < 8 ? Double(order) * 0.065 : 0.03
                withAnimation(.spring(response: 0.55, dampingFraction: 0.8).delay(delay)) {
                    visible = true
                }
            }
    }
}

// MARK: - Cinematic Press Style

private struct CinematicPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct ArtistLibraryView: View {
    @ObservedObject var viewModel: LibraryViewModel
    @State private var showFilters = false
    @State private var showQQFilters = false
    typealias Theme = PlaylistDetailView.Theme

    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    private var hasActiveFilter: Bool {
        viewModel.artistArea != -1 || viewModel.artistType != -1 || viewModel.artistInitial != "-1"
    }

    private var hasActiveQQFilter: Bool {
        viewModel.qqArtistArea != .all || viewModel.qqArtistSex != .all || viewModel.qqArtistGenre != .all
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                MusicSourcePicker(source: $viewModel.artistSource)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)
            .onChange(of: viewModel.artistSource) { _, newSource in
                if newSource == .qq {
                    viewModel.fetchQQArtistData()
                } else {
                    viewModel.fetchArtistData()
                }
            }

            if viewModel.artistSource == .ncm {
                ncmArtistContent
            } else {
                qqArtistContent
            }
        }
        .background(Color.clear)
    }

    // MARK: - NCM Artists

    private var ncmArtistContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                HStack {
                    AsideIcon(icon: .magnifyingGlass, size: 18, color: Theme.secondaryText)

                    TextField(LocalizedStringKey("search_artists"), text: $viewModel.artistSearchText)
                        .font(.system(size: 16, design: .rounded))
                        .foregroundColor(Theme.text)
                        .onSubmit {
                            viewModel.fetchArtistData(reset: true)
                        }

                    if !viewModel.artistSearchText.isEmpty {
                        Button(action: {
                            viewModel.artistSearchText = ""
                            viewModel.fetchArtistData(reset: true)
                        }) {
                            AsideIcon(icon: .xmark, size: 18, color: Theme.secondaryText)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .glassEffect(.regular, in: .rect(cornerRadius: 20))
                
                if !viewModel.isSearchingArtists {
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showFilters.toggle()
                        }
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(hasActiveFilter ? Color.asideGlassTint : Color.clear)
                                .glassEffect(.regular, in: .rect(cornerRadius: 14))
                            
                            AsideIcon(
                                icon: .filter,
                                size: 18,
                                color: hasActiveFilter ? .asideIconForeground : Theme.secondaryText
                            )
                            .rotationEffect(.degrees(showFilters ? 90 : 0))
                        }
                        .frame(width: 46, height: 46)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(AsideBouncingButtonStyle())
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            .padding(.top, 8)

            if !viewModel.isSearchingArtists && showFilters {
                VStack(alignment: .leading, spacing: 12) {
                    ScrollView(.horizontal) {
                        filterRow(options: viewModel.artistAreas.map { ($0.name, $0.value) }, selected: $viewModel.artistArea) {
                            viewModel.fetchArtistData(reset: true)
                        }
                        .padding(.horizontal, 24)
                    }
                    .scrollIndicators(.hidden)
                    ScrollView(.horizontal) {
                        filterRow(options: viewModel.artistTypes.map { ($0.name, $0.value) }, selected: $viewModel.artistType) {
                            viewModel.fetchArtistData(reset: true)
                        }
                        .padding(.horizontal, 24)
                    }
                    .scrollIndicators(.hidden)
                    ScrollView(.horizontal) {
                        filterRow(options: viewModel.artistInitials.map { ($0 == "-1" ? "search_hot" : $0, $0) }, selected: $viewModel.artistInitial) {
                            viewModel.fetchArtistData(reset: true)
                        }
                        .padding(.horizontal, 24)
                    }
                    .scrollIndicators(.hidden)
                }
                .padding(.bottom, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            artistGrid(
                artists: viewModel.topArtists,
                isLoading: viewModel.isLoadingArtists,
                hasMore: viewModel.hasMoreArtists,
                isSearching: viewModel.isSearchingArtists
            ) { index in
                if index == viewModel.topArtists.count - 1 && !viewModel.isSearchingArtists {
                    viewModel.loadMoreArtists()
                }
            }
        }
    }

    // MARK: - QQ Artists

    private var qqArtistContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                HStack {
                    AsideIcon(icon: .magnifyingGlass, size: 18, color: Theme.secondaryText)

                    TextField("搜索QQ音乐歌手", text: $viewModel.qqArtistSearchText)
                        .font(.system(size: 16, design: .rounded))
                        .foregroundColor(Theme.text)

                    if !viewModel.qqArtistSearchText.isEmpty {
                        Button(action: {
                            viewModel.qqArtistSearchText = ""
                        }) {
                            AsideIcon(icon: .xmark, size: 18, color: Theme.secondaryText)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .glassEffect(.regular, in: .rect(cornerRadius: 20))

                if !viewModel.isSearchingQQArtists {
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showQQFilters.toggle()
                        }
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(hasActiveQQFilter ? Color.asideGlassTint : Color.clear)
                                .glassEffect(.regular, in: .rect(cornerRadius: 14))
                            
                            AsideIcon(
                                icon: .filter,
                                size: 18,
                                color: hasActiveQQFilter ? .asideIconForeground : Theme.secondaryText
                            )
                            .rotationEffect(.degrees(showQQFilters ? 90 : 0))
                        }
                        .frame(width: 46, height: 46)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(AsideBouncingButtonStyle())
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            .padding(.top, 8)

            if !viewModel.isSearchingQQArtists && showQQFilters {
                VStack(alignment: .leading, spacing: 12) {
                    ScrollView(.horizontal) {
                        qqFilterRow(options: viewModel.qqArtistAreas, selected: $viewModel.qqArtistArea)
                            .padding(.horizontal, 24)
                    }
                    .scrollIndicators(.hidden)
                    ScrollView(.horizontal) {
                        qqFilterRow(options: viewModel.qqArtistSexes, selected: $viewModel.qqArtistSex)
                            .padding(.horizontal, 24)
                    }
                    .scrollIndicators(.hidden)
                    ScrollView(.horizontal) {
                        qqFilterRow(options: viewModel.qqArtistGenres, selected: $viewModel.qqArtistGenre)
                            .padding(.horizontal, 24)
                    }
                    .scrollIndicators(.hidden)
                }
                .padding(.bottom, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            artistGrid(
                artists: viewModel.qqArtists,
                isLoading: viewModel.isLoadingQQArtists,
                hasMore: viewModel.hasMoreQQArtists,
                isSearching: viewModel.isSearchingQQArtists
            ) { index in
                if index == viewModel.qqArtists.count - 1 {
                    viewModel.loadMoreQQArtists()
                }
            }
        }
    }

    // MARK: - Shared Artist Grid

    private func artistGrid(
        artists: [ArtistInfo],
        isLoading: Bool,
        hasMore: Bool,
        isSearching: Bool,
        onAppear: @escaping (Int) -> Void
    ) -> some View {
        ScrollView {
            if isLoading && artists.isEmpty {
                AsideLoadingView()
            } else if artists.isEmpty {
                VStack(spacing: 16) {
                    AsideIcon(icon: .personEmpty, size: 50, color: Theme.secondaryText.opacity(0.5))
                    Text(LocalizedStringKey("empty_no_artists"))
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.secondaryText)
                }
                .padding(.top, 50)
            } else {
                LazyVGrid(columns: columns, spacing: 24) {
                    ForEach(Array(artists.enumerated()), id: \.element.id) { index, artist in
                        NavigationLink(value: LibraryViewModel.NavigationDestination.artistInfo(artist)) {
                            VStack(spacing: 12) {
                                CachedAsyncImage(url: artist.coverUrl?.sized(400)) {
                                    Color.gray.opacity(0.1)
                                }
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)

                                Text(artist.name)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .lineLimit(1)
                                    .foregroundColor(Theme.text)
                            }
                        }
                        .buttonStyle(AsideBouncingButtonStyle(scale: 0.9))
                        .onAppear { onAppear(index) }
                    }
                }
                .padding(24)

                if hasMore && !isSearching {
                    AsideLoadingView().padding()
                }
                if !hasMore && !artists.isEmpty && !isSearching {
                    NoMoreDataView()
                }
            }

            Color.clear.frame(height: 120)
        }
        .scrollIndicators(.hidden)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }

    // MARK: - Filter Rows

    private func filterRow<T: Equatable>(options: [(String, T)], selected: Binding<T>, onChange: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            ForEach(options, id: \.0) { option in
                Button(action: {
                    if selected.wrappedValue != option.1 {
                        selected.wrappedValue = option.1
                        onChange()
                    }
                }) {
                    Text(LocalizedStringKey(option.0))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selected.wrappedValue == option.1 ? Color.asideIconBackground : Color.asideGlassTint)
                                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                        )
                        .foregroundColor(selected.wrappedValue == option.1 ? .asideIconForeground : Theme.text)
                }
                .buttonStyle(AsideBouncingButtonStyle())
            }
        }
    }

    private func qqFilterRow<T: Equatable>(options: [(name: String, value: T)], selected: Binding<T>) -> some View {
        HStack(spacing: 12) {
            ForEach(options, id: \.name) { option in
                Button(action: {
                    if selected.wrappedValue != option.value {
                        selected.wrappedValue = option.value
                        viewModel.fetchQQArtistData(reset: true)
                    }
                }) {
                    Text(LocalizedStringKey(option.name))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selected.wrappedValue == option.value ? Color.asideIconBackground : Color.asideGlassTint)
                                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                        )
                        .foregroundColor(selected.wrappedValue == option.value ? .asideIconForeground : Theme.text)
                }
                .buttonStyle(AsideBouncingButtonStyle())
            }
        }
    }
}

struct ChartsLibraryView: View {
    @ObservedObject var viewModel: LibraryViewModel
    typealias Theme = PlaylistDetailView.Theme

    private let officialIds: Set<Int> = [19723756, 3779629, 2884035, 3778678]

    private var officialCharts: [TopList] {
        viewModel.topLists.filter { officialIds.contains($0.id) }
    }

    private var otherCharts: [TopList] {
        viewModel.topLists.filter { !officialIds.contains($0.id) }
    }

    let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // HStack {
            //     MusicSourcePicker(source: $viewModel.chartsSource)
            //     Spacer()
            // }
            // .padding(.horizontal, 24)
            // .padding(.top, 4)
            // .onChange(of: viewModel.chartsSource) { _, newSource in
            //     if newSource == .qq {
            //         viewModel.fetchQQTopLists()
            //     } else {
            //         viewModel.fetchTopLists()
            //     }
            // }

            // 暂时隐藏 QQ 榜单选项，直接强制显示 NCM
            ncmChartsContent
        }
        .background(Color.clear)
    }

    // MARK: - NCM Charts

    private var ncmChartsContent: some View {
        ScrollView {
            if viewModel.isLoadingCharts && viewModel.topLists.isEmpty {
                AsideLoadingView()
            } else if viewModel.topLists.isEmpty {
                VStack(spacing: 16) {
                    AsideIcon(icon: .chart, size: 50, color: Theme.secondaryText.opacity(0.5))
                    Text(LocalizedStringKey("empty_no_charts"))
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.secondaryText)
                }
                .padding(.top, 50)
            } else {
                VStack(alignment: .leading, spacing: 28) {
                    if !officialCharts.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(LocalizedStringKey("charts_official"))
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.text)
                                .padding(.horizontal, 24)

                            ScrollView(.horizontal) {
                                HStack(spacing: 14) {
                                    ForEach(officialCharts) { list in
                                        NavigationLink(value: chartDestination(list)) {
                                            OfficialChartCard(list: list)
                                        }
                                        .buttonStyle(AsideBouncingButtonStyle(scale: 0.96))
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                            .scrollIndicators(.hidden)
                        }
                    }

                    if !otherCharts.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(LocalizedStringKey("charts_more"))
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.text)
                                .padding(.horizontal, 24)

                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(otherCharts) { list in
                                    NavigationLink(value: chartDestination(list)) {
                                        CompactChartCard(list: list)
                                    }
                                    .buttonStyle(AsideBouncingButtonStyle(scale: 0.95))
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                }
                .padding(.top, 8)
            }

            Color.clear.frame(height: 120)
        }
        .scrollIndicators(.hidden)
        .scrollContentBackground(.hidden)
        .refreshable {
            await refreshCharts()
        }
    }

    // MARK: - QQ Charts

    private var qqChartsContent: some View {
        ScrollView {
            if viewModel.isLoadingQQCharts && viewModel.qqTopLists.isEmpty {
                AsideLoadingView()
            } else if viewModel.qqTopLists.isEmpty {
                VStack(spacing: 16) {
                    AsideIcon(icon: .chart, size: 50, color: Theme.secondaryText.opacity(0.5))
                    Text("暂无QQ音乐排行榜")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.secondaryText)
                }
                .padding(.top, 50)
            } else {
                VStack(alignment: .leading, spacing: 28) {
                    ForEach(viewModel.qqTopLists) { group in
                        VStack(alignment: .leading, spacing: 14) {
                            Text(group.groupName)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.text)
                                .padding(.horizontal, 24)

                            if group.groupId == 0 || group.items.count <= 4 {
                                // 官方榜：横向大卡片
                                ScrollView(.horizontal) {
                                    HStack(spacing: 14) {
                                        ForEach(group.items) { item in
                                            NavigationLink(value: qqChartDestination(item)) {
                                                QQOfficialChartCard(item: item)
                                            }
                                            .buttonStyle(AsideBouncingButtonStyle(scale: 0.96))
                                        }
                                    }
                                    .padding(.horizontal, 24)
                                }
                                .scrollIndicators(.hidden)
                            } else {
                                // 其他榜：三列网格
                                LazyVGrid(columns: columns, spacing: 16) {
                                    ForEach(group.items) { item in
                                        NavigationLink(value: qqChartDestination(item)) {
                                            QQChartCard(item: item)
                                        }
                                        .buttonStyle(AsideBouncingButtonStyle(scale: 0.95))
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                    }
                }
                .padding(.top, 8)
            }

            Color.clear.frame(height: 120)
        }
        .scrollIndicators(.hidden)
        .scrollContentBackground(.hidden)
        .refreshable {
            await refreshQQCharts()
        }
    }

    // MARK: - Helpers

    private func chartDestination(_ list: TopList) -> LibraryViewModel.NavigationDestination {
        .playlist(Playlist(
            id: list.id, name: list.name, coverImgUrl: list.coverImgUrl,
            picUrl: nil, trackCount: nil, playCount: nil,
            subscribedCount: nil, shareCount: nil, commentCount: nil,
            creator: nil, description: nil, tags: nil
        ))
    }

    private func qqChartDestination(_ item: QQTopListItem) -> LibraryViewModel.NavigationDestination {
        .playlist(Playlist(
            id: item.topId, name: item.title, coverImgUrl: item.coverUrl,
            picUrl: nil, trackCount: nil, playCount: nil,
            subscribedCount: nil, shareCount: nil, commentCount: nil,
            creator: nil, description: item.intro.isEmpty ? nil : item.intro,
            tags: nil, source: .qqmusic, isTopList: true
        ))
    }

    private func refreshCharts() async {
        viewModel.topLists = []
        viewModel.isLoadingCharts = true
        OptimizedCacheManager.shared.setObject([TopList](), forKey: "top_charts_lists")
        viewModel.fetchTopLists()
        try? await Task.sleep(nanoseconds: 1_500_000_000)
    }

    private func refreshQQCharts() async {
        viewModel.qqTopLists = []
        viewModel.isLoadingQQCharts = true
        OptimizedCacheManager.shared.setObject([QQTopListGroup](), forKey: "qq_top_charts")
        viewModel.fetchQQTopLists()
        try? await Task.sleep(nanoseconds: 1_500_000_000)
    }
}

// MARK: - QQ 排行榜卡片

private struct QQChartCard: View {
    let item: QQTopListItem
    typealias Theme = PlaylistDetailView.Theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let url = item.coverURL {
                CachedAsyncImage(url: url) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.asideSeparator)
                }
                .aspectRatio(1, contentMode: .fill)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.asideSeparator)
                    .aspectRatio(1, contentMode: .fill)
            }

            Text(item.title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(Theme.text)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            if !item.intro.isEmpty {
                Text(item.intro)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.secondaryText)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - QQ 官方排行榜大卡片

private struct QQOfficialChartCard: View {
    let item: QQTopListItem
    typealias Theme = PlaylistDetailView.Theme

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let url = item.coverURL {
                CachedAsyncImage(url: url) {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.asideSeparator)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 200, height: 200)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.asideSeparator)
                    .frame(width: 200, height: 200)
            }

            VStack(alignment: .leading, spacing: 4) {
                Spacer()
                Text(item.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                if !item.intro.isEmpty {
                    Text(item.intro)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
            }
            .padding(14)
            .frame(width: 200, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            )
        }
        .frame(width: 200, height: 200)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

// MARK: - 官方榜单大卡片

private struct OfficialChartCard: View {
    let list: TopList
    typealias Theme = PlaylistDetailView.Theme

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            CachedAsyncImage(url: list.coverUrl?.sized(600)) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.asideSeparator)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 200, height: 200)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            // 底部渐变遮罩 + 文字
            VStack(alignment: .leading, spacing: 4) {
                Spacer()
                Text(list.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(list.updateFrequency)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(14)
            .frame(width: 200, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            )
        }
        .frame(width: 200, height: 200)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

// MARK: - 紧凑榜单卡片

private struct CompactChartCard: View {
    let list: TopList
    typealias Theme = PlaylistDetailView.Theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CachedAsyncImage(url: list.coverUrl?.sized(400)) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.asideSeparator)
            }
            .aspectRatio(1, contentMode: .fill)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)

            Text(list.name)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(Theme.text)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Text(list.updateFrequency)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(Theme.secondaryText)
        }
    }
}

// MARK: - Components

struct LibraryPlaylistRow: View {
    let playlist: Playlist
    typealias Theme = PlaylistDetailView.Theme

    var body: some View {
        HStack(spacing: 16) {
            CachedAsyncImage(url: playlist.coverUrl?.sized(200)) {
                Color.gray.opacity(0.1)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 60, height: 60)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)

            VStack(alignment: .leading, spacing: 6) {
                Text(playlist.name)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.text)
                    .lineLimit(1)

                Text(String(format: NSLocalizedString("track_count_songs", comment: ""), playlist.trackCount ?? 0))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.secondaryText)
            }

            Spacer()

            AsideIcon(icon: .chevronRight, size: 14, color: Theme.secondaryText)
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
