import SwiftUI

extension SearchView {
    // MARK: - 通用行组件

    func artistRow(artist: ArtistInfo) -> some View {
        Button(action: {
            if artist.isQQMusic {
                let mid = artist.qqMid ?? "\(artist.id)"
                qqDetailType = .artist(mid: mid, name: artist.name, coverUrl: artist.coverUrl?.absoluteString)
                showQQDetail = true
            } else if artist.source == .kugou || artist.source == .appleMusic {
                selectedArtist = artist
                selectedArtistId = nil
                showArtistDetail = true
            } else {
                selectedArtist = nil
                selectedArtistId = artist.id
                showArtistDetail = true
            }
        }) {
            HStack(spacing: 14) {
                CachedAsyncImage(url: artist.coverUrl?.sized(200)) {
                    Circle().fill(searchResultPlaceholderFill)
                }
                .frame(width: 52, height: 52)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(searchResultImageStrokeColor, lineWidth: searchResultImageStrokeWidth)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(artist.name)
                        .font(searchResultTitleFont)
                        .foregroundColor(searchResultTitleColor)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        if let albumSize = artist.albumSize, albumSize > 0 {
                            Text(String(format: String(localized: "search_album_count"), albumSize))
                                .font(searchResultMetaFont)
                                .foregroundColor(searchResultMetaColor)
                        }
                        if let musicSize = artist.musicSize, musicSize > 0 {
                            Text(String(format: String(localized: "search_song_count"), musicSize))
                                .font(searchResultMetaFont)
                                .foregroundColor(searchResultMetaColor)
                        }
                    }
                }

                Spacer()

                MonoIcon(icon: .chevronRight, size: 14, color: searchResultChevronColor)
            }
            .padding(.horizontal, searchResultRowHorizontalPadding)
            .padding(.vertical, searchResultRowVerticalPadding)
            .background {
                searchResultRowBackground
            }
            .padding(.horizontal, searchResultOuterHorizontalPadding)
            .padding(.vertical, searchResultOuterVerticalPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    func playlistRow(playlist: Playlist) -> some View {
        Button(action: {
            if playlist.isQQMusic {
                qqDetailType = .playlist(id: playlist.id, name: playlist.name, coverUrl: playlist.coverUrl?.absoluteString, creatorName: playlist.creator?.nickname)
                showQQDetail = true
            } else {
                selectedPlaylist = playlist
                showPlaylistDetail = true
            }
        }) {
            HStack(spacing: 14) {
                CachedAsyncImage(url: playlist.coverUrl?.sized(200)) {
                    RoundedRectangle(cornerRadius: searchResultCoverCornerRadius, style: .continuous)
                        .fill(searchResultPlaceholderFill)
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: searchResultCoverCornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: searchResultCoverCornerRadius, style: .continuous)
                        .stroke(searchResultImageStrokeColor, lineWidth: searchResultImageStrokeWidth)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(playlist.name)
                        .font(searchResultTitleFont)
                        .foregroundColor(searchResultTitleColor)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        if let trackCount = playlist.trackCount, trackCount > 0 {
                            Text(String(format: String(localized: "search_track_count"), trackCount))
                                .font(searchResultMetaFont)
                                .foregroundColor(searchResultMetaColor)
                        }
                        if let creator = playlist.creator?.nickname {
                            Text("by \(creator)")
                                .font(searchResultMetaFont)
                                .foregroundColor(searchResultMetaColor)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                MonoIcon(icon: .chevronRight, size: 14, color: searchResultChevronColor)
            }
            .padding(.horizontal, searchResultRowHorizontalPadding)
            .padding(.vertical, searchResultRowVerticalPadding)
            .background {
                searchResultRowBackground
            }
            .padding(.horizontal, searchResultOuterHorizontalPadding)
            .padding(.vertical, searchResultOuterVerticalPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    func albumRow(album: SearchAlbum) -> some View {
        Button(action: {
            if album.isQQMusic {
                let mid = album.qqMid ?? "\(album.id)"
                qqDetailType = .album(mid: mid, name: album.name, coverUrl: album.coverUrl?.absoluteString, artistName: album.artistName)
                showQQDetail = true
            } else if album.source == .kugou || album.source == .appleMusic {
                selectedAlbum = albumInfo(from: album)
                selectedAlbumId = nil
                showAlbumDetail = true
            } else {
                selectedAlbum = nil
                selectedAlbumId = album.id
                showAlbumDetail = true
            }
        }) {
            HStack(spacing: 14) {
                CachedAsyncImage(url: album.coverUrl?.sized(200)) {
                    RoundedRectangle(cornerRadius: searchResultCoverCornerRadius, style: .continuous)
                        .fill(searchResultPlaceholderFill)
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: searchResultCoverCornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: searchResultCoverCornerRadius, style: .continuous)
                        .stroke(searchResultImageStrokeColor, lineWidth: searchResultImageStrokeWidth)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(album.name)
                        .font(searchResultTitleFont)
                        .foregroundColor(searchResultTitleColor)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(album.artistName)
                            .font(searchResultMetaFont)
                            .foregroundColor(searchResultMetaColor)
                            .lineLimit(1)

                        if let size = album.size, size > 0 {
                            Text(String(format: String(localized: "search_track_count"), size))
                                .font(searchResultMetaFont)
                                .foregroundColor(searchResultMetaColor)
                        }
                    }
                }

                Spacer()

                MonoIcon(icon: .chevronRight, size: 14, color: searchResultChevronColor)
            }
            .padding(.horizontal, searchResultRowHorizontalPadding)
            .padding(.vertical, searchResultRowVerticalPadding)
            .background {
                searchResultRowBackground
            }
            .padding(.horizontal, searchResultOuterHorizontalPadding)
            .padding(.vertical, searchResultOuterVerticalPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    func albumInfo(from album: SearchAlbum) -> AlbumInfo {
        let artists = album.artists ?? album.artist.map { [$0] }
        let primary = album.artist ?? artists?.first
        let artistInfo = primary.map {
            ArtistInfo(
                id: $0.id,
                name: $0.name,
                picUrl: nil,
                img1v1Url: nil,
                cover: nil,
                avatar: nil,
                musicSize: nil,
                albumSize: nil,
                mvSize: nil,
                briefDesc: nil,
                alias: nil,
                followed: nil,
                accountId: nil,
                source: album.source,
                appleMusicID: nil,
                kugouID: album.source == .kugou ? String($0.id) : nil
            )
        }
        return AlbumInfo(
            id: album.id,
            name: album.name,
            picUrl: album.picUrl,
            publishTime: album.publishTime,
            size: album.size,
            artist: artistInfo,
            artists: artists,
            description: nil,
            company: nil,
            subType: nil,
            qqAlbumMid: nil,
            source: album.source,
            appleMusicID: album.appleMusicID,
            kugouID: album.kugouID
        )
    }

    func mvsResultList(mvs: [MV]) -> some View {
        LazyVGrid(columns: searchMediaGridColumns, spacing: 16) {
            ForEach(mvs.prefix(4)) { mv in
                MVGridCard(mv: mv) {
                    selectedMVId = MVIdItem(id: mv.id)
                    isFocused = false
                }
            }
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, 4)
    }

    // MARK: - QQ MV 结果列表

    func qqMVsResultList(mvs: [QQMV]) -> some View {
        LazyVGrid(columns: searchMediaGridColumns, spacing: 16) {
            ForEach(mvs.prefix(4)) { mv in
                qqMVGridCard(mv: mv)
            }
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, 4)
    }

    // MARK: - QQ MV 网格卡片

    func qqMVGridCard(mv: QQMV) -> some View {
        Button(action: {
            selectedQQMV = QQMVVidItem(vid: mv.vid)
            isFocused = false
        }) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .bottomTrailing) {
                    let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
                    ZStack {
                        shape.fill(Color.monoTextSecondary.opacity(0.06))
                    if let urlStr = mv.coverUrl, let url = URL(string: urlStr) {
                        CachedAsyncImage(url: url) {
                                shape.fill(Color.monoTextSecondary.opacity(0.06))
                        }
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 96)
                    .clipShape(shape)
                    .clipped()

                    if !mv.durationText.isEmpty {
                        Text(mv.durationText)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.clear).monoGlass(cornerRadius: (NeumorphicStyle.isActive || SignalStyle.isActive) ? 12 : 16)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .padding(8)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(mv.name)
                        .font(NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(14, weight: .semibold) : (SignalStyle.isActive ? SignalStyle.bodyFont(14, weight: .semibold) : .rounded(size: 14, weight: .semibold)))
                        .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : (SignalStyle.isActive ? SignalStyle.ink : .monoTextPrimary))
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text(mv.singerName ?? String(localized: "search_unknown_artist"))
                            .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .medium) : (SignalStyle.isActive ? SignalStyle.labelFont(12, weight: .medium) : .rounded(size: 12)))
                            .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : (SignalStyle.isActive ? SignalStyle.inkSoft : .monoTextSecondary))
                            .lineLimit(1)

                        if !mv.playCountText.isEmpty {
                            Circle()
                                .fill((NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : (SignalStyle.isActive ? SignalStyle.inkMuted : Color.monoTextSecondary)).opacity(0.3))
                                .frame(width: 3, height: 3)
                            Text(mv.playCountText + String(localized: "search_play_count_suffix"))
                                .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(11, weight: .medium) : (SignalStyle.isActive ? SignalStyle.labelFont(11, weight: .medium) : .rounded(size: 11)))
                                .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : (SignalStyle.isActive ? SignalStyle.inkMuted : .monoTextSecondary.opacity(0.6)))
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            .padding((NeumorphicStyle.isActive || SignalStyle.isActive) ? 10 : 0)
            .background {
                if NeumorphicStyle.isActive {
                    NeumorphicSurfaceBackground(cornerRadius: 22, elevated: true, lightweight: true)
                } else if SignalStyle.isActive {
                    SignalSurfaceBackground(cornerRadius: 22, elevated: true, fill: SignalStyle.device)
                }
            }
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.97))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func kcmMVGridCard(mv: KCMMV) -> some View {
        Button {
            selectedKCMMV = mv
            isFocused = false
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                ZStack(alignment: .bottomTrailing) {
                    let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
                    ZStack {
                        shape.fill(searchResultPlaceholderFill)
                        CachedAsyncImage(url: mv.coverURL.flatMap(URL.init(string:))) {
                            shape.fill(searchResultPlaceholderFill)
                        }
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 96)
                    .clipShape(shape)
                    .clipped()

                    if !mv.durationText.isEmpty {
                        Text(mv.durationText)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.58), in: Capsule())
                            .padding(8)
                    }
                }

                Text(mv.name)
                    .font(searchResultTitleFont)
                    .foregroundStyle(searchResultTitleColor)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    PlatformBadgeLabel(text: "KCM", source: .kugou, fontSize: 9)
                    Text(mv.artistName ?? String(localized: "search_unknown_artist"))
                        .font(searchResultMetaFont)
                        .foregroundStyle(searchResultMetaColor)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.97))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 展开 QQ MV 列表

    var expandedQQMVsList: some View {
        LazyVGrid(columns: searchMediaGridColumns, spacing: 22) {
            ForEach(Array(viewModel.qqMVResults.enumerated()), id: \.element.id) { index, mv in
                qqMVGridCard(mv: mv)
                    .onAppear {
                        if index == viewModel.qqMVResults.count - 3 {
                            viewModel.loadMore(source: .qqmusic)
                        }
                    }
            }
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, 8)
    }

}
