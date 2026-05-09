import Combine
import QQMusicKit
import SwiftUI
import UniformTypeIdentifiers

struct ThemedLibrarySectionHeader: View {
    let title: String

    var body: some View {
        if NeumorphicStyle.isActive {
            HStack(spacing: 9) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(NeumorphicStyle.accent.opacity(0.78))
                    .frame(width: 4, height: 18)

                Text(title)
                    .font(NeumorphicStyle.titleFont(17, weight: .semibold))
                    .foregroundColor(NeumorphicStyle.ink)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
        } else if SignalStyle.isActive {
            HStack(spacing: 9) {
                SignalPulseDot(tint: SignalStyle.accent, size: 17)

                Text(title)
                    .font(SignalStyle.titleFont(16, weight: .bold))
                    .foregroundColor(SignalStyle.ink)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
        } else if SequoiaStyle.isActive {
            HStack(spacing: 9) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(SequoiaStyle.accentGradient)
                    .frame(width: 3, height: 18)

                Text(title)
                    .font(SequoiaStyle.titleFont(17, weight: .semibold))
                    .foregroundColor(SequoiaStyle.ink)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
        } else if CapsuleStyle.isActive {
            CapsuleSectionTitle(title: title, tint: CapsuleStyle.accent) {
                HStack(spacing: 5) {
                    Capsule()
                        .fill(CapsuleStyle.accent.opacity(0.72))
                        .frame(width: 18, height: 6)
                    Capsule()
                        .fill(CapsuleStyle.cyan.opacity(0.48))
                        .frame(width: 8, height: 6)
                }
            }
            .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
        } else {
            Text(title)
                .font(MujiStyle.isActive ? MujiStyle.titleFont(17, weight: .semibold) : .system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(MujiStyle.isActive ? MujiStyle.ink : .monologueTextPrimary)
                .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
        }
    }
}

struct SignalLibraryMiniBars: View {
    let tint: Color

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(index < 3 ? tint : SignalStyle.inkMuted.opacity(0.24))
                    .frame(width: 4, height: 6 + CGFloat(index) * 3)
            }
        }
        .frame(height: 17)
    }
}

struct LibraryLoadingStateView: View {
    var text: String? = nil
    var horizontalPadding: CGFloat? = nil
    var minHeight: CGFloat? = nil

    var body: some View {
        let resolvedMinHeight = minHeight ?? (DeviceLayout.isPad ? 420 : 320)
        let resolvedPadding = horizontalPadding ?? DeviceLayout.libraryHorizontalPadding

        if SequoiaStyle.isActive {
            VStack(spacing: 12) {
                SequoiaIconBadge(icon: .library, tint: SequoiaStyle.accent, size: 50)
                ProgressView()
                    .tint(SequoiaStyle.accent)
                    .scaleEffect(0.82)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: resolvedMinHeight, alignment: .center)
            .background(SequoiaSurfaceBackground(cornerRadius: 24, elevated: true, role: .chrome))
            .padding(.horizontal, resolvedPadding)
        } else if CapsuleStyle.isActive {
            VStack(spacing: 12) {
                CapsuleIconBadge(icon: .library, tint: CapsuleStyle.accent, size: 50)
                ProgressView()
                    .tint(CapsuleStyle.accent)
                    .scaleEffect(0.82)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: resolvedMinHeight, alignment: .center)
            .background(CapsuleSurfaceBackground(cornerRadius: 26, elevated: true, tint: CapsuleStyle.surface.opacity(0.9)))
            .padding(.horizontal, resolvedPadding)
        } else {
            MonologueLoadingView(text: text)
                .frame(maxWidth: .infinity)
                .frame(minHeight: resolvedMinHeight, alignment: .center)
                .padding(.horizontal, resolvedPadding)
        }
    }
}

struct LibraryInlineLoadingView: View {
    var text: String? = nil

    var body: some View {
        MonologueLoadingView(text: text, centered: false)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
    }
}

struct ThemedLibraryEmptyState: View {
    let icon: MonologueIcon.IconType
    let title: String
    let tint: Color

