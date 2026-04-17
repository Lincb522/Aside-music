import SwiftUI
import Combine
import UniformTypeIdentifiers
import QQMusicKit

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
                MonologueBackground()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    libraryHeaderView

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
            .onAppear {
                if UserDefaults.standard.bool(forKey: "pendingLibrarySquareSwitch") {
                    UserDefaults.standard.set(false, forKey: "pendingLibrarySquareSwitch")
                    switchToTab(.square)
                }
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

    private var libraryHeaderView: some View {
        VStack(spacing: 14) {
            Text(LocalizedStringKey("tabbar_library"))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)

            libraryTabPicker
        }
        .padding(.top, DeviceLayout.headerTopPadding)
        .padding(.bottom, 8)
    }

    private var libraryTabPicker: some View {
        HStack(spacing: 0) {
            ForEach(Array(allTabs.enumerated()), id: \.element) { index, tab in
                Button(action: {
                    switchToTab(tab)
                }) {
                    VStack(spacing: 5) {
                        Text(tab.localizedKey)
                            .font(.system(size: 15, weight: tabIndex == index ? .bold : .medium, design: .rounded))
                            .foregroundColor(tabIndex == index ? Theme.text : Theme.secondaryText.opacity(0.7))
                            .animation(.none, value: tabIndex)

                        Capsule()
                            .fill(Theme.text)
                            .frame(width: 20, height: 2.5)
                            .opacity(tabIndex == index ? 1 : 0)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DeviceLayout.isPad ? 24 : 16)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: tabIndex)
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
                subTabButton(title: String(localized: "lib_local_playlists"), index: 0)
                subTabButton(title: String(localized: "lib_netease_playlists"), index: 1)
                subTabButton(title: String(localized: "QCM歌单"), index: 2)
                subTabButton(title: String(localized: "lib_my_podcasts"), index: 3)
                Spacer()
            }
            .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
            .padding(.bottom, 14)

            ZStack {
                LocalPlaylistsView(viewModel: viewModel)
                    .opacity(selectedSubTab == 0 ? 1 : 0)
                    .allowsHitTesting(selectedSubTab == 0)
                
                NetEasePlaylistsView(viewModel: viewModel)
                    .opacity(selectedSubTab == 1 ? 1 : 0)
                    .allowsHitTesting(selectedSubTab == 1)
                
                QQPlaylistsView(viewModel: viewModel)
                    .opacity(selectedSubTab == 2 ? 1 : 0)
                    .allowsHitTesting(selectedSubTab == 2)
                
                MyPodcastsView()
                    .opacity(selectedSubTab == 3 ? 1 : 0)
                    .allowsHitTesting(selectedSubTab == 3)
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
            VStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 13, weight: selectedSubTab == index ? .bold : .medium, design: .rounded))
                    .foregroundColor(selectedSubTab == index ? Theme.text : Theme.secondaryText.opacity(0.7))
                    .animation(.none, value: selectedSubTab)

                Capsule()
                    .fill(selectedSubTab == index ? Theme.text : Color.clear)
                    .frame(width: 16, height: 2)
            }
            .padding(.trailing, 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 本地歌单列表

struct LocalPlaylistsView: View {
    @ObservedObject var viewModel: LibraryViewModel
    @ObservedObject private var manager = LocalPlaylistManager.shared
    @State private var showFileImporter = false
    @State private var showQQImport = false
    @State private var isImporting = false
    typealias Theme = PlaylistDetailView.Theme
    
    var body: some View {
        Group {
            if manager.playlists.isEmpty {
                ScrollView {
                    VStack(spacing: 16) {
                        MonologueIcon(icon: .musicNoteList, size: 40, color: .monologueTextSecondary.opacity(0.3))
                        Text(LocalizedStringKey("lib_no_local_playlists"))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.secondaryText)
                        
                        Button(action: {
                            AlertManager.shared.showInput(
                                title: String(localized: "lib_create_playlist"),
                                message: "",
                                placeholder: String(localized: "lib_playlist_name"),
                                primaryButtonTitle: String(localized: "lib_create"),
                                secondaryButtonTitle: String(localized: "alert_cancel"),
                                onConfirm: { name in
                                    guard !name.isEmpty else { return }
                                    manager.createPlaylist(name: name)
                                }
                            )
                        }) {
                            HStack(spacing: 6) {
                                MonologueIcon(icon: .add, size: 14, color: .monologueIconForeground)
                                Text(LocalizedStringKey("lib_create_playlist"))
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(.monologueIconForeground)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.monologueIconBackground)
                            .cornerRadius(20)
                        }
                        .buttonStyle(MonologueBouncingButtonStyle())
                        
                        Button(action: { showFileImporter = true }) {
                            HStack(spacing: 6) {
                                MonologueIcon(icon: .download, size: 14, color: Theme.secondaryText)
                                Text(LocalizedStringKey("lib_import_playlist"))
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(Theme.secondaryText)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.monologueGlassTint)
                            .cornerRadius(20)
                        }
                        .buttonStyle(MonologueBouncingButtonStyle())
                        
                        Button(action: {
                            AlertManager.shared.showInput(
                                title: String(localized: "从链接导入歌单"),
                                message: String(localized: "支持 QCM、NCM 的歌单分享链接"),
                                placeholder: String(localized: "粘贴歌单链接"),
                                primaryButtonTitle: String(localized: "导入"),
                                secondaryButtonTitle: String(localized: "取消"),
                                onConfirm: { url in
                                    self.importPlaylistFromURL(url)
                                }
                            )
                        }) {
                            HStack(spacing: 6) {
                                MonologueIcon(icon: .share, size: 14, color: Theme.secondaryText)
                                Text("从链接导入")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(Theme.secondaryText)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.monologueGlassTint)
                            .cornerRadius(20)
                        }
                        .buttonStyle(MonologueBouncingButtonStyle())
                        
                        Button(action: { showQQImport = true }) {
                            HStack(spacing: 6) {
                                MonologueIcon(icon: .musicNoteList, size: 14, color: Theme.secondaryText)
                                Text("QCM歌单")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(Theme.secondaryText)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.monologueGlassTint)
                            .cornerRadius(20)
                        }
                        .buttonStyle(MonologueBouncingButtonStyle())
                    }
                    .padding(.top, 50)
                }
                .scrollIndicators(.hidden)
            } else {
                List {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                    Button(action: {
                        AlertManager.shared.showInput(
                            title: String(localized: "lib_create_playlist"),
                            message: "",
                            placeholder: String(localized: "lib_playlist_name"),
                            primaryButtonTitle: String(localized: "lib_create"),
                            secondaryButtonTitle: String(localized: "alert_cancel"),
                            onConfirm: { name in
                                guard !name.isEmpty else { return }
                                manager.createPlaylist(name: name)
                            }
                        )
                    }) {
                                HStack(spacing: 6) {
                                    MonologueIcon(icon: .add, size: 14, color: Theme.secondaryText)
                            Text(LocalizedStringKey("lib_create_playlist"))
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(Theme.text)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .monologueGlassCapsule()
                                .clipShape(Capsule())
                    }
                    .buttonStyle(MonologueBouncingButtonStyle())
                    
                    Button(action: { showFileImporter = true }) {
                                HStack(spacing: 6) {
                                    if isImporting {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                    } else {
                                        MonologueIcon(icon: .download, size: 14, color: Theme.secondaryText)
                                    }
                                Text(LocalizedStringKey("lib_import_playlist"))
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(Theme.text)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .monologueGlassCapsule()
                                .clipShape(Capsule())
                            }
                            .buttonStyle(MonologueBouncingButtonStyle())
                            .disabled(isImporting)
                            
                            Button(action: {
                                AlertManager.shared.showInput(
                                    title: String(localized: "从链接导入歌单"),
                                    message: String(localized: "支持 QCM、NCM 的歌单分享链接"),
                                    placeholder: String(localized: "粘贴歌单链接"),
                                    primaryButtonTitle: String(localized: "导入"),
                                    secondaryButtonTitle: String(localized: "取消"),
                                    onConfirm: { url in
                                        self.importPlaylistFromURL(url)
                                    }
                                )
                            }) {
                                HStack(spacing: 6) {
                            if isImporting {
                                ProgressView()
                                            .scaleEffect(0.7)
                                    } else {
                                        MonologueIcon(icon: .share, size: 14, color: Theme.secondaryText)
                                    }
                                    Text("从链接导入")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundColor(Theme.text)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .monologueGlassCapsule()
                                .clipShape(Capsule())
                    }
                    .buttonStyle(MonologueBouncingButtonStyle())
                    .disabled(isImporting)
                            
                            Button(action: { showQQImport = true }) {
                                HStack(spacing: 6) {
                                    MonologueIcon(icon: .musicNoteList, size: 14, color: Theme.secondaryText)
                                    Text("QCM歌单")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundColor(Theme.text)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .monologueGlassCapsule()
                                .clipShape(Capsule())
                            }
                            .buttonStyle(MonologueBouncingButtonStyle())
                        }
                        .padding(.horizontal, 4)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 4, trailing: 20))
                    
                    ForEach(manager.playlists, id: \.id) { playlist in
                        ZStack {
                            NavigationLink(value: LibraryViewModel.NavigationDestination.localPlaylist(playlist.id)) {
                                EmptyView()
                            }
                            .opacity(0)
                            
                            LocalPlaylistRow(playlist: playlist)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if !playlist.isSystem {
                                Button(role: .destructive) {
                                    AlertManager.shared.show(
                                        title: String(localized: "lib_delete_playlist"),
                                        message: String(format: String(localized: "lib_confirm_delete"), playlist.name),
                                        primaryButtonTitle: String(localized: "lib_delete"),
                                        secondaryButtonTitle: String(localized: "alert_cancel"),
                                        primaryAction: {
                                            withAnimation { manager.deletePlaylist(playlist) }
                                        }
                                    )
                                } label: {
                                    Label(String(localized: "lib_delete"), systemImage: "trash")
                                }
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
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
        .sheet(isPresented: $showQQImport) {
            QQPlaylistImportView()
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                importPlaylistFromFile(url: url)
            case .failure(let error):
                AlertManager.shared.show(
                    title: String(localized: "lib_import_failed"),
                    message: error.localizedDescription,
                    primaryButtonTitle: String(localized: "lib_confirm"),
                    primaryAction: {}
                )
            }
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
                AlertManager.shared.show(
                    title: String(localized: "lib_import_failed"),
                    message: String(localized: "lib_import_no_songs"),
                    primaryButtonTitle: String(localized: "lib_confirm"),
                    primaryAction: {}
                )
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
                        AlertManager.shared.show(
                            title: String(localized: "lib_import_failed"),
                            message: String(localized: "lib_import_fetch_failed"),
                            primaryButtonTitle: String(localized: "lib_confirm"),
                            primaryAction: {}
                        )
                    } else {
                        manager.importPlaylist(name: name, songs: allSongs)
                    }
                    isImporting = false
                }
            }
        } catch {
            AlertManager.shared.show(
                title: String(localized: "lib_import_failed"),
                message: error.localizedDescription,
                primaryButtonTitle: String(localized: "lib_confirm"),
                primaryAction: {}
            )
            isImporting = false
        }
    }
    
    // MARK: - 从链接导入
    
    private func importPlaylistFromURL(_ urlString: String) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        isImporting = true
        
        if let qqId = extractQQPlaylistId(from: trimmed) {
            importQQPlaylist(id: qqId)
        } else if let ncmId = extractNCMPlaylistId(from: trimmed) {
            importNCMPlaylist(id: ncmId)
        } else if let kugouPath = extractKugouSonglistPath(from: trimmed) {
            importKugouPlaylist(path: kugouPath)
        } else {
            AlertManager.shared.show(
                title: String(localized: "lib_import_failed"),
                message: String(localized: "无法识别的歌单链接，请使用 NCM、QCM 或酷狗的歌单分享链接"),
                primaryButtonTitle: String(localized: "lib_confirm"),
                primaryAction: {}
            )
            isImporting = false
        }
    }
    
    private func extractQQPlaylistId(from url: String) -> Int? {
        // https://y.qq.com/n/ryqq_v2/playlist/9350658112
        // https://i.y.qq.com/n2/m/share/details/taoge.html?id=9350658112
        if let range = url.range(of: #"playlist/(\d+)"#, options: .regularExpression) {
            let match = url[range]
            let digits = match.replacingOccurrences(of: "playlist/", with: "")
            return Int(digits)
        }
        if let range = url.range(of: #"id=(\d+)"#, options: .regularExpression), url.contains("y.qq.com") {
            let match = String(url[range])
            let digits = match.replacingOccurrences(of: "id=", with: "")
            return Int(digits)
        }
        return nil
    }
    
    private func extractNCMPlaylistId(from url: String) -> Int? {
        // https://music.163.com/playlist?id=123456
        // https://music.163.com/#/playlist?id=123456
        if let range = url.range(of: #"playlist\?id=(\d+)"#, options: .regularExpression) {
            let match = String(url[range])
            let digits = match.replacingOccurrences(of: "playlist?id=", with: "")
            return Int(digits)
        }
        return nil
    }
    
    /// 提取酷狗歌单路径：支持 m.kugou.com/songlist/gcid_xxx 格式
    private func extractKugouSonglistPath(from url: String) -> String? {
        // https://m.kugou.com/songlist/gcid_3z7g1nvrz5z08a/...
        if let range = url.range(of: #"m\.kugou\.com/songlist/(gcid_[A-Za-z0-9]+)"#, options: .regularExpression) {
            let match = String(url[range])
            if let gcidRange = match.range(of: #"gcid_[A-Za-z0-9]+"#, options: .regularExpression) {
                return String(match[gcidRange])
            }
        }
        // https://kugou.com/songlist/gcid_xxx 或其他变体
        if let range = url.range(of: #"kugou\.com/songlist/(gcid_[A-Za-z0-9]+)"#, options: .regularExpression) {
            let match = String(url[range])
            if let gcidRange = match.range(of: #"gcid_[A-Za-z0-9]+"#, options: .regularExpression) {
                return String(match[gcidRange])
            }
        }
        return nil
    }
    
    // MARK: - 酷狗歌单导入
    
    private func importKugouPlaylist(path: String) {
        Task {
            do {
                let urlString = "https://m.kugou.com/songlist/\(path)/"
                guard let url = URL(string: urlString) else {
                    throw URLError(.badURL)
                }
                
                var request = URLRequest(url: url, timeoutInterval: 15)
                request.setValue(
                    "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
                    forHTTPHeaderField: "User-Agent"
                )
                
                let (data, _) = try await URLSession.shared.data(for: request)
                guard let html = String(data: data, encoding: .utf8) else {
                    throw URLError(.cannotDecodeContentData)
                }
                
                let (playlistName, kugouSongs) = parseKugouHTML(html)
                
                if kugouSongs.isEmpty {
                    await MainActor.run {
                        AlertManager.shared.show(
                            title: String(localized: "lib_import_failed"),
                            message: String(localized: "酷狗歌单为空或无法解析"),
                            primaryButtonTitle: String(localized: "lib_confirm"),
                            primaryAction: {}
                        )
                        isImporting = false
                    }
                    return
                }
                
                AppLogger.info("[KugouImport] 解析到 \(kugouSongs.count) 首歌，开始搜索匹配...")
                
                var matchedSongs: [Song] = []
                let total = kugouSongs.count
                
                for (index, kg) in kugouSongs.enumerated() {
                    let keyword = "\(kg.artist) \(kg.title)"
                    AppLogger.info("[KugouImport] [\(index+1)/\(total)] 搜索: \(keyword)")
                    
                    if let song = await searchSongOnPlatforms(title: kg.title, artist: kg.artist) {
                        matchedSongs.append(song)
                    }
                    
                    if index < total - 1 {
                        try await Task.sleep(nanoseconds: 200_000_000)
                    }
                }
                
                await MainActor.run {
                    if matchedSongs.isEmpty {
                        AlertManager.shared.show(
                            title: String(localized: "lib_import_failed"),
                            message: String(localized: "酷狗歌单中的歌曲未能在 NCM/QCM 中找到匹配"),
                            primaryButtonTitle: String(localized: "lib_confirm"),
                            primaryAction: {}
                        )
                    } else {
                        let name = playlistName.isEmpty ? String(localized: "酷狗歌单") : playlistName
                        manager.importPlaylist(name: name, songs: matchedSongs)
                        let skipped = total - matchedSongs.count
                        if skipped > 0 {
                            AlertManager.shared.show(
                                title: String(localized: "导入完成"),
                                message: String(localized: "成功匹配 \(matchedSongs.count) 首，\(skipped) 首未找到"),
                                primaryButtonTitle: String(localized: "lib_confirm"),
                                primaryAction: {}
                            )
                        }
                    }
                    isImporting = false
                }
            } catch {
                await MainActor.run {
                    AlertManager.shared.show(
                        title: String(localized: "lib_import_failed"),
                        message: String(localized: "酷狗歌单导入失败: \(error.localizedDescription)"),
                        primaryButtonTitle: String(localized: "lib_confirm"),
                        primaryAction: {}
                    )
                    isImporting = false
                }
            }
        }
    }
    
    private struct KugouSongInfo {
        let title: String
        let artist: String
    }
    
    /// 从酷狗 HTML 中解析 window.$output JSON，提取歌单名和歌曲列表
    private func parseKugouHTML(_ html: String) -> (name: String, songs: [KugouSongInfo]) {
        // 匹配 window.$output = {...} 或 window.$output={...}
        guard let outputRange = html.range(of: #"window\.\$output\s*=\s*\{"#, options: .regularExpression) else {
            AppLogger.error("[KugouImport] 未找到 window.$output")
            return ("", [])
        }
        
        let startIndex = html.index(outputRange.lowerBound, offsetBy: {
            let prefix = String(html[outputRange])
            return prefix.distance(from: prefix.startIndex, to: prefix.range(of: "{")!.lowerBound)
        }())
        
        // 找到匹配的闭合大括号
        var depth = 0
        var endIndex = startIndex
        var inString = false
        var escape = false
        
        for i in html[startIndex...].indices {
            let ch = html[i]
            if escape { escape = false; continue }
            if ch == "\\" && inString { escape = true; continue }
            if ch == "\"" { inString.toggle(); continue }
            if inString { continue }
            if ch == "{" { depth += 1 }
            if ch == "}" {
                depth -= 1
                if depth == 0 {
                    endIndex = html.index(after: i)
                    break
                }
            }
        }
        
        let jsonString = String(html[startIndex..<endIndex])
        
        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            AppLogger.error("[KugouImport] JSON 解析失败")
            return ("", [])
        }
        
        var playlistName = json["title"] as? String ?? json["name"] as? String ?? ""
        
        // 实际结构：info.listinfo.name
        if playlistName.isEmpty, let info = json["info"] as? [String: Any],
           let listinfo = info["listinfo"] as? [String: Any],
           let name = listinfo["name"] as? String {
            playlistName = name
        }
        
        var songs: [KugouSongInfo] = []
        
        // 实际结构：info.songs[]
        if let info = json["info"] as? [String: Any],
           let songList = info["songs"] as? [[String: Any]] {
            for item in songList {
                if let parsed = parseKugouSongItem(item) {
                    songs.append(parsed)
                }
            }
        }
        
        // 备用：顶层 songs 对象
        if songs.isEmpty, let songObj = json["songs"] as? [String: Any],
           let list = songObj["list"] as? [[String: Any]] {
            for item in list {
                if let parsed = parseKugouSongItem(item) {
                    songs.append(parsed)
                }
            }
        }
        
        // 备用：顶层 list 数组
        if songs.isEmpty, let list = json["list"] as? [[String: Any]] {
            for item in list {
                if let parsed = parseKugouSongItem(item) {
                    songs.append(parsed)
                }
            }
        }
        
        return (playlistName, songs)
    }
    
    private func parseKugouSongItem(_ item: [String: Any]) -> KugouSongInfo? {
        // 格式 1: name = "歌手 - 歌名"（实际 API 格式）
        if let name = item["name"] as? String ?? item["filename"] as? String {
            let parts = name.components(separatedBy: " - ")
            if parts.count >= 2 {
                let artist = parts[0].trimmingCharacters(in: .whitespaces)
                let title = parts.dropFirst().joined(separator: " - ").trimmingCharacters(in: .whitespaces)
                if !artist.isEmpty && !title.isEmpty {
                    return KugouSongInfo(title: title, artist: artist)
                }
            }
        }
        // 格式 2: singerinfo + remark/songname 分开字段
        if let singerInfo = item["singerinfo"] as? [[String: Any]],
           let firstSinger = singerInfo.first,
           let singerName = firstSinger["name"] as? String {
            let songName = item["remark"] as? String ?? item["songname"] as? String ?? item["song_name"] as? String ?? ""
            if !songName.isEmpty {
                return KugouSongInfo(title: songName, artist: singerName)
            }
        }
        // 格式 3: singername + songname 直接字段
        if let songname = item["songname"] as? String ?? item["song_name"] as? String,
           let singername = item["singername"] as? String ?? item["author_name"] as? String {
            if !songname.isEmpty {
                return KugouSongInfo(title: songname, artist: singername)
            }
        }
        return nil
    }
    
    /// 在ncm和 qcm搜索匹配歌曲，优先ncm
    private func searchSongOnPlatforms(title: String, artist: String) async -> Song? {
        let keyword = "\(artist) \(title)"
        
        // 先搜ncm
        if let ncmSong = await searchNCMSong(keyword: keyword, title: title, artist: artist) {
            return ncmSong
        }
        
        // ncm没找到，搜 qcm
        if let qqSong = await searchQQSong(keyword: keyword, title: title, artist: artist) {
            return qqSong
        }
        
        AppLogger.info("[KugouImport] 未匹配: \(keyword)")
        return nil
    }
    
    private func searchNCMSong(keyword: String, title: String, artist: String) async -> Song? {
        do {
            let songs: [Song] = try await withCheckedThrowingContinuation { continuation in
                var resumed = false
                var cancellable: AnyCancellable?
                cancellable = APIService.shared.searchSongs(keyword: keyword, offset: 0)
                    .sink(receiveCompletion: { completion in
                        if case .failure(let error) = completion, !resumed {
                            resumed = true
                            continuation.resume(throwing: error)
                        }
                        cancellable?.cancel()
                    }, receiveValue: { songs in
                        guard !resumed else { return }
                        resumed = true
                        continuation.resume(returning: songs)
                        cancellable?.cancel()
                    })
            }
            return bestMatch(from: songs, title: title, artist: artist)
        } catch {
            return nil
        }
    }
    
    private func searchQQSong(keyword: String, title: String, artist: String) async -> Song? {
        do {
            let songs: [Song] = try await withCheckedThrowingContinuation { continuation in
                var resumed = false
                var cancellable: AnyCancellable?
                cancellable = APIService.shared.searchQQSongs(keyword: keyword, page: 1, num: 10)
                    .sink(receiveCompletion: { completion in
                        if case .failure(let error) = completion, !resumed {
                            resumed = true
                            continuation.resume(throwing: error)
                        }
                        cancellable?.cancel()
                    }, receiveValue: { songs in
                        guard !resumed else { return }
                        resumed = true
                        continuation.resume(returning: songs)
                        cancellable?.cancel()
                    })
            }
            return bestMatch(from: songs, title: title, artist: artist)
        } catch {
            return nil
        }
    }
    
    /// 从搜索结果中选出最佳匹配：标题和歌手名都相似
    private func bestMatch(from songs: [Song], title: String, artist: String) -> Song? {
        let normalizedTitle = title.lowercased()
        let normalizedArtist = artist.lowercased()
        
        let matchesArtist: (Song) -> Bool = { song in
            let a = song.artistName.lowercased()
            return a.contains(normalizedArtist) || normalizedArtist.contains(a)
        }
        
        if let exact = songs.first(where: {
            $0.name.lowercased() == normalizedTitle && matchesArtist($0)
        }) {
            return exact
        }
        
        if let partial = songs.first(where: {
            let t = $0.name.lowercased()
            return (t.contains(normalizedTitle) || normalizedTitle.contains(t)) && matchesArtist($0)
        }) {
            return partial
        }
        
        if let titleOnly = songs.first(where: {
            $0.name.lowercased() == normalizedTitle
        }) {
            return titleOnly
        }
        
        return nil
    }
    
    private func importQQPlaylist(id: Int) {
        Task {
            do {
                let detail = try await APIService.shared.qqClient.songlistDetail(songlistId: id, num: 1, page: 1)
                let name = detail["dirinfo"]?["title"]?.stringValue ?? String(localized: "QCM歌单")
                
                var allSongs: [Song] = []
                var page = 1
                var hasMore = true
                
                while hasMore {
                    let songs: [Song] = try await withCheckedThrowingContinuation { continuation in
                        var resumed = false
                        var cancellable: AnyCancellable?
                        cancellable = APIService.shared.fetchQQPlaylistSongs(playlistId: id, page: page, num: 50)
                            .sink(receiveCompletion: { completion in
                                if case .failure(let error) = completion, !resumed {
                                    resumed = true
                                    continuation.resume(throwing: error)
                                }
                                cancellable?.cancel()
                            }, receiveValue: { songs in
                                guard !resumed else { return }
                                resumed = true
                                continuation.resume(returning: songs)
                                cancellable?.cancel()
                            })
                    }
                    allSongs.append(contentsOf: songs)
                    if songs.count < 50 { hasMore = false }
                    page += 1
                }
                
                await MainActor.run {
                    if allSongs.isEmpty {
                        AlertManager.shared.show(
                            title: String(localized: "lib_import_failed"),
                            message: String(localized: "歌单为空或获取失败"),
                            primaryButtonTitle: String(localized: "lib_confirm"),
                            primaryAction: {}
                        )
                    } else {
                        manager.importPlaylist(name: name, songs: allSongs)
                    }
                    isImporting = false
                }
            } catch {
                await MainActor.run {
                    AlertManager.shared.show(
                        title: String(localized: "lib_import_failed"),
                        message: String(localized: "QCM歌单导入失败: \(error.localizedDescription)"),
                        primaryButtonTitle: String(localized: "lib_confirm"),
                        primaryAction: {}
                    )
                    isImporting = false
                }
            }
        }
    }
    
    private func importNCMPlaylist(id: Int) {
        Task {
            var allSongs: [Song] = []
            var offset = 0
            let limit = 50
            var hasMore = true
            let playlistName = String(localized: "NCM歌单")
            
            // 先获取歌单名
            do {
                let details: [Song] = try await withCheckedThrowingContinuation { continuation in
                    var resumed = false
                    var cancellable: AnyCancellable?
                    cancellable = APIService.shared.fetchPlaylistTracks(id: id, limit: 1, offset: 0)
                        .sink(receiveCompletion: { completion in
                            if case .failure(let error) = completion, !resumed {
                                resumed = true
                                continuation.resume(throwing: error)
                            }
                            cancellable?.cancel()
                        }, receiveValue: { songs in
                            guard !resumed else { return }
                            resumed = true
                            continuation.resume(returning: songs)
                            cancellable?.cancel()
                        })
                }
                _ = details
            } catch {
                // 获取名称失败不影响导入
            }
            
            while hasMore {
                do {
                    let songs: [Song] = try await withCheckedThrowingContinuation { continuation in
                        var resumed = false
                        var cancellable: AnyCancellable?
                        cancellable = APIService.shared.fetchPlaylistTracks(id: id, limit: limit, offset: offset)
                            .sink(receiveCompletion: { completion in
                                if case .failure(let error) = completion, !resumed {
                                    resumed = true
                                    continuation.resume(throwing: error)
                                }
                                cancellable?.cancel()
                            }, receiveValue: { songs in
                                guard !resumed else { return }
                                resumed = true
                                continuation.resume(returning: songs)
                                cancellable?.cancel()
                            })
                    }
                    allSongs.append(contentsOf: songs)
                    if songs.count < limit { hasMore = false }
                    offset += limit
                } catch {
                    hasMore = false
                }
            }
            
            await MainActor.run {
                if allSongs.isEmpty {
                    AlertManager.shared.show(
                        title: String(localized: "lib_import_failed"),
                        message: String(localized: "歌单为空或获取失败"),
                        primaryButtonTitle: String(localized: "lib_confirm"),
                        primaryAction: {}
                    )
                } else {
                    manager.importPlaylist(name: playlistName, songs: allSongs)
                }
                isImporting = false
            }
        }
    }
}

struct LocalPlaylistRow: View {
    let playlist: LocalPlaylist
    typealias Theme = PlaylistDetailView.Theme
    
    var body: some View {
        HStack(spacing: 14) {
            Group {
                if let url = playlist.displayCoverUrl {
                    CachedAsyncImage(url: url.sized(200)) {
                        systemPlaceholder
                    }
                    .aspectRatio(contentMode: .fill)
                } else {
                    systemPlaceholder
                }
            }
            .frame(width: DeviceLayout.listRowCoverStandard, height: DeviceLayout.listRowCoverStandard)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.text)
                    .lineLimit(1)
                
                Text(String(format: String(localized: "songs_count_format"), playlist.trackCount))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.secondaryText)
            }
            
            Spacer()
            
            MonologueIcon(icon: .chevronRight, size: 12, color: Theme.secondaryText.opacity(0.6))
        }
        .padding(14)
        .monologueGlass(cornerRadius: 18)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    
    private var systemPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    playlist.isFavorite
                    ? LinearGradient(colors: [.pink.opacity(0.6), .red.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : playlist.isDownload
                    ? LinearGradient(colors: [.blue.opacity(0.5), .cyan.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [Color.monologueGlassTint, Color.monologueGlassTint], startPoint: .top, endPoint: .bottom)
                )
            MonologueIcon(
                icon: playlist.isFavorite ? .liked : playlist.isDownload ? .download : .musicNoteList,
                size: 24,
                color: playlist.isSystem ? .white : .monologueTextSecondary.opacity(0.3)
            )
        }
    }
}

