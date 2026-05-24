import Combine
import QQMusicKit
import SwiftUI
import UniformTypeIdentifiers

struct MyPlaylistsContainerView: View {
    @ObservedObject var viewModel: LibraryViewModel
    @ObservedObject private var settings = SettingsManager.shared
    @State private var selectedSubTab: Int = 0
    typealias Theme = PlaylistDetailView.Theme

    var body: some View {
        let _ = settings.globalThemeRevision
        VStack(spacing: 0) {
            if NeumorphicStyle.isActive {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        subTabButton(title: String(localized: "lib_local_playlists"), index: 0)
                        subTabButton(title: String(localized: "lib_netease_playlists"), index: 1)
                        subTabButton(title: String(localized: "QCM歌单"), index: 2)
                        subTabButton(title: String(localized: "lib_my_podcasts"), index: 3)
                    }
                    .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
                .padding(.bottom, 12)
            } else {
                HStack(spacing: 0) {
                    subTabButton(title: String(localized: "lib_local_playlists"), index: 0)
                    subTabButton(title: String(localized: "lib_netease_playlists"), index: 1)
                    subTabButton(title: String(localized: "QCM歌单"), index: 2)
                    subTabButton(title: String(localized: "lib_my_podcasts"), index: 3)
                    Spacer()
                }
                .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
                .padding(.bottom, 14)
            }

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
            Group {
                if MangaStyle.isActive {
                    Text(title)
                        .font(MangaStyle.comicFont(11, weight: selectedSubTab == index ? .bold : .medium))
                        .foregroundStyle(selectedSubTab == index ? MangaStyle.ink : MangaStyle.inkMuted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(selectedSubTab == index ? MangaStyle.labelYellow : MangaStyle.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.strokeWidth)
                        )
                } else if MujiStyle.isActive {
                    Text(title)
                        .font(MujiStyle.labelFont(12, weight: selectedSubTab == index ? .semibold : .regular))
                        .foregroundStyle(selectedSubTab == index ? MujiStyle.onTint : MujiStyle.inkSoft)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(selectedSubTab == index ? MujiStyle.clay : MujiStyle.surface.opacity(0.72))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(selectedSubTab == index ? Color.clear : MujiStyle.hairline.opacity(0.44), lineWidth: 0.6)
                        )
                } else if NeumorphicStyle.isActive {
                    HStack(spacing: 7) {
                        MonologueIcon(
                            icon: neumorphicSubTabIcon(index),
                            size: 12,
                            color: selectedSubTab == index ? neumorphicSubTabTint(index) : NeumorphicStyle.inkSoft,
                            lineWidth: 1.55
                        )

                        Text(title)
                            .font(NeumorphicStyle.labelFont(12, weight: selectedSubTab == index ? .semibold : .medium))
                            .foregroundStyle(selectedSubTab == index ? NeumorphicStyle.ink : NeumorphicStyle.inkSoft)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        NeumorphicSurfaceBackground(
                            cornerRadius: 15,
                            elevated: selectedSubTab == index,
                            pressed: selectedSubTab != index,
                            tint: selectedSubTab == index ? neumorphicSubTabTint(index).opacity(0.18) : NeumorphicStyle.surface,
                            lightweight: true
                        )
                    )
                } else {
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
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func neumorphicSubTabIcon(_ index: Int) -> MonologueIcon.IconType {
        switch index {
        case 0: return .musicNoteList
        case 1, 2: return .list
        case 3: return .radio
        default: return .library
        }
    }

    private func neumorphicSubTabTint(_ index: Int) -> Color {
        switch index {
        case 0: return NeumorphicStyle.accent
        case 1: return MusicSource.netease.themedBadgeColor
        case 2: return MusicSource.qqmusic.themedBadgeColor
        case 3: return NeumorphicStyle.sage
        default: return NeumorphicStyle.warm
        }
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
                    if NeumorphicStyle.isActive {
                        VStack(spacing: 14) {
                            NeumorphicLibraryEmptyState(
                                icon: .musicNoteList,
                                title: String(localized: "lib_no_local_playlists"),
                                tint: NeumorphicStyle.accent
                            )
                            neumorphicLocalActionsRow
                        }
                        .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
                        .padding(.top, 24)
                    } else {
                        VStack(spacing: 16) {
                            MonologueIcon(icon: .musicNoteList, size: 40, color: .monologueTextSecondary.opacity(0.3))
                            Text(LocalizedStringKey("lib_no_local_playlists"))
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(Theme.secondaryText)

                            Button(action: showCreatePlaylistPrompt) {
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

                            Button(action: showLinkImportPrompt) {
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
                }
                .scrollIndicators(.hidden)
                .themeRenderScrollLayer()
            } else {
                List {
                    ScrollView(.horizontal, showsIndicators: false) {
                        Group {
                            if NeumorphicStyle.isActive {
                                neumorphicLocalActionsRow
                            } else {
                                standardLocalActionsRow
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .themeRenderScrollLayer()
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: PetWhiteStyle.isActive ? 12 : 20, bottom: 4, trailing: PetWhiteStyle.isActive ? 12 : 20))

                    ForEach(manager.playlists, id: \.id) { playlist in
                        ZStack {
                            NavigationLink(value: LibraryViewModel.NavigationDestination.localPlaylist(playlist.id)) {
                                EmptyView()
                            }
                            .opacity(0)

                            LocalPlaylistRow(summary: manager.summary(for: playlist))
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
                        .listRowInsets(EdgeInsets(top: 6, leading: PetWhiteStyle.isActive ? 12 : 20, bottom: 6, trailing: PetWhiteStyle.isActive ? 12 : 20))
                    }

                    FloatingBarBottomSpacer()
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
            }
        }
        .monologueSheet(isPresented: $showQQImport, preset: .large) {
            QQPlaylistImportView()
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            switch result {
            case let .success(urls):
                guard let url = urls.first else { return }
                importPlaylistFromFile(url: url)
            case let .failure(error):
                AlertManager.shared.show(
                    title: String(localized: "lib_import_failed"),
                    message: error.localizedDescription,
                    primaryButtonTitle: String(localized: "lib_confirm"),
                    primaryAction: {}
                )
            }
        }
    }

    private var neumorphicLocalActionsRow: some View {
        HStack(spacing: 9) {
            neumorphicLocalActionButton(icon: .add, title: String(localized: "lib_create_playlist"), tint: NeumorphicStyle.accent) {
                showCreatePlaylistPrompt()
            }

            neumorphicLocalActionButton(icon: .download, title: String(localized: "lib_import_playlist"), tint: NeumorphicStyle.warm, isLoading: isImporting) {
                showFileImporter = true
            }

            neumorphicLocalActionButton(icon: .share, title: String(localized: "从链接导入"), tint: NeumorphicStyle.sage, isLoading: isImporting) {
                showLinkImportPrompt()
            }

            neumorphicLocalActionButton(icon: .musicNoteList, title: "QCM", tint: MusicSource.qqmusic.themedBadgeColor) {
                showQQImport = true
            }
        }
    }

    private var standardLocalActionsRow: some View {
        HStack(spacing: 10) {
            Button(action: showCreatePlaylistPrompt) {
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

            Button(action: showLinkImportPrompt) {
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
    }

    private func neumorphicLocalActionButton(
        icon: MonologueIcon.IconType,
        title: String,
        tint: Color,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .tint(tint)
                        .scaleEffect(0.68)
                        .frame(width: 14, height: 14)
                } else {
                    MonologueIcon(icon: icon, size: 13, color: tint, lineWidth: 1.55)
                }

                Text(title)
                    .font(NeumorphicStyle.labelFont(12, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.ink)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                NeumorphicSurfaceBackground(
                    cornerRadius: 16,
                    elevated: true,
                    tint: tint.opacity(0.11),
                    lightweight: true
                )
            )
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
        .disabled(isLoading)
        .opacity(isLoading ? 0.72 : 1)
    }

    private func showCreatePlaylistPrompt() {
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
    }

    private func showLinkImportPrompt() {
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
                    let batch = Array(ids[i ..< min(i + batchSize, ids.count)])
                    do {
                        let songs: [Song] = try await withCheckedThrowingContinuation { continuation in
                            var cancellable: AnyCancellable?
                            cancellable = APIService.shared.fetchSongDetails(ids: batch)
                                .sink(receiveCompletion: { completion in
                                    if case let .failure(error) = completion {
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
                    AppLogger.info("[KugouImport] [\(index + 1)/\(total)] 搜索: \(keyword)")

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
            if ch == "\\", inString { escape = true; continue }
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

        let jsonString = String(html[startIndex ..< endIndex])

        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        else {
            AppLogger.error("[KugouImport] JSON 解析失败")
            return ("", [])
        }

        var playlistName = json["title"] as? String ?? json["name"] as? String ?? ""

        // 实际结构：info.listinfo.name
        if playlistName.isEmpty, let info = json["info"] as? [String: Any],
           let listinfo = info["listinfo"] as? [String: Any],
           let name = listinfo["name"] as? String
        {
            playlistName = name
        }

        var songs: [KugouSongInfo] = []

        // 实际结构：info.songs[]
        if let info = json["info"] as? [String: Any],
           let songList = info["songs"] as? [[String: Any]]
        {
            for item in songList {
                if let parsed = parseKugouSongItem(item) {
                    songs.append(parsed)
                }
            }
        }

        // 备用：顶层 songs 对象
        if songs.isEmpty, let songObj = json["songs"] as? [String: Any],
           let list = songObj["list"] as? [[String: Any]]
        {
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
                if !artist.isEmpty, !title.isEmpty {
                    return KugouSongInfo(title: title, artist: artist)
                }
            }
        }
        // 格式 2: singerinfo + remark/songname 分开字段
        if let singerInfo = item["singerinfo"] as? [[String: Any]],
           let firstSinger = singerInfo.first,
           let singerName = firstSinger["name"] as? String
        {
            let songName = item["remark"] as? String ?? item["songname"] as? String ?? item["song_name"] as? String ?? ""
            if !songName.isEmpty {
                return KugouSongInfo(title: songName, artist: singerName)
            }
        }
        // 格式 3: singername + songname 直接字段
        if let songname = item["songname"] as? String ?? item["song_name"] as? String,
           let singername = item["singername"] as? String ?? item["author_name"] as? String
        {
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
                        if case let .failure(error) = completion, !resumed {
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
                        if case let .failure(error) = completion, !resumed {
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
                                if case let .failure(error) = completion, !resumed {
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
                            if case let .failure(error) = completion, !resumed {
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
                                if case let .failure(error) = completion, !resumed {
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

struct NeumorphicLibraryEmptyState: View {
    let icon: MonologueIcon.IconType
    let title: String
    var detail: String = ""
    var tint: Color = NeumorphicStyle.accent

    var body: some View {
        VStack(spacing: 12) {
            NeumorphicIconBadge(icon: icon, tint: tint, size: 56)

            Text(title)
                .font(NeumorphicStyle.bodyFont(15, weight: .semibold))
                .foregroundStyle(NeumorphicStyle.ink)
                .multilineTextAlignment(.center)

            if !detail.isEmpty {
                Text(detail)
                    .font(NeumorphicStyle.labelFont(12))
                    .foregroundStyle(NeumorphicStyle.inkMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .padding(.horizontal, 18)
        .background(NeumorphicSurfaceBackground(cornerRadius: 24, elevated: true))
    }
}

struct LocalPlaylistRow: View {
    let summary: LocalPlaylistSummary
    typealias Theme = PlaylistDetailView.Theme

    var body: some View {
        HStack(spacing: 14) {
            Group {
                if let url = summary.displayCoverUrl {
                    CachedAsyncImage(url: url.sized(200)) {
                        systemPlaceholder
                    }
                    .aspectRatio(contentMode: .fill)
                } else {
                    systemPlaceholder
                }
            }
            .frame(width: PetWhiteStyle.isActive ? 64 : DeviceLayout.listRowCoverStandard, height: PetWhiteStyle.isActive ? 64 : DeviceLayout.listRowCoverStandard)
            .cornerRadius(PetWhiteStyle.isActive ? 18 : (CapsuleStyle.isActive ? 16 : (SequoiaStyle.isActive ? 14 : 12)))
            .overlay {
                if PetWhiteStyle.isActive {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(PetWhiteStyle.stroke, lineWidth: 1.4)
                } else if SequoiaStyle.isActive {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(SequoiaStyle.separator.opacity(0.78), lineWidth: 0.6)
                } else if CapsuleStyle.isActive {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(CapsuleStyle.hairline.opacity(0.7), lineWidth: 0.8)
                }
            }
            .shadow(color: CapsuleStyle.isActive ? CapsuleStyle.accent.opacity(0.08) : (SequoiaStyle.isActive ? Color.black.opacity(0.04) : Color.black.opacity(0.08)), radius: CapsuleStyle.isActive ? 6 : (SequoiaStyle.isActive ? 3 : 4), x: 0, y: 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(summary.name)
                    .font(localRowTitleFont)
                    .foregroundColor(localRowPrimaryColor)
                    .lineLimit(1)

                Text(String(format: String(localized: "songs_count_format"), summary.trackCount))
                    .font(localRowSubtitleFont)
                    .foregroundColor(localRowSecondaryColor)
            }

            Spacer()

            if PetWhiteStyle.isActive {
                PetWhitePackIcon(icon: .chevronRight, size: 16, visualScale: 1.05, fallbackColor: PetWhiteStyle.stroke)
            } else {
                MonologueIcon(icon: .chevronRight, size: 12, color: localRowSecondaryColor.opacity(0.7))
            }
        }
        .padding(PetWhiteStyle.isActive ? 12 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if PetWhiteStyle.isActive {
                PetWhiteSurfaceBackground(cornerRadius: 22, elevated: false, tint: PetWhiteStyle.surfaceRaised, accent: PetWhiteStyle.mint)
            } else if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 20, elevated: true, lightweight: true)
            } else if CapsuleStyle.isActive {
                CapsuleSurfaceBackground(cornerRadius: 22, elevated: true, tint: CapsuleStyle.surface.opacity(0.9))
            } else if SequoiaStyle.isActive {
                SequoiaSurfaceBackground(cornerRadius: 20, elevated: false, role: .list)
            } else {
                Color.clear
                    .monologueGlass(cornerRadius: MangaStyle.isActive ? MangaStyle.cardRadius : (MujiStyle.isActive ? 10 : 18))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: PetWhiteStyle.isActive ? 22 : (NeumorphicStyle.isActive ? 20 : (MangaStyle.isActive ? MangaStyle.cardRadius : (MujiStyle.isActive ? 10 : (CapsuleStyle.isActive ? 22 : (SequoiaStyle.isActive ? 20 : 18))))), style: .continuous))
    }

    private var systemPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    summary.isFavorite
                        ? LinearGradient(colors: [.pink.opacity(0.6), .red.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : summary.isDownload
                        ? LinearGradient(colors: [.blue.opacity(0.5), .cyan.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(
                            colors: [
                                PetWhiteStyle.isActive ? PetWhiteStyle.surfacePressed : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : (SequoiaStyle.isActive ? SequoiaStyle.materialList : Color.monologueGlassTint)),
                                PetWhiteStyle.isActive ? PetWhiteStyle.mint.opacity(0.52) : (NeumorphicStyle.isActive ? NeumorphicStyle.surface : (SequoiaStyle.isActive ? SequoiaStyle.materialRaised : Color.monologueGlassTint)),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                )
            MonologueIcon(
                icon: summary.isFavorite ? .liked : summary.isDownload ? .download : .musicNoteList,
                size: 24,
                color: summary.isSystem ? .white : (PetWhiteStyle.isActive ? PetWhiteStyle.stroke.opacity(0.54) : (NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : (SequoiaStyle.isActive ? SequoiaStyle.inkMuted : .monologueTextSecondary.opacity(0.3))))
            )
        }
    }

    private var localRowTitleFont: Font {
        if PetWhiteStyle.isActive {
            return PetWhiteStyle.bodyFont(16, weight: .black)
        }
        if MangaStyle.isActive {
            return MangaStyle.comicFont(15, weight: .bold)
        }
        if MujiStyle.isActive {
            return MujiStyle.bodyFont(15, weight: .regular)
        }
        if NeumorphicStyle.isActive {
            return NeumorphicStyle.bodyFont(15, weight: .semibold)
        }
        if CapsuleStyle.isActive {
            return CapsuleStyle.bodyFont(15, weight: .bold)
        }
        if SequoiaStyle.isActive {
            return SequoiaStyle.bodyFont(15, weight: .semibold)
        }
        return .system(size: 15, weight: .semibold, design: .rounded)
    }

    private var localRowSubtitleFont: Font {
        if PetWhiteStyle.isActive {
            return PetWhiteStyle.labelFont(12, weight: .semibold)
        }
        if MangaStyle.isActive {
            return MangaStyle.comicFont(12, weight: .medium)
        }
        if MujiStyle.isActive {
            return MujiStyle.labelFont(12, weight: .regular)
        }
        if NeumorphicStyle.isActive {
            return NeumorphicStyle.labelFont(12, weight: .medium)
        }
        if CapsuleStyle.isActive {
            return CapsuleStyle.labelFont(12, weight: .semibold)
        }
        if SequoiaStyle.isActive {
            return SequoiaStyle.labelFont(12, weight: .regular)
        }
        return .system(size: 12, weight: .medium, design: .rounded)
    }

    private var localRowPrimaryColor: Color {
        if PetWhiteStyle.isActive { return PetWhiteStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        if CapsuleStyle.isActive { return CapsuleStyle.ink }
        return NeumorphicStyle.isActive ? NeumorphicStyle.ink : Theme.text
    }

    private var localRowSecondaryColor: Color {
        if PetWhiteStyle.isActive { return PetWhiteStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        if CapsuleStyle.isActive { return CapsuleStyle.inkSoft }
        return NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : Theme.secondaryText
    }
}

// MARK: - 我的播客（订阅的播客列表）

struct MyPodcastsView: View {
    typealias Theme = PlaylistDetailView.Theme
    @ObservedObject private var subManager = SubscriptionManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    @State private var selectedTab: Int = 0

    var body: some View {
        let _ = settings.globalThemeRevision
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
            if NeumorphicStyle.isActive {
                HStack(spacing: 7) {
                    MonologueIcon(
                        icon: index == 0 ? .liked : .radio,
                        size: 13,
                        color: selectedTab == index ? NeumorphicStyle.sage : NeumorphicStyle.inkSoft,
                        lineWidth: 1.55
                    )
                    Text(title)
                        .font(NeumorphicStyle.labelFont(12, weight: selectedTab == index ? .semibold : .medium))
                        .foregroundStyle(selectedTab == index ? NeumorphicStyle.ink : NeumorphicStyle.inkSoft)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(
                    NeumorphicSurfaceBackground(
                        cornerRadius: 15,
                        elevated: selectedTab == index,
                        pressed: selectedTab != index,
                        tint: selectedTab == index ? NeumorphicStyle.sage.opacity(0.16) : NeumorphicStyle.surface
                    )
                )
            } else {
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
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.plain)
    }

    private var localPodcastsList: some View {
        Group {
            if subManager.localSubscribedRadios.isEmpty {
                ScrollView {
                    if NeumorphicStyle.isActive {
                        NeumorphicLibraryEmptyState(
                            icon: .radio,
                            title: String(localized: "暂无本地收藏"),
                            tint: NeumorphicStyle.sage
                        )
                        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                        .padding(.top, 24)
                    } else {
                        VStack(spacing: 16) {
                            MonologueIcon(icon: .radio, size: 40, color: .monologueTextSecondary.opacity(0.3))
                            Text("暂无本地收藏")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(Theme.secondaryText)
                        }
                        .padding(.top, 50)
                    }
                }
                .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
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

                    FloatingBarBottomSpacer()
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
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
            .themeRenderScrollLayer()
            } else if subManager.subscribedRadios.isEmpty {
                ScrollView {
                    if NeumorphicStyle.isActive {
                        NeumorphicLibraryEmptyState(
                            icon: .radio,
                            title: String(localized: "lib_no_podcasts"),
                            detail: String(localized: "lib_discover_podcasts"),
                            tint: MusicSource.netease.themedBadgeColor
                        )
                        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                        .padding(.top, 24)
                    } else {
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
                }
                .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
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

                    FloatingBarBottomSpacer()
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
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
                    .font(NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(14, weight: .semibold) : .system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monologueTextPrimary)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    if let dj = radio.dj?.nickname {
                        Text(dj)
                            .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(11) : .system(size: 11, design: .rounded))
                            .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : .monologueTextSecondary)
                    }
                    if let count = radio.programCount, count > 0 {
                        Text("·")
                            .font(.system(size: 11))
                            .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : .monologueTextSecondary)
                        Text(String(format: String(localized: "lib_episode_count"), count))
                            .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(11) : .system(size: 11, design: .rounded))
                            .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : .monologueTextSecondary)
                    }
                }
            }

            Spacer()

            MonologueIcon(icon: .chevronRight, size: 12, color: (NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : .monologueTextSecondary).opacity(0.7))
        }
        .padding(NeumorphicStyle.isActive ? 12 : 0)
        .padding(.vertical, NeumorphicStyle.isActive ? 0 : 5)
        .background {
            if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 20, elevated: true, lightweight: true)
            }
        }
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
                    if NeumorphicStyle.isActive {
                        NeumorphicLibraryEmptyState(
                            icon: .musicNoteList,
                            title: isAppLoggedIn ? String(localized: "暂无歌单，快去收藏一些吧！") : String(localized: "请先登录 NCM"),
                            tint: MusicSource.netease.themedBadgeColor
                        )
                        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                        .padding(.top, 24)
                    } else {
                        VStack(spacing: 16) {
                            MonologueIcon(icon: .musicNoteList, size: 40, color: .monologueTextSecondary.opacity(0.3))
                            Text(isAppLoggedIn ? String(localized: "暂无歌单，快去收藏一些吧！") : String(localized: "请先登录 NCM"))
                                .font(.rounded(size: 14, weight: .medium))
                                .foregroundColor(.monologueTextSecondary)
                        }
                        .padding(.top, 50)
                    }
                }
                .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
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

                    FloatingBarBottomSpacer()
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
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
              let creatorId = playlist.creator?.userId
        else {
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
            .themeRenderScrollLayer()
            } else if qqPlaylists.isEmpty {
                ScrollView {
                    if NeumorphicStyle.isActive {
                        NeumorphicLibraryEmptyState(
                            icon: .musicNoteList,
                            title: qqSession.isLoggedIn ? String(localized: "暂无歌单，快去收藏一些吧！") : String(localized: "请先登录 QCM"),
                            tint: MusicSource.qqmusic.themedBadgeColor
                        )
                        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                        .padding(.top, 24)
                    } else {
                        VStack(spacing: 16) {
                            MonologueIcon(icon: .musicNoteList, size: 40, color: .monologueTextSecondary.opacity(0.3))
                            Text(qqSession.isLoggedIn ? String(localized: "暂无歌单，快去收藏一些吧！") : String(localized: "请先登录 QCM"))
                                .font(.rounded(size: 14, weight: .medium))
                                .foregroundColor(.monologueTextSecondary)
                        }
                        .padding(.top, 50)
                    }
                }
                .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
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

                    FloatingBarBottomSpacer()
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
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

    private func loadPlaylists(force _: Bool = false) async {
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
    var usesPlatformTint = true
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
                    let tint = s == .ncm ? MusicSource.netease.themedBadgeColor : MusicSource.qqmusic.themedBadgeColor
                    let selected = source == s

                    Text(s == .ncm ? "NCM" : "QCM")
                        .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: selected ? .semibold : .medium) : .system(size: 13, weight: selected ? .bold : .medium, design: .rounded))
                        .foregroundColor(sourceForeground(selected: selected, tint: tint))
                        .padding(.horizontal, NeumorphicStyle.isActive ? 13 : 14)
                        .padding(.vertical, NeumorphicStyle.isActive ? 8 : 7)
                        .background {
                            if NeumorphicStyle.isActive {
                                NeumorphicSurfaceBackground(
                                    cornerRadius: 14,
                                    elevated: selected,
                                    pressed: !selected,
                                    tint: sourceBackgroundTint(selected: selected, tint: tint),
                                    lightweight: true
                                )
                            } else if selected {
                                Capsule()
                                    .fill(sourceSelectedFill(tint: tint))
                                    .matchedGeometryEffect(id: "sourcePill", in: ns)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(NeumorphicStyle.isActive ? 5 : 3)
        .background {
            if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 18, elevated: true)
            } else {
                Capsule().fill(Color.monologueTextPrimary.opacity(0.06))
            }
        }
    }

    private func sourceForeground(selected: Bool, tint: Color) -> Color {
        if usesPlatformTint {
            return selected ? tint : tint.opacity(0.66)
        }
        if NeumorphicStyle.isActive {
            return selected ? NeumorphicStyle.ink : NeumorphicStyle.inkSoft
        }
        return selected ? .monologueIconForeground : .monologueTextPrimary
    }

    private func sourceSelectedFill(tint: Color) -> Color {
        usesPlatformTint ? tint.opacity(0.13) : .monologueIconBackground
    }

    private func sourceBackgroundTint(selected: Bool, tint: Color) -> Color {
        guard selected else { return NeumorphicStyle.surface }
        return usesPlatformTint ? tint.opacity(0.16) : NeumorphicStyle.accent.opacity(0.14)
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
                MusicSourcePicker(source: $viewModel.squareSource, usesPlatformTint: false)
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
                    LibraryLoadingStateView()
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
                            LibraryInlineLoadingView()
                        }
                        if !viewModel.hasMoreSquarePlaylists && !viewModel.squarePlaylists.isEmpty {
                            NoMoreDataView()
                        }
                    }
                    .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
                    .padding(.top, 8)
                }

                FloatingBarBottomSpacer()
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
            .scrollContentBackground(.hidden)
        }
    }

    // MARK: - QQ Content

    private var qqContent: some View {
        VStack(spacing: 0) {
            qqCategoryBar

            ScrollView {
                if viewModel.isLoadingQQSquare && viewModel.qqSquarePlaylists.isEmpty {
                    LibraryLoadingStateView()
                } else if viewModel.qqSquarePlaylists.isEmpty {
                    if NeumorphicStyle.isActive {
                        NeumorphicLibraryEmptyState(
                            icon: .musicNoteList,
                            title: String(localized: "暂无QCM推荐歌单"),
                            tint: MusicSource.qqmusic.themedBadgeColor
                        )
                        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                        .padding(.top, 24)
                    } else {
                        VStack(spacing: 16) {
                            MonologueIcon(icon: .musicNoteList, size: 50, color: Theme.secondaryText.opacity(0.5))
                            Text("暂无QCM推荐歌单")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(Theme.secondaryText)
                        }
                        .padding(.top, 50)
                    }
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
                            LibraryInlineLoadingView()
                        }
                        if !viewModel.hasMoreQQSquare && !viewModel.qqSquarePlaylists.isEmpty {
                            NoMoreDataView()
                        }
                    }
                    .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
                    .padding(.top, 8)
                }

                FloatingBarBottomSpacer()
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
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
                            .font(categoryFont(selected: selected))
                            .foregroundColor(categoryForeground(selected: selected, neumorphicTint: MusicSource.qqmusic.themedBadgeColor))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background {
                                if NeumorphicStyle.isActive {
                                    NeumorphicSurfaceBackground(
                                        cornerRadius: 16,
                                        elevated: selected,
                                        pressed: !selected,
                                        tint: selected ? MusicSource.qqmusic.themedBadgeColor.opacity(0.16) : NeumorphicStyle.surface,
                                        lightweight: true
                                    )
                                } else if selected {
                                    Capsule()
                                        .fill(Color.monologueIconBackground)
                                        .matchedGeometryEffect(id: "qqCatPill", in: categoryNS)
                                } else if MujiStyle.isActive, selected {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(MujiStyle.clay)
                                        .matchedGeometryEffect(id: "qqCatPill", in: categoryNS)
                                }
                            }
                            .background {
                                if MujiStyle.isActive {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(selected ? Color.clear : MujiStyle.surface.opacity(0.78))
                                } else if !NeumorphicStyle.isActive {
                                    Capsule().fill(selected ? Color.clear : Color.monologueGlassTint)
                                }
                            }
                            .overlay {
                                if MujiStyle.isActive {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(selected ? Color.clear : MujiStyle.hairline.opacity(0.5), lineWidth: 0.6)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
            .padding(.vertical, 14)
        }
        .themeRenderScrollLayer()
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
                            .font(categoryFont(selected: selected))
                            .foregroundColor(categoryForeground(selected: selected, neumorphicTint: MusicSource.netease.themedBadgeColor))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background {
                                if NeumorphicStyle.isActive {
                                    NeumorphicSurfaceBackground(
                                        cornerRadius: 16,
                                        elevated: selected,
                                        pressed: !selected,
                                        tint: selected ? MusicSource.netease.themedBadgeColor.opacity(0.16) : NeumorphicStyle.surface,
                                        lightweight: true
                                    )
                                } else if selected {
                                    Capsule()
                                        .fill(Color.monologueIconBackground)
                                        .matchedGeometryEffect(id: "squareCatPill", in: categoryNS)
                                } else if MujiStyle.isActive, selected {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(MujiStyle.clay)
                                        .matchedGeometryEffect(id: "squareCatPill", in: categoryNS)
                                }
                            }
                            .background {
                                if MujiStyle.isActive {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(selected ? Color.clear : MujiStyle.surface.opacity(0.78))
                                } else if !NeumorphicStyle.isActive {
                                    Capsule().fill(selected ? Color.clear : Color.monologueGlassTint)
                                }
                            }
                            .overlay {
                                if MujiStyle.isActive {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(selected ? Color.clear : MujiStyle.hairline.opacity(0.5), lineWidth: 0.6)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
            .padding(.vertical, 14)
        }
        .themeRenderScrollLayer()
    }

    private func categoryFont(selected: Bool) -> Font {
        if NeumorphicStyle.isActive {
            return NeumorphicStyle.labelFont(12, weight: selected ? .semibold : .medium)
        }
        if MujiStyle.isActive {
            return MujiStyle.labelFont(12, weight: selected ? .semibold : .regular)
        }
        return .system(size: 13, weight: selected ? .semibold : .medium, design: .rounded)
    }

    private func categoryForeground(selected: Bool, neumorphicTint: Color) -> Color {
        if NeumorphicStyle.isActive {
            return selected ? neumorphicTint : NeumorphicStyle.inkSoft
        }
        if MujiStyle.isActive {
            return selected
                ? ThemeColorCustomization.readableForegroundColor(on: MujiStyle.clay, light: MujiStyle.ink, dark: Color.white)
                : MujiStyle.inkSoft
        }
        return selected ? .monologueIconForeground : .monologueTextPrimary
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

struct CinematicCard: View {
    let playlist: Playlist
    let height: CGFloat

    var body: some View {
        if NeumorphicStyle.isActive {
            cardCore
                .padding(8)
                .background(NeumorphicSurfaceBackground(cornerRadius: 26, elevated: true))
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        } else {
            cardCore
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
        }
    }

    private var cardCore: some View {
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
                    .init(color: .black.opacity(0.82), location: 1.0),
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
                            MonologueIcon(icon: .play, size: 8, color: .white.opacity(0.75), lineWidth: 1.8)
                            Text(cinematicFormatCount(count))
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(.white.opacity(0.75))
                    }
                }

                Spacer()

                if height > 200 {
                    MonologueIcon(icon: .play, size: 15, color: .white, lineWidth: 2)
                        .padding(13)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

func cinematicFormatCount(_ count: Int) -> String {
    let lang = Locale.current.language.languageCode?.identifier
    if lang == "zh" {
        if count >= 100_000_000 { return String(format: NSLocalizedString("count_hundred_million", comment: ""), Double(count) / 100_000_000) }
        if count >= 10000 { return String(format: NSLocalizedString("count_ten_thousand", comment: ""), Double(count) / 10000) }
    } else {
        if count >= 1_000_000_000 { return String(format: "%.1fB", Double(count) / 1_000_000_000) }
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1000 { return String(format: "%.1fK", Double(count) / 1000) }
    }
    return "\(count)"
}

// MARK: - Staggered Entrance Animation

struct CinematicStaggerIn: ViewModifier {
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

struct CinematicPressStyle: ButtonStyle {
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
                MusicSourcePicker(source: $viewModel.artistSource, usesPlatformTint: false)
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
                    MonologueIcon(icon: .magnifyingGlass, size: 18, color: NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : Theme.secondaryText)

                    TextField(LocalizedStringKey("search_artists"), text: $viewModel.artistSearchText)
                        .font(NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(15, weight: .medium) : .system(size: 16, design: .rounded))
                        .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : Theme.text)
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
                            MonologueIcon(icon: .xmark, size: 18, color: NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : Theme.secondaryText)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background {
                    if NeumorphicStyle.isActive {
                        NeumorphicSurfaceBackground(cornerRadius: 20, elevated: false, pressed: true, lightweight: true)
                    } else {
                        Color.clear.monologueGlass(cornerRadius: 20)
                    }
                }

                if !viewModel.isSearchingArtists {
                    Button(action: {
                        dismissArtistSearchKeyboard()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showFilters.toggle()
                        }
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(NeumorphicStyle.isActive ? Color.clear : (hasActiveFilter ? Color.monologueGlassTint : Color.clear))
                                .background {
                                    if NeumorphicStyle.isActive {
                                        NeumorphicSurfaceBackground(
                                            cornerRadius: 14,
                                            elevated: hasActiveFilter,
                                            pressed: !hasActiveFilter,
                                            tint: hasActiveFilter ? NeumorphicStyle.sage.opacity(0.16) : NeumorphicStyle.surface,
                                            lightweight: true
                                        )
                                    } else {
                                        Color.clear.monologueGlass(cornerRadius: 14)
                                    }
                                }

                            MonologueIcon(
                                icon: .filter,
                                size: 18,
                                color: NeumorphicStyle.isActive ? (hasActiveFilter ? NeumorphicStyle.sage : NeumorphicStyle.inkMuted) : (hasActiveFilter ? .monologueIconForeground : Theme.secondaryText)
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

            LibraryDisclosureReveal(isExpanded: !viewModel.isSearchingArtists && showFilters) {
                VStack(alignment: .leading, spacing: 12) {
                    ScrollView(.horizontal) {
                        filterRow(options: viewModel.artistAreas.map { ($0.name, $0.value) }, selected: $viewModel.artistArea) {
                            viewModel.fetchArtistData(reset: true)
                        }
                        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    }
                    .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
                    ScrollView(.horizontal) {
                        filterRow(options: viewModel.artistTypes.map { ($0.name, $0.value) }, selected: $viewModel.artistType) {
                            viewModel.fetchArtistData(reset: true)
                        }
                        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    }
                    .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
                    ScrollView(.horizontal) {
                        filterRow(options: viewModel.artistInitials.map { ($0 == "-1" ? "search_hot" : $0, $0) }, selected: $viewModel.artistInitial) {
                            viewModel.fetchArtistData(reset: true)
                        }
                        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    }
                    .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
                }
                .padding(.bottom, 16)
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
                    MonologueIcon(icon: .magnifyingGlass, size: 18, color: NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : Theme.secondaryText)

                    TextField(String(localized: "搜索QCM歌手"), text: $viewModel.qqArtistSearchText)
                        .font(NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(15, weight: .medium) : .system(size: 16, design: .rounded))
                        .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : Theme.text)
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
                            MonologueIcon(icon: .xmark, size: 18, color: NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : Theme.secondaryText)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background {
                    if NeumorphicStyle.isActive {
                        NeumorphicSurfaceBackground(cornerRadius: 20, elevated: false, pressed: true, lightweight: true)
                    } else {
                        Color.clear.monologueGlass(cornerRadius: 20)
                    }
                }

                if !viewModel.isSearchingQQArtists {
                    Button(action: {
                        dismissArtistSearchKeyboard()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showQQFilters.toggle()
                        }
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(NeumorphicStyle.isActive ? Color.clear : (hasActiveQQFilter ? Color.monologueGlassTint : Color.clear))
                                .background {
                                    if NeumorphicStyle.isActive {
                                        NeumorphicSurfaceBackground(
                                            cornerRadius: 14,
                                            elevated: hasActiveQQFilter,
                                            pressed: !hasActiveQQFilter,
                                            tint: hasActiveQQFilter ? MusicSource.qqmusic.themedBadgeColor.opacity(0.15) : NeumorphicStyle.surface,
                                            lightweight: true
                                        )
                                    } else {
                                        Color.clear.monologueGlass(cornerRadius: 14)
                                    }
                                }

                            MonologueIcon(
                                icon: .filter,
                                size: 18,
                                color: NeumorphicStyle.isActive ? (hasActiveQQFilter ? MusicSource.qqmusic.themedBadgeColor : NeumorphicStyle.inkMuted) : (hasActiveQQFilter ? .monologueIconForeground : Theme.secondaryText)
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

            LibraryDisclosureReveal(isExpanded: !viewModel.isSearchingQQArtists && showQQFilters) {
                VStack(alignment: .leading, spacing: 12) {
                    ScrollView(.horizontal) {
                        qqFilterRow(options: viewModel.qqArtistAreas, selected: $viewModel.qqArtistArea)
                            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    }
                    .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
                    ScrollView(.horizontal) {
                        qqFilterRow(options: viewModel.qqArtistSexes, selected: $viewModel.qqArtistSex)
                            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    }
                    .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
                    ScrollView(.horizontal) {
                        qqFilterRow(options: viewModel.qqArtistGenres, selected: $viewModel.qqArtistGenre)
                            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    }
                    .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
                }
                .padding(.bottom, 16)
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
                LibraryLoadingStateView(horizontalPadding: DeviceLayout.viewHorizontalPadding)
            } else if artists.isEmpty {
                if NeumorphicStyle.isActive {
                    NeumorphicLibraryEmptyState(
                        icon: .personEmpty,
                        title: String(localized: "empty_no_artists"),
                        tint: NeumorphicStyle.sage
                    )
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.top, 24)
                } else {
                    VStack(spacing: 16) {
                        MonologueIcon(icon: .personEmpty, size: 50, color: Theme.secondaryText.opacity(0.5))
                        Text(LocalizedStringKey("empty_no_artists"))
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.secondaryText)
                    }
                    .padding(.top, 50)
                }
            } else {
                LazyVGrid(columns: columns, spacing: 24) {
                    ForEach(Array(artists.enumerated()), id: \.element.id) { index, artist in
                        NavigationLink(value: LibraryViewModel.NavigationDestination.artistInfo(artist)) {
                            VStack(spacing: 12) {
                                CachedAsyncImage(url: artist.coverUrl?.sized(400)) {
                                    NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.gray.opacity(0.1)
                                }
                                .aspectRatio(contentMode: .fill)
                                .frame(
                                    width: NeumorphicStyle.isActive ? DeviceLayout.artistAvatarSize - 10 : DeviceLayout.artistAvatarSize,
                                    height: NeumorphicStyle.isActive ? DeviceLayout.artistAvatarSize - 10 : DeviceLayout.artistAvatarSize
                                )
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(NeumorphicStyle.isActive ? 0.06 : 0.1), radius: 8, x: 0, y: 4)

                                Text(artist.name)
                                    .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(13, weight: .semibold) : .system(size: 14, weight: .semibold, design: .rounded))
                                    .lineLimit(1)
                                    .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : Theme.text)
                            }
                            .padding(NeumorphicStyle.isActive ? 12 : 0)
                            .frame(maxWidth: .infinity)
                            .background {
                                if NeumorphicStyle.isActive {
                                    NeumorphicSurfaceBackground(cornerRadius: 22, elevated: true, lightweight: true)
                                }
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
                    LibraryInlineLoadingView()
                }
                if !hasMore && !artists.isEmpty && !isSearching {
                    NoMoreDataView()
                }
            }

            FloatingBarBottomSpacer()
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
            .themeRenderScrollLayer()
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
                    let isSelected = selected.wrappedValue == option.1
                    if NeumorphicStyle.isActive {
                        NeumorphicPill(
                            text: NSLocalizedString(option.0, comment: ""),
                            tint: NeumorphicStyle.sage,
                            selected: isSelected
                        )
                    } else if MujiStyle.isActive {
                        mujiFilterPill(title: NSLocalizedString(option.0, comment: ""), selected: isSelected)
                    } else {
                        Text(LocalizedStringKey(option.0))
                            .font(.system(size: 13, weight: isSelected ? .semibold : .medium, design: .rounded))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(isSelected ? Color.monologueIconBackground : Color.monologueGlassTint))
                            .foregroundColor(isSelected ? .monologueIconForeground : .monologueTextPrimary)
                    }
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
                    let isSelected = selected.wrappedValue == option.value
                    if NeumorphicStyle.isActive {
                        NeumorphicPill(
                            text: NSLocalizedString(option.name, comment: ""),
                            tint: MusicSource.qqmusic.themedBadgeColor,
                            selected: isSelected
                        )
                    } else if MujiStyle.isActive {
                        mujiFilterPill(title: NSLocalizedString(option.name, comment: ""), selected: isSelected)
                    } else {
                        Text(LocalizedStringKey(option.name))
                            .font(.system(size: 13, weight: isSelected ? .semibold : .medium, design: .rounded))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(isSelected ? Color.monologueIconBackground : Color.monologueGlassTint))
                            .foregroundColor(isSelected ? .monologueIconForeground : .monologueTextPrimary)
                    }
                }
                .buttonStyle(MonologueBouncingButtonStyle())
            }
        }
    }

    private func mujiFilterPill(title: String, selected: Bool) -> some View {
        Text(title)
            .font(MujiStyle.labelFont(12, weight: selected ? .semibold : .regular))
            .foregroundStyle(selected ? ThemeColorCustomization.readableForegroundColor(on: MujiStyle.clay, light: MujiStyle.ink, dark: Color.white) : MujiStyle.inkSoft)
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selected ? MujiStyle.clay : MujiStyle.surface.opacity(0.78))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(selected ? Color.clear : MujiStyle.hairline.opacity(0.5), lineWidth: 0.6)
            )
    }

    private func dismissArtistSearchKeyboard() {
        focusedSearchField = nil
    }
}

struct LibraryDisclosureReveal<Content: View>: View {
    let isExpanded: Bool
    let content: Content
    @State private var measuredHeight: CGFloat = 0

    init(isExpanded: Bool, @ViewBuilder content: () -> Content) {
        self.isExpanded = isExpanded
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .top) {
            if isExpanded {
                content
                    .fixedSize(horizontal: false, vertical: true)
                    .background {
                        GeometryReader { proxy in
                            Color.clear
                                .onAppear { updateMeasuredHeight(proxy.size.height) }
                                .onChange(of: proxy.size.height) { _, newValue in
                                    updateMeasuredHeight(newValue)
                                }
                        }
                    }
            }
        }
        .frame(height: isExpanded ? measuredHeight : 0, alignment: .top)
        .clipShape(Rectangle())
        .clipped()
        .allowsHitTesting(isExpanded)
        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: isExpanded)
    }

    private func updateMeasuredHeight(_ height: CGFloat) {
        guard height > 0, abs(measuredHeight - height) > 0.5 else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            measuredHeight = height
        }
    }
}

struct ChartsLibraryView: View {
    @ObservedObject var viewModel: LibraryViewModel
    typealias Theme = PlaylistDetailView.Theme

    private let officialIds: Set<Int> = [19_723_756, 3_779_629, 2_884_035, 3_778_678]

    private var officialCharts: [TopList] {
        viewModel.topLists.filter { officialIds.contains($0.id) }
    }

    private var otherCharts: [TopList] {
        viewModel.topLists.filter { !officialIds.contains($0.id) }
    }

    let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: DeviceLayout.artistGridColumns)

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                MusicSourcePicker(source: $viewModel.chartsSource, usesPlatformTint: false)
                Spacer()
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 4)
            .onChange(of: viewModel.chartsSource) { _, newSource in
                if newSource == .qq {
                    viewModel.fetchQQTopLists()
                } else {
                    viewModel.fetchTopLists()
                }
            }

            if viewModel.chartsSource == .qq {
                qqChartsContent
            } else {
                ncmChartsContent
            }
        }
        .background(Color.clear)
    }

    // MARK: - NCM Charts

    private var ncmChartsContent: some View {
        ScrollView {
            if viewModel.isLoadingCharts && viewModel.topLists.isEmpty {
                LibraryLoadingStateView(horizontalPadding: DeviceLayout.viewHorizontalPadding)
            } else if viewModel.topLists.isEmpty {
                if NeumorphicStyle.isActive {
                    NeumorphicLibraryEmptyState(
                        icon: .chart,
                        title: String(localized: "empty_no_charts"),
                        tint: NeumorphicStyle.red
                    )
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.top, 24)
                } else {
                    VStack(spacing: 16) {
                        MonologueIcon(icon: .chart, size: 50, color: Theme.secondaryText.opacity(0.5))
                        Text(LocalizedStringKey("empty_no_charts"))
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.secondaryText)
                    }
                    .padding(.top, 50)
                }
            } else {
                VStack(alignment: .leading, spacing: 28) {
                    if !officialCharts.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(LocalizedStringKey("charts_official"))
                                .font(NeumorphicStyle.isActive ? NeumorphicStyle.titleFont(18, weight: .semibold) : .system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : Theme.text)
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
            .themeRenderScrollLayer()
                        }
                    }

                    if !otherCharts.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(LocalizedStringKey("charts_more"))
                                .font(NeumorphicStyle.isActive ? NeumorphicStyle.titleFont(18, weight: .semibold) : .system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : Theme.text)
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

            FloatingBarBottomSpacer()
        }
        .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        .scrollContentBackground(.hidden)
        .refreshable {
            await refreshCharts()
        }
    }

    // MARK: - QQ Charts

    private var qqChartsContent: some View {
        ScrollView {
            if viewModel.isLoadingQQCharts && viewModel.qqTopLists.isEmpty {
                LibraryLoadingStateView(horizontalPadding: DeviceLayout.viewHorizontalPadding)
            } else if viewModel.qqTopLists.isEmpty {
                if NeumorphicStyle.isActive {
                    NeumorphicLibraryEmptyState(
                        icon: .chart,
                        title: String(localized: "暂无QCM排行榜"),
                        tint: MusicSource.qqmusic.themedBadgeColor
                    )
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.top, 24)
                } else {
                    VStack(spacing: 16) {
                        MonologueIcon(icon: .chart, size: 50, color: Theme.secondaryText.opacity(0.5))
                        Text("暂无QCM排行榜")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.secondaryText)
                    }
                    .padding(.top, 50)
                }
            } else {
                VStack(alignment: .leading, spacing: 28) {
                    ForEach(viewModel.qqTopLists) { group in
                        VStack(alignment: .leading, spacing: 14) {
                            Text(group.groupName)
                                .font(NeumorphicStyle.isActive ? NeumorphicStyle.titleFont(18, weight: .semibold) : .system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : Theme.text)
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
            .themeRenderScrollLayer()
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

            FloatingBarBottomSpacer()
        }
        .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
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

struct QQChartCard: View {
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
                    .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .semibold) : .system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : Theme.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(minHeight: 32, alignment: .topLeading)

                Text(item.intro.isEmpty ? " " : item.intro)
                    .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(10, weight: .medium) : .system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : Theme.secondaryText)
                    .lineLimit(1)
            }
        }
        .padding(NeumorphicStyle.isActive ? 8 : 0)
        .background {
            if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 20, elevated: true, lightweight: true)
            }
        }
    }
}

// MARK: - QQ 官方排行榜大卡片

struct QQOfficialChartCard: View {
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

struct OfficialChartCard: View {
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

struct CompactChartCard: View {
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
                    .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .semibold) : .system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : Theme.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(minHeight: 32, alignment: .topLeading)

                Text(list.updateFrequency)
                    .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(10, weight: .medium) : .system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : Theme.secondaryText)
                    .lineLimit(1)
            }
        }
        .padding(NeumorphicStyle.isActive ? 8 : 0)
        .background {
            if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 20, elevated: true, lightweight: true)
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
                PetWhiteStyle.isActive ? PetWhiteStyle.surfacePressed : Color.gray.opacity(0.1)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: PetWhiteStyle.isActive ? 64 : DeviceLayout.listRowCoverStandard, height: PetWhiteStyle.isActive ? 64 : DeviceLayout.listRowCoverStandard)
            .cornerRadius(PetWhiteStyle.isActive ? 18 : (CapsuleStyle.isActive ? 16 : (SequoiaStyle.isActive ? 14 : 12)))
            .overlay {
                if PetWhiteStyle.isActive {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(PetWhiteStyle.stroke, lineWidth: 1.4)
                } else if SequoiaStyle.isActive {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(SequoiaStyle.separator.opacity(0.78), lineWidth: 0.6)
                } else if CapsuleStyle.isActive {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(CapsuleStyle.hairline.opacity(0.7), lineWidth: 0.8)
                }
            }
            .shadow(color: CapsuleStyle.isActive ? CapsuleStyle.accent.opacity(0.08) : (SequoiaStyle.isActive ? Color.black.opacity(0.04) : Color.black.opacity(0.08)), radius: CapsuleStyle.isActive ? 6 : (SequoiaStyle.isActive ? 3 : 4), x: 0, y: 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(PetWhiteStyle.isActive ? PetWhiteStyle.bodyFont(16, weight: .black) : (NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(15, weight: .semibold) : (CapsuleStyle.isActive ? CapsuleStyle.bodyFont(15, weight: .bold) : (SequoiaStyle.isActive ? SequoiaStyle.bodyFont(15, weight: .semibold) : .system(size: 15, weight: .semibold, design: .rounded)))))
                    .foregroundColor(PetWhiteStyle.isActive ? PetWhiteStyle.ink : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : (CapsuleStyle.isActive ? CapsuleStyle.ink : (SequoiaStyle.isActive ? SequoiaStyle.ink : Theme.text))))
                    .lineLimit(1)

