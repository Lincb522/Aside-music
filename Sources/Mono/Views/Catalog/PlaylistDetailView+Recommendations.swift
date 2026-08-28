import SwiftUI

extension PlaylistDetailView {
    // MARK: - 相关歌单推荐

    var relatedPlaylistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if MinimalWhiteStyle.isActive {
                MinimalWhiteSectionTitle(title: String(localized: "related_playlists"))
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.top, 20)
            } else if MangaStyle.isActive {
                MangaSectionTitle(title: String(localized: "related_playlists"), mark: .star)
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.top, 20)
            } else if NeumorphicStyle.isActive {
                NeumorphicSectionTitle(title: String(localized: "related_playlists"))
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.top, 20)
            } else if SignalStyle.isActive {
                SignalSectionTitle(title: String(localized: "related_playlists"))
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.top, 20)
            } else if MujiStyle.isActive {
                MujiSectionTitle(title: String(localized: "related_playlists"))
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.top, 20)
            } else if CapsuleStyle.isActive {
                HStack {
                    CapsuleDetailChip(
                        text: String(localized: "related_playlists"),
                        icon: .musicNoteList,
                        tint: CapsuleStyle.cyan,
                        selected: true
                    )
                    Spacer()
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.top, 16)
            } else {
                Text(LocalizedStringKey("related_playlists"))
                    .font(.rounded(size: 16, weight: .semibold))
                    .foregroundColor(Theme.text)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
            }

            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(viewModel.relatedPlaylists) { rp in
                        Button(action: {
                            let pl = Playlist(
                                id: rp.id,
                                name: rp.name,
                                coverImgUrl: rp.coverImgUrl,
                                picUrl: nil,
                                trackCount: nil,
                                playCount: nil,
                                subscribedCount: nil,
                                shareCount: nil,
                                commentCount: nil,
                                creator: nil,
                                description: nil,
                                tags: nil
                            )
                            selectedRelatedPlaylist = pl
                            showRelatedPlaylist = true
                        }) {
                            VStack(alignment: .leading, spacing: 8) {
                                CachedAsyncImage(url: rp.coverUrl?.sized(300)) {
                                    RoundedRectangle(cornerRadius: relatedPlaylistCoverRadius, style: .continuous)
                                        .fill(relatedPlaylistCoverFill)
                                        .monoGlass(cornerRadius: relatedPlaylistCoverRadius)
                                }
                                .frame(width: 130, height: 130)
                                .clipShape(RoundedRectangle(cornerRadius: relatedPlaylistCoverRadius, style: .continuous))
                                .overlay {
                                    if MangaStyle.isActive {
                                        RoundedRectangle(cornerRadius: relatedPlaylistCoverRadius, style: .continuous)
                                            .stroke(MangaStyle.strokeInk.opacity(0.7), lineWidth: 1)
                                    } else if MujiStyle.isActive {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(MujiStyle.hairline.opacity(0.55), lineWidth: 0.6)
                                    } else if NeumorphicStyle.isActive {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(NeumorphicStyle.separator.opacity(0.35), lineWidth: 0.7)
                                    } else if SignalStyle.isActive {
                                        RoundedRectangle(cornerRadius: relatedPlaylistCoverRadius, style: .continuous)
                                            .stroke(SignalStyle.separator.opacity(0.68), lineWidth: 0.8)
                                    } else if MinimalWhiteStyle.isActive {
                                        RoundedRectangle(cornerRadius: relatedPlaylistCoverRadius, style: .continuous)
                                            .stroke(MinimalWhiteStyle.hairline, lineWidth: MinimalWhiteStyle.strokeWidth)
                                    }
                                }

                                Text(rp.name)
                                    .font(relatedPlaylistTitleFont)
                                    .foregroundColor(relatedPlaylistTitleColor)
                                    .lineLimit(2)
                                    .frame(width: 130, height: 34, alignment: .topLeading)

                                Text(rp.creatorName.isEmpty ? " " : rp.creatorName)
                                    .font(relatedPlaylistMetaFont)
                                    .foregroundColor(relatedPlaylistMetaColor)
                                    .lineLimit(1)
                                    .frame(width: 130, alignment: .leading)
                            }
                            .padding(ThemedPageStyle.isActive && !MangaStyle.isActive ? 8 : 0)
                            .background {
                                if MangaStyle.isActive {
                                    // 去卡片化：相关歌单直接排在纸上
                                    EmptyView()
                                } else if NeumorphicStyle.isActive {
                                    NeumorphicSurfaceBackground(cornerRadius: 20, elevated: false, lightweight: true)
                                } else if SignalStyle.isActive {
                                    SignalSurfaceBackground(cornerRadius: 22, elevated: false, fill: SignalStyle.paper)
                                } else if MinimalWhiteStyle.isActive {
                                    MinimalWhiteSurfaceBackground(
                                        cornerRadius: MinimalWhiteStyle.cardRadius,
                                        elevated: false,
                                        tint: MinimalWhiteStyle.glassFill
                                    )
                                }
                            }
                        }
                        .buttonStyle(MonoBouncingButtonStyle(scale: 0.97))
                    }
                }
                .padding(.horizontal, 24)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
    }

    var relatedPlaylistCoverRadius: CGFloat {
        if MinimalWhiteStyle.isActive { return 12 }
        if MangaStyle.isActive { return MangaStyle.cardRadius }
        if MujiStyle.isActive { return 8 }
        if NeumorphicStyle.isActive { return 16 }
        if SignalStyle.isActive { return 18 }
        return 12
    }

    var relatedPlaylistCoverFill: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.controlGlassFill }
        if MangaStyle.isActive { return MangaStyle.paperCool }
        if MujiStyle.isActive { return MujiStyle.surfaceRaised }
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfacePressed }
        if SignalStyle.isActive { return SignalStyle.controlPressed }
        return Color.monoGlassTint
    }

    var relatedPlaylistTitleFont: Font {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.bodyFont(13, weight: .medium) }
        if MangaStyle.isActive { return MangaStyle.bodyFont(13, weight: .black) }
        if MujiStyle.isActive { return MujiStyle.bodyFont(13, weight: .regular) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(13, weight: .semibold) }
        if SignalStyle.isActive { return SignalStyle.labelFont(13, weight: .bold) }
        return .rounded(size: 13, weight: .medium)
    }

    var relatedPlaylistMetaFont: Font {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.labelFont(11, weight: .regular) }
        if MangaStyle.isActive { return MangaStyle.bodyFont(11, weight: .bold) }
        if MujiStyle.isActive { return MujiStyle.labelFont(11, weight: .regular) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(11, weight: .medium) }
        if SignalStyle.isActive { return SignalStyle.labelFont(11, weight: .medium) }
        return .rounded(size: 11)
    }

    var relatedPlaylistTitleColor: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.ink }
        if MangaStyle.isActive { return MangaStyle.ink }
        if MujiStyle.isActive { return MujiStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if SignalStyle.isActive { return SignalStyle.ink }
        return .monoTextPrimary
    }

    var relatedPlaylistMetaColor: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.inkMuted }
        if MangaStyle.isActive { return MangaStyle.inkSub }
        if MujiStyle.isActive { return MujiStyle.inkSoft }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if SignalStyle.isActive { return SignalStyle.inkSoft }
        return .monoTextSecondary
    }
}
