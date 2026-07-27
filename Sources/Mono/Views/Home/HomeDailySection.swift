import SwiftUI

/// 每日推荐 — 宽幅横卡横滑，封面全覆盖 + 底部渐变叠文字
struct HomeDailySection: View {
    let songs: [Song]
    let onViewAll: () -> Void
    let onPlay: (Song) -> Void

    @ObservedObject private var playback = SongRowPlaybackModel.shared
    @State private var animatedCount: Int = 0
    @State private var countAnimated = false

    var body: some View {
        if MinimalWhiteStyle.isActive {
            minimalWhiteBody
        } else {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader

                ScrollView(.horizontal) {
                    LazyHStack(spacing: 12) {
                        ForEach(Array(songs.prefix(15).enumerated()), id: \.element.id) { idx, song in
                            Button(action: { onPlay(song) }) {
                                dailySongCard(song, rank: idx + 1)
                            }
                            .buttonStyle(MonoBouncingButtonStyle())
                            .compatScrollTransition(animation: .spring(response: 0.35)) { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity ? 1 : 0.93)
                                    .opacity(phase.isIdentity ? 1 : 0.5)
                                    .offset(y: phase.isIdentity ? 0 : phase.value * 8)
                            }
                        }
                    }
                    .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                    .compatScrollTargetLayout()
                }
                .scrollIndicators(.hidden)
                .themeRenderScrollLayer()
                .compatViewAlignedScrollBehavior(limitNever: true)
            }
        }
    }

    // MARK: - Header

    private var sectionHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey("made_for_you"))
                    .font(NeumorphicStyle.isActive ? NeumorphicStyle.titleFont(20, weight: .semibold) : .system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(.monoTextPrimary)
                    .tracking(NeumorphicStyle.isActive ? 0 : -0.3)

                HStack(spacing: 0) {
                    Text("\(animatedCount)")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(.monoTextPrimary)
                        .compatNumericTextTransition(countsDown: false)

                    Text(" " + NSLocalizedString("fresh_tunes_daily", comment: ""))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.monoTextSecondary)
                }
            }

            Spacer()

            Button(action: onViewAll) {
                HStack(spacing: 4) {
                    Text(LocalizedStringKey("view_all"))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                    MonoIcon(icon: .chevronRight, size: 8, color: .monoTextSecondary)
                }
                .foregroundColor(.monoTextSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background {
                    if NeumorphicStyle.isActive {
                        NeumorphicSurfaceBackground(cornerRadius: 13, elevated: false, pressed: true, lightweight: true)
                    } else {
                        Capsule().fill(Color.monoTextSecondary.opacity(0.06))
                    }
                }
            }
            .buttonStyle(MonoBouncingButtonStyle())
            .padding(.bottom, 1)
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        .onAppear {
            guard !countAnimated else { return }
            countAnimated = true
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3)) {
                animatedCount = songs.count
            }
        }
    }

    // MARK: - Song Card

    @Environment(\.colorScheme) private var colorScheme

    private var cardWidth: CGFloat { DeviceLayout.dailyCardSize }

    private var minimalWhiteBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            MinimalWhiteSectionTitle(title: String(localized: "made_for_you")) {
                Button(action: onViewAll) {
                    MinimalWhiteDisclosureGlyph()
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

            VStack(spacing: 0) {
                ForEach(Array(songs.prefix(6).enumerated()), id: \.element.id) { index, song in
                    Button {
                        onPlay(song)
                    } label: {
                        minimalWhiteSongRow(song, rank: index + 1)
                    }
                    .buttonStyle(.plain)

                    if index < min(songs.count, 6) - 1 {
                        Rectangle()
                            .fill(MinimalWhiteStyle.hairline)
                            .frame(height: 1)
                            .padding(.leading, 62)
                    }
                }
            }
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        }
    }

    private func minimalWhiteSongRow(_ song: Song, rank: Int) -> some View {
        let isCurrent = playback.currentSongId == song.id
        let isPlaying = isCurrent && playback.isPlaying

        return HStack(spacing: 12) {
            CachedAsyncImage(url: song.coverUrl, width: 50, height: 50) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(MinimalWhiteStyle.controlGlassFill)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(MinimalWhiteStyle.hairline, lineWidth: MinimalWhiteStyle.strokeWidth)
            )
            .overlay(alignment: .bottomTrailing) {
                if isCurrent {
                    PlayingVisualizerView(isAnimating: isPlaying, color: MinimalWhiteStyle.onAccent)
                        .frame(width: 15, height: 12)
                        .padding(4)
                        .background(MinimalWhiteStyle.ink, in: Circle())
                        .offset(x: 4, y: 4)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(song.name)
                    .font(MinimalWhiteStyle.bodyFont(14, weight: .medium))
                    .foregroundStyle(isCurrent ? MinimalWhiteStyle.ink : MinimalWhiteStyle.ink)
                    .lineLimit(1)

                Text(song.artistName)
                    .font(MinimalWhiteStyle.labelFont(12, weight: .regular))
                    .foregroundStyle(isCurrent ? MinimalWhiteStyle.inkSoft : MinimalWhiteStyle.inkMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text("\(rank)")
                .font(MinimalWhiteStyle.labelFont(12, weight: .regular))
                .foregroundStyle(MinimalWhiteStyle.inkMuted)
                .frame(width: 24, alignment: .trailing)
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }

    private func dailySongCard(_ song: Song, rank: Int) -> some View {
        let isCurrent = playback.currentSongId == song.id
        let isPlaying = isCurrent && playback.isPlaying

        return VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                CachedAsyncImage(url: song.coverUrl, width: cardWidth, height: cardWidth) {
                    RoundedRectangle(cornerRadius: 0)
                        .fill(Color.monoSeparator)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: cardWidth, height: cardWidth)
                .clipped()

                // 排名角标
                Text("\(rank)")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : .white)
                    .frame(width: 22, height: 22)
                    .background(rankBackground)
                    .padding(6)

                // 正在播放指示
                if isCurrent {
                    PlayingVisualizerView(isAnimating: isPlaying, color: .white)
                        .frame(width: 20, height: 16)
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }
            }
            .frame(width: cardWidth, height: cardWidth)

            VStack(alignment: .leading, spacing: 2) {
                Text(song.name)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.monoTextPrimary)
                    .lineLimit(1)

                Text(song.artistName)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(isCurrent ? .monoAccent : .monoTextSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .frame(width: cardWidth, alignment: .leading)
            .background(
                NeumorphicStyle.isActive
                    ? NeumorphicStyle.surfaceRaised.opacity(0.72)
                    : (ThemedPageStyle.isActive ? Color.monoGlassTint : Color.clear)
            )
            .modifier(DailyInfoSurfaceModifier())
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .background {
            if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 16, elevated: true)
            }
        }
    }

    private var rankBackground: some View {
        Group {
            if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 7, elevated: false, pressed: true, lightweight: true)
            } else {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(light: .black.opacity(0.15), dark: .white.opacity(0.12)))
                    .monoGlass(cornerRadius: 7)
            }
        }
    }
}

private struct DailyInfoSurfaceModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if NeumorphicStyle.isActive {
            content
        } else {
            content.homeInformationSurface(cornerRadius: 0, showsTopSeparator: true)
        }
    }
}

// MARK: - 脉冲光圈动画（正在播放的封面）

struct PulseRingView: View {
    let color: Color
    @State private var pulse = false

    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(color.opacity(pulse ? 0 : 0.5), lineWidth: pulse ? 6 : 2)
            .scaleEffect(pulse ? 1.08 : 1.0)
            .animation(
                .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                value: pulse
            )
            .onAppear { pulse = true }
            .onDisappear {
                var transaction = Transaction(animation: nil)
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    pulse = false
                }
            }
    }
}