// MARK: - 我的播客（订阅的播客列表）

struct MyPodcastsView: View {
    typealias Theme = PlaylistDetailView.Theme
    @ObservedObject private var subManager = SubscriptionManager.shared
    @State private var selectedTab: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            // 自定义标签栏（与下载管理等页面风格统一）
            HStack(spacing: 0) {
                podcastTabButton(title: String(localized: "本地收藏"), index: 0)
                podcastTabButton(title: String(localized: "NCM 播客"), index: 1)
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 12)

            if selectedTab == 0 {
                localPodcastsList
            } else {
                ncmPodcastsList
            }
        }
        .onAppear {
            if subManager.subscribedRadios.isEmpty {
                subManager.fetchSubscribedRadios()
            }
        }
    }

    private func podcastTabButton(title: String, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = index }
        } label: {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 15, weight: selectedTab == index ? .bold : .medium, design: .rounded))
                    .foregroundColor(selectedTab == index ? .monologueTextPrimary : .monologueTextSecondary)

                Rectangle()
                    .fill(selectedTab == index ? Color.monologueTextPrimary : Color.clear)
                    .frame(height: 2)
                    .frame(width: 40)
            }
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.plain)
    }

    private var localPodcastsList: some View {
        Group {
            if subManager.localSubscribedRadios.isEmpty {
                ScrollView {
                    VStack(spacing: 16) {
                        MonologueIcon(icon: .radio, size: 40, color: .monologueTextSecondary.opacity(0.3))
                        Text("暂无本地收藏")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.secondaryText)
                    }
                    .padding(.top, 50)
                }
                .scrollIndicators(.hidden)
            } else {
                List {
                    ForEach(subManager.localSubscribedRadios) { radio in
                        ZStack {
                            NavigationLink(value: LibraryViewModel.NavigationDestination.radioDetail(radio.id)) {
                                EmptyView()
                            }
                            .opacity(0)
                            
                            podcastRow(radio: radio)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                withAnimation {
                                    subManager.removeLocalRadio(radio)
                                }
                            } label: {
                                Label(String(localized: "lib_unsubscribe"), systemImage: "heart.slash")
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                withAnimation {
                                    subManager.removeLocalRadio(radio)
                                }
                            } label: {
                                Label(String(localized: "lib_unsubscribe"), systemImage: "heart.slash")
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                    }

                    Color.clear.frame(height: 100)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
            }
        }
    }

    private var ncmPodcastsList: some View {
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
                        MonologueIcon(icon: .radio, size: 40, color: .monologueTextSecondary.opacity(0.3))
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
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                    }

                    Color.clear.frame(height: 100)
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
    }

    private func podcastRow(radio: RadioStation) -> some View {
        HStack(spacing: 14) {
            CachedAsyncImage(url: radio.coverUrl) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.monologueGlassTint)
            }
            .frame(width: DeviceLayout.listRowCoverSmall, height: DeviceLayout.listRowCoverSmall)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text(radio.name)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    if let dj = radio.dj?.nickname {
                        Text(dj)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(.monologueTextSecondary)
                    }
                    if let count = radio.programCount, count > 0 {
                        Text("·")
                            .font(.system(size: 11))
                            .foregroundColor(.monologueTextSecondary)
                        Text(String(format: String(localized: "lib_episode_count"), count))
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(.monologueTextSecondary)
                    }
                }
            }

            Spacer()

            MonologueIcon(icon: .chevronRight, size: 12, color: .monologueTextSecondary.opacity(0.6))
        }
        .padding(.vertical, 5)
    }
}

