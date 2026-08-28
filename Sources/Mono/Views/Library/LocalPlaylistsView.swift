import Combine
import QQMusicKit
import SwiftUI
import UniformTypeIdentifiers

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
                            MonoIcon(icon: .musicNoteList, size: 40, color: .monoTextSecondary.opacity(0.3))
                            Text(LocalizedStringKey("lib_no_local_playlists"))
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(Theme.secondaryText)

                            Button(action: showCreatePlaylistPrompt) {
                                HStack(spacing: 6) {
                                    MonoIcon(icon: .add, size: 14, color: .monoIconForeground)
                                    Text(LocalizedStringKey("lib_create_playlist"))
                                        .font(.system(size: 14, weight: .bold))
                                }
                                .foregroundColor(.monoIconForeground)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.monoIconBackground)
                                .cornerRadius(20)
                            }
                            .buttonStyle(MonoBouncingButtonStyle())

                            Button(action: { showFileImporter = true }) {
                                HStack(spacing: 6) {
                                    MonoIcon(icon: .download, size: 14, color: Theme.secondaryText)
                                    Text(LocalizedStringKey("lib_import_playlist"))
                                        .font(.system(size: 14, weight: .bold))
                                }
                                .foregroundColor(Theme.secondaryText)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.monoGlassTint)
                                .cornerRadius(20)
                            }
                            .buttonStyle(MonoBouncingButtonStyle())

                            Button(action: showLinkImportPrompt) {
                                HStack(spacing: 6) {
                                    MonoIcon(icon: .share, size: 14, color: Theme.secondaryText)
                                    Text("从链接导入")
                                        .font(.system(size: 14, weight: .bold))
                                }
                                .foregroundColor(Theme.secondaryText)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.monoGlassTint)
                                .cornerRadius(20)
                            }
                            .buttonStyle(MonoBouncingButtonStyle())

                            Button(action: { showQQImport = true }) {
                                HStack(spacing: 6) {
                                    MonoIcon(icon: .musicNoteList, size: 14, color: Theme.secondaryText)
                                    Text("QCM歌单")
                                        .font(.system(size: 14, weight: .bold))
                                }
                                .foregroundColor(Theme.secondaryText)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.monoGlassTint)
                                .cornerRadius(20)
                            }
                            .buttonStyle(MonoBouncingButtonStyle())
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
        .monoSheet(isPresented: $showQQImport, preset: .large) {
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
                    MonoIcon(icon: .add, size: 14, color: Theme.secondaryText)
                    Text(LocalizedStringKey("lib_create_playlist"))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Theme.text)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .monoGlassCapsule()
                .clipShape(Capsule())
            }
            .buttonStyle(MonoBouncingButtonStyle())

            Button(action: { showFileImporter = true }) {
                HStack(spacing: 6) {
                    if isImporting {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        MonoIcon(icon: .download, size: 14, color: Theme.secondaryText)
                    }
                    Text(LocalizedStringKey("lib_import_playlist"))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Theme.text)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .monoGlassCapsule()
                .clipShape(Capsule())
            }
            .buttonStyle(MonoBouncingButtonStyle())
            .disabled(isImporting)

            Button(action: showLinkImportPrompt) {
                HStack(spacing: 6) {
                    if isImporting {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        MonoIcon(icon: .share, size: 14, color: Theme.secondaryText)
                    }
                    Text("从链接导入")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Theme.text)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .monoGlassCapsule()
                .clipShape(Capsule())
            }
            .buttonStyle(MonoBouncingButtonStyle())
            .disabled(isImporting)

            Button(action: { showQQImport = true }) {
                HStack(spacing: 6) {
                    MonoIcon(icon: .musicNoteList, size: 14, color: Theme.secondaryText)
                    Text("QCM歌单")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Theme.text)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .monoGlassCapsule()
                .clipShape(Capsule())
            }
            .buttonStyle(MonoBouncingButtonStyle())
        }
    }

    private func neumorphicLocalActionButton(
        icon: MonoIcon.IconType,
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
                    MonoIcon(icon: icon, size: 13, color: tint, lineWidth: 1.55)
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
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
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
        viewModel.navigationPath.append(
            LibraryViewModel.NavigationDestination.externalPlaylistImport
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
                message: String(localized: "无法识别歌单链接，请使用 NCM、QCM、KCM、汽水音乐、Apple Music、Spotify 或酷我音乐的歌单分享链接"),
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
                                message: L10n.format(
                                    "playlist_import_match_result_format",
                                    matchedSongs.count,
                                    skipped
                                ),
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
                        message: L10n.format(
                            "kugou_playlist_import_failed_format",
                            error.localizedDescription
                        ),
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
                            message: String(localized: "playlist_empty_or_load_failed"),
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
                        message: L10n.format(
                            "qcm_playlist_import_failed_format",
                            error.localizedDescription
                        ),
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
                        message: String(localized: "playlist_empty_or_load_failed"),
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
