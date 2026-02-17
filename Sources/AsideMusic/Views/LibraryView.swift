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
            .navigationBarHidden(true)
            .navigationDestination(for: LibraryViewModel.NavigationDestination.self) { destination in
                switch destination {
                case .playlist(let playlist):
                    PlaylistDetailView(playlist: playlist)
                case .artist(let id):
                    ArtistDetailView(artistId: id)
                case .artistInfo(let artist):
                    ArtistDetailView(artistId: artist.id)
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
                // 外部改变 currentTab 时同步 tabIndex
                if let idx = allTabs.firstIndex(of: newTab), idx != tabIndex {
                    tabIndex = idx
                }
                if newTab == .square {
                    viewModel.fetchSquareData()
                } else if newTab == .artists {
                    viewModel.fetchArtistData()
                } else if newTab == .charts {
                    viewModel.fetchTopLists()
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

            // 标签栏 — 用下划线位置偏移替代 matchedGeometryEffect
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
                                .fill(tabIndex == index ? Theme.text : Color.clear)
                                .frame(height: 3)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
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
                ScrollView(showsIndicators: false) {
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
                            .background(Color.asideCardBackground)
                            .cornerRadius(20)
                        }
                        .buttonStyle(AsideBouncingButtonStyle())
                    }
                    .padding(.top, 50)
                }
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
                        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.ultraThinMaterial).overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.asideGlassOverlay)).shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2))
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
                                    .fill(Color.asideCardBackground)
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
                        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.ultraThinMaterial).overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.asideGlassOverlay)).shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(AsideBouncingButtonStyle())
                    .disabled(isImporting)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 24, bottom: 8, trailing: 24))
                    
                    ForEach(manager.playlists, id: \.id) { playlist in
                        NavigationLink(value: LibraryViewModel.NavigationDestination.localPlaylist(playlist.id)) {
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
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.ultraThinMaterial).overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.asideGlassOverlay)).shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
    
    private var localCoverPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.asideCardBackground)
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
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text(LocalizedStringKey("lib_loading"))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.secondaryText)
                    }
                    .padding(.top, 50)
                }
            } else if subManager.subscribedRadios.isEmpty {
                ScrollView(showsIndicators: false) {
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
            } else {
                List {
                    ForEach(subManager.subscribedRadios) { radio in
                        NavigationLink(value: LibraryViewModel.NavigationDestination.radioDetail(radio.id)) {
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
                        .listRowInsets(EdgeInsets(top: 2, leading: 24, bottom: 2, trailing: 24))
                    }

                    Color.clear.frame(height: 120)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
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
                    .fill(Color.asideCardBackground)
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

            AsideIcon(icon: .chevronRight, size: 12, color: .asideTextSecondary)
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
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        AsideIcon(icon: .musicNoteList, size: 40, color: .asideTextSecondary.opacity(0.3))
                        Text(LocalizedStringKey("library_playlists_empty"))
                            .font(.rounded(size: 14, weight: .medium))
                            .foregroundColor(.asideTextSecondary)
                    }
                    .padding(.top, 50)
                }
            } else {
                List {
                    ForEach(viewModel.userPlaylists) { playlist in
                        NavigationLink(value: LibraryViewModel.NavigationDestination.playlist(playlist)) {
                            LibraryPlaylistRow(playlist: playlist)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                playlistToRemove = playlist
                                isOwnPlaylist = isUserCreated(playlist)
                                showRemoveAlert = true
                            } label: {
                                Label(isUserCreated(playlist) ? String(localized: "lib_delete") : String(localized: "lib_uncollect"),
                                      systemImage: isUserCreated(playlist) ? "trash" : "heart.slash")
                            }
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
                .refreshable {
                    viewModel.fetchPlaylists(force: true)
                }
            }
        }
        .background(Color.clear)
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

struct PlaylistSquareView: View {
    @ObservedObject var viewModel: LibraryViewModel
    typealias Theme = PlaylistDetailView.Theme

    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.playlistCategories, id: \.idString) { cat in
                        Button(action: {
                            if viewModel.selectedCategory != cat.name {
                                viewModel.selectedCategory = cat.name
                                viewModel.loadSquarePlaylists(cat: cat.name, reset: true)
                            }
                        }) {
                            Text(cat.name)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(viewModel.selectedCategory == cat.name ? Color.asideIconBackground : Color.asideCardBackground)
                                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                                )
                                .foregroundColor(viewModel.selectedCategory == cat.name ? .asideIconForeground : Theme.text)
                        }
                        .buttonStyle(AsideBouncingButtonStyle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .scrollContentBackground(.hidden)

            ScrollView(showsIndicators: false) {
                if viewModel.isLoadingSquare && viewModel.squarePlaylists.isEmpty {
                    AsideLoadingView()
                } else {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(Array(viewModel.squarePlaylists.enumerated()), id: \.element.id) { index, playlist in
                            NavigationLink(value: LibraryViewModel.NavigationDestination.playlist(playlist)) {
                                PlaylistVerticalCard(playlist: playlist)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(AsideBouncingButtonStyle(scale: 0.96))
                            .onAppear {
                                if index == viewModel.squarePlaylists.count - 1 {
                                    viewModel.loadMoreSquarePlaylists()
                                }
                            }
                        }
                    }
                    .padding(24)

                    if viewModel.isLoadingMoreSquare && viewModel.hasMoreSquarePlaylists {
                        AsideLoadingView(centered: false)
                            .padding()
                    }
                    if !viewModel.hasMoreSquarePlaylists && !viewModel.squarePlaylists.isEmpty {
                        NoMoreDataView()
                    }
                }

                Color.clear.frame(height: 120)
            }
            .scrollContentBackground(.hidden)
        }
        .background(Color.clear)
    }
}