struct NetEasePlaylistsView: View {
    @ObservedObject var viewModel: LibraryViewModel
    @ObservedObject private var subManager = SubscriptionManager.shared
    @AppStorage("isLoggedIn") private var isAppLoggedIn = false
    typealias Theme = PlaylistDetailView.Theme

    var body: some View {
        Group {
            if viewModel.userPlaylists.isEmpty {
                ScrollView {
                    VStack(spacing: 16) {
                        MonologueIcon(icon: .musicNoteList, size: 40, color: .monologueTextSecondary.opacity(0.3))
                        Text(isAppLoggedIn ? String(localized: "暂无歌单，快去收藏一些吧！") : String(localized: "请先登录 NCM"))
                            .font(.rounded(size: 14, weight: .medium))
                            .foregroundColor(.monologueTextSecondary)
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
                                let isOwn = isUserCreated(playlist)
                                let title = isOwn ? String(localized: "lib_delete_playlist") : String(localized: "lib_uncollect")
                                let message = isOwn ? String(format: String(localized: "lib_confirm_delete"), playlist.name) : String(format: String(localized: "lib_confirm_uncollect"), playlist.name)
                                let buttonTitle = isOwn ? String(localized: "lib_delete") : String(localized: "lib_uncollect")
                                AlertManager.shared.show(
                                    title: title,
                                    message: message,
                                    primaryButtonTitle: buttonTitle,
                                    secondaryButtonTitle: String(localized: "alert_cancel"),
                                    primaryAction: { [viewModel, subManager] in
                                        let playlistId = playlist.id
                                        withAnimation {
                                            viewModel.userPlaylists.removeAll { $0.id == playlistId }
                                        }
                                        OptimizedCacheManager.shared.setObject(viewModel.userPlaylists, forKey: "user_playlists")
                                        if isOwn {
                                            subManager.deletePlaylist(id: playlistId) { success in
                                                if !success {
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
                                    }
                                )
                            } label: {
                                Label(isUserCreated(playlist) ? String(localized: "lib_delete_playlist") : String(localized: "lib_uncollect"),
                                      systemImage: isUserCreated(playlist) ? "trash" : "heart.slash")
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                    }

                    Color.clear.frame(height: 100)
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

// MARK: - qcm歌单

struct QQPlaylistsView: View {
    @ObservedObject var viewModel: LibraryViewModel
    @ObservedObject private var qqSession = QQUserSession.shared
    @State private var qqPlaylists: [Playlist] = []
    @State private var isLoading = false
    @State private var hasLoaded = false
    typealias Theme = PlaylistDetailView.Theme

    var body: some View {
        Group {
            if isLoading && qqPlaylists.isEmpty {
                ScrollView {
                    VStack(spacing: 16) {
                        ProgressView().scaleEffect(1.2)
                        Text("加载中...")
                            .font(.rounded(size: 14, weight: .medium))
                            .foregroundColor(.monologueTextSecondary)
                    }
                    .padding(.top, 50)
                }
                .scrollIndicators(.hidden)
            } else if qqPlaylists.isEmpty {
                ScrollView {
                    VStack(spacing: 16) {
                        MonologueIcon(icon: .musicNoteList, size: 40, color: .monologueTextSecondary.opacity(0.3))
                        Text(qqSession.isLoggedIn ? String(localized: "暂无歌单，快去收藏一些吧！") : String(localized: "请先登录 QCM"))
                            .font(.rounded(size: 14, weight: .medium))
                            .foregroundColor(.monologueTextSecondary)
                    }
                    .padding(.top, 50)
                }
                .scrollIndicators(.hidden)
            } else {
                List {
                    ForEach(qqPlaylists) { playlist in
                        ZStack {
                            NavigationLink(value: LibraryViewModel.NavigationDestination.playlist(playlist)) {
                                EmptyView()
                            }
                            .opacity(0)
                            LibraryPlaylistRow(playlist: playlist)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                    }

                    Color.clear.frame(height: 100)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .refreshable { await loadPlaylists(force: true) }
            }
        }
        .background(Color.clear)
        .onAppear {
            if !hasLoaded { Task { await loadPlaylists() } }
        }
        .onChange(of: qqSession.isLoggedIn) { _, loggedIn in
            if !loggedIn {
                qqPlaylists = []
                hasLoaded = false
            } else if !hasLoaded {
                Task { await loadPlaylists() }
            }
        }
    }

    private func loadPlaylists(force: Bool = false) async {
        guard QQUserSession.shared.isLoggedIn else { return }
        guard let mid = QQUserSession.shared.musicId else { return }
        isLoading = true
        defer { isLoading = false; hasLoaded = true }

        do {
            let result: JSON = try await QQUserSession.shared.withUserSession { client in
                try await client.createdSonglist(uin: String(mid))
            }

            var items: [Playlist] = []
            let list = result["v_playlist"]?.arrayValue ?? result.arrayValue ?? []
            for json in list {
                guard let obj = json.objectValue else { continue }
                let tid = obj["tid"]?.intValue ?? 0
                let name = obj["dirName"]?.stringValue ?? obj["diss_name"]?.stringValue ?? ""
                let cover = obj["picUrl"]?.stringValue ?? obj["logo"]?.stringValue ?? ""
                let songCount = obj["songNum"]?.intValue ?? obj["song_cnt"]?.intValue ?? 0
                if !name.isEmpty {
                    items.append(Playlist(
                        id: tid, name: name, coverImgUrl: cover, picUrl: nil,
                        trackCount: songCount, playCount: nil,
                        subscribedCount: nil, shareCount: nil, commentCount: nil,
                        creator: nil, description: nil, tags: nil, source: .qqmusic
                    ))
                }
            }
            qqPlaylists = items
        } catch {
            AppLogger.error("[QQPlaylists] 加载歌单失败: \(error)")
        }
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
                    Text(s == .ncm ? "NCM" : "QCM")
                        .font(.system(size: 13, weight: source == s ? .bold : .medium, design: .rounded))
                        .foregroundColor(source == s ? .monologueIconForeground : Theme.text.opacity(0.6))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background {
                            if source == s {
                                Capsule()
                                    .fill(Color.monologueIconBackground)
                                    .matchedGeometryEffect(id: "sourcePill", in: ns)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.monologueTextPrimary.opacity(0.06)))
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
            .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
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
                    MonologueLoadingView()
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
                            MonologueLoadingView(centered: false).padding()
                    }
                    if !viewModel.hasMoreSquarePlaylists && !viewModel.squarePlaylists.isEmpty {
                        NoMoreDataView()
                    }
                    }
                    .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
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
                    MonologueLoadingView()
                } else if viewModel.qqSquarePlaylists.isEmpty {
                    VStack(spacing: 16) {
                        MonologueIcon(icon: .musicNoteList, size: 50, color: Theme.secondaryText.opacity(0.5))
                        Text("暂无QCM推荐歌单")
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
                            MonologueLoadingView(centered: false).padding()
                        }
                        if !viewModel.hasMoreQQSquare && !viewModel.qqSquarePlaylists.isEmpty {
                            NoMoreDataView()
                        }
                    }
                    .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
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

    private static let hiddenQQCategories: Set<String> = [String(localized: "全部"), String(localized: "ai歌单"), String(localized: "私藏"), String(localized: "音乐人在听"), "chill vibes", String(localized: "ai 歌单")]

    private var filteredQQCategories: [(id: Int, name: String)] {
        viewModel.qqPlaylistCategories.filter { !Self.hiddenQQCategories.contains($0.name.lowercased()) }
    }

    private var qqCategoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(filteredQQCategories, id: \.id) { cat in
                    let selected = viewModel.selectedQQCategoryId == cat.id
                    Button {
                        guard !selected else { return }
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                            viewModel.selectQQCategory(id: cat.id, name: cat.name)
                        }
                    } label: {
                        Text(cat.name)
                            .font(.system(size: 13, weight: selected ? .semibold : .medium, design: .rounded))
                            .foregroundColor(selected ? .monologueIconForeground : .monologueTextPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background {
                                if selected {
                                    Capsule()
                                        .fill(Color.monologueIconBackground)
                                        .matchedGeometryEffect(id: "qqCatPill", in: categoryNS)
                                }
                            }
                            .background(Capsule().fill(selected ? Color.clear : Color.monologueGlassTint))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
            .padding(.vertical, 14)
        }
    }

    // MARK: - Animated Category Selector

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
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
                            .font(.system(size: 13, weight: selected ? .semibold : .medium, design: .rounded))
                            .foregroundColor(selected ? .monologueIconForeground : .monologueTextPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background {
                                if selected {
                                    Capsule()
                                        .fill(Color.monologueIconBackground)
                                        .matchedGeometryEffect(id: "squareCatPill", in: categoryNS)
                                }
                            }
                            .background(Capsule().fill(selected ? Color.clear : Color.monologueGlassTint))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
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
                    .fill(Color.monologueSeparator)
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
    @FocusState private var focusedSearchField: SearchField?
    typealias Theme = PlaylistDetailView.Theme

    let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: DeviceLayout.artistGridColumns)

    private enum SearchField: Hashable {
        case ncm
        case qq
    }
    
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
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 4)
            .onChange(of: viewModel.artistSource) { _, newSource in
                dismissArtistSearchKeyboard()
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
                    MonologueIcon(icon: .magnifyingGlass, size: 18, color: Theme.secondaryText)

                    TextField(LocalizedStringKey("search_artists"), text: $viewModel.artistSearchText)
                        .font(.system(size: 16, design: .rounded))
                        .foregroundColor(Theme.text)
                        .monologueTextInputBehavior()
                        .focused($focusedSearchField, equals: .ncm)
                        .submitLabel(.search)
                        .onSubmit {
                            dismissArtistSearchKeyboard()
                            viewModel.fetchArtistData(reset: true)
                        }

                    if !viewModel.artistSearchText.isEmpty {
                        Button(action: {
                            viewModel.artistSearchText = ""
                            viewModel.fetchArtistData(reset: true)
                        }) {
                            MonologueIcon(icon: .xmark, size: 18, color: Theme.secondaryText)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .monologueGlass(cornerRadius: 20)
                
                if !viewModel.isSearchingArtists {
                    Button(action: {
                        dismissArtistSearchKeyboard()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showFilters.toggle()
                        }
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(hasActiveFilter ? Color.monologueGlassTint : Color.clear)
                                .monologueGlass(cornerRadius: 14)
                            
                            MonologueIcon(
                                icon: .filter,
                                size: 18,
                                color: hasActiveFilter ? .monologueIconForeground : Theme.secondaryText
                            )
                            .rotationEffect(.degrees(showFilters ? 90 : 0))
                        }
                        .frame(width: 46, height: 46)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(MonologueBouncingButtonStyle())
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.bottom, 12)
            .padding(.top, 8)

            if !viewModel.isSearchingArtists && showFilters {
                VStack(alignment: .leading, spacing: 12) {
                    ScrollView(.horizontal) {
                        filterRow(options: viewModel.artistAreas.map { ($0.name, $0.value) }, selected: $viewModel.artistArea) {
                            viewModel.fetchArtistData(reset: true)
                        }
                            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    }
                    .scrollIndicators(.hidden)
                    ScrollView(.horizontal) {
                        filterRow(options: viewModel.artistTypes.map { ($0.name, $0.value) }, selected: $viewModel.artistType) {
                            viewModel.fetchArtistData(reset: true)
                        }
                            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    }
                    .scrollIndicators(.hidden)
                    ScrollView(.horizontal) {
                        filterRow(options: viewModel.artistInitials.map { ($0 == "-1" ? "search_hot" : $0, $0) }, selected: $viewModel.artistInitial) {
                            viewModel.fetchArtistData(reset: true)
                        }
                            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
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
                    MonologueIcon(icon: .magnifyingGlass, size: 18, color: Theme.secondaryText)

                    TextField(String(localized: "搜索QCM歌手"), text: $viewModel.qqArtistSearchText)
                        .font(.system(size: 16, design: .rounded))
                        .foregroundColor(Theme.text)
                        .monologueTextInputBehavior()
                        .focused($focusedSearchField, equals: .qq)
                        .submitLabel(.search)
                        .onSubmit {
                            dismissArtistSearchKeyboard()
                        }

                    if !viewModel.qqArtistSearchText.isEmpty {
                        Button(action: {
                            viewModel.qqArtistSearchText = ""
                        }) {
                            MonologueIcon(icon: .xmark, size: 18, color: Theme.secondaryText)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .monologueGlass(cornerRadius: 20)

                if !viewModel.isSearchingQQArtists {
                    Button(action: {
                        dismissArtistSearchKeyboard()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showQQFilters.toggle()
                        }
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(hasActiveQQFilter ? Color.monologueGlassTint : Color.clear)
                                .monologueGlass(cornerRadius: 14)
                            
                            MonologueIcon(
                                icon: .filter,
                                size: 18,
                                color: hasActiveQQFilter ? .monologueIconForeground : Theme.secondaryText
                            )
                            .rotationEffect(.degrees(showQQFilters ? 90 : 0))
                        }
                        .frame(width: 46, height: 46)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(MonologueBouncingButtonStyle())
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.bottom, 12)
            .padding(.top, 8)

            if !viewModel.isSearchingQQArtists && showQQFilters {
                VStack(alignment: .leading, spacing: 12) {
                    ScrollView(.horizontal) {
                        qqFilterRow(options: viewModel.qqArtistAreas, selected: $viewModel.qqArtistArea)
                            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    }
                    .scrollIndicators(.hidden)
                    ScrollView(.horizontal) {
                        qqFilterRow(options: viewModel.qqArtistSexes, selected: $viewModel.qqArtistSex)
                            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    }
                    .scrollIndicators(.hidden)
                    ScrollView(.horizontal) {
                        qqFilterRow(options: viewModel.qqArtistGenres, selected: $viewModel.qqArtistGenre)
                            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
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
                MonologueLoadingView()
            } else if artists.isEmpty {
                VStack(spacing: 16) {
                    MonologueIcon(icon: .personEmpty, size: 50, color: Theme.secondaryText.opacity(0.5))
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
                                .frame(width: DeviceLayout.artistAvatarSize, height: DeviceLayout.artistAvatarSize)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)

                                Text(artist.name)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .lineLimit(1)
                                    .foregroundColor(Theme.text)
                            }
                        }
                        .simultaneousGesture(TapGesture().onEnded {
                            dismissArtistSearchKeyboard()
                        })
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.9))
                        .onAppear { onAppear(index) }
                    }
                }
                .padding(DeviceLayout.viewHorizontalPadding)

                if hasMore && !isSearching {
                    MonologueLoadingView().padding()
                }
                if !hasMore && !artists.isEmpty && !isSearching {
                    NoMoreDataView()
                }
            }

            Color.clear.frame(height: 120)
        }
        .scrollDismissesKeyboard(.immediately)
        .simultaneousGesture(
            DragGesture(minimumDistance: 4)
                .onChanged { _ in
                    if focusedSearchField != nil {
                        focusedSearchField = nil
                    }
                }
        )
        .simultaneousGesture(TapGesture().onEnded {
            dismissArtistSearchKeyboard()
        })
        .scrollIndicators(.hidden)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }

    // MARK: - Filter Rows

    private func filterRow<T: Equatable>(options: [(String, T)], selected: Binding<T>, onChange: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            ForEach(options, id: \.0) { option in
                Button(action: {
                    dismissArtistSearchKeyboard()
                    if selected.wrappedValue != option.1 {
                        selected.wrappedValue = option.1
                        onChange()
                    }
                }) {
                    Text(LocalizedStringKey(option.0))
                        .font(.system(size: 13, weight: selected.wrappedValue == option.1 ? .semibold : .medium, design: .rounded))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(selected.wrappedValue == option.1 ? Color.monologueIconBackground : Color.monologueGlassTint))
                        .foregroundColor(selected.wrappedValue == option.1 ? .monologueIconForeground : .monologueTextPrimary)
                }
                .buttonStyle(MonologueBouncingButtonStyle())
            }
        }
    }

    private func qqFilterRow<T: Equatable>(options: [(name: String, value: T)], selected: Binding<T>) -> some View {
        HStack(spacing: 10) {
            ForEach(options, id: \.name) { option in
                Button(action: {
                    dismissArtistSearchKeyboard()
                    if selected.wrappedValue != option.value {
                        selected.wrappedValue = option.value
                        viewModel.fetchQQArtistData(reset: true)
                    }
                }) {
                    Text(LocalizedStringKey(option.name))
                        .font(.system(size: 13, weight: selected.wrappedValue == option.value ? .semibold : .medium, design: .rounded))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(selected.wrappedValue == option.value ? Color.monologueIconBackground : Color.monologueGlassTint))
                        .foregroundColor(selected.wrappedValue == option.value ? .monologueIconForeground : .monologueTextPrimary)
                }
                .buttonStyle(MonologueBouncingButtonStyle())
            }
        }
    }

    private func dismissArtistSearchKeyboard() {
        focusedSearchField = nil
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

    let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: DeviceLayout.artistGridColumns)

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
                MonologueLoadingView()
            } else if viewModel.topLists.isEmpty {
                VStack(spacing: 16) {
                    MonologueIcon(icon: .chart, size: 50, color: Theme.secondaryText.opacity(0.5))
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
                                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

                            ScrollView(.horizontal) {
                                HStack(spacing: 14) {
                                    ForEach(officialCharts) { list in
                                        NavigationLink(value: chartDestination(list)) {
                                            OfficialChartCard(list: list)
                                        }
                                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
                                    }
                                }
                                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                            }
                            .scrollIndicators(.hidden)
                        }
                    }

                    if !otherCharts.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(LocalizedStringKey("charts_more"))
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.text)
                                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(otherCharts) { list in
                                    NavigationLink(value: chartDestination(list)) {
                                        CompactChartCard(list: list)
                                    }
                                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
                                }
                            }
                            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
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
                MonologueLoadingView()
            } else if viewModel.qqTopLists.isEmpty {
                VStack(spacing: 16) {
                    MonologueIcon(icon: .chart, size: 50, color: Theme.secondaryText.opacity(0.5))
                    Text("暂无QCM排行榜")
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
                                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

                            if group.groupId == 0 || group.items.count <= 4 {
                                // 官方榜：横向大卡片
                                ScrollView(.horizontal) {
                                    HStack(spacing: 14) {
                                        ForEach(group.items) { item in
                                            NavigationLink(value: qqChartDestination(item)) {
                                                QQOfficialChartCard(item: item)
                                            }
                                            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
                                        }
                                    }
                                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                                }
                                .scrollIndicators(.hidden)
                            } else {
                                // 其他榜：三列网格
                                LazyVGrid(columns: columns, spacing: 16) {
                                    ForEach(group.items) { item in
                                        NavigationLink(value: qqChartDestination(item)) {
                                            QQChartCard(item: item)
                                        }
                                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
                                    }
                                }
                                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
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
            creator: nil, description: nil, tags: nil, isTopList: true
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
                        .fill(Color.monologueSeparator)
                }
                .aspectRatio(1, contentMode: .fit)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.monologueSeparator)
                    .aspectRatio(1, contentMode: .fit)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(minHeight: 32, alignment: .topLeading)

                Text(item.intro.isEmpty ? " " : item.intro)
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
                        .fill(Color.monologueSeparator)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: DeviceLayout.chartCardSize, height: DeviceLayout.chartCardSize)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.monologueSeparator)
                    .frame(width: DeviceLayout.chartCardSize, height: DeviceLayout.chartCardSize)
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
            .frame(width: DeviceLayout.chartCardSize, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            )
        }
        .frame(width: DeviceLayout.chartCardSize, height: DeviceLayout.chartCardSize)
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
                    .fill(Color.monologueSeparator)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: DeviceLayout.chartCardSize, height: DeviceLayout.chartCardSize)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

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
            .frame(width: DeviceLayout.chartCardSize, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            )
        }
        .frame(width: DeviceLayout.chartCardSize, height: DeviceLayout.chartCardSize)
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
                    .fill(Color.monologueSeparator)
            }
            .aspectRatio(1, contentMode: .fit)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)

            VStack(alignment: .leading, spacing: 4) {
                Text(list.name)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(minHeight: 32, alignment: .topLeading)

                Text(list.updateFrequency)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.secondaryText)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Components

struct LibraryPlaylistRow: View {
    let playlist: Playlist
    typealias Theme = PlaylistDetailView.Theme

    var body: some View {
        HStack(spacing: 14) {
            CachedAsyncImage(url: playlist.coverUrl?.sized(200)) {
                Color.gray.opacity(0.1)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: DeviceLayout.listRowCoverStandard, height: DeviceLayout.listRowCoverStandard)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.text)
                    .lineLimit(1)

                Text(String(format: NSLocalizedString("track_count_songs", comment: ""), playlist.trackCount ?? 0))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.secondaryText)
            }

            Spacer()

            MonologueIcon(icon: .chevronRight, size: 12, color: Theme.secondaryText.opacity(0.6))
        }
        .padding(14)
        .monologueGlass(cornerRadius: 18)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
