import SwiftUI
import FFmpegSwiftSDK

/// 经典播放器布局 - 完全还原原始 FullScreenPlayerView 布局，仅增加主题切换按钮
struct ClassicPlayerLayout: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject var downloadManager = DownloadManager.shared
    @ObservedObject var lyricVM = LyricViewModel.shared
    @ObservedObject var settings = SettingsManager.shared
    @StateObject var asideCoverColors = CoverColorExtractor()

    @State var isDraggingSlider = false
    @State var dragTimeValue: Double = 0
    @State var showPlaylist = false
    @State var showQualitySheet = false
    @State var showLyrics = false
    @State var showComments = false
    @State var showEQSettings = false
    @State var showThemePicker = false
    @State var showMoreMenu = false
    @State var showArtistDetail = false
    @State var showDownloadSheet = false


    var isThemedClassic: Bool { ThemedPageStyle.isActive }

    var contentColor: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.ink }
        if MangaStyle.isActive { return MangaStyle.ink }
        if MujiStyle.isActive { return MujiStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if CapsuleStyle.isActive { return CapsuleStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        if ClayStyle.isActive { return ClayStyle.ink }
        return .monoTextPrimary
    }

    var secondaryContentColor: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.inkMuted }
        if MangaStyle.isActive { return MangaStyle.inkSub }
        if MujiStyle.isActive { return MujiStyle.inkSoft }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if CapsuleStyle.isActive { return CapsuleStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        if ClayStyle.isActive { return ClayStyle.inkSoft }
        return .monoTextSecondary
    }

    var asideCoverAccent: Color {
        guard player.currentSong != nil else { return .monoIconBackground }
        return asideCoverColors.dominantColor
    }

    var asideCoverAccentForeground: Color {
        ThemeColorCustomization.readableForegroundColor(
            on: asideCoverAccent,
            light: Color(hex: "111318"),
            dark: .white
        )
    }

    var progressColor: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.ink }
        if MangaStyle.isActive { return MangaStyle.accentPink }
        if MujiStyle.isActive { return MujiStyle.clay }
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        if CapsuleStyle.isActive { return CapsuleStyle.accent }
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        if ClayStyle.isActive { return ClayStyle.accent }
        return contentColor.opacity(0.7)
    }

    var classicArtworkCornerRadius: CGFloat {
        if MinimalWhiteStyle.isActive { return 12 }
        if MangaStyle.isActive { return 12 }
        if MujiStyle.isActive { return 22 }
        if NeumorphicStyle.isActive { return 22 }
        if CapsuleStyle.isActive { return 28 }
        if SequoiaStyle.isActive { return 24 }
        if ClayStyle.isActive { return 30 }
        return isThemedClassic ? 24 : 14
    }

    func classicTitleFont(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.titleFont(size, weight: weight) }
        if MangaStyle.isActive { return MangaStyle.titleFont(size, weight: .black) }
        if MujiStyle.isActive { return MujiStyle.titleFont(size, weight: weight == .bold ? .medium : weight) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.titleFont(size, weight: weight == .bold ? .semibold : weight) }
        if CapsuleStyle.isActive { return CapsuleStyle.titleFont(size, weight: weight == .bold ? .bold : weight) }
        if SequoiaStyle.isActive { return SequoiaStyle.titleFont(size, weight: weight == .bold ? .semibold : weight) }
        if ClayStyle.isActive { return ClayStyle.titleFont(size, weight: weight == .bold ? .bold : weight) }
        return .rounded(size: size, weight: weight)
    }

    func classicBodyFont(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.bodyFont(size, weight: weight) }
        if MangaStyle.isActive { return MangaStyle.bodyFont(size, weight: weight == .regular ? .bold : weight) }
        if MujiStyle.isActive { return MujiStyle.bodyFont(size, weight: weight == .bold ? .medium : weight) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.bodyFont(size, weight: weight) }
        if CapsuleStyle.isActive { return CapsuleStyle.bodyFont(size, weight: weight) }
        if SequoiaStyle.isActive { return SequoiaStyle.bodyFont(size, weight: weight == .bold ? .semibold : weight) }
        if ClayStyle.isActive { return ClayStyle.bodyFont(size, weight: weight) }
        return .rounded(size: size, weight: weight)
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        GeometryReader { geometry in
            ZStack {
                if isThemedClassic {
                    classicThemeBackdrop
                }

                if showLyrics && !isThemedClassic {
                    Rectangle()
                        .fill(Color.monoGlassTint)
                        .monoGlass(cornerRadius: 16)
                        .ignoresSafeArea()
                        .transition(.opacity)
                }

                if MangaStyle.isActive {
                    mangaPlayerContent(geometry: geometry)
                } else if MujiStyle.isActive {
                    mujiPlayerContent(geometry: geometry)
                } else if NeumorphicStyle.isActive {
                    neumorphicPlayerContent(geometry: geometry)
                } else if CapsuleStyle.isActive {
                    capsulePlayerContent(geometry: geometry)
                } else if ClayStyle.isActive {
                    clayPlayerContent(geometry: geometry)
                } else if isThemedClassic {
                    classicPlayerContent(geometry: geometry)
                } else {
                    asideDefaultPlayerContent(geometry: geometry)
                }

                // 三点菜单浮层
                if showMoreMenu {
                    PlayerMoreMenu(
                        isPresented: $showMoreMenu,
                        onEQ: { showEQSettings = true },
                        onTheme: { showThemePicker = true }
                    )
                }
            }
        }
        .monoSheet(isPresented: $showPlaylist, preset: .standard){
            PlaylistPopupView()

        }
        .onAppear {
            refreshAsideCoverAccent()
        }
        .onChange(of: player.currentSong?.coverUrl?.absoluteString) { _, _ in
            refreshAsideCoverAccent()
        }
        .onChange(of: isThemedClassic) { _, themed in
            if !themed {
                refreshAsideCoverAccent()
            }
        }
        .monoSheet(isPresented: $showQualitySheet, preset: .standard){
            SoundQualitySheet(
                currentQuality: player.soundQuality,
                currentQQQuality: player.qqMusicQuality,
                isQQMusic: player.currentSong?.isQQMusic == true,
                onSelectNetease: { quality in
                    player.switchQuality(quality)
                    showQualitySheet = false
                },
                onSelectQQ: { quality in
                    player.switchQQMusicQuality(quality)
                    showQualitySheet = false
                },
                songMid: player.currentSong?.qqMid,
                songId: player.currentSong?.id,
                isQishui: player.currentSong?.isQishui == true,
                qishuiTrackId: player.currentSong?.qishuiTrackId,
                onSelectQishui: { info in player.switchQishuiQuality(info); showQualitySheet = false }
            )

        }
        .fullScreenCover(isPresented: $showEQSettings) {
            NavigationStack { MonoAudioCenterView() }

        }
        .monoSheet(isPresented: $showThemePicker, preset: .themePicker){
            PlayerThemePickerSheet()

        }
        .monoSheet(isPresented: $showComments, preset: .large){
            if let song = player.currentSong {
                CommentView(song: song)

            }
        }
        .monoSheet(isPresented: $showArtistDetail, preset: .detail){
            if let song = player.currentSong {
                NavigationStack {
                    if song.isQQMusic, let mid = song.qqArtistMid {
                        QQMusicDetailView(detailType: .artist(mid: mid, name: song.artistName, coverUrl: nil))
                    } else if let artistId = song.ar?.first?.id {
                        ArtistDetailView(artistId: artistId)
                    }
                }

            }
        }
        .monoSheet(isPresented: $showDownloadSheet, preset: .compact){
            if let song = player.currentSong {
                DownloadQualitySheet(song: song) {
                    showDownloadSheet = false
                }

            }
        }
    }

}
