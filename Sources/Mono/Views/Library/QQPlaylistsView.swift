import Combine
import QQMusicKit
import SwiftUI
import UniformTypeIdentifiers

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
                            .foregroundColor(.monoTextSecondary)
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
                            title: qqSession.isLoggedIn ? String(localized: "暂无歌单，快去收藏一些吧！") : String(localized: "qcm_login_required"),
                            tint: MusicSource.qqmusic.themedBadgeColor
                        )
                        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                        .padding(.top, 24)
                    } else {
                        VStack(spacing: 16) {
                            MonoIcon(icon: .musicNoteList, size: 40, color: .monoTextSecondary.opacity(0.3))
                            Text(qqSession.isLoggedIn ? String(localized: "暂无歌单，快去收藏一些吧！") : String(localized: "qcm_login_required"))
                                .font(.rounded(size: 14, weight: .medium))
                                .foregroundColor(.monoTextSecondary)
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
        .onChange(of: qqSession.sessionRevision) { _, _ in
            qqPlaylists = []
            hasLoaded = false
            isLoading = false
            if qqSession.isLoggedIn {
                Task { await loadPlaylists(force: true) }
            }
        }
    }

    private func loadPlaylists(force _: Bool = false) async {
        let session = qqSession.sessionSnapshot
        guard !isLoading else { return }
        guard session.isLoggedIn, let mid = session.musicID else { return }
        isLoading = true
        defer {
            if qqSession.isCurrentSession(session) {
                isLoading = false
                hasLoaded = true
            }
        }

        do {
            let result: JSON = try await QQUserSession.shared.withUserSession { client in
                try await client.createdSonglist(uin: String(mid))
            }

            var items: [Playlist] = []
            // 新版 API: { playlists: [{ id, dirid, title, picurl, songnum }], total }
            let list = result["playlists"]?.arrayValue
                ?? result["v_playlist"]?.arrayValue
                ?? result.arrayValue ?? []
            for json in list {
                guard let obj = json.objectValue else { continue }
                let tid = obj["id"]?.intValue ?? obj["tid"]?.intValue ?? 0
                let name = obj["title"]?.stringValue ?? obj["dirName"]?.stringValue ?? obj["diss_name"]?.stringValue ?? ""
                let cover = obj["picurl"]?.stringValue ?? obj["picUrl"]?.stringValue ?? obj["logo"]?.stringValue ?? ""
                let songCount = obj["songnum"]?.intValue ?? obj["songNum"]?.intValue ?? obj["song_cnt"]?.intValue ?? 0
                if !name.isEmpty {
                    items.append(Playlist(
                        id: tid, name: name, coverImgUrl: cover, picUrl: nil,
                        trackCount: songCount, playCount: nil,
                        subscribedCount: nil, shareCount: nil, commentCount: nil,
                        creator: nil, description: nil, tags: nil, source: .qqmusic
                    ))
                }
            }
            guard qqSession.isCurrentSession(session) else { return }
            qqPlaylists = items
        } catch {
            guard qqSession.isCurrentSession(session) else { return }
            AppLogger.error("[QQPlaylists] 加载歌单失败: \(error)")
        }
    }
}
