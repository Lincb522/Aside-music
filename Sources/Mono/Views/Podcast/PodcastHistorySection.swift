import Combine
import SwiftUI

struct PodcastHistorySection: View {
    let onOpenRadio: (Int) -> Void

    @State private var history: [Song]
    @State private var currentSongID: Int?
    @State private var isPlaying: Bool

    private let player = PlayerManager.shared

    init(onOpenRadio: @escaping (Int) -> Void) {
        self.onOpenRadio = onOpenRadio
        _history = State(initialValue: Self.uniqued(PlayerManager.shared.podcastHistory))
        _currentSongID = State(initialValue: PlayerManager.shared.currentSong?.id)
        _isPlaying = State(initialValue: PlayerManager.shared.isPlaying)
    }

    var body: some View {
        Group {
            if !history.isEmpty {
                content
            }
        }
        .task {
            guard await MainTabActivationGate.waitUntilSettled(.podcast) else { return }
            history = Self.uniqued(player.podcastHistory)
            currentSongID = player.currentSong?.id
            isPlaying = player.isPlaying
        }
        .onReceive(PlayerManager.shared.$podcastHistory.map { Self.uniqued($0) }) { history in
            guard MainTabActivationGate.isSettled(.podcast) else { return }
            self.history = history
        }
        .onReceive(PlayerManager.shared.$currentSong.map { $0?.id }.removeDuplicates()) { currentSongID in
            guard MainTabActivationGate.isSettled(.podcast) else { return }
            self.currentSongID = currentSongID
        }
        .onReceive(PlayerManager.shared.$isPlaying.removeDuplicates()) { isPlaying in
            guard MainTabActivationGate.isSettled(.podcast) else { return }
            self.isPlaying = isPlaying
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            historyHeader

            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(history.prefix(10)) { song in
                        historyCard(song: song)
                            .compatScrollTransition(animation: .spring(response: 0.35)) { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity ? 1 : 0.93)
                                    .opacity(phase.isIdentity ? 1 : 0.5)
                                    .offset(y: phase.isIdentity ? 0 : phase.value * 8)
                            }
                    }
                }
                .compatScrollTargetLayout()
                .padding(.horizontal, padH)
            }
            .compatViewAlignedScrollBehavior(limitNever: true)
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
    }

    @ViewBuilder
    private var historyHeader: some View {
        if MujiStyle.isActive {
            HStack(alignment: .bottom, spacing: 14) {
                MujiSectionTitle(title: String(localized: "profile_recently_played"))

                Spacer(minLength: 0)

                Button(action: clearHistory) {
                    MujiPill(text: String(localized: "storage_clear"), tint: MujiStyle.red)
                }
                .buttonStyle(.plain)

                NavigationLink(destination: RecentPlayHistoryView(songs: history)) {
                    MujiPill(text: String(localized: "view_all"), tint: MujiStyle.tea)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, padH)
        } else if NeumorphicStyle.isActive {
            HStack(alignment: .center, spacing: 14) {
                NeumorphicSectionTitle(title: String(localized: "profile_recently_played"))

                Spacer(minLength: 0)

                Button(action: clearHistory) {
                    NeumorphicPill(text: String(localized: "storage_clear"), tint: NeumorphicStyle.red, icon: .trash, compact: true)
                }
                .buttonStyle(.plain)

                NavigationLink(destination: RecentPlayHistoryView(songs: history)) {
                    NeumorphicPill(text: String(localized: "view_all"), tint: NeumorphicStyle.accent, icon: .chevronRight, selected: true, compact: true)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, padH)
        } else if SequoiaStyle.isActive {
            HStack(alignment: .center, spacing: 10) {
                SequoiaIconBadge(icon: .history, tint: SequoiaStyle.green, size: 32)

                Text(LocalizedStringKey("profile_recently_played"))
                    .font(SequoiaStyle.titleFont(17, weight: .semibold))
                    .foregroundStyle(SequoiaStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 8)

                Button(action: clearHistory) {
                    SequoiaPill(text: String(localized: "storage_clear"), icon: .trash, tint: SequoiaStyle.red, compact: true)
                }
                .buttonStyle(.plain)

                NavigationLink(destination: RecentPlayHistoryView(songs: history)) {
                    SequoiaPill(text: String(localized: "view_all"), icon: .chevronRight, tint: SequoiaStyle.accent, selected: true, compact: true)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, padH)
        } else if !ThemedPageStyle.isActive {
            HStack(alignment: .center, spacing: 8) {
                Capsule()
                    .fill(Color.monoAccent)
                    .frame(width: 3, height: 13)

                Text(LocalizedStringKey("profile_recently_played"))
                    .font(.rounded(size: 15.5, weight: .bold))
                    .foregroundColor(.monoTextPrimary)
                    .lineLimit(1)
                    .fixedSize()

                Rectangle()
                    .fill(Color.monoSeparator.opacity(0.5))
                    .frame(height: 0.5)

                Button(action: clearHistory) {
                    Text(LocalizedStringKey("storage_clear"))
                        .font(.rounded(size: 12, weight: .semibold))
                        .foregroundColor(.monoTextSecondary.opacity(0.85))
                        .fixedSize()
                }
                .buttonStyle(.plain)

                NavigationLink(destination: RecentPlayHistoryView(songs: history)) {
                    HStack(spacing: 3) {
                        Text(LocalizedStringKey("view_all"))
                            .font(.rounded(size: 12, weight: .semibold))
                        MonoIcon(icon: .chevronRight, size: 10, color: .monoTextSecondary.opacity(0.8), lineWidth: 1.7)
                    }
                    .foregroundColor(.monoTextSecondary.opacity(0.85))
                    .fixedSize()
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, padH)
        } else {
            HStack {
                Text(LocalizedStringKey("profile_recently_played"))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.monoTextPrimary)

                Spacer()

                HStack(spacing: 12) {
                    Button(action: clearHistory) {
                        HStack(spacing: 4) {
                            MonoIcon(icon: .trash, size: 12, color: .monoTextSecondary, lineWidth: 1.2)
                            Text(LocalizedStringKey("storage_clear"))
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(.monoTextSecondary)
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: RecentPlayHistoryView(songs: history)) {
                        HStack(spacing: 4) {
                            Text(LocalizedStringKey("view_all"))
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                            MonoIcon(icon: .chevronRight, size: 12, color: .monoTextSecondary, lineWidth: 1.2)
                        }
                        .foregroundColor(.monoTextSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, padH)
        }
    }

    @ViewBuilder
    private func historyCard(song: Song) -> some View {
        if ThemedPageStyle.isActive {
            themedHistoryCard(song: song)
        } else {
            asideHistoryCard(song: song)
        }
    }

    /// aside 最近播放卡：发丝描边横卡
    private func asideHistoryCard(song: Song) -> some View {
        let cardWidth: CGFloat = DeviceLayout.isPad ? 220 : 184
        let coverSide: CGFloat = DeviceLayout.isPad ? 46 : 42
        let isCurrent = currentSongID == song.id

        return Button {
            HapticStyle.light.trigger()
            let rid = song.podcastRadioId ?? song.album?.id ?? 0
            player.playPodcast(song: song, in: player.podcastHistory, radioId: rid)
            if rid > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    onOpenRadio(rid)
                }
            }
        } label: {
            HStack(spacing: 11) {
                ZStack {
                    CachedAsyncImage(url: song.coverUrl) {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(Color.monoSeparator.opacity(0.35))
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: coverSide, height: coverSide)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(Color.monoTextPrimary.opacity(0.08), lineWidth: 0.8)
                    )

                    if isCurrent {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(Color.black.opacity(0.32))
                            .frame(width: coverSide, height: coverSide)

                        PlayingVisualizerView(isAnimating: isPlaying, color: .white)
                            .frame(width: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(song.name)
                        .font(.rounded(size: 12.5, weight: .semibold))
                        .foregroundColor(isCurrent ? .monoAccent : .monoTextPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    let subtitle = song.podcastRadioName ?? song.ar?.first?.name ?? ""
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.rounded(size: 10.5, weight: .medium))
                            .foregroundColor(.monoTextSecondary.opacity(0.85))
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .frame(width: cardWidth)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isCurrent ? Color.monoAccent.opacity(0.5) : Color.monoSeparator.opacity(0.85), lineWidth: 0.8)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(MonoBouncingButtonStyle())
    }

    private func themedHistoryCard(song: Song) -> some View {
        let cardWidth: CGFloat = DeviceLayout.isPad ? 220 : 180
        let cardHeight: CGFloat = DeviceLayout.isPad ? 64 : 56
        let cr: CGFloat = MujiStyle.isActive ? 8 : ((NeumorphicStyle.isActive || SequoiaStyle.isActive) ? 16 : 12)
        let isCurrent = currentSongID == song.id
        let placeholderFill: Color = SequoiaStyle.isActive ? SequoiaStyle.materialList : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monoGlassTint)
        let titleFont: Font = SequoiaStyle.isActive ? SequoiaStyle.bodyFont(13, weight: .semibold) : (MujiStyle.isActive ? MujiStyle.bodyFont(13, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(13, weight: .semibold) : .system(size: 13, weight: .bold, design: .rounded)))
        let subtitleFont: Font = SequoiaStyle.isActive ? SequoiaStyle.labelFont(11, weight: .regular) : (MujiStyle.isActive ? MujiStyle.labelFont(11, weight: .regular) : .system(size: 11, design: .rounded))
        let titleColor: Color
        if isCurrent {
            titleColor = SequoiaStyle.isActive ? SequoiaStyle.accent : (NeumorphicStyle.isActive ? NeumorphicStyle.accent : .monoAccent)
        } else {
            titleColor = SequoiaStyle.isActive ? SequoiaStyle.ink : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monoTextPrimary)
        }
        let subtitleColor: Color = SequoiaStyle.isActive ? SequoiaStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monoTextSecondary)
        let cardFill: Color = SequoiaStyle.isActive ? .clear : (NeumorphicStyle.isActive ? NeumorphicStyle.surface : Color.monoGlassTint)

        return Button {
            HapticStyle.light.trigger()
            let rid = song.podcastRadioId ?? song.album?.id ?? 0
            player.playPodcast(song: song, in: player.podcastHistory, radioId: rid)
            if rid > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    onOpenRadio(rid)
                }
            }
        } label: {
            HStack(spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    CachedAsyncImage(url: song.coverUrl) {
                        RoundedRectangle(cornerRadius: cr)
                            .fill(placeholderFill)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: cardHeight, height: cardHeight)
                    .clipShape(RoundedRectangle(cornerRadius: cr, style: .continuous))

                    if isCurrent {
                        PlayingVisualizerView(isAnimating: isPlaying, color: .white)
                            .frame(width: 10)
                            .padding(4)
                            .background(Circle().fill(.black.opacity(0.4)))
                            .padding(4)
                            .clipShape(Circle())
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(song.name)
                        .font(titleFont)
                        .foregroundColor(titleColor)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    let subtitle = song.podcastRadioName ?? song.ar?.first?.name ?? ""
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(subtitleFont)
                            .foregroundColor(subtitleColor)
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.trailing, 12)
            .frame(width: cardWidth, height: cardHeight)
            .background(cardFill)
            .clipShape(RoundedRectangle(cornerRadius: cr, style: .continuous))
            .themedPageSurface(cornerRadius: cr, elevated: isCurrent)
        }
        .buttonStyle(MonoBouncingButtonStyle())
    }

    private var padH: CGFloat {
        DeviceLayout.viewHorizontalPadding
    }

    private func clearHistory() {
        HapticStyle.light.trigger()
        player.clearPodcastHistory()
    }

    private static func uniqued(_ songs: [Song]) -> [Song] {
        var seenIds = Set<Int>()
        var result = [Song]()
        for song in songs where !seenIds.contains(song.id) {
            seenIds.insert(song.id)
            result.append(song)
        }
        return result
    }
}
