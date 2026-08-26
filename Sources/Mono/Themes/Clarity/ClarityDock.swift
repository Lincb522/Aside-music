import SwiftUI

/// 通透主题自己的连续底座：歌曲条从页面内容与导航之间浮起，导航仍是
/// 同一层膜面的一部分，不使用通用悬浮胶囊骨架。
struct ClarityDock: View {
    @Binding var currentTab: Tab
    @ObservedObject private var playback = FloatingBarPlaybackModel.shared
    @State private var showsQueue = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(spacing: 0) {
                if playback.currentSong != nil { nowPlaying }
                navigation
            }
            .background {
                ClarityMembrane(
                    shape: RoundedRectangle(cornerRadius: 34, style: .continuous),
                    strength: .strong
                )
            }
            .frame(maxWidth: 680)
            .padding(.horizontal, DeviceLayout.isPad ? 28 : 14)
            .padding(.bottom, 5)
        }
        .monoSheet(isPresented: $showsQueue, preset: .standard) {
            playback.isPlayingPodcast ? AnyView(PodcastPlaylistPopupView()) : AnyView(PlaylistPopupView())
        }
    }

    private var nowPlaying: some View {
        HStack(spacing: 10) {
            Button(action: openPlayer) {
                ClarityArtwork(url: playback.currentSong?.coverUrl, size: 44, radius: 13)
            }
            .buttonStyle(ClarityPressStyle())

            Button(action: openPlayer) {
                VStack(alignment: .leading, spacing: 3) {
                    MarqueeText(
                        text: playback.currentSong?.name ?? String(localized: "not_playing"),
                        font: .system(size: 12.5, weight: .semibold, design: .default),
                        color: ClarityStyle.ink
                    )
                    Text(playback.lyricLineText ?? playback.currentSong?.artistName ?? "")
                        .font(ClarityStyle.body(10, weight: .medium))
                        .foregroundStyle(ClarityStyle.inkSoft)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button { playback.togglePlayPause() } label: {
                MonoIcon(icon: playback.isPlaying ? .pause : .play, size: 17, color: ClarityStyle.ink, lineWidth: 1.7)
                    .frame(width: 40, height: 40)
                    .background(ClarityMembrane(shape: Circle(), strength: .regular))
            }
            .buttonStyle(ClarityPressStyle())

            Button { showsQueue = true } label: {
                MonoIcon(icon: .list, size: 17, color: ClarityStyle.ink, lineWidth: 1.5)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(ClarityPressStyle())
        }
        .padding(.horizontal, 11)
        .padding(.top, 8)
        .padding(.bottom, 7)
        .overlay(alignment: .bottom) {
            ClarityDockProgress()
            .frame(height: 2)
            .padding(.horizontal, 20)
        }
    }

    private var navigation: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) { currentTab = tab }
                } label: {
                    VStack(spacing: 3) {
                        MonoIcon(
                            icon: tab.icon,
                            size: 17,
                            color: currentTab == tab ? ClarityStyle.ink : ClarityStyle.inkFaint,
                            lineWidth: currentTab == tab ? 1.9 : 1.45
                        )
                        Text(String(localized: String.LocalizationValue(tab.titleKey())))
                            .font(ClarityStyle.body(9, weight: currentTab == tab ? .semibold : .regular))
                            .foregroundStyle(currentTab == tab ? ClarityStyle.ink : ClarityStyle.inkFaint)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 55)
                    .background {
                        if currentTab == tab {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.white.opacity(0.66))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(Color.white.opacity(0.92), lineWidth: 0.9)
                                }
                                .shadow(color: Color.black.opacity(0.07), radius: 12, y: 7)
                                .padding(.horizontal, 3)
                                .padding(.vertical, 5)
                                .matchedGeometryEffect(id: "clarity-dock-selection", in: selectionNamespace)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 7)
        .padding(.bottom, 1)
    }

    @Namespace private var selectionNamespace

    private func openPlayer() {
        switch playback.playSource {
        case .fm: NotificationCenter.default.post(name: .init("OpenFMPlayer"), object: nil)
        case let .podcast(id): NotificationCenter.default.post(name: .init("OpenRadioPlayer"), object: id)
        case .normal: NotificationCenter.default.post(name: .init("OpenNormalPlayer"), object: nil)
        }
    }
}

/// Keeps the playback clock out of the dock's membrane and navigation subtree.
private struct ClarityDockProgress: View {
    @ObservedObject private var time = PlaybackTimePublisher.shared

    var body: some View {
        GeometryReader { proxy in
            let progress = time.duration > 0
                ? min(max(time.currentTime / time.duration, 0), 1)
                : 0
            Capsule()
                .fill(ClarityStyle.accent.opacity(0.78))
                .frame(width: proxy.size.width * progress, height: 2)
        }
        .accessibilityHidden(true)
    }
}
