import Combine
import QQMusicKit
import SwiftUI
import UniformTypeIdentifiers

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
                            MonoIcon(icon: .musicNoteList, size: 40, color: .monoTextSecondary.opacity(0.3))
                            Text(isAppLoggedIn ? String(localized: "暂无歌单，快去收藏一些吧！") : String(localized: "请先登录 NCM"))
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