    var body: some View {
        VStack(spacing: 12) {
            if SequoiaStyle.isActive {
                SequoiaIconBadge(icon: icon, tint: tint, size: 50)
            } else if CapsuleStyle.isActive {
                CapsuleIconBadge(icon: icon, tint: tint, size: 50)
            } else {
                MonologueIcon(icon: icon, size: 28, color: tint.opacity(0.72), lineWidth: 1.8)
            }
            Text(title)
                .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(13, weight: .medium) : (MujiStyle.isActive ? MujiStyle.labelFont(13, weight: .regular) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(13, weight: .medium) : (CapsuleStyle.isActive ? CapsuleStyle.labelFont(13, weight: .semibold) : .system(size: 13, weight: .medium, design: .rounded)))))
                .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : (MujiStyle.isActive ? MujiStyle.inkSoft : (SequoiaStyle.isActive ? SequoiaStyle.inkMuted : (CapsuleStyle.isActive ? CapsuleStyle.inkSoft : .monologueTextSecondary))))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background {
            if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 22, elevated: true, lightweight: true)
            } else if MujiStyle.isActive {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(MujiStyle.surface.opacity(0.76))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(MujiStyle.hairline.opacity(0.44), lineWidth: 0.6))
            } else if SequoiaStyle.isActive {
                SequoiaSurfaceBackground(cornerRadius: 22, elevated: true, role: .chrome)
            } else if CapsuleStyle.isActive {
                CapsuleSurfaceBackground(cornerRadius: 24, elevated: true, tint: CapsuleStyle.surface.opacity(0.9))
            } else {
                Color.clear.monologueGlass(cornerRadius: 18)
            }
        }
    }
}

struct ThemedLibraryPodcastRow: View {
    let radio: RadioStation
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            CachedAsyncImage(url: radio.coverUrl) {
                Color.gray.opacity(0.1)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: DeviceLayout.listRowCoverStandard, height: DeviceLayout.listRowCoverStandard)
            .clipShape(RoundedRectangle(cornerRadius: SequoiaStyle.isActive ? 14 : 12, style: .continuous))
            .overlay {
                if SequoiaStyle.isActive {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(SequoiaStyle.separator.opacity(0.78), lineWidth: 0.6)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(radio.name)
                    .font(NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(15, weight: .semibold) : (SequoiaStyle.isActive ? SequoiaStyle.bodyFont(15, weight: .semibold) : .system(size: 15, weight: .semibold, design: .rounded)))
                    .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : (MujiStyle.isActive ? MujiStyle.ink : (SequoiaStyle.isActive ? SequoiaStyle.ink : .monologueTextPrimary)))
                    .lineLimit(1)

                Text(radio.dj?.nickname ?? radio.category ?? "Podcast")
                    .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .medium) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(12, weight: .regular) : .system(size: 12, weight: .medium, design: .rounded)))
                    .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : (MujiStyle.isActive ? MujiStyle.inkSoft : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monologueTextSecondary)))
                    .lineLimit(1)
            }

            Spacer()

            MonologueIcon(icon: .chevronRight, size: 12, color: tint.opacity(0.72), lineWidth: 1.8)
        }
        .padding(14)
        .background {
            if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 20, elevated: true, tint: tint.opacity(0.08), lightweight: true)
            } else if MujiStyle.isActive {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(MujiStyle.surface.opacity(0.82))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(MujiStyle.hairline.opacity(0.44), lineWidth: 0.6))
            } else if SequoiaStyle.isActive {
                SequoiaSurfaceBackground(cornerRadius: 20, elevated: false, fill: tint.opacity(0.055), role: .list)
            } else if CapsuleStyle.isActive {
                CapsuleSurfaceBackground(cornerRadius: 22, elevated: true, tint: CapsuleStyle.surface.opacity(0.88))
            } else {
                Color.clear.monologueGlass(cornerRadius: 18)
            }
        }
    }
}

struct ThemedLibraryArtistCard: View {
    let artist: ArtistInfo
    let tint: Color

