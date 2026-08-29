import SwiftUI

/// Apple Music 歌手曲目页：以歌手名为关键词分页搜索歌曲（每页 25 首），滚到底部自动加载更多。
struct AppleMusicArtistSongsView: View {
    let artist: ArtistInfo

    @State private var songs: [Song] = []
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var hasMore = true
    @State private var page = 0
    @State private var errorMessage: String?

    private let pageSize = 25

    var body: some View {
        ZStack {
            ThemedPageBackground(useRenderLayer: true)
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 14) {
                    header
                        .monoPageHeaderCollapse()

                    if isLoading, songs.isEmpty {
                        LibraryLoadingStateView(horizontalPadding: DeviceLayout.viewHorizontalPadding)
                    } else if songs.isEmpty {
                        ThemedLibraryEmptyState(
                            icon: .musicNote,
                            title: errorMessage ?? String(localized: "empty_no_songs"),
                            tint: MusicSource.appleMusic.themedBadgeColor
                        )
                        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                                SongListRow(
                                    song: song,
                                    index: index,
                                    onTap: {
                                        PlayerManager.shared.play(
                                            song: song,
                                            in: songs
                                        )
                                    }
                                )
                                .onAppear {
                                    if index == songs.count - 1 {
                                        loadMoreIfNeeded()
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

                        if isLoadingMore {
                            LibraryInlineLoadingView()
                        }
                    }

                    FloatingBarBottomSpacer()
                }
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .monoNavigationBackButton()
        .task {
            await load(reset: true)
        }
    }

    @ViewBuilder
    private var header: some View {
        if SignalStyle.isActive {
            HStack(spacing: 15) {
                ZStack {
                    SignalScreenBackground(cornerRadius: 9)
                    CachedAsyncImage(url: artist.coverUrl?.sized(600)) {
                        SignalStyle.controlPressed
                    }
                    .aspectRatio(contentMode: .fill)
                    .padding(7)
                }
                .frame(width: 86, height: 86)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 7) {
                        SignalPill(text: MusicSource.appleMusic.shortName, tint: SignalStyle.accent, selected: true, compact: true)
                        SignalPill(text: "ARTIST TRACKS", tint: SignalStyle.mint, compact: true)
                    }

                    Text(artist.name)
                        .font(SignalStyle.titleFont(23, weight: .bold))
                        .foregroundStyle(SignalStyle.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                }

                Spacer(minLength: 0)
            }
            .padding(15)
            .background(SignalSurfaceBackground(cornerRadius: 13, elevated: true, fill: SignalStyle.surface))
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 12)
        } else {
            HStack(spacing: 16) {
                CachedAsyncImage(url: artist.coverUrl?.sized(600)) {
                    Color.monoSeparator.opacity(0.22)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 82, height: 82)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 7) {
                    PlatformBadgeLabel(
                        text: MusicSource.appleMusic.shortName,
                        source: .appleMusic,
                        fontSize: 11
                    )

                    Text(artist.name)
                        .font(.rounded(size: 27, weight: .heavy))
                        .foregroundStyle(Color.monoTextPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 16)
        }
    }

    private func loadMoreIfNeeded() {
        guard hasMore, !isLoading, !isLoadingMore else { return }
        Task { await load(reset: false) }
    }

    @MainActor
    private func load(reset: Bool) async {
        if reset {
            page = 0
            hasMore = true
            songs = []
            errorMessage = nil
            isLoading = true
        } else {
            isLoadingMore = true
        }

        do {
            let result = try await AppleMusicService.shared.searchSongs(
                term: artist.name,
                offset: page * pageSize,
                limit: pageSize
            )
            if reset {
                songs = result.songs
            } else {
                let existingIDs = Set(songs.map {
                    PlayerManager.playbackIdentityKey(for: $0)
                })
                songs.append(contentsOf: result.songs.filter {
                    !existingIDs.contains(PlayerManager.playbackIdentityKey(for: $0))
                })
            }
            page += 1
            hasMore = result.hasMore
        } catch {
            errorMessage = error.localizedDescription
            hasMore = false
        }

        isLoading = false
        isLoadingMore = false
    }
}
