import SwiftUI

extension PlaylistDetailView {
    var songListSection: some View {
        Group {
            if MinimalWhiteStyle.isActive {
                minimalWhiteSongListSection
            } else if CapsuleStyle.isActive {
                capsuleSongListSection
            } else if PetWhiteStyle.isActive {
                petWhiteSongListSection
            } else {
                defaultSongListSection
            }
        }
    }

    var minimalWhiteSongListSection: some View {
        LazyVStack(alignment: .leading, spacing: 14) {
            MinimalWhiteSectionTitle(title: String(localized: "歌曲")) {
                if !filteredSongs.isEmpty {
                    Text("\(filteredSongs.count)")
                        .font(MinimalWhiteStyle.labelFont(12, weight: .medium))
                        .foregroundStyle(MinimalWhiteStyle.inkMuted)
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

            if viewModel.isLoading {
                MonoLoadingView(text: "")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .background(
                        MinimalWhiteSurfaceBackground(
                            cornerRadius: MinimalWhiteStyle.cardRadius,
                            elevated: false,
                            tint: MinimalWhiteStyle.glassFill
                        )
                    )
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            } else if filteredSongs.isEmpty {
                playlistEmptyState
            } else {
                LazyVStack(spacing: 0) {
                    playlistSongRows
                    playlistPagination
                }
                .background(
                    MinimalWhiteSurfaceBackground(
                        cornerRadius: MinimalWhiteStyle.cardRadius,
                        elevated: false,
                        tint: MinimalWhiteStyle.glassFill
                    )
                )
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

                if !isSearching && !viewModel.relatedPlaylists.isEmpty && !viewModel.isLoading {
                    relatedPlaylistsSection
                }

                FloatingBarBottomSpacer()
            }
        }
        .padding(.top, 4)
    }

    var capsuleSongListSection: some View {
        LazyVStack(spacing: 16) {
            if viewModel.isLoading {
                CapsuleDetailSection(title: "TRACKS", icon: .musicNoteList, tint: CapsuleStyle.accent) {
                    MonoLoadingView(text: "LOADING TRACKS")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                }
            } else if filteredSongs.isEmpty {
                CapsuleDetailSection(title: "TRACKS", icon: .musicNoteList, tint: CapsuleStyle.accent) {
                    CapsuleDetailEmptyState(title: "album_no_songs", icon: .musicNoteList, tint: CapsuleStyle.accent)
                }
            } else {
                CapsuleDetailSection(
                    title: "TRACKS",
                    subtitle: String(format: NSLocalizedString("songs_count_format", comment: ""), filteredSongs.count),
                    icon: .musicNoteList,
                    tint: CapsuleStyle.accent
                ) {
                    playlistSongRows
                    playlistPagination
                }

                if !isSearching && !viewModel.relatedPlaylists.isEmpty && !viewModel.isLoading {
                    relatedPlaylistsSection
                }

                FloatingBarBottomSpacer()
            }
        }
    }

    var petWhiteSongListSection: some View {
        LazyVStack(spacing: 14) {
            if viewModel.isLoading {
                petWhiteTrackSection(title: "TRACKS", detail: nil) {
                    MonoLoadingView(text: "LOADING TRACKS")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                }
            } else if filteredSongs.isEmpty {
                petWhiteTrackSection(title: "TRACKS", detail: nil) {
                    playlistEmptyState
                        .padding(.top, 0)
                }
            } else {
                petWhiteTrackSection(
                    title: "TRACKS",
                    detail: String(format: NSLocalizedString("songs_count_format", comment: ""), filteredSongs.count)
                ) {
                    playlistSongRows
                    playlistPagination
                }

                if !isSearching && !viewModel.relatedPlaylists.isEmpty && !viewModel.isLoading {
                    relatedPlaylistsSection
                }

                FloatingBarBottomSpacer()
            }
        }
    }

    func petWhiteTrackSection<Content: View>(
        title: String,
        detail: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            PetWhiteSectionTitle(
                title: title,
                detail: detail,
                icon: .musicNoteList,
                tint: PetWhiteStyle.butter
            )

            LazyVStack(spacing: 0) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PetWhiteSurfaceBackground(cornerRadius: PetWhiteStyle.cardRadius, elevated: true, tint: PetWhiteStyle.surfaceRaised, accent: PetWhiteStyle.butter))
        .padding(.horizontal, petWhiteDetailHorizontalPadding)
    }

    var defaultSongListSection: some View {
        LazyVStack(spacing: 0) {
            if viewModel.isLoading {
                MonoLoadingView(text: "LOADING TRACKS")
            } else {
                if filteredSongs.isEmpty {
                    playlistEmptyState
                } else {
                    playlistSongRows
                }

                if !isSearching {
                    playlistPagination

                    if !viewModel.relatedPlaylists.isEmpty && !viewModel.isLoading {
                        relatedPlaylistsSection
                    }
                }

                FloatingBarBottomSpacer()
            }
        }
    }

    var playlistEmptyState: some View {
        VStack(spacing: 14) {
            if MinimalWhiteStyle.isActive {
                MinimalWhiteIconBadge(icon: .musicNoteList, size: 54)
            } else if NeumorphicStyle.isActive {
                NeumorphicIconBadge(icon: .musicNoteList, tint: NeumorphicStyle.accent, size: 54)
            } else if SignalStyle.isActive {
                SignalIconBadge(icon: .musicNoteList, tint: SignalStyle.accent, size: 54)
            } else {
                MonoIcon(icon: .musicNoteList, size: 40, color: .monoTextSecondary.opacity(0.3))
            }

            Text(LocalizedStringKey("album_no_songs"))
                .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.bodyFont(15, weight: .medium) : (SignalStyle.isActive ? SignalStyle.labelFont(14, weight: .medium) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(14, weight: .medium) : .rounded(size: 15))))
                .foregroundColor(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.inkMuted : (SignalStyle.isActive ? SignalStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monoTextSecondary)))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, (ThemedPageStyle.isActive || MinimalWhiteStyle.isActive) ? 34 : 0)
        .background {
            if MinimalWhiteStyle.isActive {
                MinimalWhiteSurfaceBackground(
                    cornerRadius: MinimalWhiteStyle.cardRadius,
                    elevated: false,
                    tint: MinimalWhiteStyle.glassFill
                )
            } else if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 24, elevated: false, pressed: true, lightweight: true)
            } else if SignalStyle.isActive {
                SignalSurfaceBackground(cornerRadius: 26, elevated: false, pressed: true, fill: SignalStyle.controlPressed)
            }
        }
        .padding(.horizontal, (ThemedPageStyle.isActive || MinimalWhiteStyle.isActive) ? DeviceLayout.viewHorizontalPadding : 0)
        .padding(.top, 40)
    }

    var playlistSongRows: some View {
        ForEach(Array(filteredSongs.enumerated()), id: \.element.id) { index, song in
            SongListRow(
                song: song,
                index: index,
                isSelecting: isSelectMode,
                isSelected: selectedSongIds.contains(song.id),
                onArtistTap: { artistId in
                    selectedArtistId = artistId
                    showArtistDetail = true
                },
                onDetailTap: { detailSong in
                    selectedSongForDetail = detailSong
                    showSongDetail = true
                },
                onAlbumTap: { albumId in
                    selectedAlbumId = albumId
                    showAlbumDetail = true
                },
                onTap: {
                    if isSelectMode {
                        if selectedSongIds.contains(song.id) {
                            selectedSongIds.remove(song.id)
                        } else {
                            selectedSongIds.insert(song.id)
                        }
                    } else {
                        PlayerManager.shared.play(song: song, in: filteredSongs)
                    }
                },
                horizontalPadding: PetWhiteStyle.isActive ? CGFloat(0) : nil
            )
        }
    }

    var playlistPagination: some View {
        Group {
            if viewModel.isLoadingMore {
                MonoLoadingView(text: "LOADING MORE", centered: false)
                    .padding()
            }
            if viewModel.hasMore && !viewModel.isLoading && !viewModel.isLoadingMore {
                Color.clear.frame(height: 20).onAppear { viewModel.loadMore() }
            }
            if !viewModel.hasMore && !viewModel.songs.isEmpty && !viewModel.isLoading {
                NoMoreDataView()
            }
        }
    }

}