struct ArtistLibraryView: View {
    @ObservedObject var viewModel: LibraryViewModel
    @State private var showFilters = false
    typealias Theme = PlaylistDetailView.Theme

    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    /// 是否有非默认筛选条件（用于高亮筛选按钮）
    private var hasActiveFilter: Bool {
        viewModel.artistArea != -1 || viewModel.artistType != -1 || viewModel.artistInitial != "-1"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                HStack {
                    AsideIcon(icon: .magnifyingGlass, size: 18, color: Theme.secondaryText)

                    TextField(LocalizedStringKey("search_artists"), text: $viewModel.artistSearchText)
                        .font(.system(size: 16, design: .rounded))
                        .foregroundColor(Theme.text)

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
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.ultraThinMaterial).overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.asideGlassOverlay)).shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2))
                
                // 筛选抽屉按钮
                if !viewModel.isSearchingArtists {
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showFilters.toggle()
                        }
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(hasActiveFilter ? Color.asideIconBackground : Color.clear)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.asideGlassOverlay))
                                )
                                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                            
                            AsideIcon(
                                icon: .filter,
                                size: 18,
                                color: hasActiveFilter ? .asideIconForeground : Theme.secondaryText
                            )
                            .rotationEffect(.degrees(showFilters ? 180 : 0))
                        }
                        .frame(width: 46, height: 46)
                    }
                    .buttonStyle(AsideBouncingButtonStyle())
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            .padding(.top, 8)

            if !viewModel.isSearchingArtists && showFilters {
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        filterRow(options: viewModel.artistAreas.map { ($0.name, $0.value) }, selected: $viewModel.artistArea)
                        filterRow(options: viewModel.artistTypes.map { ($0.name, $0.value) }, selected: $viewModel.artistType)
                        filterRow(options: viewModel.artistInitials.map { ($0 == "-1" ? "search_hot" : $0, $0) }, selected: $viewModel.artistInitial)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }
                .scrollContentBackground(.hidden)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            ScrollView(showsIndicators: false) {
                if viewModel.isLoadingArtists && viewModel.topArtists.isEmpty {
                    AsideLoadingView()
                } else if viewModel.topArtists.isEmpty {
                    VStack(spacing: 16) {
                        AsideIcon(icon: .personEmpty, size: 50, color: Theme.secondaryText.opacity(0.5))
                        Text(LocalizedStringKey("empty_no_artists"))
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.secondaryText)
                    }
                    .padding(.top, 50)
                } else {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(Array(viewModel.topArtists.enumerated()), id: \.element.id) { index, artist in
                            NavigationLink(value: LibraryViewModel.NavigationDestination.artist(artist.id)) {
                                VStack(spacing: 12) {
                                    CachedAsyncImage(url: artist.coverUrl?.sized(400)) {
                                        Color.gray.opacity(0.1)
                                    }
                                    .aspectRatio(contentMode: .fill)
                                    .clipShape(Circle())
                                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)

                                    Text(artist.name)
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .lineLimit(1)
                                        .foregroundColor(Theme.text)
                                }
                            }
                            .buttonStyle(AsideBouncingButtonStyle(scale: 0.9))
                            .onAppear {
                                if index == viewModel.topArtists.count - 1 && !viewModel.isSearchingArtists {
                                    viewModel.loadMoreArtists()
                                }
                            }
                        }
                    }
                    .padding(24)

                    if viewModel.hasMoreArtists && !viewModel.isSearchingArtists {
                        AsideLoadingView()
                            .padding()
                    }
                    if !viewModel.hasMoreArtists && !viewModel.topArtists.isEmpty && !viewModel.isSearchingArtists {
                        NoMoreDataView()
                    }
                }

                Color.clear.frame(height: 120)
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        }
        .background(Color.clear)
    }

    private func filterRow<T: Equatable>(options: [(String, T)], selected: Binding<T>) -> some View {
        HStack(spacing: 12) {
            ForEach(options, id: \.0) { option in
                Button(action: {
                    if selected.wrappedValue != option.1 {
                        selected.wrappedValue = option.1
                        viewModel.fetchArtistData(reset: true)
                    }
                }) {
                    Text(LocalizedStringKey(option.0))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selected.wrappedValue == option.1 ? Color.asideIconBackground : Color.asideCardBackground)
                                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                        )
                        .foregroundColor(selected.wrappedValue == option.1 ? .asideIconForeground : Theme.text)
                }
                .buttonStyle(AsideBouncingButtonStyle())
            }
        }
    }
}

struct ChartsLibraryView: View {
    @ObservedObject var viewModel: LibraryViewModel
    typealias Theme = PlaylistDetailView.Theme

    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
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
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(viewModel.topLists) { list in
                        NavigationLink(value: LibraryViewModel.NavigationDestination.playlist(Playlist(id: list.id, name: list.name, coverImgUrl: list.coverImgUrl, picUrl: nil, trackCount: nil, playCount: nil, subscribedCount: nil, shareCount: nil, commentCount: nil, creator: nil, description: nil, tags: nil))) {
                            VStack(alignment: .leading, spacing: 8) {
                                CachedAsyncImage(url: list.coverUrl?.sized(400)) {
                                    Color.gray.opacity(0.1)
                                }
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 110)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)

                                Text(list.name)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(Theme.text)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)

                                Text(list.updateFrequency)
                                    .font(.system(size: 10, design: .rounded))
                                    .foregroundColor(Theme.secondaryText)
                            }
                        }
                        .buttonStyle(AsideBouncingButtonStyle(scale: 0.95))
                    }
                }
                .padding(24)
            }

            Color.clear.frame(height: 120)
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
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
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.ultraThinMaterial).overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.asideGlassOverlay)).shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
