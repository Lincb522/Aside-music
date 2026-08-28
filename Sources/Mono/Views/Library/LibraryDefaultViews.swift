import Combine
import QQMusicKit
import SwiftUI
import UniformTypeIdentifiers

struct MyPlaylistsContainerView: View {
    @ObservedObject var viewModel: LibraryViewModel
    @ObservedObject private var settings = SettingsManager.shared
    @State private var selectedSubTab: Int = 0
    typealias Theme = PlaylistDetailView.Theme

    var body: some View {
        let _ = settings.globalThemeRevision
        VStack(spacing: 0) {
            if NeumorphicStyle.isActive {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        subTabButton(title: String(localized: "lib_local_playlists"), index: 0)
                        subTabButton(title: String(localized: "lib_netease_playlists"), index: 1)
                        subTabButton(title: String(localized: "QCM歌单"), index: 2)
                        subTabButton(title: "KCM 歌单", index: 3)
                        subTabButton(title: String(localized: "apple_music_library"), index: 4)
                        subTabButton(title: String(localized: "lib_my_podcasts"), index: 5)
                    }
                    .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
                .padding(.bottom, 12)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 7) {
                        subTabButton(title: String(localized: "lib_local_playlists"), index: 0)
                        subTabButton(title: String(localized: "lib_netease_playlists"), index: 1)
                        subTabButton(title: String(localized: "QCM歌单"), index: 2)
                        subTabButton(title: "KCM 歌单", index: 3)
                        subTabButton(title: String(localized: "apple_music_library"), index: 4)
                        subTabButton(title: String(localized: "lib_my_podcasts"), index: 5)
                    }
                    .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
                }
                .scrollIndicators(.hidden)
                .themeRenderScrollLayer()
                .padding(.bottom, 14)
            }

            ZStack {
                LocalPlaylistsView(viewModel: viewModel)
                    .opacity(selectedSubTab == 0 ? 1 : 0)
                    .allowsHitTesting(selectedSubTab == 0)

                NetEasePlaylistsView(viewModel: viewModel)
                    .opacity(selectedSubTab == 1 ? 1 : 0)
                    .allowsHitTesting(selectedSubTab == 1)

                QQPlaylistsView(viewModel: viewModel)
                    .opacity(selectedSubTab == 2 ? 1 : 0)
                    .allowsHitTesting(selectedSubTab == 2)

                KCMPlaylistsView(viewModel: viewModel)
                    .opacity(selectedSubTab == 3 ? 1 : 0)
                    .allowsHitTesting(selectedSubTab == 3)

                AppleMusicLibraryView()
                    .opacity(selectedSubTab == 4 ? 1 : 0)
                    .allowsHitTesting(selectedSubTab == 4)

                MyPodcastsView()
                    .opacity(selectedSubTab == 5 ? 1 : 0)
                    .allowsHitTesting(selectedSubTab == 5)
            }
        }
        .background(Color.clear)
    }

    private func subTabButton(title: String, index: Int) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedSubTab = index
            }
        }) {
            Group {
                if MangaStyle.isActive {
                    Text(title)
                        .font(MangaStyle.labelFont(11, weight: selectedSubTab == index ? .black : .bold))
                        .foregroundStyle(
                            selectedSubTab == index
                                ? ThemeColorCustomization.readableForegroundColor(on: MangaStyle.labelYellow, light: MangaStyle.ink, dark: MangaStyle.onStrokeInk)
                                : MangaStyle.inkMuted
                        )
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous)
                                .fill(selectedSubTab == index ? MangaStyle.labelYellow : MangaStyle.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous)
                                .stroke(MangaStyle.strokeInk, lineWidth: selectedSubTab == index ? MangaStyle.strokeWidth : MangaStyle.fineStrokeWidth)
                        )
                } else if MujiStyle.isActive {
                    // Muji：目次式子页签，前置圆点 + 墨色层级
                    HStack(spacing: 6) {
                        Circle()
                            .fill(selectedSubTab == index ? MujiStyle.clay : MujiStyle.separator.opacity(0.85))
                            .frame(width: 4, height: 4)

                        Text(title)
                            .font(MujiStyle.labelFont(12, weight: selectedSubTab == index ? .semibold : .regular))
                            .foregroundStyle(selectedSubTab == index ? MujiStyle.ink : MujiStyle.inkMuted)
                            .lineLimit(1)
                    }
                    .padding(.vertical, 8)
                    .padding(.trailing, 4)
                } else if NeumorphicStyle.isActive {
                    HStack(spacing: 7) {
                        MonoIcon(
                            icon: neumorphicSubTabIcon(index),
                            size: 12,
                            color: selectedSubTab == index ? neumorphicSubTabTint(index) : NeumorphicStyle.inkSoft,
                            lineWidth: 1.55
                        )

                        Text(title)
                            .font(NeumorphicStyle.labelFont(12, weight: selectedSubTab == index ? .semibold : .medium))
                            .foregroundStyle(selectedSubTab == index ? NeumorphicStyle.ink : NeumorphicStyle.inkSoft)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        NeumorphicSurfaceBackground(
                            cornerRadius: 15,
                            elevated: selectedSubTab == index,
                            pressed: selectedSubTab != index,
                            tint: selectedSubTab == index ? neumorphicSubTabTint(index).opacity(0.18) : NeumorphicStyle.surface,
                            lightweight: true
                        )
                    )
                } else {
                    // aside：胶囊分段，与主页签的下划线区分层级
                    Text(title)
                        .font(.system(size: 12.5, weight: selectedSubTab == index ? .bold : .medium, design: .rounded))
                        .foregroundColor(
                            selectedSubTab == index
                                ? Theme.text
                                : Theme.secondaryText.opacity(0.75)
                        )
                        .lineLimit(1)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(
                                selectedSubTab == index
                                    ? Color.monoTextPrimary.opacity(0.075)
                                    : Color.clear
                            )
                        )
                        .overlay(
                            Capsule().stroke(
                                selectedSubTab == index
                                    ? Color.monoTextPrimary.opacity(0.1)
                                    : Color.clear,
                                lineWidth: 1
                            )
                        )
                        .animation(.none, value: selectedSubTab)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func neumorphicSubTabIcon(_ index: Int) -> MonoIcon.IconType {
        switch index {
        case 0: return .musicNoteList
        case 1, 2: return .list
        case 3: return .musicNote
        case 4: return .radio
        default: return .library
        }
    }

    private func neumorphicSubTabTint(_ index: Int) -> Color {
        switch index {
        case 0: return NeumorphicStyle.accent
        case 1: return MusicSource.netease.themedBadgeColor
        case 2: return MusicSource.qqmusic.themedBadgeColor
        case 3: return MusicSource.appleMusic.themedBadgeColor
        case 4: return NeumorphicStyle.sage
        default: return NeumorphicStyle.warm
        }
    }
}
