import SwiftUI

extension SearchView {
    // MARK: - 最佳匹配卡片

    func bestMatchSection(match: SearchMultimatchResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(LocalizedStringKey("search_best_match"))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.monoTextSecondary)
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.bottom, 10)

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    if let artist = match.artist {
                        bestMatchCard(
                            imageUrl: artist.coverUrl?.sized(200),
                            title: artist.name,
                            subtitle: String(localized: "search_type_artist"),
                            isCircle: true
                        ) {
                            selectedArtistId = artist.id
                            showArtistDetail = true
                        }
                    }

                    if let album = match.album {
                        bestMatchCard(
                            imageUrl: album.coverUrl?.sized(200),
                            title: album.name,
                            subtitle: album.artistName,
                            isCircle: false
                        ) {
                            selectedAlbumId = album.id
                            showAlbumDetail = true
                        }
                    }

                    if let playlist = match.playlist {
                        bestMatchCard(
                            imageUrl: playlist.coverUrl?.sized(200),
                            title: playlist.name,
                            subtitle: playlist.creator?.nickname ?? "",
                            isCircle: false
                        ) {
                            selectedPlaylist = playlist
                            showPlaylistDetail = true
                        }
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
        .padding(.top, 4)
    }

    func bestMatchCard(
        imageUrl: URL?,
        title: String,
        subtitle: String,
        isCircle: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                CachedAsyncImage(url: imageUrl) {
                    RoundedRectangle(cornerRadius: isCircle ? 25 : 10)
                        .fill(Color.monoSeparator)
                }
                .frame(width: 50, height: 50)
                .clipShape(isCircle ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 10)))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.rounded(size: 14, weight: .semibold))
                        .foregroundColor(.monoTextPrimary)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.rounded(size: 12))
                        .foregroundColor(.monoTextSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                MonoIcon(icon: .chevronRight, size: 14, color: .monoTextSecondary.opacity(0.5))
            }
            .padding(12)
            .frame(width: 220)
            .background(
                Group {
                    if NeumorphicStyle.isActive {
                        NeumorphicSurfaceBackground(cornerRadius: 20, elevated: true, lightweight: true)
                    } else {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.monoGlassTint)
                            .monoGlass(cornerRadius: 20)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.97))
    }

    // MARK: - 空结果提示

    @ViewBuilder
    var emptyResultsView: some View {
        if viewModel.selectedPlatform == .kugou, let error = viewModel.kugouErrorMessage {
            themeSearchStatePanel(
                icon: .personCircle,
                title: error,
                tint: MusicSource.kugou.themedBadgeColor
            )
        } else if viewModel.selectedPlatform == .appleMusic, let error = viewModel.appleMusicErrorMessage {
            themeSearchStatePanel(
                icon: .warning,
                title: error,
                tint: MusicSource.appleMusic.themedBadgeColor
            )
        } else if MinimalWhiteStyle.isActive {
            themeSearchStatePanel(
                icon: .magnifyingGlass,
                title: String(localized: "search_no_results"),
                tint: MinimalWhiteStyle.inkMuted
            )
        } else if MangaStyle.isActive {
            themeSearchStatePanel(
                icon: .magnifyingGlass,
                title: viewModel.displayKeyword.isEmpty ? String(localized: "search_no_results") : viewModel.displayKeyword,
                subtitle: String(localized: "search_no_results"),
                tint: MangaStyle.labelYellow
            )
        } else if MujiStyle.isActive {
            themeSearchStatePanel(
                icon: .magnifyingGlass,
                title: viewModel.displayKeyword.isEmpty ? String(localized: "search_no_results") : viewModel.displayKeyword,
                subtitle: String(localized: "search_no_results"),
                tint: MujiStyle.clay
            )
        } else if NeumorphicStyle.isActive {
            VStack(spacing: 14) {
                NeumorphicIconBadge(icon: .magnifyingGlass, tint: NeumorphicStyle.inkMuted, size: 52)

                Text(viewModel.displayKeyword)
                    .font(NeumorphicStyle.titleFont(18, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.ink)
                    .lineLimit(1)

                Text(String(localized: "search_no_results"))
                    .font(NeumorphicStyle.labelFont(12, weight: .medium))
                    .foregroundStyle(NeumorphicStyle.inkMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 38)
            .background(NeumorphicSurfaceBackground(cornerRadius: 24, elevated: true))
        } else if SequoiaStyle.isActive {
            SequoiaSearchStatePanel(
                icon: .magnifyingGlass,
                title: viewModel.displayKeyword.isEmpty ? String(localized: "search_no_results") : viewModel.displayKeyword,
                subtitle: String(localized: "search_no_results"),
                tint: SequoiaStyle.inkMuted
            )
        } else if CapsuleStyle.isActive {
            themeSearchStatePanel(
                icon: .magnifyingGlass,
                title: viewModel.displayKeyword.isEmpty ? String(localized: "search_no_results") : viewModel.displayKeyword,
                subtitle: String(localized: "search_no_results"),
                tint: CapsuleStyle.accent
            )
        } else if #available(iOS 17.0, *) {
            ContentUnavailableView.search(text: viewModel.displayKeyword)
        } else {
            VStack(spacing: 13) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 42, weight: .regular))
                    .foregroundStyle(.secondary)
                Text("search_no_results")
                    .font(.headline)
                Text(viewModel.displayKeyword)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    func themeSearchStatePanel(
        icon: MonoIcon.IconType,
        title: String,
        subtitle: String = "",
        tint: Color,
        loading: Bool = false
    ) -> some View {
        VStack(spacing: 13) {
            if MangaStyle.isActive {
                MangaSectionMark(kind: .star, tint: tint)
                    .frame(width: 50, height: 50)
            } else if MujiStyle.isActive {
                MonoIcon(icon: icon, size: 22, color: tint, lineWidth: 1.55)
                    .frame(width: 52, height: 52)
                    .background(MujiStyle.wash(tint, strength: 1.25), in: Circle())
            } else if MinimalWhiteStyle.isActive {
                MonoIcon(icon: icon, size: 21, color: tint, lineWidth: 1.55)
                    .frame(width: 50, height: 50)
                    .background(MinimalWhiteCircleBackground())
            } else if CapsuleStyle.isActive {
                CapsuleIconBadge(icon: icon, tint: tint, size: 52)
            } else {
                MonoIcon(icon: icon, size: 22, color: tint, lineWidth: 1.6)
                    .frame(width: 52, height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(tint.opacity(0.12))
                    )
            }

            VStack(spacing: 5) {
                Text(title)
                    .font(themeSearchStateTitleFont)
                    .foregroundStyle(themeSearchPrimaryColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(themeSearchStateSubtitleFont)
                        .foregroundStyle(themeSearchSecondaryColor)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }

            if loading {
                ProgressView()
                    .tint(tint)
                    .scaleEffect(0.82)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 38)
        .padding(.horizontal, 18)
        .background { themeSearchStateBackground }
    }

    var themeSearchStateTitleFont: Font {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.titleFont(17, weight: .semibold) }
        if MangaStyle.isActive { return MangaStyle.titleFont(18, weight: .black) }
        if MujiStyle.isActive { return MujiStyle.titleFont(18, weight: .medium) }
        if CapsuleStyle.isActive { return CapsuleStyle.titleFont(18, weight: .bold) }
        return .rounded(size: 18, weight: .semibold)
    }

    var themeSearchStateSubtitleFont: Font {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.labelFont(12, weight: .regular) }
        if MangaStyle.isActive { return MangaStyle.labelFont(12, weight: .bold) }
        if MujiStyle.isActive { return MujiStyle.labelFont(12, weight: .regular) }
        if CapsuleStyle.isActive { return CapsuleStyle.labelFont(12, weight: .semibold) }
        return .rounded(size: 12, weight: .regular)
    }

    var themeSearchPrimaryColor: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.ink }
        if MangaStyle.isActive { return MangaStyle.ink }
        if MujiStyle.isActive { return MujiStyle.ink }
        if CapsuleStyle.isActive { return CapsuleStyle.ink }
        return .monoTextPrimary
    }

    var themeSearchSecondaryColor: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.inkMuted }
        if MangaStyle.isActive { return MangaStyle.inkMuted }
        if MujiStyle.isActive { return MujiStyle.inkMuted }
        if CapsuleStyle.isActive { return CapsuleStyle.inkMuted }
        return .monoTextSecondary
    }

    @ViewBuilder
    var themeSearchStateBackground: some View {
        if MinimalWhiteStyle.isActive {
            MinimalWhiteSurfaceBackground(
                cornerRadius: MinimalWhiteStyle.cardRadius,
                elevated: false,
                tint: MinimalWhiteStyle.glassFill
            )
        } else if MangaStyle.isActive {
            // 去卡片化：状态提示直接排在纸上
            EmptyView()
        } else if MujiStyle.isActive {
            EmptyView()
        } else if CapsuleStyle.isActive {
            CapsuleSurfaceBackground(cornerRadius: 24, elevated: true, tint: CapsuleStyle.surface.opacity(0.92))
        } else {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.monoGlassTint.opacity(0.62))
                .monoGlass(cornerRadius: 22)
        }
    }

}
