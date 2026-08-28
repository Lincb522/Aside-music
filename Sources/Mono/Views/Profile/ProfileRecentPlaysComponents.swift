import Combine
import QQMusicKit
import SwiftUI

enum ProfileRecentPlaysVariant {
    case standard
    case manga
    case neumorphic
    case capsule
    case signal
    case sequoia
}

struct SignalProfilePulseStrip: View {
    let tint: Color

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<18, id: \.self) { index in
                Capsule()
                    .fill(index < 12 ? tint.opacity(0.82) : SignalStyle.inkMuted.opacity(0.2))
                    .frame(maxWidth: .infinity)
                    .frame(height: 4 + CGFloat(index % 5))
            }
        }
        .padding(12)
        .background(SignalScreenBackground(cornerRadius: 18))
    }
}

struct ProfileRecentPlaysHost: View {
    let variant: ProfileRecentPlaysVariant

    @State private var history = PlayerManager.shared.history
    @State private var currentSongID = PlayerManager.shared.currentSong?.id
    @State private var isPlaying = PlayerManager.shared.isPlaying

    var body: some View {
        Group {
            if !history.isEmpty {
                if PetWhiteStyle.isActive {
                    petWhiteRecentPlays(history: history)
                } else {
                switch variant {
                case .standard:
                    standardRecentPlays(history: history)
                case .manga:
                    mangaRecentPlays(history: history)
                case .neumorphic:
                    neumorphicRecentPlays(history: history)
                case .capsule:
                    capsuleRecentPlays(history: history)
                case .signal:
                    signalRecentPlays(history: history)
                case .sequoia:
                    sequoiaRecentPlays(history: history)
                }
                }
            }
        }
        .task {
            guard await MainTabActivationGate.waitUntilSettled(.profile) else { return }
            history = PlayerManager.shared.history
            currentSongID = PlayerManager.shared.currentSong?.id
            isPlaying = PlayerManager.shared.isPlaying
        }
        .onReceive(PlayerManager.shared.$history.removeDuplicates()) { history in
            guard MainTabActivationGate.isSettled(.profile) else { return }
            self.history = history
        }
        .onReceive(PlayerManager.shared.$currentSong.map { $0?.id }.removeDuplicates()) { currentSongID in
            guard MainTabActivationGate.isSettled(.profile) else { return }
            self.currentSongID = currentSongID
        }
        .onReceive(PlayerManager.shared.$isPlaying.removeDuplicates()) { isPlaying in
            guard MainTabActivationGate.isSettled(.profile) else { return }
            self.isPlaying = isPlaying
        }
    }

    private func petWhiteRecentPlays(history: [Song]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                PetWhiteIconBadge(icon: .history, tint: PetWhiteStyle.sky, size: 32)

                VStack(alignment: .leading, spacing: 3) {
                    Text(String(localized: "profile_recently_played"))
                        .font(PetWhiteStyle.titleFont(18, weight: .black))
                        .foregroundStyle(PetWhiteStyle.ink)
                        .lineLimit(1)

                    Text(String(format: String(localized: "profile_recent_count"), history.count))
                        .font(PetWhiteStyle.labelFont(11, weight: .semibold))
                        .foregroundStyle(PetWhiteStyle.inkSoft)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                NavigationLink(destination: RecentPlayHistoryView()) {
                    PetWhitePill(
                        text: String(localized: "view_all"),
                        tint: PetWhiteStyle.butter
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(Array(history.prefix(12).enumerated()), id: \.element.id) { index, song in
                        Button {
                            PlayerManager.shared.play(song: song, in: history)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                CachedAsyncImage(url: song.coverUrl) {
                                    PetWhiteMascotMark(kind: index.isMultiple(of: 2) ? .cat : .dog, size: 44)
                                        .frame(width: 112, height: 112)
                                        .background(PetWhiteStyle.surfacePressed)
                                }
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 112, height: 112)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(PetWhiteStyle.stroke, lineWidth: 1)
                                )
                                .overlay(alignment: .bottomTrailing) {
                                    PetWhitePackIcon(icon: .play, size: 14, visualScale: 1.06)
                                        .frame(width: 30, height: 30)
                                        .background(PetWhiteStyle.mint, in: Circle())
                                        .overlay(Circle().stroke(PetWhiteStyle.stroke, lineWidth: 1.1))
                                        .padding(8)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(song.name)
                                        .font(PetWhiteStyle.bodyFont(13, weight: .black))
                                        .foregroundStyle(PetWhiteStyle.ink)
                                        .lineLimit(1)

                                    Text(song.artistName)
                                        .font(PetWhiteStyle.labelFont(11, weight: .semibold))
                                        .foregroundStyle(PetWhiteStyle.inkSoft)
                                        .lineLimit(1)
                                }
                                .frame(width: 112, alignment: .leading)
                            }
                            .padding(10)
                            .background(
                                PetWhiteSurfaceBackground(
                                    cornerRadius: 22,
                                    elevated: true,
                                    tint: PetWhiteStyle.surfaceRaised,
                                    accent: PetWhiteStyle.sky
                                )
                            )
                        }
                        .buttonStyle(MonoBouncingButtonStyle(scale: 0.96))
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
    }

    private func sequoiaRecentPlays(history: [Song]) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 9) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(SequoiaStyle.accentGradient)
                    .frame(width: 3, height: 18)