    var body: some View {
        VStack(spacing: 10) {
            CachedAsyncImage(url: artist.coverUrl?.sized(400)) {
                NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.gray.opacity(0.1)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: DeviceLayout.artistAvatarSize - (NeumorphicStyle.isActive ? 12 : 0), height: DeviceLayout.artistAvatarSize - (NeumorphicStyle.isActive ? 12 : 0))
            .clipShape(Circle())
            .shadow(color: tint.opacity(0.14), radius: 7, y: 3)

            Text(artist.name)
                .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(13, weight: .semibold) : (MujiStyle.isActive ? MujiStyle.labelFont(13, weight: .semibold) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(13, weight: .semibold) : (CapsuleStyle.isActive ? CapsuleStyle.labelFont(13, weight: .bold) : .system(size: 13, weight: .semibold, design: .rounded)))))
                .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : (MujiStyle.isActive ? MujiStyle.ink : (SequoiaStyle.isActive ? SequoiaStyle.ink : (CapsuleStyle.isActive ? CapsuleStyle.ink : .monologueTextPrimary))))
                .lineLimit(1)
        }
        .padding(NeumorphicStyle.isActive || SequoiaStyle.isActive || CapsuleStyle.isActive ? 12 : 0)
        .frame(maxWidth: .infinity)
        .background {
            if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 22, elevated: true, tint: tint.opacity(0.06), lightweight: true)
            } else if SequoiaStyle.isActive {
                SequoiaSurfaceBackground(cornerRadius: 20, elevated: false, fill: tint.opacity(0.055), role: .list)
            } else if CapsuleStyle.isActive {
                CapsuleSurfaceBackground(cornerRadius: 22, elevated: true, tint: CapsuleStyle.surface.opacity(0.9))
            }
        }
    }
}

struct SequoiaLibraryPlaylistTile: View {
    let playlist: Playlist
    let tint: Color

    var body: some View {
        HStack(spacing: 11) {
            CachedAsyncImage(url: playlist.coverUrl?.sized(400)) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.opacity(0.12))
                    .overlay(
                        MonologueIcon(icon: .musicNoteList, size: 20, color: tint.opacity(0.62), lineWidth: 1.55)
                    )
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 58, height: 58)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(SequoiaStyle.separator, lineWidth: 0.55)
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(playlist.name)
                    .font(SequoiaStyle.labelFont(13, weight: .semibold))
                    .foregroundStyle(SequoiaStyle.ink)
                    .lineLimit(2)
                    .frame(minHeight: 33, alignment: .topLeading)

                HStack(spacing: 6) {
                    Capsule()
                        .fill(tint.opacity(0.74))
                        .frame(width: 18, height: 3)
                    Text(metaText)
                        .font(SequoiaStyle.labelFont(10, weight: .medium))
                        .foregroundStyle(SequoiaStyle.inkMuted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
        .background(SequoiaSurfaceBackground(cornerRadius: 18, elevated: false, role: .list))
    }

    private var metaText: String {
        if let count = playlist.playCount, count > 0 {
            return cinematicFormatCount(count)
        }
        if let trackCount = playlist.trackCount, trackCount > 0 {
            return String(format: String(localized: "songs_count_format"), trackCount)
        }
        return playlist.source == .qqmusic ? "QCM" : "NCM"
    }
}

struct NeumorphicPlaylistPoster: View {
    let playlist: Playlist
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                CachedAsyncImage(url: playlist.coverUrl?.sized(600)) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(NeumorphicStyle.surfacePressed)
                        .overlay(
                            MonologueIcon(icon: .musicNoteList, size: 24, color: NeumorphicStyle.inkMuted.opacity(0.55), lineWidth: 1.7)
                        )
                }
                .aspectRatio(1, contentMode: .fill)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                MonologueIcon(icon: .play, size: 12, color: Color(light: .white, dark: .black), lineWidth: 1.8)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(tint)
                            .shadow(color: tint.opacity(0.22), radius: 8, x: 0, y: 4)
                    )
                    .padding(9)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(playlist.name)
                    .font(NeumorphicStyle.labelFont(13, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.ink)
                    .lineLimit(2)
                    .frame(minHeight: 36, alignment: .topLeading)

                HStack(spacing: 6) {
                    Capsule()
                        .fill(tint.opacity(0.78))
                        .frame(width: 18, height: 3)

                    Text(metaText)
                        .font(NeumorphicStyle.labelFont(10, weight: .medium))
                        .foregroundStyle(NeumorphicStyle.inkMuted)
                        .lineLimit(1)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            NeumorphicSurfaceBackground(
                cornerRadius: 24,
                elevated: true,
                tint: tint.opacity(0.055),
                lightweight: true
            )
        )
    }

    private var metaText: String {
        if let count = playlist.playCount, count > 0 {
            return cinematicFormatCount(count)
        }
        if let trackCount = playlist.trackCount, trackCount > 0 {
            return String(format: String(localized: "songs_count_format"), trackCount)
        }
        return playlist.source == .qqmusic ? "QCM" : "NCM"
    }
}