                Text(String(format: NSLocalizedString("track_count_songs", comment: ""), playlist.trackCount ?? 0))
                    .font(PetWhiteStyle.isActive ? PetWhiteStyle.labelFont(12, weight: .semibold) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .medium) : (CapsuleStyle.isActive ? CapsuleStyle.labelFont(12, weight: .semibold) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(12, weight: .regular) : .system(size: 12, weight: .medium, design: .rounded)))))
                    .foregroundColor(PetWhiteStyle.isActive ? PetWhiteStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : (CapsuleStyle.isActive ? CapsuleStyle.inkSoft : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : Theme.secondaryText))))
            }

            Spacer()

            if PetWhiteStyle.isActive {
                PetWhitePackIcon(icon: .chevronRight, size: 16, visualScale: 1.05, fallbackColor: PetWhiteStyle.stroke)
            } else {
                MonologueIcon(icon: .chevronRight, size: 12, color: (NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : (CapsuleStyle.isActive ? CapsuleStyle.inkMuted : (SequoiaStyle.isActive ? SequoiaStyle.inkMuted : Theme.secondaryText))).opacity(0.7))
            }
        }
        .padding(PetWhiteStyle.isActive ? 12 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if PetWhiteStyle.isActive {
                PetWhiteSurfaceBackground(cornerRadius: 22, elevated: false, tint: PetWhiteStyle.surfaceRaised, accent: playlist.source == .qqmusic ? MusicSource.qqmusic.themedBadgeColor : PetWhiteStyle.mint)
            } else if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 20, elevated: true, lightweight: true)
            } else if CapsuleStyle.isActive {
                CapsuleSurfaceBackground(cornerRadius: 22, elevated: true, tint: CapsuleStyle.surface.opacity(0.9))
            } else if SequoiaStyle.isActive {
                SequoiaSurfaceBackground(cornerRadius: 20, elevated: false, role: .list)
            } else {
                Color.clear.monologueGlass(cornerRadius: 18)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: PetWhiteStyle.isActive ? 22 : (NeumorphicStyle.isActive ? 20 : (CapsuleStyle.isActive ? 22 : (SequoiaStyle.isActive ? 20 : 18))), style: .continuous))
    }
}