                Text(String(localized: "profile_recently_played"))
                    .font(SequoiaStyle.titleFont(17, weight: .semibold))
                    .foregroundStyle(SequoiaStyle.ink)
                    .lineLimit(1)

                Spacer(minLength: 8)

                NavigationLink(destination: RecentPlayHistoryView()) {
                    SequoiaPill(
                        text: String(format: String(localized: "profile_recent_count"), history.count),
                        icon: .chevronRight,
                        tint: SequoiaStyle.aqua,
                        compact: true
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(Array(history.prefix(15))) { song in
                        Button {
                            PlayerManager.shared.play(song: song, in: history)
                        } label: {
                            SequoiaProfileRecentCard(
                                song: song,
                                isPlaying: currentSongID == song.id && isPlaying
                            )
                        }
                        .buttonStyle(MonoBouncingButtonStyle(scale: 0.96))
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
    }

    private func capsuleRecentPlays(history: [Song]) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            CapsuleSectionTitle(title: String(localized: "profile_recently_played"), tint: CapsuleStyle.cyan) {
                NavigationLink(destination: RecentPlayHistoryView()) {
                    CapsulePillLabel(
                        title: String(format: String(localized: "profile_recent_count"), history.count),
                        icon: .chevronRight,
                        tint: CapsuleStyle.cyan
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(Array(history.prefix(14))) { song in
                        Button {
                            PlayerManager.shared.play(song: song, in: history)
                        } label: {
                            CapsuleProfileRecentCard(
                                song: song,
                                isPlaying: currentSongID == song.id && isPlaying
                            )
                        }
                        .buttonStyle(CapsulePressStyle())
                    }
                }
                .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                .padding(.vertical, 3)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
    }

    private func standardRecentPlays(history: [Song]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(LocalizedStringKey("profile_recently_played"))
                    .font(MangaStyle.isActive ? MangaStyle.titleFont(18, weight: .black) : (MujiStyle.isActive ? MujiStyle.titleFont(18, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.titleFont(18, weight: .semibold) : .system(size: 18, weight: .bold, design: .rounded))))
                    .foregroundColor(.monoTextPrimary)

                Spacer()

                NavigationLink(destination: RecentPlayHistoryView()) {
                    HStack(spacing: 4) {
                        Text(String(format: String(localized: "profile_recent_count"), history.count))
                            .font(MangaStyle.isActive ? MangaStyle.comicFont(13, weight: .medium) : (MujiStyle.isActive ? MujiStyle.labelFont(13, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(13, weight: .medium) : .system(size: 13, weight: .medium, design: .rounded))))
                            .foregroundColor(.monoTextSecondary)
                        MonoIcon(icon: .chevronRight, size: 12, color: .monoTextSecondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 14) {
                    ForEach(Array(history.prefix(15))) { song in
                        Button {
                            PlayerManager.shared.play(song: song, in: history)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                CachedAsyncImage(url: song.coverUrl, width: 110, height: 110) {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.monoSeparator)
                                }
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 110, height: 110)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(song.name)
                                        .font(MangaStyle.isActive ? MangaStyle.comicFont(13, weight: .bold) : (MujiStyle.isActive ? MujiStyle.bodyFont(13, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(13, weight: .semibold) : .system(size: 13, weight: .semibold, design: .rounded))))
                                        .foregroundColor(.monoTextPrimary)
                                        .lineLimit(1)

                                    Text(song.artistName)
                                        .font(MangaStyle.isActive ? MangaStyle.comicFont(11, weight: .medium) : (MujiStyle.isActive ? MujiStyle.labelFont(11, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(11, weight: .regular) : .system(size: 11, weight: .medium, design: .rounded))))
                                        .foregroundColor(.monoTextSecondary)
                                        .lineLimit(1)
                                }
                                .frame(width: 110, alignment: .leading)
                            }
                        }
                        .buttonStyle(MonoBouncingButtonStyle())
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
    }

    private func mangaRecentPlays(history: [Song]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                MangaSectionMark(kind: .star)

                Text(String(localized: "profile_recently_played"))
                    .font(MangaStyle.titleFont(18, weight: .black))
                    .foregroundStyle(MangaStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Rectangle()
                    .fill(MangaStyle.ink.opacity(0.22))
                    .frame(height: 1.4)

                NavigationLink(destination: RecentPlayHistoryView()) {
                    MangaLabel(
                        text: String(format: String(localized: "profile_recent_count"), history.count),
                        tint: MangaStyle.decoBlue,
                        small: true
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(Array(history.prefix(12))) { song in
                        Button {
                            PlayerManager.shared.play(song: song, in: history)
                        } label: {
                            MangaProfileRecentCard(song: song)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.bottom, 4)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
    }

    private func neumorphicRecentPlays(history: [Song]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                NeumorphicIconBadge(icon: .history, tint: NeumorphicStyle.sage, size: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "profile_recently_played"))
                        .font(NeumorphicStyle.titleFont(18, weight: .semibold))
                        .foregroundStyle(NeumorphicStyle.ink)

                    Text(String(format: String(localized: "profile_recent_count"), history.count))
                        .font(NeumorphicStyle.labelFont(11, weight: .medium))
                        .foregroundStyle(NeumorphicStyle.inkMuted)
                }

                Spacer()

                NavigationLink(destination: RecentPlayHistoryView()) {
                    NeumorphicPill(
                        text: String(localized: "common_view_more"),
                        tint: NeumorphicStyle.accent,
                        icon: .chevronRight,
                        compact: true
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(Array(history.prefix(12))) { song in
                        Button {
                            PlayerManager.shared.play(song: song, in: history)
                        } label: {
                            NeumorphicProfileRecentCard(
                                song: song,
                                isPlaying: currentSongID == song.id && isPlaying
                            )
                        }
                        .buttonStyle(MonoBouncingButtonStyle(scale: 0.97))
                    }
                }
                .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
    }

    private func signalRecentPlays(history: [Song]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                SignalIconBadge(icon: .history, tint: SignalStyle.olive, size: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "profile_recently_played"))
                        .font(SignalStyle.titleFont(18, weight: .bold))
                        .foregroundStyle(SignalStyle.ink)

                    Text(String(format: String(localized: "profile_recent_count"), history.count))
                        .font(SignalStyle.labelFont(11, weight: .medium))
                        .foregroundStyle(SignalStyle.inkMuted)
                }

                Spacer()

                NavigationLink(destination: RecentPlayHistoryView()) {
                    SignalPill(
                        text: String(localized: "common_view_more"),
                        tint: SignalStyle.accent,
                        icon: .chevronRight,
                        compact: true
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(Array(history.prefix(12))) { song in
                        Button {
                            PlayerManager.shared.play(song: song, in: history)
                        } label: {
                            SignalProfileRecentCard(
                                song: song,
                                isPlaying: currentSongID == song.id && isPlaying
                            )
                        }
                        .buttonStyle(MonoBouncingButtonStyle(scale: 0.97))
                    }
                }
                .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
    }
}