struct NeumorphicLocalShelfRow: View {
    let playlist: LocalPlaylist
    let tint: Color

    var body: some View {
        HStack(spacing: 13) {
            cover
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(playlist.name)
                    .font(NeumorphicStyle.bodyFont(15, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.ink)
                    .lineLimit(1)

                HStack(spacing: 7) {
                    platformDot
                    Text(String(format: String(localized: "songs_count_format"), playlist.trackCount))
                        .font(NeumorphicStyle.labelFont(11, weight: .medium))
                        .foregroundStyle(NeumorphicStyle.inkMuted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            MonologueIcon(icon: .chevronRight, size: 12, color: tint.opacity(0.72), lineWidth: 1.8)
                .frame(width: 34, height: 34)
                .background(NeumorphicSurfaceBackground(cornerRadius: 13, elevated: false, pressed: true, tint: tint.opacity(0.08), lightweight: true))
        }
        .padding(12)
        .background(
            NeumorphicSurfaceBackground(
                cornerRadius: 24,
                elevated: true,
                tint: tint.opacity(0.055),
                lightweight: true
            )
        )
    }

    @ViewBuilder
    private var cover: some View {
        if let url = playlist.displayCoverUrl {
            CachedAsyncImage(url: url.sized(260)) {
                placeholder
            }
            .aspectRatio(contentMode: .fill)
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.42), NeumorphicStyle.surfacePressed],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            MonologueIcon(
                icon: playlist.isFavorite ? .liked : playlist.isDownload ? .download : .musicNoteList,
                size: 22,
                color: Color(light: .white, dark: NeumorphicStyle.ink),
                lineWidth: 1.8
            )
        }
    }

    private var platformDot: some View {
        Capsule()
            .fill(tint.opacity(0.82))
            .frame(width: 18, height: 4)
    }
}

struct NeumorphicPlaylistShelfRow: View {
    let playlist: Playlist
    let tint: Color

