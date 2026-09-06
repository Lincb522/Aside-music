import SwiftUI

/// 通透主题自己的连续底座：歌曲条从页面内容与导航之间浮起，导航仍是
/// 同一层膜面的一部分，不使用通用悬浮胶囊骨架。
struct ClarityDock: View {
    @Binding var currentTab: Tab
    private let playback = FloatingBarPlaybackModel.shared
    @State private var currentSong = FloatingBarPlaybackModel.shared.currentSong
    @State private var isPlaying = FloatingBarPlaybackModel.shared.isPlaying
    @State private var playSource = FloatingBarPlaybackModel.shared.playSource
    @State private var showsQueue = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(spacing: 0) {
                if currentSong != nil { nowPlaying }
                navigation
            }
            .background {
                ClarityMembrane(
                    shape: RoundedRectangle(cornerRadius: 34, style: .continuous),
                    strength: .strong
                )
            }
            .frame(maxWidth: 680)
            .padding(.horizontal, DeviceLayout.usesExpandedLayout ? 28 : 14)
            .padding(.bottom, 5)
        }
        .monoSheet(isPresented: $showsQueue, preset: .standard) {
            playSource.isPodcast ? AnyView(PodcastPlaylistPopupView()) : AnyView(PlaylistPopupView())
        }
        .onReceive(playback.$currentSong.removeDuplicates()) { song in
            currentSong = song
        }
        .onReceive(playback.$isPlaying.removeDuplicates()) { playing in
            isPlaying = playing
        }
        .onReceive(playback.$playSource.removeDuplicates()) { source in
            playSource = source
        }
    }

    private var nowPlaying: some View {
        HStack(spacing: 10) {
            Button(action: openPlayer) {
                ClarityArtwork(url: currentSong?.coverUrl, size: 44, radius: 13)
            }
            .buttonStyle(ClarityPressStyle())

            Button(action: openPlayer) {
                VStack(alignment: .leading, spacing: 3) {
                    MarqueeText(
                        text: currentSong?.name ?? String(localized: "not_playing"),
                        font: .system(size: 12.5, weight: .semibold, design: .default),
                        color: ClarityStyle.ink
                    )
                    FloatingBarLyricReader { lyricLineText in
                        Text(lyricLineText ?? currentSong?.artistName ?? "")
                            .font(ClarityStyle.body(10, weight: .medium))
                            .foregroundStyle(ClarityStyle.inkSoft)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button { playback.togglePlayPause() } label: {
                MonoIcon(icon: isPlaying ? .pause : .play, size: 17, color: ClarityStyle.ink, lineWidth: 1.7)
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
                            lineWidth: currentTab == tab ? 1.9 : 1.45,
                            artworkContrastBackground: currentTab == tab ? .white : nil
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
    @Environment(\.floatingBarColorRevision) private var colorRevision
    @ObservedObject private var time = PlaybackTimePublisher.shared

    var body: some View {
        let _ = colorRevision

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
