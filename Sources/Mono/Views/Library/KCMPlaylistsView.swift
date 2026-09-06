import Combine
import QQMusicKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - KCM 歌单

struct KCMPlaylistsView: View {
    @ObservedObject var viewModel: LibraryViewModel

    var body: some View {
        Group {
            if viewModel.kugouUserPlaylists.isEmpty {
                ScrollView {
                    VStack(spacing: 16) {
                        MonoIcon(icon: .musicNoteList, size: 40, color: MusicSource.kugou.themedBadgeColor.opacity(0.55))
                        Text(KCMMusicService.shared.isAuthenticated ? "暂无 KCM 歌单" : "请先登录 KCM")
                            .font(.rounded(size: 14, weight: .medium))
                            .foregroundColor(.monoTextSecondary)
                    }
                    .padding(.top, 50)
                }
                .scrollIndicators(.hidden)
                .themeRenderScrollLayer()
            } else {
                List {
                    ForEach(viewModel.kugouUserPlaylists) { playlist in
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
                .refreshable { viewModel.loadKugouUserPlaylists(force: true) }
            }
        }
        .background(Color.clear)
        .onAppear {
            if KCMMusicService.shared.isAuthenticated, viewModel.kugouUserPlaylists.isEmpty {
                viewModel.loadKugouUserPlaylists()
            }
        }
    }
}

// MARK: - qcm歌单