    var body: some View {
        HStack(spacing: 13) {
            CachedAsyncImage(url: playlist.coverUrl?.sized(260)) {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(NeumorphicStyle.surfacePressed)
                    .overlay(MonologueIcon(icon: .list, size: 22, color: NeumorphicStyle.inkMuted.opacity(0.6), lineWidth: 1.7))
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(playlist.name)
                    .font(NeumorphicStyle.bodyFont(15, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.ink)
                    .lineLimit(1)

                HStack(spacing: 7) {
                    Text(playlist.source == .qqmusic ? "QCM" : "NCM")
                        .font(NeumorphicStyle.labelFont(10, weight: .semibold))
                        .foregroundStyle(tint)

                    Text(metaText)
                        .font(NeumorphicStyle.labelFont(11, weight: .medium))
                        .foregroundStyle(NeumorphicStyle.inkMuted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            MonologueIcon(icon: .chevronRight, size: 12, color: tint.opacity(0.72), lineWidth: 1.8)
                .frame(width: 34, height: 34)
                .background(NeumorphicSurfaceBackground(cornerRadius: 13, elevated: false, pressed: true, tint: tint.opacity(0.08), lightweight: true))
        }
        .padding(12)
        .background(
            NeumorphicSurfaceBackground(
                cornerRadius: 24,
                elevated: true,
                tint: tint.opacity(0.055),
                lightweight: true
            )
        )
    }

    private var metaText: String {
        if let trackCount = playlist.trackCount, trackCount > 0 {
            return String(format: String(localized: "songs_count_format"), trackCount)
        }
        if let playCount = playlist.playCount, playCount > 0 {
            return cinematicFormatCount(playCount)
        }
        return String(localized: "歌单")
    }
}

struct NeumorphicPodcastShelfRow: View {
    let radio: RadioStation
    let tint: Color

    var body: some View {
        HStack(spacing: 13) {
            CachedAsyncImage(url: radio.coverUrl) {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(NeumorphicStyle.surfacePressed)
                    .overlay(MonologueIcon(icon: .radio, size: 22, color: NeumorphicStyle.inkMuted.opacity(0.6), lineWidth: 1.7))
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(radio.name)
                    .font(NeumorphicStyle.bodyFont(15, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.ink)
                    .lineLimit(1)

                Text(radio.dj?.nickname ?? radio.category ?? "Podcast")
                    .font(NeumorphicStyle.labelFont(11, weight: .medium))
                    .foregroundStyle(NeumorphicStyle.inkMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            MonologueIcon(icon: .chevronRight, size: 12, color: tint.opacity(0.72), lineWidth: 1.8)
                .frame(width: 34, height: 34)
                .background(NeumorphicSurfaceBackground(cornerRadius: 13, elevated: false, pressed: true, tint: tint.opacity(0.08), lightweight: true))
        }
        .padding(12)
        .background(
            NeumorphicSurfaceBackground(
                cornerRadius: 24,
                elevated: true,
                tint: tint.opacity(0.055),
                lightweight: true
            )
        )
    }
}

struct NeumorphicPlaylistShelfCard: View {
    let playlist: Playlist
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                CachedAsyncImage(url: playlist.coverUrl?.sized(500)) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(NeumorphicStyle.surfacePressed)
                        .overlay(MonologueIcon(icon: .musicNoteList, size: 24, color: NeumorphicStyle.inkMuted.opacity(0.55), lineWidth: 1.7))
                }
                .aspectRatio(1, contentMode: .fill)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                Text(playlist.source == .qqmusic ? "QCM" : "NCM")
                    .font(NeumorphicStyle.labelFont(9, weight: .semibold))
                    .foregroundStyle(Color(light: .white, dark: .black))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(tint))
                    .padding(8)
            }

            Text(playlist.name)
                .font(NeumorphicStyle.labelFont(13, weight: .semibold))
                .foregroundStyle(NeumorphicStyle.ink)
                .lineLimit(2)
                .frame(minHeight: 36, alignment: .topLeading)

            HStack(spacing: 6) {
                Capsule()
                    .fill(tint.opacity(0.8))
                    .frame(width: 18, height: 3)
                Text(metaText)
                    .font(NeumorphicStyle.labelFont(10, weight: .medium))
                    .foregroundStyle(NeumorphicStyle.inkMuted)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .background(NeumorphicSurfaceBackground(cornerRadius: 24, elevated: true, tint: tint.opacity(0.055), lightweight: true))
    }

    private var metaText: String {
        if let playCount = playlist.playCount, playCount > 0 {
            return cinematicFormatCount(playCount)
        }
        if let trackCount = playlist.trackCount, trackCount > 0 {
            return String(format: String(localized: "songs_count_format"), trackCount)
        }
        return String(localized: "推荐")
    }
}

struct NeumorphicArtistShelfTile: View {
    let artist: ArtistInfo
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                CachedAsyncImage(url: artist.coverUrl?.sized(400)) {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(NeumorphicStyle.surfacePressed)
                        .overlay(
                            MonologueIcon(
                                icon: .personCircle,
                                size: 25,
                                color: NeumorphicStyle.inkMuted.opacity(0.58),
                                lineWidth: 1.7
                            )
                        )
                }
                .aspectRatio(1, contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                MonologueIcon(icon: .chevronRight, size: 11, color: tint, lineWidth: 1.8)
                    .frame(width: 30, height: 30)
                    .background(
                        NeumorphicSurfaceBackground(
                            cornerRadius: 12,
                            elevated: false,
                            pressed: true,
                            tint: tint.opacity(0.12),
                            lightweight: true
                        )
                    )
                    .padding(8)
            }

            Text(artist.name)
                .font(NeumorphicStyle.labelFont(13, weight: .semibold))
                .foregroundStyle(NeumorphicStyle.ink)
                .lineLimit(1)

            HStack(spacing: 6) {
                Capsule()
                    .fill(tint.opacity(0.82))
                    .frame(width: 18, height: 3)

                Text(artist.source == .qqmusic ? "QCM" : "NCM")
                    .font(NeumorphicStyle.labelFont(10, weight: .semibold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .background(NeumorphicSurfaceBackground(cornerRadius: 24, elevated: true, tint: tint.opacity(0.055), lightweight: true))
    }
}

struct NeumorphicChartShelfRow: View {
    let list: TopList
    let tint: Color

    var body: some View {
        HStack(spacing: 13) {
            CachedAsyncImage(url: list.coverUrl?.sized(300)) {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(NeumorphicStyle.surfacePressed)
                    .overlay(MonologueIcon(icon: .chart, size: 22, color: NeumorphicStyle.inkMuted.opacity(0.6), lineWidth: 1.7))
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 58, height: 58)
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(list.name)
                    .font(NeumorphicStyle.bodyFont(15, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.ink)
                    .lineLimit(1)

                Text(list.updateFrequency)
                    .font(NeumorphicStyle.labelFont(11, weight: .medium))
                    .foregroundStyle(NeumorphicStyle.inkMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            MonologueIcon(icon: .chevronRight, size: 12, color: tint.opacity(0.72), lineWidth: 1.8)
        }
        .padding(12)
        .background(NeumorphicSurfaceBackground(cornerRadius: 24, elevated: true, tint: tint.opacity(0.055), lightweight: true))
    }
}

struct NeumorphicQQChartShelfRow: View {
    let item: QQTopListItem
    let tint: Color

    var body: some View {
        HStack(spacing: 13) {
            CachedAsyncImage(url: item.coverURL) {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(NeumorphicStyle.surfacePressed)
                    .overlay(MonologueIcon(icon: .chart, size: 22, color: NeumorphicStyle.inkMuted.opacity(0.6), lineWidth: 1.7))
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 58, height: 58)
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(NeumorphicStyle.bodyFont(15, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.ink)
                    .lineLimit(1)

                Text(item.period.isEmpty ? item.intro : item.period)
                    .font(NeumorphicStyle.labelFont(11, weight: .medium))
                    .foregroundStyle(NeumorphicStyle.inkMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            MonologueIcon(icon: .chevronRight, size: 12, color: tint.opacity(0.72), lineWidth: 1.8)
        }
        .padding(12)
        .background(NeumorphicSurfaceBackground(cornerRadius: 24, elevated: true, tint: tint.opacity(0.055), lightweight: true))
    }
}

struct NeumorphicChartTile: View {
    let list: TopList
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            CachedAsyncImage(url: list.coverUrl?.sized(300)) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(NeumorphicStyle.surfacePressed)
            }
            .aspectRatio(1, contentMode: .fill)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Text(list.name)
                .font(NeumorphicStyle.labelFont(13, weight: .semibold))
                .foregroundStyle(NeumorphicStyle.ink)
                .lineLimit(2)

            Text(list.updateFrequency)
                .font(NeumorphicStyle.labelFont(10, weight: .medium))
                .foregroundStyle(tint)
                .lineLimit(1)
        }
        .padding(10)
        .background(NeumorphicSurfaceBackground(cornerRadius: 24, elevated: true, tint: tint.opacity(0.055), lightweight: true))
    }
}
